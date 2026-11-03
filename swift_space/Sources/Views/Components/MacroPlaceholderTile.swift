import SwiftUI

struct MacroPlaceholderTile: View {
    let category: String
    var size: CGFloat = 52
    
    private var cat: MacroCategory {
        MacroCategory(rawValue: category) ?? .utility
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [cat.gradientStart, Theme.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: cat.icon)
                .font(.system(size: size * 0.4))
                .foregroundStyle(Theme.secondaryText.opacity(0.6))
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
