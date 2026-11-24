import SwiftUI

/// Clean avatar for feed rows. Loads the real Discord avatar when there is one,
/// otherwise shows a Discord-style colored circle with the sender's initial —
/// never the plain grey placeholder.
struct DiscordAvatar: View {
    let message: DiscordMessage
    var size: CGFloat = 36

    private var initial: String {
        let name = message.displayName.trimmingCharacters(in: .whitespaces)
        return String(name.first ?? Character("?")).uppercased()
    }

    // Deterministic color from the author id (stable across launches).
    private var bgColor: Color {
        let palette: [String] = [
            "5865F2", "57F287", "EB459E", "ED4245",
            "3BA55D", "FAA61A", "9B59B6", "11806A",
            "E67E22", "1ABC9C"
        ]
        let hash = message.author.id.unicodeScalars.reduce(0) { $0 &* 31 &+ Int($1.value) }
        let idx = abs(hash) % palette.count
        return Color(hex: palette[idx])
    }

    var body: some View {
        AsyncImage(url: message.avatarURL) { phase in
            switch phase {
            case .success(let img):
                img.resizable().aspectRatio(contentMode: .fill)
            default:
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))
    }

    private var fallback: some View {
        ZStack {
            LinearGradient(
                colors: [bgColor, bgColor.opacity(0.75)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(initial)
                .font(.system(size: size * 0.44, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}
