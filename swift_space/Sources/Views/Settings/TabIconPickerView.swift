import SwiftUI
import SwiftData
import PhotosUI

struct TabIconPickerView: View {
    let tab: AppTab
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var tabIcons: [TabIconConfig]
    
    @State private var mode: IconMode = .symbol
    @State private var selectedSymbol: String = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    
    enum IconMode: String, CaseIterable {
        case symbol = "SF Symbol"
        case photo = "Photo"
    }
    
    private let symbols = [
        "house.fill", "gamecontroller.fill", "bolt.fill", "calendar", "clock.fill",
        "list.bullet.rectangle", "bubble.left.and.bubble.right.fill", "gearshape.fill",
        "star.fill", "flame.fill", "pawprint.fill", "sparkles", "crown.fill",
        "cube.fill", "trophy.fill", "heart.fill", "bell.fill", "terminal.fill",
        "square.grid.2x2.fill", "text.bubble.fill", "calendar.badge.clock",
        "wrench.and.screwdriver.fill", "play.fill", "stop.fill", "camera.fill",
        "chart.bar.fill", "arrow.clockwise", "eye.fill", "hand.thumbsup.fill",
        "flag.fill", "map.fill", "magnifyingglass", "person.fill",
        "shield.fill", "lock.fill", "key.fill", "command", "power",
        "wifi", "antenna.radiowaves.left.and.right", "desktopcomputer"
    ]
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)
    
    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.spacing16) {
                Picker("Mode", selection: $mode) {
                    ForEach(IconMode.allCases, id: \.rawValue) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Theme.spacing16)
                
                if mode == .symbol {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(symbols, id: \.self) { sym in
                                Button {
                                    selectedSymbol = sym
                                    photoData = nil
                                } label: {
                                    Image(systemName: sym)
                                        .font(.system(size: 22))
                                        .frame(width: 48, height: 48)
                                        .background(
                                            selectedSymbol == sym ? Color(hex: "FF0000").opacity(0.2) : Theme.elevated,
                                            in: RoundedRectangle(cornerRadius: 10)
                                        )
                                        .overlay {
                                            if selectedSymbol == sym {
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(Color(hex: "FF0000"), lineWidth: 2)
                                            }
                                        }
                                        .foregroundStyle(Theme.primaryText)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(Theme.spacing16)
                    }
                } else {
                    VStack(spacing: Theme.spacing16) {
                        if let data = photoData, let ui = UIImage(data: data) {
                            Image(uiImage: ui)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 96, height: 96)
                                .clipShape(Circle())
                        }
                        
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Text("Choose Photo")
                                .font(.headline)
                                .foregroundStyle(Theme.primaryText)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Theme.elevated, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
                        }
                        .padding(.horizontal, Theme.spacing16)
                        
                        Spacer()
                    }
                    .padding(.top, Theme.spacing24)
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("\(tab.label) Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("Use Default") {
                        if let existing = tabIcons.first(where: { $0.tabKey == tab.rawValue }) {
                            context.delete(existing)
                            try? context.save()
                        }
                        dismiss()
                    }
                    .foregroundStyle(Theme.secondaryText)
                }
            }
            .onAppear {
                let config = tabIcons.first(where: { $0.tabKey == tab.rawValue })
                selectedSymbol = config?.symbolName ?? tab.defaultIcon
                photoData = config?.customImageData
                if photoData != nil { mode = .photo }
            }
            .onChange(of: selectedPhoto) { _, newVal in
                Task {
                    if let item = newVal,
                       let data = try? await item.loadTransferable(type: Data.self),
                       let ui = UIImage(data: data) {
                        let sz = CGSize(width: 96, height: 96)
                        let r = UIGraphicsImageRenderer(size: sz)
                        let img = r.image { _ in ui.draw(in: CGRect(origin: .zero, size: sz)) }
                        photoData = img.pngData()
                        selectedSymbol = ""
                    }
                }
            }
        }
    }
    
    private func save() {
        let existing = tabIcons.first(where: { $0.tabKey == tab.rawValue })
        
        if mode == .symbol && !selectedSymbol.isEmpty {
            if let config = existing {
                config.symbolName = selectedSymbol
                config.customImageData = nil
            } else {
                context.insert(TabIconConfig(tabKey: tab.rawValue, symbolName: selectedSymbol))
            }
        } else if mode == .photo, let data = photoData {
            if let config = existing {
                config.symbolName = nil
                config.customImageData = data
            } else {
                context.insert(TabIconConfig(tabKey: tab.rawValue, customImageData: data))
            }
        }
        
        try? context.save()
        dismiss()
    }
}
