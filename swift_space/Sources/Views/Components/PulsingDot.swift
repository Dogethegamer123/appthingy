import SwiftUI

struct PulsingDot: View {
    let color: Color
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 10, height: 10)
            .opacity(pulse ? 0.4 : 1.0)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }
}
