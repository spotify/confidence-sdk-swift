import Foundation

struct CacheData: Codable {
    typealias ResolveToken = String

    var data: [ResolveToken: FlagEvents]

    var isEmpty: Bool {
        if data.isEmpty {
            return true
        }

        let nonEmptyItem = self.data.first(where: { item in
            !item.value.isEmpty
        })

        return nonEmptyItem == nil
    }
}

struct FlagEvents: Codable {
    typealias FlagName = String
    typealias AppliedDate = Date

    var data: [FlagName: [UUID: AppliedDate]]

    var isEmpty: Bool {
        if data.isEmpty {
            return true
        }

        let nonEmptyItem = self.data.first(where: { item in
            !item.value.isEmpty
        })

        return nonEmptyItem == nil
    }
}

extension CacheData {
    func flagEvents(resolveToken: ResolveToken) -> FlagEvents? {
        self.data[resolveToken]
    }

    mutating func addEvent(resolveToken: String, flagName: String, applyTime: Date) {
        guard var flagEvents = self.flagEvents(resolveToken: resolveToken) else {
            // Event is not in the cache, adding new record
            let eventEntry = [UUID(): applyTime]
            self.data[resolveToken] = FlagEvents(data: [flagName: eventEntry])
            return
        }

        if flagEvents.data[flagName] == nil {
            // apply event for this flag has not been added
            flagEvents.data[flagName] = [UUID(): applyTime]
        } else {
            // apply event for this flag has been added
            flagEvents.data[flagName]?[UUID()] = applyTime
        }
        self.data[resolveToken] = flagEvents
    }

    mutating func remove(resolveToken: String, flagName: String, uuid: UUID) {
        self.data[resolveToken]?.data[flagName]?.removeValue(forKey: uuid)

        if isEmpty {
            self.data = [:]
        }
    }
}
