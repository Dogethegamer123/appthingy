import SwiftUI

struct ToastView: View {
    let icon: String
    let message: String
    var isError: Bool = false
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(isError ? Color(hex: "FF0000") : Theme.statusGreen)
            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.primaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.elevated, in: Capsule())
    }
}
