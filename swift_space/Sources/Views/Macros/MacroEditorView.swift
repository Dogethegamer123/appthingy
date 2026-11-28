import SwiftUI
import SwiftData
import PhotosUI

struct MacroEditorView: View {
    let macro: Macro?
    var defaultCategoryKey: String? = nil
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MacroCategoryModel.sortOrder) private var categories: [MacroCategoryModel]
    
    @State private var name: String = ""
    @State private var command: String = ""
    @State private var desc: String = ""
    @State private var categoryKey: String = "utility"
    @State private var subcategory: MacroSubcategory = .utility
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var iconSymbol: String = "bolt.fill"
    @State private var commandError: String?
    
    static let symbolChoices: [String] = [
        "bolt.fill", "camera.fill", "chart.bar.fill", "stop.fill", "play.fill",
        "arrow.clockwise", "questionmark.circle.fill", "pawprint.fill", "sparkles",
        "gift.fill", "cube.box.fill", "shippingbox.fill", "crown.fill", "flame.fill",
        "star.fill", "wrench.and.screwdriver.fill", "cursorarrow.click", "timer",
        "wand.and.stars", "trophy.fill", "hare.fill", "gamecontroller.fill",
        "moon.fill", "snowflake"
    ]
    
    private var isEditing: Bool { macro != nil }
    private let commandRegex = /^[A-Za-z0-9_]+$/
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !command.trimmingCharacters(in: .whitespaces).isEmpty &&
        commandError == nil
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Photo") {
                    HStack {
                        if let data = imageData, let ui = UIImage(data: data) {
                            Image(uiImage: ui)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            MacroPlaceholderTile(category: categoryKey, size: 64, symbol: iconSymbol)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                Text(imageData == nil ? "Add Photo" : "Change Photo")
                            }
                            if imageData != nil {
                                Button("Remove Photo", role: .destructive) { imageData = nil }
                                    .font(.caption)
                            }
                        }
                    }
                }
                
                if imageData == nil {
                    Section("Icon") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(Self.symbolChoices, id: \.self) { sym in
                                    Button {
                                        iconSymbol = sym
                                    } label: {
                                        Image(systemName: sym)
                                            .font(.system(size: 20))
                                            .frame(width: 44, height: 44)
                                            .foregroundStyle(iconSymbol == sym ? .white : Theme.primaryText)
                                            .background(
                                                iconSymbol == sym ? Color(hex: "FF0000") : Theme.elevated,
                                                in: RoundedRectangle(cornerRadius: 10)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                Section("Details") {
                    TextField("Name", text: $name)
                    
                    VStack(alignment: .leading) {
                        TextField("Command", text: $command)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onChange(of: command) { _, newVal in
                                let cleaned = newVal.replacingOccurrences(of: "!", with: "")
                                if cleaned != newVal { command = cleaned }
                                validateCommand()
                            }
                        if let err = commandError {
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(Color(hex: "FF0000"))
                        }
                    }
                    
                    TextField("Description", text: $desc, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Classification") {
                    Picker("Category", selection: $categoryKey) {
                        ForEach(categories, id: \.key) { cat in
                            Text(cat.name).tag(cat.key)
                        }
                    }
                    
                    Picker("Subcategory", selection: $subcategory) {
                        ForEach(MacroSubcategory.allCases, id: \.rawValue) { sub in
                            Text(sub.displayName).tag(sub)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(isEditing ? "Edit Macro" : "New Macro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                }
            }
            .onAppear { loadMacro() }
            .onChange(of: selectedPhoto) { _, newVal in
                guard let item = newVal else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let ui = UIImage(data: data) {
                        let sz = CGSize(width: 1200, height: 1200)
                        let r = UIGraphicsImageRenderer(size: sz)
                        let img = r.image { _ in ui.draw(in: CGRect(origin: .zero, size: sz)) }
                        imageData = img.jpegData(compressionQuality: 0.8)
                    }
                }
            }
        }
    }
    
    private func loadMacro() {
        guard let m = macro else {
            // New macro: default to the category the user is currently viewing,
            // falling back to the first category or "utility".
            categoryKey = defaultCategoryKey ?? categories.first?.key ?? "utility"
            return
        }
        name = m.name
        command = m.command
        desc = m.macroDescription
        categoryKey = m.category
        subcategory = MacroSubcategory(rawValue: m.subcategory) ?? .utility
        imageData = m.imageData
        iconSymbol = m.iconSymbol
    }
    
    private var resolvedGame: String {
        categories.first(where: { $0.key == categoryKey })?.game ?? "Utility"
    }
    
    private func validateCommand() {
        let trimmed = command.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            commandError = nil
        } else if trimmed.firstMatch(of: commandRegex) == nil {
            commandError = "Only letters, numbers and underscores"
        } else {
            commandError = nil
        }
    }
    
    private func save() {
        let trimmedCmd = command.trimmingCharacters(in: .whitespaces)
        if let m = macro {
            m.name = name.trimmingCharacters(in: .whitespaces)
            m.command = trimmedCmd
            m.macroDescription = desc
            m.category = categoryKey
            m.subcategory = subcategory.rawValue
            m.game = resolvedGame
            m.imageData = imageData
            m.iconSymbol = iconSymbol
        } else {
            let newMacro = Macro(
                name: name.trimmingCharacters(in: .whitespaces),
                command: trimmedCmd,
                macroDescription: desc,
                category: categoryKey,
                subcategory: subcategory.rawValue,
                game: resolvedGame,
                imageData: imageData,
                iconSymbol: iconSymbol,
                isCustom: true
            )
            context.insert(newMacro)
        }
        try? context.save()
        dismiss()
    }
}
