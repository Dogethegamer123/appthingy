import SwiftUI
import SwiftData

struct MacrosView: View {
    @Query private var macros: [Macro]
    @Query private var activeStates: [ActiveMacroState]
    @Query private var settings: [AppSettings]
    @State private var selectedCategory: MacroCategory = .psxClassic
    @State private var searchText = ""
    @State private var showEditor = false
    @State private var editingMacro: Macro?
    @Environment(\.modelContext) private var context
    
    private var accent: Color { Color(hex: settings.first?.accentHex ?? Theme.defaultAccent) }
    private var activeCommand: String? { activeStates.first?.command }
    
    private var filteredMacros: [Macro] {
        macros.filter { $0.category == selectedCategory.rawValue }
              .filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) || $0.command.localizedCaseInsensitiveContains(searchText) }
    }
    
    private var groupedMacros: [(String, [Macro])] {
        let order = MacroSubcategory.displayOrder.map { $0.rawValue }
        var groups: [(String, [Macro])] = []
        for sub in order {
            let items = filteredMacros.filter { $0.subcategory == sub }
            if !items.isEmpty {
                groups.append((MacroSubcategory(rawValue: sub)?.displayName ?? sub, items))
            }
        }
        return groups
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.spacing8) {
                        ForEach(MacroCategory.allCases, id: \.rawValue) { cat in
                            Button {
                                selectedCategory = cat
                            } label: {
                                Label(cat.displayName, systemImage: cat.icon)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(selectedCategory == cat ? .white : Theme.primaryText)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        selectedCategory == cat ? accent : Theme.elevated,
                                        in: Capsule()
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Theme.spacing16)
                    .padding(.vertical, Theme.spacing12)
                }
                
                if groupedMacros.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(groupedMacros, id: \.0) { sectionName, items in
                            Section(sectionName) {
                                ForEach(items, id: \.id) { macro in
                                    NavigationLink(value: macro.id) {
                                        MacroRow(macro: macro, isRunning: macro.command == activeCommand)
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            deleteMacro(macro)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                        Button {
                                            editingMacro = macro
                                        } label: {
                                            Label("Edit", systemImage: "pencil")
                                        }
                                        .tint(.blue)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Macros")
            .searchable(text: $searchText, prompt: "Search macros")
            .navigationDestination(for: UUID.self) { macroId in
                if let macro = macros.first(where: { $0.id == macroId }) {
                    MacroDetailView(macro: macro)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editingMacro = nil
                        showEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showEditor) {
                MacroEditorView(macro: nil)
            }
            .sheet(item: $editingMacro) { macro in
                MacroEditorView(macro: macro)
            }
        }
    }
    
    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: Theme.spacing16) {
            Spacer()
            Image(systemName: searchText.isEmpty ? "square.grid.2x2" : "magnifyingglass")
                .font(.system(size: 44))
                .foregroundStyle(Theme.secondaryText)
            Text(searchText.isEmpty ? "No macros here" : "No macros match")
                .font(.headline)
                .foregroundStyle(Theme.primaryText)
            Button(searchText.isEmpty ? "Add Macro" : "Clear search") {
                if searchText.isEmpty {
                    showEditor = true
                } else {
                    searchText = ""
                }
            }
            .buttonStyle(PrimaryButtonStyle(accent: accent))
            .padding(.horizontal, 60)
            Spacer()
        }
    }
    
    private func deleteMacro(_ macro: Macro) {
        // Delete associated schedules
        let macroId = macro.id
        let descriptor = FetchDescriptor<Schedule>(predicate: #Predicate { $0.macroId == macroId })
        if let schedules = try? context.fetch(descriptor) {
            schedules.forEach { context.delete($0) }
        }
        context.delete(macro)
        try? context.save()
    }
}

struct MacroRow: View {
    let macro: Macro
    var isRunning: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            if let data = macro.imageData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                MacroPlaceholderTile(category: macro.category, size: 52)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(macro.name)
                    .font(.headline)
                    .foregroundStyle(Theme.primaryText)
                Text("!\(macro.command)")
                    .font(.caption.monospaced())
                    .foregroundStyle(Theme.secondaryText)
            }
            
            Spacer()
            
            if isRunning {
                Text("RUNNING")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.statusGreen, in: Capsule())
            }
            
            if macro.isCustom {
                Text("Custom")
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Theme.elevated, in: Capsule())
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(Theme.surface)
    }
}
