import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(AppRouter.self) private var router
    @Environment(FeedStore.self) private var feedStore
    @Environment(CredentialStore.self) private var credentials
    @Environment(\.modelContext) private var context
    @Query private var activeStates: [ActiveMacroState]
    @Query private var allMacros: [Macro]
    @Query private var settings: [AppSettings]
    
    @State private var sendingAction: String?
    @State private var toastMessage: String?
    @State private var showImageViewer = false
    @State private var viewerImageURL: URL?
    
    private var accent: Color { Color(hex: settings.first?.accentHex ?? Theme.defaultAccent) }
    private var activeState: ActiveMacroState? { activeStates.first }
    
    private var utilityCommands: Set<String> {
        Set(["stop", "cancel", "close_all", "close_ahks", "reconnect", "send_screenshot", "stats",
             "toggle_autoclicker", "open_autoclicker", "autoclicker_check", "focus_roblox",
             "check_disconnect", "mouse_correction", "pause_disconnect", "unpause_disconnect",
             "enable_autoclicker_warning", "disable_autoclicker_warning", "help"])
    }
    
    private var runningInfo: (name: String, startTime: Date, fromApp: Bool)? {
        if let state = activeState {
            // Check if stop was sent after our start
            if let newestStop = feedStore.messages.first(where: {
                $0.isCommand && $0.content.contains("!stop")
            }), newestStop.parsedDate > state.startTime {
                // Stop was sent after we started - clear state
                Task { @MainActor in
                    context.delete(state)
                    try? context.save()
                }
                return nil
            }
            return (state.macroName, state.startTime, state.startedFromApp)
        }
        // Infer from channel
        let pattern = /\[App\] !(\w+)/
        if let msg = feedStore.messages.first(where: { $0.content.contains("[App] !") }),
           let match = msg.content.firstMatch(of: pattern) {
            let cmd = String(match.1)
            if utilityCommands.contains(cmd) { return nil }
            let name = allMacros.first(where: { $0.command == cmd })?.name ?? cmd
            return (name, msg.parsedDate, false)
        }
        return nil
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(spacing: Theme.spacing16) {
                        statusCard
                        quickActionsRow
                        screenshotCard
                        statsCard
                        recentActivity
                    }
                    .padding(Theme.spacing16)
                    .padding(.bottom, 80)
                }
                .refreshable {
                    await feedStore.refresh(credentials: credentials, context: context)
                }
                
                if let msg = toastMessage {
                    ToastView(icon: "checkmark.circle.fill", message: msg)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 8)
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("AFK Remote")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if feedStore.isLoading {
                        ProgressView().tint(Theme.secondaryText)
                    } else if let last = feedStore.lastFetched {
                        Text(relativeTimeShort(last))
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
            }
            .fullScreenCover(isPresented: $showImageViewer) {
                ImageViewer(url: viewerImageURL)
            }
        }
    }
    
    // MARK: - Status Card
    @ViewBuilder
    private var statusCard: some View {
        Group {
            if let info = runningInfo {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            PulsingDot(color: Theme.statusGreen)
                            Text("RUNNING")
                                .font(.caption.bold())
                                .foregroundStyle(Theme.statusGreen)
                        }
                        Text(info.name)
                            .font(.title2.bold())
                            .foregroundStyle(Theme.primaryText)
                        TimelineView(.periodic(from: .now, by: 1)) { timeline in
                            Text(elapsedString(from: info.startTime, to: timeline.date))
                                .font(.title3.monospacedDigit())
                                .foregroundStyle(Theme.primaryText)
                                .contentTransition(.numericText())
                        }
                        Text(info.fromApp ? "Started from this app" : "Detected from channel")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                    }
                    Spacer()
                    Button {
                        sendQuickAction("stop")
                    } label: {
                        Text("Stop")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(hex: "FF0000"), in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            } else {
                VStack(spacing: Theme.spacing12) {
                    HStack(spacing: 6) {
                        Circle().fill(Theme.secondaryText).frame(width: 10, height: 10)
                        Text("Nothing running")
                            .font(.headline)
                            .foregroundStyle(Theme.secondaryText)
                    }
                    Button {
                        router.selectedTab = .macros
                    } label: {
                        Label("START MACRO", systemImage: "play.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle(accent: accent))
                }
            }
        }
        .cardStyle()
    }
    
    // MARK: - Quick Actions
    private var quickActionsRow: some View {
        HStack(spacing: Theme.spacing8) {
            quickAction(icon: "stop.fill", label: "Stop", command: "stop", tint: Color(hex: "FF0000"))
            quickAction(icon: "camera.fill", label: "Screenshot", command: "send_screenshot", tint: Theme.primaryText)
            quickAction(icon: "chart.bar.fill", label: "Stats", command: "stats", tint: Theme.primaryText)
            quickAction(icon: "arrow.clockwise", label: "Reconnect", command: "reconnect", tint: Theme.primaryText)
        }
    }
    
    @ViewBuilder
    private func quickAction(icon: String, label: String, command: String, tint: Color) -> some View {
        Button {
            sendQuickAction(command)
        } label: {
            VStack(spacing: 6) {
                if sendingAction == command {
                    ProgressView().tint(tint).frame(width: 24, height: 24)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundStyle(tint)
                }
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("\(label) macro")
    }
    
    // MARK: - Screenshot Card
    @ViewBuilder
    private var screenshotCard: some View {
        VStack(alignment: .leading, spacing: Theme.spacing8) {
            Text("Latest Screenshot")
                .font(.headline)
                .foregroundStyle(Theme.primaryText)
            
            if let msg = feedStore.latestScreenshot, let url = msg.firstImageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().aspectRatio(16/9, contentMode: .fill)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
                    case .failure:
                        HStack {
                            Image(systemName: "photo")
                            Text("Couldn’t load image")
                        }
                        .foregroundStyle(Theme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .background(Theme.elevated, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
                    default:
                        RoundedRectangle(cornerRadius: Theme.cardRadius)
                            .fill(Theme.elevated)
                            .frame(height: 180)
                            .shimmer()
                    }
                }
                .onTapGesture {
                    viewerImageURL = url
                    showImageViewer = true
                }
                
                HStack {
                    Text(msg.displayName)
                        .font(.caption.bold())
                    Text(relativeTimeShort(msg.parsedDate))
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
            } else {
                VStack(spacing: 8) {
                    Text("No screenshots yet")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                    Button("Request Screenshot") {
                        sendQuickAction("send_screenshot")
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(accent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.spacing24)
            }
        }
        .cardStyle()
    }
    
    // MARK: - Stats Card
    @ViewBuilder
    private var statsCard: some View {
        VStack(alignment: .leading, spacing: Theme.spacing8) {
            Text("Latest Stats")
                .font(.headline)
                .foregroundStyle(Theme.primaryText)
            
            if let msg = feedStore.latestStats {
                if let embed = msg.embeds.first {
                    EmbedCard(embed: embed)
                } else {
                    Text(msg.content)
                        .font(.caption.monospaced())
                        .foregroundStyle(Theme.primaryText)
                }
                Text(relativeTimeShort(msg.parsedDate))
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            } else {
                VStack(spacing: 8) {
                    Text("No stats yet")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                    Button("Request Stats") {
                        sendQuickAction("stats")
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(accent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.spacing24)
            }
        }
        .cardStyle()
    }
    
    // MARK: - Recent Activity
    @ViewBuilder
    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: Theme.spacing8) {
            HStack {
                Text("Recent Activity")
                    .font(.headline)
                    .foregroundStyle(Theme.primaryText)
                Spacer()
                Button("See all") {
                    router.selectedTab = .feed
                }
                .font(.subheadline)
                .foregroundStyle(accent)
            }
            
            if feedStore.messages.isEmpty && !feedStore.isLoading {
                Text("No activity yet")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.spacing16)
            } else {
                let recentMsgs = Array(feedStore.messages.prefix(15).reversed())
                ForEach(recentMsgs) { msg in
                    MessageRow(message: msg, compact: true)
                }
            }
        }
        .cardStyle()
    }
    
    // MARK: - Helpers
    private func sendQuickAction(_ command: String) {
        sendingAction = command
        Task {
            do {
                let discord = DiscordService()
                try await discord.sendCommand(channelId: credentials.channelId, command: command, token: credentials.botToken)
                if command == "stop" {
                    if let state = activeState {
                        context.delete(state)
                        try? context.save()
                    }
                }
                showToast("Sent !\(command)")
                // Refresh after delay
                try? await Task.sleep(for: .seconds(3))
                await feedStore.refresh(credentials: credentials, context: context)
            } catch {
                showToast("Failed: \(error.localizedDescription)")
            }
            sendingAction = nil
        }
    }
    
    private func showToast(_ msg: String) {
        withAnimation { toastMessage = msg }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { toastMessage = nil }
        }
    }
    
    private func elapsedString(from start: Date, to now: Date) -> String {
        let diff = Int(now.timeIntervalSince(start))
        let h = diff / 3600
        let m = (diff % 3600) / 60
        let s = diff % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
    
    private func relativeTimeShort(_ date: Date) -> String {
        let diff = Date.now.timeIntervalSince(date)
        if diff < 5 { return "just now" }
        if diff < 60 { return "\(Int(diff))s ago" }
        if diff < 3600 { return "\(Int(diff / 60))m ago" }
        if diff < 86400 { return "\(Int(diff / 3600))h ago" }
        return "\(Int(diff / 86400))d ago"
    }
}
