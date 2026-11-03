import SwiftUI
import SwiftData

struct RootView: View {
    @State private var credentials = CredentialStore()
    @Environment(\.modelContext) private var context
    
    var body: some View {
        Group {
            if credentials.isConfigured {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .environment(credentials)
        .preferredColorScheme(.dark)
        .onAppear {
            SeedService.seedIfNeeded(context: context)
        }
    }
}
