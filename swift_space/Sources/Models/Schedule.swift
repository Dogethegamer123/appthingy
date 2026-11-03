import SwiftData
import Foundation

@Model
final class Schedule {
    var id: UUID
    var macroId: UUID
    var time: Date
    var repeatType: String // once, daily, weekdays
    var selectedWeekdays: [Int] // 1=Sun...7=Sat
    var isEnabled: Bool
    var lastFiredAt: Date?
    
    init(id: UUID = UUID(), macroId: UUID, time: Date = .now, repeatType: String = "once", selectedWeekdays: [Int] = [], isEnabled: Bool = true, lastFiredAt: Date? = nil) {
        self.id = id
        self.macroId = macroId
        self.time = time
        self.repeatType = repeatType
        self.selectedWeekdays = selectedWeekdays
        self.isEnabled = isEnabled
        self.lastFiredAt = lastFiredAt
    }
}
