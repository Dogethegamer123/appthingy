import SwiftUI
import SwiftData

struct FeedView: View {
    @Environment(FeedStore.self) private var feedStore
    @Environment(CredentialStore.self) private var credentials
    @Environment(\.modelContext) private var context
    @Query private var settings: [AppSettings]
    
    @State private var searchText = ""
    @State private var filter: FeedFilter = .all
    @State private var showImageViewer = false
    @State private var viewerImageURL: URL?
    
    private var accent: Color { Color(hex: settings.first?.accentHex ?? Theme.defaultAccent) }
    
    enum FeedFilter: String, CaseIterable {
        case all = "All"
        case commands = "Commands"
        case screenshots = "Screenshots"
        case stats = "Stats"
        case bots = "Bots"
    }
    
    private var filteredMessages: [DiscordMessage] {
        var msgs = feedStore.messages
        
        if !searchText.isEmpty {
            msgs = msgs.filter {
                $0.content.localizedCaseInsensitiveContains(searchText) ||
                $0.displayName.localizedCaseInsensitiveContains(searchText) ||
                $0.embeds.contains(where: {
                    ($0.title ?? "").localizedCaseInsensitiveContains(searchText) ||
                    ($0.description ?? "").localizedCaseInsensitiveContains(searchText)
                })
            }
        }
        
        switch filter {
        case .all: break
        case .commands: msgs = msgs.filter { $0.isCommand }
        case .screenshots: msgs = msgs.filter { $0.hasImage }
        case .stats: msgs = msgs.filter { $0.isStats }
        case .bots: msgs = msgs.filter { $0.isBot || $0.isWebhook }
        }
        
        return msgs
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.spacing8) {
                        ForEach(FeedFilter.allCases, id: \.rawValue) { f in
                            Button {
                                filter = f
                            } label: {
                                Text(f.rawValue)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(filter == f ? .white : Theme.primaryText)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        filter == f ? accent : Theme.elevated,
                                        in: Capsule()
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Theme.spacing16)
                    .padding(.vertical, Theme.spacing8)
                }
                
                if feedStore.isLoading && feedStore.messages.isEmpty {
                    VStack(spacing: 12) {
                        ForEach(0..<5, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Theme.elevated)
                                .frame(height: 60)
                                .shimmer()
                        }
                    }
                    .padding(Theme.spacing16)
                } else if filteredMessages.isEmpty {
                    VStack(spacing: Theme.spacing16) {
                        Spacer()
                        Image(systemName: filter == .all ? "text.bubble" : "line.3.horizontal.decrease")
                            .font(.system(size: 44))
                            .foregroundStyle(Theme.secondaryText)
                        Text(filter == .all ? "No messages in this channel yet" : "Nothing matches")
                            .font(.headline)
                            .foregroundStyle(Theme.primaryText)
                        if filter != .all {
                            Button("Clear filters") { filter = .all }
                                .font(.subheadline.bold())
                                .foregroundStyle(accent)
                        } else {
                            Button("Refresh") {
                                Task { await feedStore.refresh(credentials: credentials, context: context) }
                            }
                            .font(.subheadline.bold())
                            .foregroundStyle(accent)
                        }
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: Theme.spacing8) {
                            ForEach(filteredMessages) { msg in
                                MessageRow(message: msg) { url in
                                    viewerImageURL = url
                                    showImageViewer = true
                                }
                                .padding(.horizontal, Theme.spacing16)
                            }
                        }
                        .padding(.vertical, Theme.spacing8)
                        .padding(.bottom, 80)
                    }
                    .refreshable {
                        await feedStore.refresh(credentials: credentials, context: context)
                    }
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Feed")
            .searchable(text: $searchText, prompt: "Search messages")
            .fullScreenCover(isPresented: $showImageViewer) {
                ImageViewer(url: viewerImageURL)
            }
        }
    }
}
