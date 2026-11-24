import SwiftUI
import SwiftData

struct MacroPlaceholderTile: View {
    let category: String
    var size: CGFloat = 52
    var symbol: String? = nil
    @Query private var categories: [MacroCategoryModel]

    private var resolved: MacroCategoryModel? {
        categories.first { $0.key == category }
    }

    private var gradientStart: Color {
        Color(hex: resolved?.colorHex ?? "262626")
    }

    private var icon: String {
        symbol ?? resolved?.iconSymbol ?? "bolt.fill"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [gradientStart, Theme.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: icon)
                .font(.system(size: size * 0.4))
                .foregroundStyle(Theme.secondaryText.opacity(0.6))
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
