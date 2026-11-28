import SwiftUI
import SwiftData

/// Lets the user manage macro categories: add new ones (e.g. TTD), rename,
/// recolor and reorder. Built-in categories can be edited but not deleted;
/// deleting a custom category moves its macros to Utility so none are orphaned.
struct CategoryManagerView: View {
    @Query(sort: \MacroCategoryModel.sortOrder) private var categories: [MacroCategoryModel]
    @Query private var macros: [Macro]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var settings: [AppSettings]

    @State private var editingCategory: MacroCategoryModel?
    @State private var showNew = false

    private var accent: Color { Color(hex: settings.first?.accentHex ?? Theme.defaultAccent) }

    private func macroCount(_ key: String) -> Int {
        macros.filter { $0.category == key }.count
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(categories, id: \.id) { cat in
                        Button {
                            editingCategory = cat
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    LinearGradient(colors: [cat.gradientStart, Theme.surface],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                                    Image(systemName: cat.iconSymbol)
                                        .font(.system(size: 18))
                                        .foregroundStyle(.white.opacity(0.85))
                                }
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cat.name)
                                        .font(.headline)
                                        .foregroundStyle(Theme.primaryText)
                                    Text("\(macroCount(cat.key)) macro\(macroCount(cat.key) == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundStyle(Theme.secondaryText)
                                }
                                Spacer()
                                if cat.isBuiltIn {
                                    Text("Built-in")
                                        .font(.caption2)
                                        .foregroundStyle(Theme.secondaryText)
                                        .padding(.horizontal, 6).padding(.vertical, 3)
                                        .background(Theme.elevated, in: Capsule())
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(Theme.secondaryText)
                            }
                        }
                        .listRowBackground(Theme.surface)
                        .swipeActions(edge: .trailing) {
                            if !cat.isBuiltIn {
                                Button(role: .destructive) {
                                    deleteCategory(cat)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                } footer: {
                    Text("Deleting a custom category moves its macros to Utility. Built-in categories can be renamed and recolored but not deleted.")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNew = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showNew) {
                CategoryEditorView(category: nil)
            }
            .sheet(item: $editingCategory) { cat in
                CategoryEditorView(category: cat)
            }
        }
        .tint(accent)
    }

    private func deleteCategory(_ cat: MacroCategoryModel) {
        guard !cat.isBuiltIn else { return }
        // Move its macros to Utility so none become orphaned.
        let key = cat.key
        for m in macros where m.category == key {
            m.category = "utility"
            m.game = "Utility"
        }
        context.delete(cat)
        try? context.save()
    }
}

struct CategoryEditorView: View {
    let category: MacroCategoryModel?
    @Query(sort: \MacroCategoryModel.sortOrder) private var categories: [MacroCategoryModel]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var settings: [AppSettings]

    @State private var name: String = ""
    @State private var game: String = ""
    @State private var iconSymbol: String = "gamecontroller.fill"
    @State private var colorHex: String = "1C263A"
    @FocusState private var nameFocused: Bool
    @FocusState private var gameFocused: Bool

    private var accent: Color { Color(hex: settings.first?.accentHex ?? Theme.defaultAccent) }
    private var isEditing: Bool { category != nil }
    private var isBuiltIn: Bool { category?.isBuiltIn ?? false }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Preview") {
                    HStack(spacing: 12) {
                        ZStack {
                            LinearGradient(colors: [Color(hex: colorHex), Theme.surface],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                            Image(systemName: iconSymbol)
                                .font(.system(size: 26))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        Text(name.isEmpty ? "Category name" : name)
                            .font(.title3.bold())
                            .foregroundStyle(name.isEmpty ? Theme.secondaryText : Theme.primaryText)
                    }
                    .listRowBackground(Theme.surface)
                }

                Section("Details") {
                    TextField("Name (e.g. TTD)", text: $name)
                        .focused($nameFocused)
                    TextField("Game (optional, e.g. Toilet Tower Defense)", text: $game)
                        .focused($gameFocused)
                }

                Section("Icon") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(MacroEditorView.symbolChoices, id: \.self) { sym in
                                Button {
                                    iconSymbol = sym
                                } label: {
                                    Image(systemName: sym)
                                        .font(.system(size: 20))
                                        .frame(width: 44, height: 44)
                                        .foregroundStyle(iconSymbol == sym ? .white : Theme.primaryText)
                                        .background(
                                            iconSymbol == sym ? accent : Theme.elevated,
                                            in: RoundedRectangle(cornerRadius: 10)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Color") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(MacroCategoryModel.colorChoices, id: \.self) { hex in
                                Button {
                                    colorHex = hex
                                } label: {
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Circle().stroke(colorHex == hex ? accent : Color.white.opacity(0.15),
                                                            lineWidth: colorHex == hex ? 3 : 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(isEditing ? "Edit Category" : "New Category")
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
            .onAppear { load() }
        }
        .tint(accent)
    }

    private func load() {
        guard let c = category else { return }
        name = c.name
        game = c.game == c.name ? "" : c.game
        iconSymbol = c.iconSymbol
        colorHex = c.colorHex
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedGame = game.trimmingCharacters(in: .whitespaces)
        let resolvedGame = trimmedGame.isEmpty ? trimmedName : trimmedGame
        if let c = category {
            c.name = trimmedName
            c.iconSymbol = iconSymbol
            c.colorHex = colorHex
            // Keep built-in game label stable; custom categories track the field.
            if !c.isBuiltIn { c.game = resolvedGame }
        } else {
            let nextOrder = (categories.map(\.sortOrder).max() ?? 0) + 1
            let newCat = MacroCategoryModel(
                key: "cat_" + String(UUID().uuidString.prefix(8)),
                name: trimmedName,
                iconSymbol: iconSymbol,
                colorHex: colorHex,
                game: resolvedGame,
                sortOrder: nextOrder,
                isBuiltIn: false
            )
            context.insert(newCat)
        }
        try? context.save()
        dismiss()
    }
}
