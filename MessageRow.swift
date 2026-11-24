import SwiftUI

struct MessageRow: View {
    let message: DiscordMessage
    var compact: Bool = false
    var commandMacros: [Macro] = []
    var onImageTap: ((URL) -> Void)? = nil
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if !compact {
                DiscordAvatar(message: message, size: 36)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(message.displayName)
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.primaryText)
                    
                    if message.isBot {
                        Text("BOT")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color(hex: "5865F2"), in: Capsule())
                    }
                    if message.isWebhook {
                        Text("WEBHOOK")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Theme.secondaryText, in: Capsule())
                    }
                    
                    Spacer()
                    
                    Text(relativeTime(message.parsedDate))
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
                
                // Content
                if !message.content.isEmpty {
                    if message.isCommand {
                        CommandPill(slug: message.appCommandSlug, macro: matchedMacro)
                    } else {
                        Text(message.content)
                            .font(.subheadline)
                            .foregroundStyle(Theme.primaryText)
                    }
                }
                
                // Embeds
                ForEach(Array(message.embeds.enumerated()), id: \.offset) { _, embed in
                    EmbedCard(embed: embed)
                }
                
                // Image attachments
                ForEach(message.attachments.filter { ($0.contentType ?? "").hasPrefix("image/") }) { att in
                    AsyncImage(url: URL(string: att.proxyUrl ?? att.url)) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().aspectRatio(contentMode: .fill)
                                .frame(maxHeight: 240)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .onTapGesture {
                                    if let u = URL(string: att.proxyUrl ?? att.url) {
                                        onImageTap?(u)
                                    }
                                }
                        default:
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Theme.elevated)
                                .frame(height: 120)
                                .shimmer()
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var matchedMacro: Macro? {
        guard let slug = message.appCommandSlug else { return nil }
        return commandMacros.first { $0.command.caseInsensitiveCompare(slug) == .orderedSame }
    }
    
    private func relativeTime(_ date: Date) -> String {
        let diff = Date.now.timeIntervalSince(date)
        if diff < 60 { return "now" }
        if diff < 3600 { return "\(Int(diff / 60))m" }
        if diff < 86400 { return "\(Int(diff / 3600))h" }
        return "\(Int(diff / 86400))d"
    }
}

struct CommandPill: View {
    var slug: String?
    var macro: Macro? = nil
    
    private var title: String {
        if let m = macro { return m.name }
        guard let s = slug else { return "Command" }
        return s.replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
    
    private var symbol: String {
        if let m = macro { return m.iconSymbol }
        return CommandPill.defaultSymbol(for: slug)
    }
    
    static func defaultSymbol(for slug: String?) -> String {
        switch (slug ?? "").lowercased() {
        case "send_screenshot": return "camera.fill"
        case "stats": return "chart.bar.fill"
        case "stop": return "stop.fill"
        case "reconnect", "check_disconnect": return "arrow.clockwise"
        case "help": return "questionmark.circle.fill"
        case "gifts": return "gift.fill"
        case "rankup": return "crown.fill"
        case let s where s.contains("candy"): return "sparkles"
        case let s where s.contains("egg") || s.contains("halloween"): return "pawprint.fill"
        case let s where s.contains("chest"): return "cube.box.fill"
        case let s where s.contains("raid"): return "flame.fill"
        case let s where s.contains("autoclicker"): return "cursorarrow.click"
        default: return "bolt.fill"
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Group {
                if let data = macro?.imageData, let ui = UIImage(data: data) {
                    Image(uiImage: ui).resizable().aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 24, height: 24)
            .background(Color(hex: "FF0000"), in: RoundedRectangle(cornerRadius: 6))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.primaryText)
                Text("Sent from app")
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(hex: "FF0000").opacity(0.4), lineWidth: 1)
                .background(Color(hex: "FF0000").opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        )
    }
}

struct EmbedCard: View {
    let embed: DiscordEmbed
    
    var barColor: Color {
        if let c = embed.color {
            return Color(red: Double((c >> 16) & 0xFF) / 255.0,
                         green: Double((c >> 8) & 0xFF) / 255.0,
                         blue: Double(c & 0xFF) / 255.0)
        }
        return Theme.secondaryText
    }
    
    var body: some View {
        HStack(spacing: 0) {
            barColor
                .frame(width: 3)
            
            VStack(alignment: .leading, spacing: 6) {
                if let t = embed.title, !t.isEmpty {
                    Text(t).font(.subheadline.bold()).foregroundStyle(Theme.primaryText)
                }
                if let d = embed.description, !d.isEmpty {
                    Text(d).font(.caption).foregroundStyle(Theme.secondaryText)
                }
                if let fields = embed.fields, !fields.isEmpty {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 4) {
                        ForEach(Array(fields.enumerated()), id: \.offset) { _, field in
                            VStack(alignment: .leading, spacing: 1) {
                                Text(field.name)
                                    .font(.caption2.bold())
                                    .foregroundStyle(Theme.secondaryText)
                                Text(field.value)
                                    .font(.caption)
                                    .foregroundStyle(Theme.primaryText)
                            }
                        }
                    }
                }
            }
            .padding(8)
        }
        .background(Theme.elevated, in: RoundedRectangle(cornerRadius: 8))
    }
}
