import Foundation

public protocol Storage {
    func save(data: Encodable) throws

    func load<T>(_ type: T.Type, defaultValue: T) throws -> T where T: Decodable

    func clear() throws
}
