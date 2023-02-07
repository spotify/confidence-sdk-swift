import Foundation

public class DefaultStorage: Storage {
    private static let storageQueue = DispatchQueue(label: "com.konfidens.storage")
    public static let resolverCacheBundleId = "com.konfidens.cache"
    public static let resolverCacheFilename = "resolver.cache"

    public func save(data: Encodable) throws {
        try DefaultStorage.storageQueue.sync {
            let encoded = try JSONEncoder().encode(data)
            let configUrl = try DefaultStorage.getConfigUrl()

            if !FileManager.default.fileExists(atPath: configUrl.backport.path) {
                try FileManager.default.createDirectory(
                    at: configUrl.deletingLastPathComponent(), withIntermediateDirectories: true)
            }

            do {
                try encoded.write(to: configUrl, options: .atomic)
            } catch {
                throw KonfidensError.cacheError(message: "Unable to encode: \(error)")
            }
        }
    }

    public func load<T>(_ type: T.Type, defaultValue: T) throws -> T where T: Decodable {
        try DefaultStorage.storageQueue.sync {
            let configUrl = try DefaultStorage.getConfigUrl()
            guard FileManager.default.fileExists(atPath: configUrl.backport.path) else {
                return defaultValue
            }

            let data = try {
                do {
                    return try Data(contentsOf: configUrl)
                } catch {
                    throw KonfidensError.cacheError(message: "Unable to load cache file: \(error)")
                }
            }()

            do {
                return try JSONDecoder().decode(type, from: data)
            } catch {
                throw KonfidensError.corruptedCache(message: "Unable to decode: \(error)")
            }
        }
    }

    public func clear() throws {
        try DefaultStorage.storageQueue.sync {
            let configUrl = try DefaultStorage.getConfigUrl()
            if !FileManager.default.fileExists(atPath: configUrl.backport.path) {
                return
            }

            do {
                try FileManager.default.removeItem(atPath: configUrl.backport.path)
            } catch {
                throw KonfidensError.cacheError(message: "Unable to clear cache: \(error)")
            }
        }
    }

    static func getConfigUrl() throws -> URL {
        guard
            let applicationSupportUrl = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .last
        else {
            throw KonfidensError.cacheError(message: "Could not get URL for application directory")
        }

        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            throw KonfidensError.cacheError(message: "Unable to get bundle identifier")
        }

        return applicationSupportUrl.backport.appending(
            components: resolverCacheBundleId, "\(bundleIdentifier)", resolverCacheFilename)
    }
}
