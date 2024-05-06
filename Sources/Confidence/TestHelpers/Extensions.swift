import Foundation

extension URLRequest {
    public func decodeBody<T: Codable>(type: T.Type) -> T? {
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

extension [ResolvedValue] {
    func toCacheData(context: ConfidenceStruct, resolveToken: String) -> FlagResolution {
        return FlagResolution(
            context: context,
            flags: self,
            resolveToken: resolveToken
        )
    }
}

/// Used for testing
public protocol DispatchQueueType {
    func async(execute work: @escaping @convention(block) () -> Void)
}

extension DispatchQueue: DispatchQueueType {
    public func async(execute work: @escaping @convention(block) () -> Void) {
        async(group: nil, qos: .unspecified, flags: [], execute: work)
    }
}
