import Foundation
import SwiftData
import Observation
import os

@Observable
final class FeedStore {
    var messages: [DiscordMessage] = []
    var isLoading = false
    var error: String?
    var lastFetched: Date?
    
    private let discord = DiscordService()
    private let logger = Logger(subsystem: "com.afkremote", category: "FeedStore")
    
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
            messages = msgs
            lastFetched = .now
            
            // cache
            let descriptor = FetchDescriptor<CachedFeed>()
            let existing = try? context.fetch(descriptor)
            existing?.forEach { context.delete($0) }
            if let data = try? JSONEncoder().encode(msgs) {
                context.insert(CachedFeed(rawJSON: data, fetchedAt: .now))
                try? context.save()
            }
        } catch {
            self.error = error.localizedDescription
            logger.error("Feed refresh failed: \(error.localizedDescription)")
        }
        isLoading = false
    }
    
    var latestScreenshot: DiscordMessage? {
        messages.first(where: { $0.hasImage })
    }
    
    var latestStats: DiscordMessage? {
        messages.first(where: { $0.isStats })
    }
}
