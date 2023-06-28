import Foundation

struct CacheData: Codable {
    var resolveEvents: [ResolveEvent]

    var isEmpty: Bool {
        resolveEvents.isEmpty
    }

    init(resolveToken: String, flagName: String, applyTime: Date) {
        resolveEvents = [
            ResolveEvent(resolveToken: resolveToken, flagName: flagName, applyTime: applyTime)
        ]
    }

    init(resolveToken: String, events: [FlagEvent]) {
        resolveEvents = [ResolveEvent(resolveToken: resolveToken, events: events)]
    }

    private init(resolveEvents: [ResolveEvent]) {
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
            // Resolve event with given resolve token exists
            let resolveEvent = resolveEvents[resolveEventIndex]
            let flagEventIndex = resolveEvent.events.firstIndex { flagEvent in
                flagEvent.name == flagName
            }
            if let flagEventIndex {
                // Flag event for given flag name exists, adding new apply record to it
                let applyEvent = ApplyEvent(id: UUID(), applyTime: applyTime)
                resolveEvents[resolveEventIndex].events[flagEventIndex].applyEvents.append(applyEvent)
            } else {
                // No flag event for given resolve token, adding new record
                let flagEvent = FlagEvent(name: flagName, applyTime: applyTime)
                resolveEvents[resolveEventIndex].events.append(flagEvent)
            }
        } else {
            // No resolve event for given resolve token, adding new record
            let event = ResolveEvent(resolveToken: resolveToken, flagName: flagName, applyTime: applyTime)
            resolveEvents.append(event)
        }
    }

    mutating func remove(resolveToken: String, flagName: String, uuid: UUID) {
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

        // Flag event with given flag name exists
        var flagEvent = resolveEvent.events[flagEventIndex]
        let applyEventIndex = flagEvent.applyEvents.firstIndex { applyEvent in
            applyEvent.id == uuid
        }

        guard let applyEventIndex = applyEventIndex else {
            return
        }
        flagEvent.applyEvents.remove(at: applyEventIndex)

        // Clean flag event if apply events are empty
        if flagEvent.applyEvents.isEmpty {
            resolveEvents[resolveEventIndex].events.remove(at: flagEventIndex)
        }
    }
}
