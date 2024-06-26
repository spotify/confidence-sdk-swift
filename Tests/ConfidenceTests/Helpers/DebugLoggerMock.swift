import Foundation
import XCTest

@testable import Confidence

internal class DebugLoggerMock: DebugLogger {
    var eventsLogged = 0
    var messagesLogged = 0
    var flagsLogged = 0
    var contextLogs = 0

    func logEvent(event: ConfidenceEvent, action: String) {
        eventsLogged+=1
    }
    
    func logMessage(message: String, isWarning: Bool) {
        messagesLogged+=1
    }
    
    func logFlags(flag: String) {
        flagsLogged+=1
    }
    
    func logContext(context: ConfidenceStruct) {
        contextLogs+=1
    }

}
