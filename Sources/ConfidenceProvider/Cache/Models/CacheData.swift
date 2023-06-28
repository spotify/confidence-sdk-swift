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
        let resolveEventIndex = resolveEvents.firstIndex(where: { resolveEvent in
            resolveEvent.resolveToken == resolveToken
        })

        if let resolveEventIndex {
            let resolveEvent =  resolveEvents[resolveEventIndex]
            let flagEventIndex = resolveEvent.events.firstIndex { flagEvent in
                flagEvent.name == flagName
            }
            if let flagEventIndex {
                let applyEvent = ApplyEvent(id: UUID(), applyTime: applyTime)
                resolveEvents[resolveEventIndex].events[flagEventIndex].applyEvents.append(applyEvent)
            } else {
                let flagEvent = FlagEvent(name: flagName, applyTime: applyTime)
                resolveEvents[resolveEventIndex].events.append(flagEvent)
            }
        } else {
            let event = ResolveEvent(resolveToken: resolveToken, flagName: flagName, applyTime: applyTime)
            resolveEvents.append(event)
        }
    }

    mutating func remove(resolveToken:String, flagName: String, uuid: UUID) {
        let resolveEventIndex = resolveEvents.firstIndex(where: { resolveEvent in
            resolveEvent.resolveToken == resolveToken
        })

        guard let resolveEventIndex else {
            return
        }

        let resolveEvent = resolveEvents[resolveEventIndex]
        let flagEventIndex = resolveEvent.events.firstIndex(where: { event in
            event.name == flagName
        })

        guard let flagEventIndex else {
            return
        }

        var flagEvent = resolveEvent.events[flagEventIndex]

        let applyEventIndex = flagEvent.applyEvents.firstIndex(where: { applyEvent in
            applyEvent.id == uuid
        })

        guard let applyEventIndex = applyEventIndex else {
            return
        }

        flagEvent.applyEvents.remove(at: applyEventIndex)

        if flagEvent.applyEvents.isEmpty {
            resolveEvents[resolveEventIndex].events.remove(at: flagEventIndex)
        }
    }
}
