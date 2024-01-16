import Foundation

/// `CacheData` represents object that encapsulates exposure events for evaluated flags.
/// It holds information related to apply event i.e. resolve token, flag name, timestamp .
/// This object is used for tracking exposure events, i.e. by storing them on disk.
struct CacheData: Codable {
    var resolveEvents: [ResolveApply]

    var isEmpty: Bool {
        resolveEvents.isEmpty || resolveEvents.allSatisfy { $0.isEmpty }
    }

    init(resolveToken: String, flagName: String, applyTime: Date) {
        resolveEvents = [
            ResolveApply(resolveToken: resolveToken, flagName: flagName, applyTime: applyTime)
        ]
    }

    init(resolveToken: String, events: [FlagApply]) {
        resolveEvents = [ResolveApply(resolveToken: resolveToken, events: events)]
    }

    private init(resolveEvents: [ResolveApply]) {
        self.resolveEvents = resolveEvents
    }

    static func convertInTransit(cache: CacheData) -> CacheData {
        var mutatedCache = cache
        for resolveIndex in 0..<mutatedCache.resolveEvents.count {
            for eventIndex in 0..<mutatedCache.resolveEvents[resolveIndex].events.count
            where mutatedCache.resolveEvents[resolveIndex].events[eventIndex].status == .sending {
                mutatedCache.resolveEvents[resolveIndex].events[eventIndex].status = .created
            }
        }
        return mutatedCache
    }

    static func empty() -> CacheData {
        CacheData(resolveEvents: [])
    }

    func applyEventExists(resolveToken: String, name: String) -> Bool {
        let resolveTokenIndex = applyEventIndex(resolveToken: resolveToken, name: name)
        return resolveTokenIndex != nil
    }

    mutating func setEventStatus(resolveToken: String, name: String, status: ApplyEventStatus = .sent) {
        let flagEventIndexes = flagEventIndex(resolveToken: resolveToken, name: name)
        guard let resolveIndex = flagEventIndexes.resolveEventIndex,
            let flagIndex = flagEventIndexes.flagEventIndex
        else {
            return
        }

        resolveEvents[resolveIndex].events[flagIndex].status = status
    }

    mutating func setEventStatus(resolveToken: String, status: ApplyEventStatus = .sent) {
        guard let resolveIndex = resolveEventIndex(resolveToken: resolveToken) else {
            return
        }

        for i in 0..<resolveEvents[resolveIndex].events.count {
            resolveEvents[resolveIndex].events[i].status = status
        }
    }

    mutating func add(resolveToken: String, flagName: String, applyTime: Date) -> Bool {
        let resolveEventIndex = resolveEventIndex(resolveToken: resolveToken)

        if let resolveEventIndex {
            // Resolve apply event with given resolve token exists
            let resolveEvent = resolveEvents[resolveEventIndex]
            let flagEventIndex = resolveEvent.events.firstIndex { flagEvent in
                flagEvent.name == flagName
            }
            if flagEventIndex == nil {
                // No flag apply event for given resolve token, adding new record
                let flagEvent = FlagApply(name: flagName, applyTime: applyTime)
                resolveEvents[resolveEventIndex].events.append(flagEvent)
                return true
            }
        } else {
            // No resolve event for given resolve token, adding new record
            let event = ResolveApply(resolveToken: resolveToken, flagName: flagName, applyTime: applyTime)
            resolveEvents.append(event)
            return true
        }
        return false
    }

    mutating func remove(resolveToken: String) {
        let resolveEventIndex = resolveEvents.firstIndex { resolveEvent in
            resolveEvent.resolveToken == resolveToken
        }

        guard let resolveEventIndex else {
            return
        }

        resolveEvents.remove(at: resolveEventIndex)
    }

    mutating func remove(resolveToken: String, flagName: String) {
        let resolveEventIndex = resolveEvents.firstIndex { resolveEvent in
            resolveEvent.resolveToken == resolveToken
        }

        guard let resolveEventIndex else {
            return
        }
        let resolveEvent = resolveEvents[resolveEventIndex]

        let flagEventIndex = resolveEvent.events.firstIndex { event in
            event.name == flagName
        }
        guard let flagEventIndex else {
            return
        }

        // Flag apply event with given flag name exists, cleaning it up
        resolveEvents[resolveEventIndex].events.remove(at: flagEventIndex)

        if resolveEvents[resolveEventIndex].isEmpty {
            resolveEvents.remove(at: resolveEventIndex)
        }
    }

    func flagEvent(resolveToken: String, name: String) -> FlagApply? {
        guard let resolveTokenIndex = resolveEventIndex(resolveToken: resolveToken),
            let flagEventIndex = applyEventIndex(resolveToken: resolveToken, name: name)
        else {
            return nil
        }

        return resolveEvents[resolveTokenIndex].events[flagEventIndex]
    }

    // MARK: Private

    private func flagEventIndex(resolveToken: String, name: String) -> (resolveEventIndex: Int?, flagEventIndex: Int?) {
        guard let resolveTokenIndex = resolveEventIndex(resolveToken: resolveToken) else {
            return (nil, nil)
        }

        guard let flagEventIndex = applyEventIndex(resolveToken: resolveToken, name: name) else {
            return (resolveTokenIndex, nil)
        }

        return (resolveTokenIndex, flagEventIndex)
    }

    private func resolveEventIndex(resolveToken: String) -> Int? {
        let resolveTokenIndex = resolveEvents.firstIndex { resolveEvent in
            resolveEvent.resolveToken == resolveToken
        }

        return resolveTokenIndex
    }

    private func applyEventIndex(resolveToken: String, name: String) -> Int? {
        guard let resolveTokenIndex = resolveEventIndex(resolveToken: resolveToken) else {
            return nil
        }

        let flagEventIndex = resolveEvents[resolveTokenIndex].events.firstIndex { applyEvent in
            applyEvent.name == name
        }

        return flagEventIndex
    }
}
