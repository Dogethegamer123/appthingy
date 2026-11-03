import SwiftUI
import SwiftData

@Model
final class Macro {
    var id: UUID
    var name: String
    var command: String
    var macroDescription: String
    var category: String
    var subcategory: String
    var game: String
    @Attribute(.externalStorage) var imageData: Data?
    var dateCreated: Date
    var isCustom: Bool
    
    init(id: UUID = UUID(), name: String, command: String, macroDescription: String, category: String, subcategory: String, game: String, imageData: Data? = nil, dateCreated: Date = .now, isCustom: Bool = false) {
        self.id = id
        self.name = name
        self.command = command
        self.macroDescription = macroDescription
        self.category = category
        self.subcategory = subcategory
        self.game = game
        self.imageData = imageData
        self.dateCreated = dateCreated
        self.isCustom = isCustom
    }
}

enum MacroCategory: String, CaseIterable {
    case psxClassic
    case ps99
    case utility
    
    var displayName: String {
        switch self {
        case .psxClassic: return "PSX Classic"
        case .ps99: return "PS99"
        case .utility: return "Utility"
        }
    }
    
    var game: String {
        switch self {
        case .psxClassic: return "Pet Simulator X"
        case .ps99: return "Pet Simulator 99"
        case .utility: return "Utility"
        }
    }
    
    var icon: String {
        switch self {
        case .psxClassic: return "pawprint.fill"
        case .ps99: return "sparkles"
        case .utility: return "wrench.and.screwdriver.fill"
        }
    }
    
    var gradientStart: Color {
        switch self {
        case .psxClassic: return Color(hex: "3A1C1C")
        case .ps99: return Color(hex: "1C263A")
        case .utility: return Color(hex: "262626")
        }
    }
}

enum MacroSubcategory: String, CaseIterable {
    case event
    case grinding
    case hatching
    case utility
    
    var displayName: String {
        switch self {
        case .event: return "Event"
        case .grinding: return "Grinding"
        case .hatching: return "Hatching"
        case .utility: return "Utility"
        }
    }
    
    static var displayOrder: [MacroSubcategory] {
        [.event, .grinding, .hatching, .utility]
    }
}
