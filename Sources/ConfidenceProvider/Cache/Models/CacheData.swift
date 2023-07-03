import Foundation

/**
 `CacheData` represents object that encapsulates exposure events for evaluated flags.
It holds information related to apply event i.e. resolve token, flag name, timestamp .
 This object is used for tracking exposure events, i.e. by storing them on disk.
 */
struct CacheData: Codable {
    var resolveEvents: [ResolveApply]

    var isEmpty: Bool {
        resolveEvents.isEmpty
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

    static func empty() -> CacheData {
        CacheData(resolveEvents: [])
    }

    mutating func add(resolveToken: String, flagName: String, applyTime: Date) {
        let resolveEventIndex = resolveEvents.firstIndex { resolveEvent in
            resolveEvent.resolveToken == resolveToken
        }

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
            }
        } else {
            // No resolve event for given resolve token, adding new record
            let event = ResolveApply(resolveToken: resolveToken, flagName: flagName, applyTime: applyTime)
            resolveEvents.append(event)
        }
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

        // Flag apply event with given flag name exists, cleaning it  up
        resolveEvents[resolveEventIndex].events.remove(at: flagEventIndex)

        if resolveEvents[resolveEventIndex].isEmpty {
            resolveEvents.remove(at: resolveEventIndex)
        }
    }
}
