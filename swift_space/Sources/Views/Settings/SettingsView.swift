import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(CredentialStore.self) private var credentials
    @Environment(\.modelContext) private var context
    @Query private var settings: [AppSettings]
    
    @State private var testResult: String?
    @State private var isTesting = false
    @State private var showClearConfirm = false
    
    private var appSettings: AppSettings {
        if let s = settings.first { return s }
        let s = AppSettings()
        context.insert(s)
        try? context.save()
        return s
    }
    
    private var accent: Color { Color(hex: appSettings.accentHex) }
    
    var body: some View {
        NavigationStack {
            List {
                Section("Discord") {
                    NavigationLink {
                        CredentialsFormView(isOnboarding: false)
                    } label: {
                        HStack {
                            Text("Bot Token")
                            Spacer()
                            Text(credentials.maskedToken)
                                .font(.caption.monospaced())
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                    
                    NavigationLink {
                        CredentialsFormView(isOnboarding: false)
                    } label: {
                        HStack {
                            Text("Channel ID")
                            Spacer()
                            Text(credentials.channelId)
                                .font(.caption.monospaced())
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                    
                    Button {
                        testConnection()
                    } label: {
                        HStack {
                            Text("Test Connection")
                            Spacer()
                            if isTesting {
                                ProgressView()
                            } else if let result = testResult {
                                Text(result)
                                    .font(.caption)
                                    .foregroundStyle(result.contains("Connected") ? Theme.statusGreen : Color(hex: "FF0000"))
                            }
                        }
                    }
                    
                    Button(role: .destructive) {
                        showClearConfirm = true
                    } label: {
                        Text("Clear Credentials")
                    }
                }
                
                Section("Appearance") {
                    NavigationLink("Tab Icons") {
                        TabIconsView()
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Accent Color")
                        HStack(spacing: 12) {
                            ForEach(Theme.accentPresets, id: \.1) { name, hex, color in
                                Button {
                                    appSettings.accentHex = hex
                                    try? context.save()
                                } label: {
                                    Circle()
                                        .fill(color)
                                        .frame(width: 32, height: 32)
                                        .overlay {
                                            if appSettings.accentHex == hex {
                                                Circle().stroke(.white, lineWidth: 2)
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    Toggle("Haptics", isOn: Binding(
                        get: { appSettings.hapticsEnabled },
                        set: { newVal in
                            appSettings.hapticsEnabled = newVal
                            try? context.save()
                        }
                    ))
                }
                
                Section("Refresh") {
                    Picker("Auto-refresh Interval", selection: Binding(
                        get: { appSettings.refreshInterval },
                        set: { newVal in
                            appSettings.refreshInterval = newVal
                            try? context.save()
                        }
                    )) {
                        Text("10s").tag(10)
                        Text("15s").tag(15)
                        Text("30s").tag(30)
                        Text("60s").tag(60)
                        Text("Off").tag(0)
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(Theme.secondaryText)
                    }
                    Text("AFK Remote sends commands to your Discord channel; your PC macro bot reads them.")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                    Text("Your token stays in this device’s Keychain and is only sent to discord.com.")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Settings")
            .alert("Clear Credentials?", isPresented: $showClearConfirm) {
                Button("Clear", role: .destructive) {
                    credentials.clear()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You’ll need to re-enter your bot token and channel ID.")
            }
        }
    }
    
    private func testConnection() {
        isTesting = true
        testResult = nil
        Task {
            do {
                let discord = DiscordService()
                let channel = try await discord.getChannel(id: credentials.channelId, token: credentials.botToken)
                testResult = "Connected to #\(channel.name ?? credentials.channelId)"
            } catch {
                testResult = error.localizedDescription
            }
            isTesting = false
        }
    }
}
