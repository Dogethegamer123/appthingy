import SwiftUI
import SwiftData
import UserNotifications

struct ScheduleEditorView: View {
    let schedule: Schedule?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var macros: [Macro]
    
    @State private var selectedMacroId: UUID?
    @State private var time = Date()
    @State private var repeatType = "once"
    @State private var selectedWeekdays: Set<Int> = []
    @State private var isEnabled = true
    @State private var showMacroPicker = false
    
    private var isEditing: Bool { schedule != nil }
    private var selectedMacro: Macro? { macros.first(where: { $0.id == selectedMacroId }) }
    private var isValid: Bool { selectedMacroId != nil && (repeatType != "weekdays" || !selectedWeekdays.isEmpty) }
    
    private let weekdayLabels = ["S", "M", "T", "W", "T", "F", "S"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Macro") {
                    NavigationLink {
                        MacroPickerList(selectedId: $selectedMacroId)
                    } label: {
                        HStack {
                            Text("Macro")
                            Spacer()
                            Text(selectedMacro?.name ?? "Choose...")
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                }
                
                Section("Time") {
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                }
                
                Section("Repeat") {
                    Picker("Repeat", selection: $repeatType) {
                        Text("Once").tag("once")
                        Text("Daily").tag("daily")
                        Text("Weekdays").tag("weekdays")
                    }
                    .pickerStyle(.segmented)
                    
                    if repeatType == "once" {
                        DatePicker("Date", selection: $time, displayedComponents: .date)
                    }
                    
                    if repeatType == "weekdays" {
                        HStack(spacing: 8) {
                            ForEach(1...7, id: \.self) { day in
                                Button {
                                    if selectedWeekdays.contains(day) {
                                        selectedWeekdays.remove(day)
                                    } else {
                                        selectedWeekdays.insert(day)
                                    }
                                } label: {
                                    Text(weekdayLabels[day - 1])
                                        .font(.caption.bold())
                                        .frame(width: 36, height: 36)
                                        .background(
                                            selectedWeekdays.contains(day) ? Color(hex: "FF0000") : Theme.elevated,
                                            in: Circle()
                                        )
                                        .foregroundStyle(.white)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                
                Section {
                    Toggle("Enabled", isOn: $isEnabled)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(isEditing ? "Edit Schedule" : "New Schedule")
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
            .onAppear { loadSchedule() }
        }
    }
    
    private func loadSchedule() {
        guard let s = schedule else { return }
        selectedMacroId = s.macroId
        time = s.time
        repeatType = s.repeatType
        selectedWeekdays = Set(s.selectedWeekdays)
        isEnabled = s.isEnabled
    }
    
    private func save() {
        // Request notifications
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        
        guard let macroId = selectedMacroId else { return }
        
        if let s = schedule {
            s.macroId = macroId
            s.time = time
            s.repeatType = repeatType
            s.selectedWeekdays = Array(selectedWeekdays.sorted())
            s.isEnabled = isEnabled
        } else {
            let newSched = Schedule(
                macroId: macroId,
                time: time,
                repeatType: repeatType,
                selectedWeekdays: Array(selectedWeekdays.sorted()),
                isEnabled: isEnabled
            )
            context.insert(newSched)
        }
        try? context.save()
        scheduleNotifications()
        dismiss()
    }
    
    private func scheduleNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        
        let descriptor = FetchDescriptor<Schedule>()
        guard let allSchedules = try? context.fetch(descriptor) else { return }
        
        for sched in allSchedules where sched.isEnabled {
            guard let macro = macros.first(where: { $0.id == sched.macroId }) else { continue }
            let cal = Calendar.current
            let hour = cal.component(.hour, from: sched.time)
            let minute = cal.component(.minute, from: sched.time)
            
            let content = UNMutableNotificationContent()
            content.title = "Time to run \(macro.name)"
            content.body = "Tap Start now to send !\(macro.command)."
            content.sound = .default
            content.userInfo = ["scheduleId": sched.id.uuidString, "macroId": macro.id.uuidString, "command": macro.command]
            
            switch sched.repeatType {
            case "once":
                let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: sched.time)
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                let req = UNNotificationRequest(identifier: sched.id.uuidString, content: content, trigger: trigger)
                center.add(req)
            case "daily":
                var comps = DateComponents()
                comps.hour = hour
                comps.minute = minute
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
                let req = UNNotificationRequest(identifier: sched.id.uuidString, content: content, trigger: trigger)
                center.add(req)
            case "weekdays":
                for wd in sched.selectedWeekdays {
                    var comps = DateComponents()
                    comps.hour = hour
                    comps.minute = minute
                    comps.weekday = wd
                    let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
                    let req = UNNotificationRequest(identifier: "\(sched.id.uuidString)-\(wd)", content: content, trigger: trigger)
                    center.add(req)
                }
            default:
                break
            }
        }
    }
}

struct MacroPickerList: View {
    @Binding var selectedId: UUID?
    @Query private var macros: [Macro]
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss
    
    private var filtered: [Macro] {
        if searchText.isEmpty { return macros }
        return macros.filter { $0.name.localizedCaseInsensitiveContains(searchText) || $0.command.localizedCaseInsensitiveContains(searchText) }
    }
    
    private var grouped: [(String, [Macro])] {
        var result: [(String, [Macro])] = []
        for cat in MacroCategory.allCases {
            let items = filtered.filter { $0.category == cat.rawValue }
            if !items.isEmpty {
                result.append((cat.displayName, items))
            }
        }
        return result
    }
    
    var body: some View {
        List {
            ForEach(grouped, id: \.0) { name, items in
                Section(name) {
                    ForEach(items, id: \.id) { macro in
                        Button {
                            selectedId = macro.id
                            dismiss()
                        } label: {
                            HStack {
                                MacroPlaceholderTile(category: macro.category, size: 36)
                                Text(macro.name)
                                    .foregroundStyle(Theme.primaryText)
                                Spacer()
                                if macro.id == selectedId {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color(hex: "FF0000"))
                                }
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search macros")
        .navigationTitle("Choose Macro")
        .navigationBarTitleDisplayMode(.inline)
    }
}
