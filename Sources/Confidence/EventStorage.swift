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
    private static let DIRECTORY = "events"
    private static let READYTOSENDEXTENSION = ".ready"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let currentFolderURL: URL
    private var currentFileURL: URL
    private var currentBatch: [Event] = []

    init() throws {
        currentFolderURL = URL(fileURLWithPath: try EventStorageImpl.getFolderURL())
        currentFileURL = EventStorageImpl.latestWriteFile() ?? currentFolderURL.appendingPathComponent("events-\(Date().currentTime)")
    }

    func startNewBatch() {
        guard let latestWriteFile = EventStorageImpl.latestWriteFile() else {
            let urlString = "\(currentFileURL)\(EventStorageImpl.READYTOSENDEXTENSION)"
            let newPath = URL(fileURLWithPath: urlString)
            do {
                try FileManager.default.moveItem(at: currentFileURL, to: newPath)
            } catch {
                Logger(subsystem: "com.confidence.eventsender", category: "storage").error(
                "Error when trying to start a new batch: \(error)")
            }
            currentFileURL = currentFolderURL.appendingPathComponent("events-\(Date().currentTime)")
            currentBatch = []
            return
        }
        currentFileURL = latestWriteFile
        currentBatch = eventsFrom(id: latestWriteFile.absoluteString)
    }
    
    func writeEvent(event: Event) {
        currentBatch.append(event)
        do {
            let data = try encoder.encode(currentBatch)
            try data.write(to: currentFileURL, options: .atomic)
        } catch {
            Logger(subsystem: "com.confidence.eventsender", category: "storage").error(
            "Error when trying to write to disk: \(error)")
        }
    }
    
    func batchReadyIds() -> [String] {
        var readyFilesList: [String] = []
        var directoryContents: [String] = []
        do {
            directoryContents = try FileManager.default.contentsOfDirectory(atPath: currentFolderURL.absoluteString)
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

    private static func latestWriteFile() -> URL? {
        var directoryContents: [String] = []
        do {
            directoryContents = try FileManager.default.contentsOfDirectory(atPath: EventStorageImpl.getFolderURL())
        } catch {
            Logger(subsystem: "com.confidence.eventsender", category: "storage").error(
            "Error when trying to read contents of directory on disk: \(error)")
        }
        for file in directoryContents {
            if !file.hasSuffix(EventStorageImpl.READYTOSENDEXTENSION) {
                return URL(string: file)
            }
        }
        return nil
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

