import SwiftUI
import SwiftData

/// A macro category (PS99, PSX Classic, Utility, TTD, ...). Fully user-editable:
/// the three built-ins are seeded on first launch, and the user can add, rename,
/// recolor and delete their own. `key` is the stable value stored in `Macro.category`
/// and never changes once created, so renaming a category keeps its macros attached.
@Model
final class MacroCategoryModel {
    var id: UUID
    var key: String
    var name: String
    var iconSymbol: String
    var colorHex: String
    var game: String
    var sortOrder: Int
    var isBuiltIn: Bool

    init(id: UUID = UUID(),
         key: String,
         name: String,
         iconSymbol: String,
         colorHex: String,
         game: String,
         sortOrder: Int,
         isBuiltIn: Bool = false) {
        self.id = id
        self.key = key
        self.name = name
        self.iconSymbol = iconSymbol
        self.colorHex = colorHex
        self.game = game
        self.sortOrder = sortOrder
        self.isBuiltIn = isBuiltIn
    }

    var gradientStart: Color { Color(hex: colorHex) }

    /// The built-in categories seeded on first launch (and back-filled for users
    /// who already have macros from an older version).
    static let builtInSeeds: [MacroCategoryModel] = [
        MacroCategoryModel(key: "psxClassic", name: "PSX Classic", iconSymbol: "pawprint.fill",
                           colorHex: "3A1C1C", game: "Pet Simulator X", sortOrder: 0, isBuiltIn: true),
        MacroCategoryModel(key: "ps99", name: "PS99", iconSymbol: "sparkles",
                           colorHex: "1C263A", game: "Pet Simulator 99", sortOrder: 1, isBuiltIn: true),
        MacroCategoryModel(key: "utility", name: "Utility", iconSymbol: "wrench.and.screwdriver.fill",
                           colorHex: "262626", game: "Utility", sortOrder: 2, isBuiltIn: true)
    ]

    /// Color choices offered in the category editor (dark gradient starts that suit the theme).
    static let colorChoices: [String] = [
        "3A1C1C", "1C263A", "262626", "2A1C3A",
        "1C3A2A", "3A341C", "1C3A3A", "3A1C2E",
        "1C1C3A", "3A271C"
    ]
}
