import SwiftUI
import SwiftData
import PhotosUI

struct MacroDetailView: View {
    let macro: Macro
    @Environment(CredentialStore.self) private var credentials
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var activeStates: [ActiveMacroState]
    @Query private var settings: [AppSettings]
    @Query private var allMacros: [Macro]
    
    @State private var isSending = false
    @State private var toastMessage: String?
    @State private var showDeleteConfirm = false
    @State private var showStopConfirm = false
    @State private var showEditor = false
    @State private var selectedPhoto: PhotosPickerItem?
    
    private var accent: Color { Color(hex: settings.first?.accentHex ?? Theme.defaultAccent) }
    private var activeState: ActiveMacroState? { activeStates.first }
    private var isThisMacroRunning: Bool { activeState?.command == macro.command }
    private var isOtherMacroRunning: Bool { activeState != nil && !isThisMacroRunning }
    private var isUtility: Bool { macro.category == "utility" }
    
    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacing16) {
                    // Hero image
                    ZStack(alignment: .bottomTrailing) {
                        if let data = macro.imageData, let ui = UIImage(data: data) {
                            Image(uiImage: ui)
                                .resizable()
                                .aspectRatio(4/3, contentMode: .fill)
                                .frame(maxWidth: .infinity)
                                .frame(height: 260)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
                        } else {
                            MacroPlaceholderTile(category: macro.category, size: 260)
                                .frame(maxWidth: .infinity)
                                .frame(height: 260)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
                        }
                        
                        Menu {
                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                Label("Change Photo", systemImage: "photo")
                            }
                            if macro.imageData != nil {
                                Button(role: .destructive) {
                                    macro.imageData = nil
                                    try? context.save()
                                } label: {
                                    Label("Remove Photo", systemImage: "trash")
                                }
                            }
                        } label: {
                            Image(systemName: "camera.fill")
                                .font(.caption)
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .padding(12)
                    }
                    
                    // Info
                    VStack(alignment: .leading, spacing: Theme.spacing8) {
                        Text(macro.name)
                            .font(.title.bold())
                            .foregroundStyle(Theme.primaryText)
                        
                        if !macro.macroDescription.isEmpty {
                            Text(macro.macroDescription)
                                .font(.body)
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                    
                    // Details
                    VStack(spacing: 0) {
                        detailRow("Game", macro.game)
                        Divider().background(Theme.hairline)
                        detailRow("Category", MacroCategory(rawValue: macro.category)?.displayName ?? macro.category)
                        Divider().background(Theme.hairline)
                        detailRow("Subcategory", MacroSubcategory(rawValue: macro.subcategory)?.displayName ?? macro.subcategory)
                        Divider().background(Theme.hairline)
                        detailRow("Created", macro.dateCreated.formatted(date: .abbreviated, time: .omitted))
                        Divider().background(Theme.hairline)
                        HStack {
                            Text("Command")
                                .foregroundStyle(Theme.secondaryText)
                            Spacer()
                            Text("!\(macro.command)")
                                .font(.body.monospaced())
                                .foregroundStyle(Theme.primaryText)
                            Button {
                                UIPasteboard.general.string = "!\(macro.command)"
                                showToast("Copied")
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.caption)
                                    .foregroundStyle(Theme.secondaryText)
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, Theme.spacing16)
                    }
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
                    
                    Spacer(minLength: 100)
                }
                .padding(Theme.spacing16)
            }
            
            if let msg = toastMessage {
                ToastView(icon: "checkmark.circle.fill", message: msg)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            actionButton
                .padding(Theme.spacing16)
                .background(Theme.background)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showEditor = true } label: { Label("Edit", systemImage: "pencil") }
                    Button(role: .destructive) { showDeleteConfirm = true } label: { Label("Delete", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Delete Macro?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                context.delete(macro)
                try? context.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Stop \(activeState?.macroName ?? "") and start \(macro.name)?", isPresented: $showStopConfirm) {
            Button("Stop & Start") { stopAndStart() }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showEditor) {
            MacroEditorView(macro: macro)
        }
        .onChange(of: selectedPhoto) { _, newVal in
            Task {
                if let item = newVal,
                   let data = try? await item.loadTransferable(type: Data.self),
                   let ui = UIImage(data: data) {
                    let sz = CGSize(width: 1200, height: 1200)
                    let r = UIGraphicsImageRenderer(size: sz)
                    let img = r.image { _ in ui.draw(in: CGRect(origin: .zero, size: sz)) }
                    macro.imageData = img.jpegData(compressionQuality: 0.8)
                    try? context.save()
                }
            }
        }
    }
    
    @ViewBuilder
    private var actionButton: some View {
        if isUtility {
            Button {
                sendCommand()
            } label: {
                HStack {
                    if isSending { ProgressView().tint(.white) }
                    Label("Send", systemImage: "paperplane.fill")
                }
            }
            .buttonStyle(PrimaryButtonStyle(accent: accent))
            .disabled(isSending)
        } else if isThisMacroRunning {
            VStack(spacing: Theme.spacing8) {
                HStack(spacing: 6) {
                    PulsingDot(color: Theme.statusGreen)
                    Text("Running")
                        .font(.headline)
                        .foregroundStyle(Theme.statusGreen)
                }
                if let start = activeState?.startTime {
                    TimelineView(.periodic(from: .now, by: 1)) { timeline in
                        Text(elapsedStr(from: start, to: timeline.date))
                            .font(.title3.monospacedDigit())
                            .foregroundStyle(Theme.primaryText)
                            .contentTransition(.numericText())
                    }
                }
                Button {
                    stopMacro()
                } label: {
                    Text("Stop")
                }
                .buttonStyle(DestructiveOutlineButtonStyle())
            }
        } else {
            Button {
                if isOtherMacroRunning {
                    showStopConfirm = true
                } else {
                    sendCommand()
                }
            } label: {
                HStack {
                    if isSending { ProgressView().tint(.white) }
                    Label("Start", systemImage: "play.fill")
                }
            }
            .buttonStyle(PrimaryButtonStyle(accent: accent))
            .disabled(isSending)
        }
    }
    
    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Theme.secondaryText)
            Spacer()
            Text(value).foregroundStyle(Theme.primaryText)
        }
        .font(.body)
        .padding(.vertical, 12)
        .padding(.horizontal, Theme.spacing16)
    }
    
    private func sendCommand() {
        isSending = true
        Task {
            do {
                let discord = DiscordService()
                try await discord.sendCommand(channelId: credentials.channelId, command: macro.command, token: credentials.botToken)
                if !isUtility {
                    // Clear old state
                    activeStates.forEach { context.delete($0) }
                    let state = ActiveMacroState(macroName: macro.name, command: macro.command)
                    context.insert(state)
                    try? context.save()
                }
                showToast(isUtility ? "Sent !\(macro.command)" : "Started \(macro.name)")
            } catch {
                showToast("Failed: \(error.localizedDescription)")
            }
            isSending = false
        }
    }
    
    private func stopMacro() {
        Task {
            let discord = DiscordService()
            try? await discord.sendCommand(channelId: credentials.channelId, command: "stop", token: credentials.botToken)
            activeStates.forEach { context.delete($0) }
            try? context.save()
        }
    }
    
    private func stopAndStart() {
        Task {
            let discord = DiscordService()
            try? await discord.sendCommand(channelId: credentials.channelId, command: "stop", token: credentials.botToken)
            activeStates.forEach { context.delete($0) }
            try? context.save()
            try? await Task.sleep(for: .seconds(1))
            sendCommand()
        }
    }
    
    private func showToast(_ msg: String) {
        withAnimation { toastMessage = msg }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { toastMessage = nil }
        }
    }
    
    private func elapsedStr(from start: Date, to now: Date) -> String {
        let d = Int(now.timeIntervalSince(start))
        return String(format: "%02d:%02d:%02d", d / 3600, (d % 3600) / 60, d % 60)
    }
}
