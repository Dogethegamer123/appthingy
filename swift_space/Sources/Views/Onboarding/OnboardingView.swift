import SwiftUI

struct OnboardingView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.spacing32) {
                Spacer()
                
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color(hex: "FF0000"))
                    .padding(24)
                    .background(Color(hex: "FF0000").opacity(0.15), in: RoundedRectangle(cornerRadius: 20))
                
                VStack(spacing: Theme.spacing8) {
                    Text("AFK Remote")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(Theme.primaryText)
                    Text("Control your PC’s Roblox macros from anywhere through your Discord bot.")
                        .font(.body)
                        .foregroundStyle(Theme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.spacing32)
                }
                
                Spacer()
                
                NavigationLink {
                    CredentialsFormView(isOnboarding: true)
                } label: {
                    Text("Get Started")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color(hex: "FF0000"), in: RoundedRectangle(cornerRadius: Theme.cardRadius))
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.horizontal, Theme.spacing24)
                .padding(.bottom, Theme.spacing32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background.ignoresSafeArea())
        }
    }
}
