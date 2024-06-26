import Foundation

class VisitorUtil {
    let defaults = UserDefaults.standard
    let userDefaultsKey = "confidence.visitor_id"
    func getId() -> String {
        let id = defaults.string(forKey: userDefaultsKey) ?? ""
        if id.isEmpty {
            let newId = UUID.init().uuidString
            defaults.set(newId, forKey: userDefaultsKey)
            defaults.synchronize()
            return newId
        } else {
            return id
        }
    }
}
