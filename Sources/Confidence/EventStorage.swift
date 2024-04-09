import Foundation
import os

internal protocol EventStorage {
    func startNewBatch()
    func writeEvent(event: Event)
    func batchReadyIds() -> [String]
    func eventsFrom(id: String) -> [Event]
    func remove(id: String)
}

internal class EventStorageImpl: EventStorage {
    static let DIRECTORY = "events"
    static let READYTOSENDEXTENSION = ".ready"
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    let folderURL: URL
    var fileURL: URL
    var currentBatch: [Event] = []

    init() throws {
        folderURL = URL(fileURLWithPath: try EventStorageImpl.getFolderURL())
        fileURL = folderURL.appendingPathComponent("events-\(Date().currentTime)")
    }

    func startNewBatch() {
        let urlString = "\(fileURL)"+"\(EventStorageImpl.READYTOSENDEXTENSION)"
        let newPath = URL(fileURLWithPath: urlString)
        do {
            try FileManager.default.moveItem(at: fileURL, to: newPath)
        } catch {
            Logger(subsystem: "com.confidence.eventsender", category: "storage").error(
            "Error when trying to start a new batch: \(error)")
        }
        fileURL = folderURL.appendingPathComponent("events-\(Date().currentTime)")
        currentBatch = []
    }
    
    func writeEvent(event: Event) {
        currentBatch.append(event)
        do {
            let data = try encoder.encode(currentBatch)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            Logger(subsystem: "com.confidence.eventsender", category: "storage").error(
            "Error when trying to write to disk: \(error)")
        }
    }
    
    func batchReadyIds() -> [String] {
        var readyFilesList: [String] = []
        var directoryContents: [String] = []
        do {
            directoryContents = try FileManager.default.contentsOfDirectory(atPath: folderURL.absoluteString)
        } catch {
            Logger(subsystem: "com.confidence.eventsender", category: "storage").error(
            "Error when trying to read contents of directory on disk: \(error)")
        }
        for file in directoryContents {
            if file.hasSuffix(EventStorageImpl.READYTOSENDEXTENSION) {
                readyFilesList.append(file)
            }
        }
        return readyFilesList
    }
    
    func eventsFrom(id: String) -> [Event] {
        var events: [Event] = []
        do {
            let currentData = try Data(contentsOf: URL(string: id)!)
            events = try decoder.decode([Event].self, from: currentData)
        } catch {
            Logger(subsystem: "com.confidence.eventsender", category: "storage").error(
            "Error when trying to get events at path: \(error)")
        }
        return events
    }

    func remove(id: String) {
        do {
            try FileManager.default.removeItem(atPath: id)
        } catch {
            Logger(subsystem: "com.confidence.eventsender", category: "storage").error(
                "Error when trying to delete an event batch: \(error)")
        }
    }

    private static func getFolderURL() throws -> String {
        let rootFolderURL = try FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        var nestedFolderURL: String
        if #available(iOS 16.0, *) {
            nestedFolderURL = rootFolderURL.appending(path: DIRECTORY).absoluteString
        } else {
            nestedFolderURL = rootFolderURL.appendingPathComponent(DIRECTORY, isDirectory: true).absoluteString
        }
        return nestedFolderURL
    }
}

struct Event: Codable {
    let eventDefinition: String
    let eventTime: Date
    // TODO: fix this to be ConfidenceValue
    let payload: [String]
    let context: [String]
}


extension Date {
    var currentTime: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        return dateFormatter.string(from: self)
    }
}
