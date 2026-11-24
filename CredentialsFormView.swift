import SwiftUI

struct CredentialsFormView: View {
    var isOnboarding = false
    @Environment(CredentialStore.self) private var credentials
    @Environment(\.dismiss) private var dismiss
    
    @State private var token: String = ""
    @State private var channelId: String = ""
    @State private var testResult: TestResult?
    @State private var isTesting = false
    @State private var showSaveConfirm = false
    
    enum TestResult {
        case success(String)
        case failure(String)
    }
    
    private var canSave: Bool {
        !token.trimmingCharacters(in: .whitespaces).isEmpty &&
        !channelId.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacing24) {
                VStack(alignment: .leading, spacing: Theme.spacing8) {
                    Text("Bot Token")
                        .font(.headline)
                        .foregroundStyle(Theme.primaryText)
                    AppTextField(title: "Paste your bot token", text: $token, isSecure: true)
                }
                
                VStack(alignment: .leading, spacing: Theme.spacing8) {
                    Text("Channel ID")
                        .font(.headline)
                        .foregroundStyle(Theme.primaryText)
                    AppTextField(title: "Enter channel ID", text: $channelId)
                        .keyboardType(.numberPad)
                }
                
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 8) {
                        helpStep("1.", "Go to Discord Developer Portal → Bot → Reset Token")
                        helpStep("2.", "Enable Message Content Intent")
                        helpStep("3.", "Invite the bot with View Channel, Send Messages, Read Message History and Attach Files permissions")
                        helpStep("4.", "Turn on Developer Mode → right-click the channel → Copy Channel ID")
                    }
                    .padding(.top, 8)
                } label: {
                    Text("Where do I find these?")
                        .font(.subheadline)
                        .foregroundStyle(Color(hex: "FF0000"))
                }
                
                // Test result
                if let result = testResult {
                    HStack(spacing: 8) {
                        switch result {
                        case .success(let name):
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.statusGreen)
                            Text("Connected to #\(name)")
                                .foregroundStyle(Theme.statusGreen)
                        case .failure(let msg):
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color(hex: "FF0000"))
                            Text(msg)
                                .foregroundStyle(Color(hex: "FF0000"))
                        }
                    }
                    .font(.subheadline)
                }
                
                Button {
                    testConnection()
                } label: {
                    HStack {
                        if isTesting {
                            ProgressView().tint(Theme.primaryText)
                        }
                        Text("Test Connection")
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(!canSave || isTesting)
                
                Button {
                    if case .success = testResult {
                        saveCredentials()
                    } else {
                        showSaveConfirm = true
                    }
                } label: {
                    Text(isOnboarding ? "Save & Continue" : "Save")
                }
                .buttonStyle(PrimaryButtonStyle(accent: Color(hex: "FF0000")))
                .disabled(!canSave)
            }
            .padding(Theme.spacing16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(isOnboarding ? "Setup" : "Credentials")
        .navigationBarTitleDisplayMode(.large)
        .alert("Connection not verified", isPresented: $showSaveConfirm) {
            Button("Save Anyway") { saveCredentials() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The connection hasn’t been tested. Save anyway?")
        }
        .onAppear {
            if !isOnboarding {
                token = credentials.botToken
                channelId = credentials.channelId
            }
        }
    }
    
    @ViewBuilder
    private func helpStep(_ num: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(num).font(.caption.bold()).foregroundStyle(Theme.secondaryText)
            Text(text).font(.caption).foregroundStyle(Theme.secondaryText)
        }
    }
    
    private func testConnection() {
        isTesting = true
        testResult = nil
        Task {
            do {
                let discord = DiscordService()
                let channel = try await discord.getChannel(id: channelId.trimmingCharacters(in: .whitespaces), token: token.trimmingCharacters(in: .whitespaces))
                testResult = .success(channel.name ?? channelId)
            } catch {
                testResult = .failure(error.localizedDescription)
            }
            isTesting = false
        }
    }
    
    private func saveCredentials() {
        credentials.save(token: token.trimmingCharacters(in: .whitespaces), channelId: channelId.trimmingCharacters(in: .whitespaces))
        if !isOnboarding {
            dismiss()
        }
    }
}
