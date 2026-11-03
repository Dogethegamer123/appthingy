import SwiftUI
import SwiftData
import PhotosUI

struct MacroEditorView: View {
    let macro: Macro?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var command: String = ""
    @State private var desc: String = ""
    @State private var category: MacroCategory = .utility
    @State private var subcategory: MacroSubcategory = .utility
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var commandError: String?
    
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
                            MacroPlaceholderTile(category: category.rawValue, size: 64)
                        }
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Text(imageData == nil ? "Add Photo" : "Change Photo")
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
                    Picker("Category", selection: $category) {
                        ForEach(MacroCategory.allCases, id: \.rawValue) { cat in
                            Text(cat.displayName).tag(cat)
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
        guard let m = macro else { return }
        name = m.name
        command = m.command
        desc = m.macroDescription
        category = MacroCategory(rawValue: m.category) ?? .utility
        subcategory = MacroSubcategory(rawValue: m.subcategory) ?? .utility
        imageData = m.imageData
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
            m.category = category.rawValue
            m.subcategory = subcategory.rawValue
            m.game = category.game
            m.imageData = imageData
        } else {
            let newMacro = Macro(
                name: name.trimmingCharacters(in: .whitespaces),
                command: trimmedCmd,
                macroDescription: desc,
                category: category.rawValue,
                subcategory: subcategory.rawValue,
                game: category.game,
                imageData: imageData,
                isCustom: true
            )
            context.insert(newMacro)
        }
        try? context.save()
        dismiss()
    }
}
