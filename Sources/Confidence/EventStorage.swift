import Foundation
import os

internal protocol EventStorage {
    func startNewBatch() throws
    func writeEvent(event: Event) throws
    func batchReadyIds() throws -> [String]
    func eventsFrom(id: String) throws -> [Event]
    func remove(id: String) throws
}

internal class EventStorageImpl: EventStorage {
    private let READYTOSENDEXTENSION = "READY"
    private let storageQueue = DispatchQueue(label: "com.confidence.events.storage")
    private var folderURL: URL
    private var currentFileUrl: URL?
    private var currentFileHandle: FileHandle?

    init() throws {
        self.folderURL = try EventStorageImpl.getFolderURL()
        if !FileManager.default.fileExists(atPath: folderURL.backport.path) {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }
        try resetCurrentFile()
    }

    func startNewBatch() throws {
        try storageQueue.sync {
            guard let currentFileName = self.currentFileUrl else {
                return
            }
            try currentFileHandle?.close()
            try FileManager.default.moveItem(at: currentFileName, to: currentFileName.appendingPathExtension(READYTOSENDEXTENSION))
            try resetCurrentFile()
        }
    }

    func writeEvent(event: Event) throws {
        try storageQueue.sync {
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
    }


    func batchReadyIds() throws -> [String] {
        try storageQueue.sync {
            let fileUrls = try FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
            return fileUrls.filter({ url in url.pathExtension == READYTOSENDEXTENSION }).map({ url in url.lastPathComponent })
        }
    }

    func eventsFrom(id: String) throws -> [Event] {
        try storageQueue.sync {
            let decoder = JSONDecoder()
            let fileUrl = folderURL.appendingPathComponent(id)
            let data = try Data(contentsOf: fileUrl)
            let dataString = String(data: data, encoding: .utf8)
            return try dataString?.components(separatedBy: "\n")
                .filter({ events in !events.isEmpty })
                .map({ eventString in try decoder.decode(Event.self, from: eventString.data(using: .utf8)!) }) ?? []
        }
    }

    func remove(id: String) throws {
        try storageQueue.sync {
                let fileUrl = folderURL.appendingPathComponent(id)
                try FileManager.default.removeItem(at: fileUrl)
        }
    }

    private func getLastWritingFile() throws -> URL? {
        let files = try FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
        for fileUrl in files {
            if fileUrl.pathExtension != READYTOSENDEXTENSION {
                return fileUrl
            }
        }
        return nil
    }

    private func resetCurrentFile() throws {
        if let currentFile = try getLastWritingFile() {
            self.currentFileUrl = currentFile
            self.currentFileHandle = try FileHandle(forWritingTo: currentFile)
        } else {
            let fileUrl = folderURL.appendingPathComponent(String(Date().timeIntervalSince1970))
            FileManager.default.createFile(atPath: fileUrl.path, contents: nil)
            self.currentFileUrl = fileUrl
            self.currentFileHandle = try FileHandle(forWritingTo: fileUrl)
        }
    }

    internal static func getFolderURL() throws -> URL {
        guard
            let applicationSupportUrl = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
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
}

struct Event: Codable {
    let eventDefinition: String
    let eventTime: Date
    // TODO: fix this to be ConfidenceValue
    let payload: [String]
    let context: [String]
}
