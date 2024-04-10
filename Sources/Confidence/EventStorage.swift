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
        print("events-\(Date().currentTime)")
        let possibleFileURL = currentFolderURL.appendingPathComponent("events-\(Date().currentTime)")
        EventStorageImpl.createNewFile(path: possibleFileURL)
        currentFileURL = possibleFileURL
    }

    func startNewBatch() {
        //
        if FileManager.default.fileExists(atPath: currentFileURL.absoluteString) {
            print("😍 file exists")
        }
        //
        let urlString = "\(currentFileURL)\(EventStorageImpl.READYTOSENDEXTENSION)"
        let newPath = URL(fileURLWithPath: urlString)
        do {
            try FileManager.default.moveItem(at: currentFileURL, to: newPath)
        } catch {
            Logger(subsystem: "com.confidence.eventsender", category: "storage").error(
            "Error when trying to start a new batch: \(error)")
        }
        currentFileURL = currentFolderURL.appendingPathComponent("events-\(Date().currentTime)")
        EventStorageImpl.createNewFile(path: currentFileURL)
        currentBatch = []
        return
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
            nestedFolderURL = rootFolderURL.appending(path: EventStorageImpl.DIRECTORY).absoluteString
        } else {
            nestedFolderURL = rootFolderURL.appendingPathComponent(EventStorageImpl.DIRECTORY, isDirectory: true).absoluteString
        }
        if !FileManager.default.fileExists(atPath: nestedFolderURL) {
            do {
                try FileManager.default.createDirectory(
                    atPath: nestedFolderURL,
                    withIntermediateDirectories: true,
                    attributes: nil)
            } catch {
                print(error.localizedDescription)
            }
        }
        return nestedFolderURL
    }

    private static func latestWriteFile() throws -> URL? {
        var directoryContents: [String] = []
        do {
            directoryContents = try FileManager.default.contentsOfDirectory(atPath: EventStorageImpl.getFolderURL())
        } catch {
            Logger(subsystem: "com.confidence.eventsender", category: "storage").error(
            "No previous batch file found \(error)")
        }
        for file in directoryContents {
            if !file.hasSuffix(EventStorageImpl.READYTOSENDEXTENSION) {
                return URL(fileURLWithPath: try EventStorageImpl.getFolderURL()).appendingPathComponent(file)
            }
        }
        return nil
    }

    private static func createNewFile(path: URL) {
        FileManager.default.createFile(atPath: path.absoluteString, contents: nil)
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
        dateFormatter.dateStyle = .medium
        dateFormatter.dateFormat = "YY-MM-dd-HH-mm-ss"
        return dateFormatter.string(from: self).replacingOccurrences(of: "%", with: "")
    }
}
