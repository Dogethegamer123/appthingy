import SwiftUI

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

enum Theme {
    static let background = Color(hex: "0F0F0F")
    static let surface = Color(hex: "1F1F1F")
    static let elevated = Color(hex: "272727")
    static let hairline = Color(hex: "303030")
    static let primaryText = Color(hex: "F1F1F1")
    static let secondaryText = Color(hex: "AAAAAA")
    static let statusGreen = Color(hex: "2BA640")
    
    static func brand(_ hex: String) -> Color {
        Color(hex: hex)
    }
    
    static let defaultAccent = "FF0000"
    
    static let accentPresets: [(String, String, Color)] = [
        ("YouTube Red", "FF0000", Color(hex: "FF0000")),
        ("Orange", "FF6A00", Color(hex: "FF6A00")),
        ("Electric Blue", "3EA6FF", Color(hex: "3EA6FF")),
        ("Lime", "22C55E", Color(hex: "22C55E"))
    ]
    
    static let spacing4: CGFloat = 4
    static let spacing8: CGFloat = 8
    static let spacing12: CGFloat = 12
    static let spacing16: CGFloat = 16
    static let spacing24: CGFloat = 24
    static let spacing32: CGFloat = 32
    
    static let cardRadius: CGFloat = 12
    static let inputRadius: CGFloat = 10
}

// MARK: - Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    let accent: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(accent, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Theme.primaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Theme.elevated, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25), value: configuration.isPressed)
    }
}

struct DestructiveOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color(hex: "FF0000"))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardRadius)
                    .stroke(Color(hex: "FF0000"), lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25), value: configuration.isPressed)
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25), value: configuration.isPressed)
    }
}

// MARK: - Card Modifier
struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.spacing16)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }
}

// MARK: - Shimmer
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    func body(content: Content) -> some View {
        content
            .overlay {
                LinearGradient(
                    colors: [.clear, Theme.hairline.opacity(0.5), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .onAppear {
                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        phase = 300
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Styled Text Field
struct AppTextField: View {
    let title: String
    @Binding var text: String
    var isSecure = false
    @State private var showText = false
    @FocusState private var focused: Bool
    
    var body: some View {
        HStack {
            Group {
                if isSecure && !showText {
                    SecureField(title, text: $text)
                        .focused($focused)
                } else {
                    TextField(title, text: $text)
                        .focused($focused)
                }
            }
            .foregroundStyle(Theme.primaryText)
            
            if isSecure {
                Button {
                    showText.toggle()
                } label: {
                    Image(systemName: showText ? "eye.slash" : "eye")
                        .foregroundStyle(Theme.secondaryText)
                }
            }
        }
        .padding()
        .background(Theme.elevated, in: RoundedRectangle(cornerRadius: Theme.inputRadius))
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
    }
}
