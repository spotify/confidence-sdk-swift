import Foundation

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
