import Foundation
import OpenFeature

@testable import KonfidensProvider

class MockedKonfidensClientURLProtocol: URLProtocol {
    public static var callStats = 0
    public static var resolveStats: [String: Int] = [:]
    public static var batchResolveStats = 0
    public static var applyStats = 0
    public static var flags: [String: TestFlag] = [:]
    public static var failFirstApply = false

    static func set(flags: [String: TestFlag]) {
        MockedKonfidensClientURLProtocol.flags = flags
    }

    static func mockedSession(flags: [String: TestFlag]) -> URLSession {
        MockedKonfidensClientURLProtocol.set(flags: flags)
        let config = URLSessionConfiguration.default
        config.protocolClasses = [MockedKonfidensClientURLProtocol.self]

        return URLSession(configuration: config)
    }

    static func reset() {
        MockedKonfidensClientURLProtocol.flags = [:]
        MockedKonfidensClientURLProtocol.callStats = 0
        MockedKonfidensClientURLProtocol.resolveStats = [:]
        MockedKonfidensClientURLProtocol.batchResolveStats = 0
        MockedKonfidensClientURLProtocol.applyStats = 0
        MockedKonfidensClientURLProtocol.failFirstApply = false
    }

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let path = request.url?.absoluteString, request.httpMethod == "POST" else {
            client?.urlProtocol(self, didFailWithError: NSError(domain: "test", code: URLError.badURL.rawValue))
            return
        }

        switch path {
        case _ where path.hasSuffix(":resolve"):
            return resolve()
        case _ where path.hasSuffix(":apply"):
            return MockedKonfidensClientURLProtocol.failFirstApply
                ? apply(failAt: 1)
                : apply()
        default:
            client?.urlProtocol(self, didFailWithError: NSError(domain: "test", code: URLError.badURL.rawValue))
            return
        }
    }

    override func stopLoading() {
        // This is called if the request gets canceled or completed.
    }

    private func resolve() {
        MockedKonfidensClientURLProtocol.callStats += 1
        MockedKonfidensClientURLProtocol.batchResolveStats += 1

        guard let request = request.decodeBody(type: RemoteKonfidensClient.ResolveFlagsRequest.self) else {
            client?.urlProtocol(
                self, didFailWithError: NSError(domain: "test", code: URLError.cannotDecodeRawData.rawValue))
            return
        }

        guard case .string(let targetingKey) = request.evaluationContext.fields["targeting_key"] else {
            respondWithError(
                statusCode: 400,
                code: GrpcStatusCode.invalidArgument.rawValue,
                message: "Request missing field targeting_key")
            return
        }

        let flags = MockedKonfidensClientURLProtocol.flags
            .filter { _, flag in
                flag.isArchived == false
            }
            .map { flagName, flag in
                guard let resolved = flag.resolve[targetingKey], let schema = flag.schemas[targetingKey] else {
                    return RemoteKonfidensClient.ResolvedFlag(flag: flagName, reason: .noSegmentMatch)
                }
                var responseValue: Struct?
                do {
                    responseValue = try TypeMapper.from(value: resolved.value)
                } catch {
                    respondWithError(statusCode: 500, code: GrpcStatusCode.internalError.rawValue, message: "\(error)")
                }

                if responseValue == nil {
                    respondWithError(
                        statusCode: 400,
                        code: GrpcStatusCode.invalidArgument.rawValue,
                        message: "Could not convert value to response")
                }
                return RemoteKonfidensClient.ResolvedFlag(
                    flag: flagName, value: responseValue, variant: resolved.variant, flagSchema: schema, reason: .match)
            }
        respondWithSuccess(
            response: RemoteKonfidensClient.ResolveFlagsResponse(resolvedFlags: flags, resolveToken: "token1"))
    }

    private func apply(failAt: Int = 0) {
        MockedKonfidensClientURLProtocol.callStats += 1
        MockedKonfidensClientURLProtocol.applyStats += 1
        if MockedKonfidensClientURLProtocol.applyStats == failAt {
            respondWithError(
                statusCode: 500, code: GrpcStatusCode.internalError.rawValue, message: "Server error")
        }

        guard let request = request.decodeBody(type: RemoteKonfidensClient.ApplyFlagsRequest.self) else {
            client?.urlProtocol(
                self, didFailWithError: NSError(domain: "test", code: URLError.cannotDecodeRawData.rawValue))
            return
        }

        request.flags.forEach { flag in
            guard flag.flag.hasPrefix("flags/") else {
                respondWithError(
                    statusCode: 400, code: GrpcStatusCode.failedPrecondition.rawValue, message: "Incorrect flag name")
                return
            }
        }
        respondWithSuccess(response: RemoteKonfidensClient.ApplyFlagsResponse())
    }

    private func respondWithError(statusCode: Int, code: Int, message: String) {
        let error = HttpError(code: code, message: message, details: [])
        let errorData = try? JSONEncoder().encode(error)

        let response = HTTPURLResponse(
            // swiftlint:disable:next force_unwrapping
            url: request.url!, statusCode: statusCode, httpVersion: "", headerFields: [:])!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if let errorData = errorData {
            client?.urlProtocol(self, didLoad: errorData)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    private func respondWithSuccess(response: Codable) {
        // swiftlint:disable:next force_unwrapping
        let httpResponse = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "", headerFields: [:])!

        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)

        if let data = try? JSONEncoder().encode(response) {
            client?.urlProtocol(self, didLoad: data)
        }

        client?.urlProtocolDidFinishLoading(self)
    }
}

extension MockedKonfidensClientURLProtocol {
    struct ResolvedTestFlag {
        var variant: String
        var value: Value
    }

    struct TestFlag {
        var resolve: [String: ResolvedTestFlag]
        var schemas: [String: StructFlagSchema]
        var isArchived: Bool

        init(
            resolve: [String: ResolvedTestFlag],
            schemas: [String: StructFlagSchema],
            isArchived: Bool = false
        ) {
            self.resolve = resolve
            self.schemas = schemas
            self.isArchived = isArchived
        }

        init(resolve: [String: ResolvedTestFlag], isArchived: Bool = false) {
            self.resolve = resolve
            self.schemas = resolve.compactMapValues { value in
                guard case .structure(let structure) = value.value else {
                    return nil
                }

                let schema = structure.compactMapValues(TestFlag.toSchema)

                return StructFlagSchema(schema: schema)
            }
            self.isArchived = isArchived
        }

        // swiftlint:disable:next cyclomatic_complexity
        private static func toSchema(value: Value) -> FlagSchema? {
            switch value {
            case .boolean:
                return FlagSchema.boolSchema
            case .string:
                return FlagSchema.stringSchema
            case .integer:
                return FlagSchema.intSchema
            case .double:
                return FlagSchema.doubleSchema
            case .date:
                return nil
            case .list(let list):
                if list.isEmpty {
                    return nil
                }

                let schemas = list.compactMap(TestFlag.toSchema)
                guard let firstSchema = schemas.first else {
                    return nil
                }

                if !schemas.allSatisfy({ $0 == firstSchema }) {
                    return nil
                }

                return FlagSchema.listSchema(firstSchema)
            case .structure(let structure):
                if structure.isEmpty {
                    return nil
                }

                let schemas = structure.compactMapValues(TestFlag.toSchema)

                return FlagSchema.structSchema(StructFlagSchema(schema: schemas))
            case .null:
                return nil
            }
        }
    }
}

extension URLRequest {
    func decodeBody<T: Codable>(type: T.Type) -> T? {
        guard let bodyStream = self.httpBodyStream else { return nil }

        bodyStream.open()

        let bufferSize: Int = 128
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)

        var data = Data()
        while bodyStream.hasBytesAvailable {
            let readBytes = bodyStream.read(buffer, maxLength: bufferSize)
            data.append(buffer, count: readBytes)
        }

        buffer.deallocate()

        bodyStream.close()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(type, from: data)
        } catch {
            return nil
        }
    }
}
