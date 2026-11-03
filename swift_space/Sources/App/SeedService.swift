import SwiftData
import Foundation

enum SeedService {
    static func seedIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<AppSettings>()
        let settings: AppSettings
        if let existing = try? context.fetch(descriptor).first {
            settings = existing
        } else {
            settings = AppSettings()
            context.insert(settings)
        }
        
        guard !settings.didSeed else { return }
        
        // PSX Classic
        let psxMacros: [(String, String, String, String)] = [
            ("psx_candy", "Joins PSX Classic, goes to Heaven's Island, toggles pet sending to Single and grinds candy forever until stopped", "grinding", "Pet Simulator X"),
            ("psx_chest", "Grinds chests in PSX Classic", "grinding", "Pet Simulator X"),
            ("psx_final_egg", "Goes to the final egg and auto hatches; switches to psx_candy when out of coins", "hatching", "Pet Simulator X"),
            ("psx_halloween", "Halloween 2021 event – hatches the Cursed Egg; switches to psx_candy when out of coins", "event", "Pet Simulator X"),
            ("psx_classic", "Joins PSX Classic", "utility", "Pet Simulator X")
        ]
        for m in psxMacros {
            let macro = Macro(name: formatName(m.0), command: m.0, macroDescription: m.1, category: "psxClassic", subcategory: m.2, game: m.3)
            context.insert(macro)
        }
        
        // PS99
        let ps99Macros: [(String, String, String)] = [
            ("best_area", "Teleports to the best unlocked area and starts grinding", "grinding"),
            ("start_raid", "Starts a raid and begins farming", "grinding"),
            ("world_1", "Goes to World 1 and starts farming", "grinding"),
            ("world_4", "Goes to World 4 and starts farming", "grinding"),
            ("vault_raid", "Starts a vault raid", "grinding"),
            ("raid_xp_boosters", "Uses Lucky Raid XP boosters", "grinding"),
            ("gifts", "Claims available gifts", "event"),
            ("rankup", "Starts the rank-up sequence", "event"),
            ("default_hoverboard", "Equips the default hoverboard", "event")
        ]
        for m in ps99Macros {
            let macro = Macro(name: formatName(m.0), command: m.0, macroDescription: m.1, category: "ps99", subcategory: m.2, game: "Pet Simulator 99")
            context.insert(macro)
        }
        
        // Utility
        let utilMacros: [(String, String)] = [
            ("stop", "Stops all running macros and releases held keys"),
            ("reconnect", "Kills Roblox and relaunches, waits for load"),
            ("send_screenshot", "Takes a screenshot and posts it to Discord"),
            ("stats", "Posts current game stats to Discord"),
            ("toggle_autoclicker", "Toggles the autoclicker on/off with F4"),
            ("open_autoclicker", "Opens AutoClicker if not running"),
            ("autoclicker_check", "Checks if AutoClicker is running and clicking"),
            ("focus_roblox", "Brings Roblox window to front and maximizes"),
            ("check_disconnect", "Checks if disconnected and reconnects if needed"),
            ("close_all", "Closes all running processes"),
            ("close_ahks", "Closes all AHK scripts except itself"),
            ("cancel", "Cancels current operation"),
            ("mouse_correction", "Runs mouse position correction"),
            ("pause_disconnect", "Pauses disconnect checking"),
            ("unpause_disconnect", "Resumes disconnect checking"),
            ("enable_autoclicker_warning", "Enables AutoClicker not-clicking warnings"),
            ("disable_autoclicker_warning", "Disables AutoClicker warnings"),
            ("help", "Shows the command list in Discord")
        ]
        for m in utilMacros {
            let macro = Macro(name: formatName(m.0), command: m.0, macroDescription: m.1, category: "utility", subcategory: "utility", game: "Utility")
            context.insert(macro)
        }
        
        settings.didSeed = true
        try? context.save()
    }
    
    private static func formatName(_ command: String) -> String {
        command.split(separator: "_").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }
}
