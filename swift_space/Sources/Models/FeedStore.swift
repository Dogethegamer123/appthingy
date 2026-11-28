import Foundation
import SwiftData
import Observation
import os

@MainActor
@Observable
final class FeedStore {
    var messages: [DiscordMessage] = []
    var isLoading = false
    var error: String?
    var lastFetched: Date?
    
    private let discord = DiscordService()
    private let logger = Logger(subsystem: "com.afkremote", category: "FeedStore")
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    
    /// Starts (or restarts) automatic polling. Refreshes immediately, then every `interval` seconds.
    /// An interval of 0 means "Off" — refresh once and stop.
    func startPolling(credentials: CredentialStore, context: ModelContext, interval: Int) {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            guard let self else { return }
            await self.refresh(credentials: credentials, context: context)
            guard interval > 0 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double(interval)))
                if Task.isCancelled { break }
                await self.refresh(credentials: credentials, context: context)
            }
        }
    }
    
    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }
    
    func loadCache(context: ModelContext) {
        let descriptor = FetchDescriptor<CachedFeed>()
        if let cached = try? context.fetch(descriptor).first,
           let msgs = try? JSONDecoder().decode([DiscordMessage].self, from: cached.rawJSON) {
            messages = msgs
            lastFetched = cached.fetchedAt
        }
    }
    
    func refresh(credentials: CredentialStore, context: ModelContext) async {
        guard credentials.isConfigured else { return }
        isLoading = true
        error = nil
        do {
            let msgs = try await discord.fetchMessages(channelId: credentials.channelId, token: credentials.botToken)
            lastFetched = .now
            
            // Only touch the UI and the cache when the feed actually changed.
            // This stops needless view rebuilds and image reloads on every poll.
            if msgs.map(\.id) != messages.map(\.id) {
                messages = msgs
                let descriptor = FetchDescriptor<CachedFeed>()
                let existing = try? context.fetch(descriptor)
                existing?.forEach { context.delete($0) }
                if let data = try? JSONEncoder().encode(msgs) {
                    context.insert(CachedFeed(rawJSON: data, fetchedAt: .now))
                    try? context.save()
                }
            }
            // The PC is the source of truth for what is actually running:
            // reconcile the shown macro with its [Status] active= markers so a
            // hand-off (e.g. ttd_boost restarting the real grind) updates the app.
            reconcileActiveMacro(context: context)
        } catch {
            self.error = error.localizedDescription
            logger.error("Feed refresh failed: \(error.localizedDescription)")
        }
        isLoading = false
    }
    
    /// Messages to show in the feed UI (the machine-readable [Status] markers
    /// are used for tracking only and hidden here).
    var displayMessages: [DiscordMessage] {
        messages.filter { !$0.isStatusMarker }
    }

    /// Updates the ActiveMacroState from the newest PC [Status] active= marker.
    /// "none" clears it; a different command replaces it; the same command is
    /// left alone so an app-started timer keeps its original start time.
    private func reconcileActiveMacro(context: ModelContext) {
        guard let statusMsg = messages.first(where: { $0.activeStatusCommand != nil }),
              let cmd = statusMsg.activeStatusCommand else { return }
        let states = (try? context.fetch(FetchDescriptor<ActiveMacroState>())) ?? []
        let current = states.first

        if cmd == "none" {
            if let current, statusMsg.parsedDate >= current.startTime {
                states.forEach { context.delete($0) }
                try? context.save()
            }
            return
        }

        if let current {
            if current.command == cmd { return }
            // Only switch when the marker is newer than the current state, so an
            // old marker can't override a macro the user just started.
            guard statusMsg.parsedDate >= current.startTime else { return }
            states.forEach { context.delete($0) }
        }
        let macros = (try? context.fetch(FetchDescriptor<Macro>())) ?? []
        let name = macros.first(where: { $0.command == cmd })?.name ?? cmd
        context.insert(ActiveMacroState(macroName: name, command: cmd,
                                        startTime: statusMsg.parsedDate, startedFromApp: false))
        try? context.save()
    }

    var latestScreenshot: DiscordMessage? {
        messages.first(where: { $0.hasImage })
    }
    
    var latestStats: DiscordMessage? {
        messages.first(where: { $0.isStats })
    }
}
