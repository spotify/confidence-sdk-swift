import Foundation
import os

internal protocol EventStorage {
    func startNewBatch() throws
    func writeEvent(event: Event) throws
    func batchReadyIds() throws -> [String]
    func eventsFrom(id: String) throws -> [Event]
    func remove(id: String)
}

internal class EventStorageImpl: EventStorage {
    private let READYTOSENDEXTENSION = "READY"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var folderURL: URL
    private var currentFileUrl: URL? = nil
    private var currentFileHandle: FileHandle? = nil
    private var currentBatch: [Event] = []

    init() throws {
        self.folderURL = try EventStorageImpl.getFolderURL()
        try FileManager.default.removeItem(at: folderURL)
        if(!FileManager.default.fileExists(atPath: folderURL.backport.path)) {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }

        try resetCurrentFile()
    }

    func startNewBatch() throws {
        guard let currentFileName = self.currentFileUrl else {
            return
        }

        try currentFileHandle?.close()
        try FileManager.default.moveItem(at: currentFileName, to: currentFileName.appendingPathExtension(READYTOSENDEXTENSION))
        try resetCurrentFile()
    }
    
    func writeEvent(event: Event) throws {
        guard let currentFileHandle = currentFileHandle else {
            return
        }
        let encoder = JSONEncoder()
        let serialied = try encoder.encode(event)
        let delimiter = "\n".data(using: .utf8)
        guard let delimiter else {
            return
        }
        currentFileHandle.seekToEndOfFile()
        try currentFileHandle.write(contentsOf: delimiter)
        try currentFileHandle.write(contentsOf: serialied)
    }


    func batchReadyIds() throws -> [String]{
        let folderUrl = try FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
        return folderUrl.filter({ url in url.pathExtension ==  READYTOSENDEXTENSION}).map({ url in url.lastPathComponent })
    }
    
    func eventsFrom(id: String) throws -> [Event] {
        let decoder = JSONDecoder()
        let fileUrl = folderURL.appendingPathComponent(id)
        let data = try Data(contentsOf: fileUrl)
        let dataString = String(data: data, encoding: .utf8)
        return try dataString?.components(separatedBy: "\n")
            .filter({ events in !events.isEmpty })
            .map({eventString in try decoder.decode(Event.self, from: eventString.data(using: .utf8)!)}) ?? []
    }

    func remove(id: String) {
        do {
            let fileUrl = folderURL.appendingPathComponent(id)
            try FileManager.default.removeItem(at: fileUrl)
        } catch {
            Logger(subsystem: "com.confidence.eventsender", category: "storage").error(
                "Error when trying to delete an event batch: \(error)")
        }
    }

    private func currentWritingFile() throws -> URL? {
        let files = try FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
        for fileUrl in files {
            if fileUrl.pathExtension != READYTOSENDEXTENSION {
                return fileUrl
            }
        }
        return nil
    }

    private func resetCurrentFile() throws {
        if let currentFile = try currentWritingFile() {
            self.currentFileUrl = currentFile
            self.currentFileHandle = try FileHandle(forWritingTo: currentFile)
        } else {
            let fileUrl = folderURL.appendingPathComponent(Date().currentTime)
            FileManager.default.createFile(atPath: fileUrl.path, contents: nil)
            self.currentFileUrl = fileUrl
            self.currentFileHandle = try FileHandle(forWritingTo: fileUrl)
        }
    }

    private static func getFolderURL() throws -> URL {
        guard
            let applicationSupportUrl: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .last
        else {
            throw ConfidenceError.cacheError(message: "Could not get URL for application directory")
        }

        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            throw ConfidenceError.cacheError(message: "Unable to get bundle identifier")
        }

        return applicationSupportUrl.backport.appending(
            components: "com.confidence.cache", "\(bundleIdentifier)", "events")
    }

    private func latestWriteFile() throws -> URL? {
        var directoryContents: [URL] = []
        do {
            directoryContents = try FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: [])
        } catch {
            Logger(subsystem: "com.confidence.eventsender", category: "storage").error(
            "No previous batch file found \(error)")
        }
        for fileUrl in directoryContents {
            if fileUrl.pathExtension.lowercased() == READYTOSENDEXTENSION  {
                return fileUrl
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
