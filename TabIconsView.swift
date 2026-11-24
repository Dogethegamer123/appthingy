import SwiftUI
import SwiftData

struct TabIconsView: View {
    @Query private var tabIcons: [TabIconConfig]
    @Environment(\.modelContext) private var context
    @State private var editingTab: AppTab?
    
    private let tabs: [AppTab] = [.macros, .schedule, .home, .feed, .settings]
    
    var body: some View {
        List {
            ForEach(tabs, id: \.rawValue) { tab in
                Button {
                    editingTab = tab
                } label: {
                    HStack(spacing: 12) {
                        currentIcon(for: tab)
                            .frame(width: 32, height: 32)
                        Text(tab.label)
                            .foregroundStyle(Theme.primaryText)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                .listRowBackground(Theme.surface)
            }
            
            Section {
                Button("Reset All") {
                    tabIcons.forEach { context.delete($0) }
                    try? context.save()
                }
                .foregroundStyle(Color(hex: "FF0000"))
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Tab Icons")
        .sheet(item: $editingTab) { tab in
            TabIconPickerView(tab: tab)
        }
    }
    
    @ViewBuilder
    private func currentIcon(for tab: AppTab) -> some View {
        let config = tabIcons.first(where: { $0.tabKey == tab.rawValue })
        if let data = config?.customImageData, let ui = UIImage(data: data) {
            Image(uiImage: ui)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipShape(Circle())
        } else {
            Image(systemName: config?.symbolName ?? tab.defaultIcon)
                .font(.system(size: 20))
                .foregroundStyle(Theme.primaryText)
        }
    }
}

extension AppTab: Identifiable {
    public var id: String { rawValue }
}
