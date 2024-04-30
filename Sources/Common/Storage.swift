import Foundation

public protocol Storage {
    func save(data: Encodable) throws

    func load<T>(defaultValue: T) throws -> T where T: Decodable

    func clear() throws

    func isEmpty() -> Bool
}
