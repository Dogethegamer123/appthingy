import SwiftUI
import SwiftData

struct MainTabView: View {
    @State private var router = AppRouter()
    @State private var feedStore = FeedStore()
    @Environment(CredentialStore.self) private var credentials
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query private var settings: [AppSettings]
    
    private var appSettings: AppSettings? { settings.first }
    private var accent: Color { Color(hex: appSettings?.accentHex ?? Theme.defaultAccent) }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $router.selectedTab) {
                Tab(value: AppTab.macros) {
                    MacrosView()
                }
                Tab(value: AppTab.schedule) {
                    ScheduleView()
                }
                Tab(value: AppTab.home) {
                    HomeView()
                }
                Tab(value: AppTab.feed) {
                    FeedView()
                }
                Tab(value: AppTab.settings) {
                    SettingsView()
                }
            }
            .toolbar(.hidden, for: .tabBar)
            
            AFKTabBar(selectedTab: $router.selectedTab, accent: accent)
        }
        .environment(router)
        .environment(feedStore)
        .tint(accent)
        .onAppear {
            feedStore.loadCache(context: context)
            Task { await feedStore.refresh(credentials: credentials, context: context) }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await feedStore.refresh(credentials: credentials, context: context) }
            }
        }
    }
}
