import SwiftUI
import SwiftData

struct AFKTabBar: View {
    @Binding var selectedTab: AppTab
    let accent: Color
    @Query private var tabIcons: [TabIconConfig]
    @Query private var settings: [AppSettings]
    
    private var hapticsEnabled: Bool { settings.first?.hapticsEnabled ?? true }
    
    private let tabs: [AppTab] = [.macros, .schedule, .home, .feed, .settings]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.rawValue) { tab in
                if tab == .home {
                    centerTab(tab)
                } else {
                    sideTab(tab)
                }
            }
        }
        .frame(height: 64)
        .background {
            VStack(spacing: 0) {
                Theme.hairline.frame(height: 0.5)
                Theme.background
            }
        }
        .sensoryFeedback(.selection, trigger: selectedTab)
    }
    
    private func iconName(for tab: AppTab) -> String {
        tabIcons.first(where: { $0.tabKey == tab.rawValue })?.symbolName ?? tab.defaultIcon
    }
    
    private func customImage(for tab: AppTab) -> Data? {
        tabIcons.first(where: { $0.tabKey == tab.rawValue })?.customImageData
    }
    
    @ViewBuilder
    private func sideTab(_ tab: AppTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 3) {
                tabIcon(tab, size: 22)
                Text(tab.label)
                    .font(.caption2)
                    .foregroundStyle(selectedTab == tab ? .white : Theme.secondaryText)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func centerTab(_ tab: AppTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            ZStack {
                Circle()
                    .fill(accent)
                    .frame(width: 56, height: 56)
                    .shadow(color: accent.opacity(0.4), radius: 12)
                    .overlay {
                        if selectedTab == tab {
                            Circle()
                                .stroke(.white, lineWidth: 2)
                        }
                    }
                
                tabIcon(tab, size: 24, forceWhite: true)
            }
            .offset(y: -12)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func tabIcon(_ tab: AppTab, size: CGFloat, forceWhite: Bool = false) -> some View {
        if let data = customImage(for: tab), let ui = UIImage(data: data) {
            Image(uiImage: ui)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Image(systemName: iconName(for: tab))
                .font(.system(size: size))
                .foregroundStyle(forceWhite ? .white : (selectedTab == tab ? .white : Theme.secondaryText))
        }
    }
}
