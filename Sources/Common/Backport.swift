import Foundation

<<<<<<<< HEAD:Sources/Confidence/Backport.swift
public extension URL {
    struct Backport {
|||||||| parent of 44209ae (Finalize the network layer for events):Sources/ConfidenceProvider/Utils/Backport.swift
extension URL {
    struct Backport {
========
extension URL {
    public struct Backport {
>>>>>>>> 44209ae (Finalize the network layer for events):Sources/Common/Backport.swift
        var base: URL

        public init(base: URL) {
            self.base = base
        }
    }

    public var backport: Backport {
        Backport(base: self)
    }
}

<<<<<<<< HEAD:Sources/Confidence/Backport.swift
public extension URL.Backport {
    var path: String {
|||||||| parent of 44209ae (Finalize the network layer for events):Sources/ConfidenceProvider/Utils/Backport.swift
extension URL.Backport {
    var path: String {
========
extension URL.Backport {
    public var path: String {
>>>>>>>> 44209ae (Finalize the network layer for events):Sources/Common/Backport.swift
        if #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
            return self.base.path(percentEncoded: false)
        } else {
            return self.base.path
        }
    }

    public func appending<S>(components: S...) -> URL where S: StringProtocol {
        if #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
            return components.reduce(self.base) { acc, cur in
                return acc.appending(component: cur)
            }
        } else {
            return components.reduce(self.base) { acc, cur in
                return acc.appendingPathComponent(String(cur))
            }
        }
    }
}

<<<<<<<< HEAD:Sources/Confidence/Backport.swift
public extension Date {
    struct Backport {
|||||||| parent of 44209ae (Finalize the network layer for events):Sources/ConfidenceProvider/Utils/Backport.swift
extension Date {
    struct Backport {
========
extension Date {
    public struct Backport {
>>>>>>>> 44209ae (Finalize the network layer for events):Sources/Common/Backport.swift
    }

    static public var backport: Backport.Type { Backport.self }
}

<<<<<<<< HEAD:Sources/Confidence/Backport.swift
public extension Date.Backport {
    static var now: Date {
|||||||| parent of 44209ae (Finalize the network layer for events):Sources/ConfidenceProvider/Utils/Backport.swift
extension Date.Backport {
    static var now: Date {
========
extension Date.Backport {
    static public var now: Date {
>>>>>>>> 44209ae (Finalize the network layer for events):Sources/Common/Backport.swift
        if #available(macOS 12, iOS 15, tvOS 15, watchOS 8, *) {
            return Date.now
        } else {
            return Date()
        }
    }

    static public var nowISOString: String {
        if #available(macOS 12, iOS 15, tvOS 15, watchOS 8, *) {
            return toISOString(date: Date.now)
        } else {
            return toISOString(date: Date())
        }
    }

    static func toISOString(date: Date) -> String {
        if #available(macOS 12, iOS 15, tvOS 15, watchOS 8, *) {
            return date.ISO8601Format()
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.timeZone = TimeZone(abbreviation: "GMT")
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
            return dateFormatter.string(from: date).appending("Z")
        }
    }
}
