import SwiftUI
import SwiftData

@main
struct AfkRemoteIosApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [
            Macro.self,
            Schedule.self,
            ActiveMacroState.self,
            AppSettings.self,
            TabIconConfig.self,
            CachedFeed.self
        ])
    }
}
