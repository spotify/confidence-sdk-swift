import Foundation

public class DefaultStorage: Storage {
    private let storageQueue = DispatchQueue(label: "com.confidence.storage")
    private let resolverCacheBundleId = "com.confidence.cache"
    private let filePath: String

    init(filePath: String) {
        self.filePath = filePath
    }

    public func save(data: Encodable) throws {
        try storageQueue.sync {
            let encoded = try JSONEncoder().encode(data)
            let configUrl = try getConfigUrl()

            if !FileManager.default.fileExists(atPath: configUrl.backport.path) {
                try FileManager.default.createDirectory(
                    at: configUrl.deletingLastPathComponent(), withIntermediateDirectories: true)
            }

            do {
                try encoded.write(to: configUrl, options: .atomic)
            } catch {
                throw ConfidenceError.cacheError(message: "Unable to encode: \(error)")
            }
        }
    }

    public func load<T>(defaultValue: T) throws -> T where T: Decodable {
        try storageQueue.sync {
            let configUrl = try getConfigUrl()
            guard FileManager.default.fileExists(atPath: configUrl.backport.path) else {
                return defaultValue
            }

            let data = try {
                do {
                    return try Data(contentsOf: configUrl)
                } catch {
                    throw ConfidenceError.cacheError(message: "Unable to load cache file: \(error)")
                }
            }()

            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw ConfidenceError.corruptedCache(message: "Unable to decode: \(error)")
            }
        }
    }

    public func clear() throws {
        try storageQueue.sync {
            let configUrl = try getConfigUrl()
            if !FileManager.default.fileExists(atPath: configUrl.backport.path) {
                return
            }

            do {
                try FileManager.default.removeItem(atPath: configUrl.backport.path)
            } catch {
                throw ConfidenceError.cacheError(message: "Unable to clear cache: \(error)")
            }
        }
    }

    func getConfigUrl() throws -> URL {
        guard
            let applicationSupportUrl = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .last
        else {
            throw ConfidenceError.cacheError(message: "Could not get URL for application directory")
        }

        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            throw ConfidenceError.cacheError(message: "Unable to get bundle identifier")
        }

        return applicationSupportUrl.backport.appending(
            components: resolverCacheBundleId, "\(bundleIdentifier)", filePath)
    }
}
