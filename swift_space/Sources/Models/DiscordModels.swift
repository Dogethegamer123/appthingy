import Foundation

struct DiscordMessage: Codable, Identifiable, Equatable {
    let id: String
    let content: String
    let timestamp: String
    let author: DiscordAuthor
    let webhookId: String?
    let attachments: [DiscordAttachment]
    let embeds: [DiscordEmbed]
    
    enum CodingKeys: String, CodingKey {
        case id, content, timestamp, author
        case webhookId = "webhook_id"
        case attachments, embeds
    }
    
    var parsedDate: Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: timestamp) { return d }
        let f2 = ISO8601DateFormatter()
        f2.formatOptions = [.withInternetDateTime]
        return f2.date(from: timestamp) ?? .now
    }
    
    var displayName: String {
        author.globalName ?? author.username
    }
    
    var avatarURL: URL? {
        guard let av = author.avatar else { return nil }
        return URL(string: "https://i.etsystatic.com/61071113/r/il/83c2bf/8060437828/il_1080xN.8060437828_wbme.jpg")
    }
    
    var isBot: Bool { author.bot == true }
    var isWebhook: Bool { webhookId != nil }
    
    var isCommand: Bool { content.hasPrefix("[App]") }
    
    var hasImage: Bool {
        attachments.contains(where: { ($0.contentType ?? "").hasPrefix("image/") }) ||
        embeds.contains(where: { $0.image != nil })
    }
    
    var firstImageURL: URL? {
        if let att = attachments.first(where: { ($0.contentType ?? "").hasPrefix("image/") }) {
            return URL(string: att.proxyUrl ?? att.url)
        }
        if let emb = embeds.first(where: { $0.image != nil }), let u = emb.image?.url {
            return URL(string: u)
        }
        return nil
    }
    
    var isStats: Bool {
        let low = content.lowercased()
        if low.contains("stats") || low.contains("hourly") { return true }
        for e in embeds {
            if (e.title ?? "").lowercased().contains("stats") || (e.title ?? "").lowercased().contains("hourly") { return true }
            if (e.description ?? "").lowercased().contains("stats") || (e.description ?? "").lowercased().contains("hourly") { return true }
        }
        return false
    }
    
    static func == (lhs: DiscordMessage, rhs: DiscordMessage) -> Bool { lhs.id == rhs.id }
}

struct DiscordAuthor: Codable {
    let id: String
    let username: String
    let globalName: String?
    let avatar: String?
    let bot: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id, username
        case globalName = "global_name"
        case avatar, bot
    }
}

struct DiscordAttachment: Codable, Identifiable {
    let id: String
    let filename: String
    let url: String
    let proxyUrl: String?
    let contentType: String?
    let width: Int?
    let height: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, filename, url
        case proxyUrl = "proxy_url"
        case contentType = "content_type"
        case width, height
    }
}

struct DiscordEmbed: Codable {
    let title: String?
    let description: String?
    let color: Int?
    let image: DiscordEmbedMedia?
    let thumbnail: DiscordEmbedMedia?
    let fields: [DiscordEmbedField]?
}

struct DiscordEmbedMedia: Codable {
    let url: String?
}

struct DiscordEmbedField: Codable {
    let name: String
    let value: String
}

struct DiscordChannel: Codable {
    let id: String
    let name: String?
}

struct DiscordRateLimit: Codable {
    let retryAfter: Double
    enum CodingKeys: String, CodingKey {
        case retryAfter = "retry_after"
    }
}
