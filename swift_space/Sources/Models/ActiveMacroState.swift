import SwiftData
import Foundation

@Model
final class ActiveMacroState {
    var macroName: String
    var command: String
    var startTime: Date
    var startedFromApp: Bool
    
    init(macroName: String, command: String, startTime: Date = .now, startedFromApp: Bool = true) {
        self.macroName = macroName
        self.command = command
        self.startTime = startTime
        self.startedFromApp = startedFromApp
    }
}
