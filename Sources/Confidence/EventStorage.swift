import Foundation

internal protocol EventStorage {
    func startNewBatch() throws
    func writeEvent(event: Event) throws
    func batchReadyFiles() throws -> [URL]
    func eventsFrom(fileURL: URL) throws -> [Event]
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

    func startNewBatch() throws {
        let urlString = "\(fileURL)"+"\(EventStorageImpl.READYTOSENDEXTENSION)"
        let newPath = URL(fileURLWithPath: urlString)
        try FileManager.default.moveItem(at: fileURL, to: newPath)
        fileURL = folderURL.appendingPathComponent("events-\(Date().currentTime)")
        currentBatch = []
    }
    
    func writeEvent(event: Event) throws {
        currentBatch.append(event)
        let data = try encoder.encode(currentBatch)
        try data.write(to: fileURL, options: .atomic)
    }
    
    func batchReadyFiles() throws -> [URL] {
        var readyFilesList: [URL] = []
        let directoryContents = try FileManager.default.contentsOfDirectory(atPath: folderURL.absoluteString)
        for file in directoryContents {
            if file.hasSuffix(EventStorageImpl.READYTOSENDEXTENSION) {
                readyFilesList.append(URL(string: file)!)
            }
        }
        return readyFilesList
    }
    
    func eventsFrom(fileURL: URL) throws -> [Event] {
        let data = try Data(contentsOf: fileURL)
        let events = try decoder.decode([Event].self, from: data)
        return events
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
