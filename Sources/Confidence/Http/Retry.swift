import Foundation

public enum Retry {
    case none
    case exponential(maxBackoff: TimeInterval, maxAttempts: UInt)

    func handler() -> RetryHandler {
        switch self {
        case .none:
            return NoneRetryHandler()
        case let .exponential(maxBackoff, maxAttempts):
            return ExponentialBackoffRetryHandler(maxBackoff: maxBackoff, maxAttempts: maxAttempts)
        }
    }
}

public protocol RetryHandler {
    func retryIn() -> TimeInterval?
}

public class ExponentialBackoffRetryHandler: RetryHandler {
    private var currentAttempts: UInt = 0
    private let maxBackoff: TimeInterval
    private let maxAttempts: UInt

    init(maxBackoff: TimeInterval, maxAttempts: UInt) {
        self.maxBackoff = maxBackoff
        self.maxAttempts = maxAttempts
    }

    public func retryIn() -> TimeInterval? {
        if currentAttempts >= maxAttempts {
            return nil
        }

        let nextRetryTime = min(pow(2, Double(currentAttempts)) + Double.random(in: 0..<1), maxBackoff)

        currentAttempts += 1
        return nextRetryTime
    }
}

public class NoneRetryHandler: RetryHandler {
    public func retryIn() -> TimeInterval? {
        return nil
    }
}
