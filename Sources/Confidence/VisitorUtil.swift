import Foundation
import Common

class VisitorUtil {
    let storage: Storage

    init(storage: Storage) {
        self.storage = storage
    }

    func getId() -> String {
        do {
            let id = try storage.load(defaultValue: "")
            if id.isEmpty {
                let newId = UUID.init().uuidString
                try storage.save(data: newId)
                return newId
            } else {
                return id
            }
        } catch {
            return "storage-error"
        }
    }
}
