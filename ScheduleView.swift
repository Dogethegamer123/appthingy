import SwiftUI
import SwiftData
import UserNotifications

struct ScheduleView: View {
    @Query private var schedules: [Schedule]
    @Query private var macros: [Macro]
    @Query private var settings: [AppSettings]
    @Environment(\.modelContext) private var context
    
    @State private var showEditor = false
    @State private var editingSchedule: Schedule?
    @State private var notificationsAllowed = true
    
    private var accent: Color { Color(hex: settings.first?.accentHex ?? Theme.defaultAccent) }
    
    private var nextOccurrence: (schedule: Schedule, macro: Macro, date: Date)? {
        let now = Date.now
        var best: (Schedule, Macro, Date)?
        for sched in schedules where sched.isEnabled {
            guard let macro = macros.first(where: { $0.id == sched.macroId }) else { continue }
            if let next = nextDate(for: sched, after: now) {
                if best == nil || next < best!.2 {
                    best = (sched, macro, next)
                }
            }
        }
        return best
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.spacing16) {
                    // Permission banner
                    if !notificationsAllowed {
                        HStack {
                            Image(systemName: "bell.slash.fill")
                                .foregroundStyle(Color(hex: "FF0000"))
                            Text("Notifications are off — schedules can’t alert you")
                                .font(.subheadline)
                                .foregroundStyle(Theme.primaryText)
                            Spacer()
                            Button("Open Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .font(.caption.bold())
                            .foregroundStyle(accent)
                        }
                        .padding(Theme.spacing12)
                        .background(Color(hex: "FF0000").opacity(0.15), in: RoundedRectangle(cornerRadius: Theme.cardRadius))
                        .padding(.horizontal, Theme.spacing16)
                    }
                    
                    // Up next card
                    upNextCard
                        .padding(.horizontal, Theme.spacing16)
                    
                    if schedules.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: Theme.spacing8) {
                            ForEach(schedules, id: \.id) { schedule in
                                if let macro = macros.first(where: { $0.id == schedule.macroId }) {
                                    ScheduleRow(schedule: schedule, macro: macro, accent: accent, context: context)
                                        .onTapGesture {
                                            editingSchedule = schedule
                                        }
                                }
                            }
                        }
                        .padding(.horizontal, Theme.spacing16)
                    }
                    
                    // Info card
                    infoCard
                        .padding(.horizontal, Theme.spacing16)
                }
                .padding(.vertical, Theme.spacing16)
                .padding(.bottom, 80)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Schedule")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editingSchedule = nil
                        showEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showEditor) {
                ScheduleEditorView(schedule: nil)
            }
            .sheet(item: $editingSchedule) { sched in
                ScheduleEditorView(schedule: sched)
            }
            .onAppear { checkNotificationAuth() }
        }
    }
    
    @ViewBuilder
    private var upNextCard: some View {
        if let next = nextOccurrence {
            VStack(alignment: .leading, spacing: 6) {
                Text("UP NEXT")
                    .font(.caption.bold())
                    .foregroundStyle(Theme.secondaryText)
                Text(next.macro.name)
                    .font(.title3.bold())
                    .foregroundStyle(Theme.primaryText)
                Text(next.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    Text("in \(countdownString(from: timeline.date, to: next.date))")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(accent)
                        .contentTransition(.numericText())
                }
            }
            .cardStyle()
        } else {
            VStack {
                Text("No upcoming schedules")
                    .font(.headline)
                    .foregroundStyle(Theme.secondaryText)
            }
            .cardStyle()
        }
    }
    
    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: Theme.spacing16) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 44))
                .foregroundStyle(Theme.secondaryText)
            Text("Schedule a macro")
                .font(.headline)
                .foregroundStyle(Theme.primaryText)
            Button("Add Schedule") {
                showEditor = true
            }
            .buttonStyle(PrimaryButtonStyle(accent: accent))
            .padding(.horizontal, 60)
        }
        .padding(.vertical, Theme.spacing32)
    }
    
    private var infoCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .foregroundStyle(Theme.secondaryText)
            Text("How scheduling works: At the scheduled time you’ll get a notification with a “Start now” button. If AFK Remote is open, the command is sent automatically. iOS controls background activity, so automatic sending while the app is closed is best-effort and may be late or skipped — the notification is the reliable part.")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(Theme.spacing12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }
    
    private func checkNotificationAuth() {
        UNUserNotificationCenter.current().getNotificationSettings { s in
            DispatchQueue.main.async {
                notificationsAllowed = s.authorizationStatus != .denied
            }
        }
    }
    
    private func nextDate(for schedule: Schedule, after now: Date) -> Date? {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: schedule.time)
        let minute = cal.component(.minute, from: schedule.time)
        
        switch schedule.repeatType {
        case "once":
            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: schedule.time)
            if let d = cal.date(from: comps), d > now { return d }
            return nil
        case "daily":
            var comps = DateComponents()
            comps.hour = hour
            comps.minute = minute
            return cal.nextDate(after: now, matching: comps, matchingPolicy: .nextTime)
        case "weekdays":
            var dates: [Date] = []
            for wd in schedule.selectedWeekdays {
                var comps = DateComponents()
                comps.hour = hour
                comps.minute = minute
                comps.weekday = wd
                if let d = cal.nextDate(after: now, matching: comps, matchingPolicy: .nextTime) {
                    dates.append(d)
                }
            }
            return dates.min()
        default:
            return nil
        }
    }
    
    private func countdownString(from now: Date, to target: Date) -> String {
        let diff = Int(max(0, target.timeIntervalSince(now)))
        let h = diff / 3600
        let m = (diff % 3600) / 60
        let s = diff % 60
        if h > 0 {
            return String(format: "%dh %02dm %02ds", h, m, s)
        }
        return String(format: "%dm %02ds", m, s)
    }
}

struct ScheduleRow: View {
    let schedule: Schedule
    let macro: Macro
    let accent: Color
    let context: ModelContext
    
    var body: some View {
        HStack(spacing: 12) {
            MacroPlaceholderTile(category: macro.category, size: 44)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(macro.name)
                    .font(.headline)
                    .foregroundStyle(Theme.primaryText)
                Text(repeatSummary)
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
            
            Spacer()
            
            Text(timeString)
                .font(.title3.monospacedDigit().bold())
                .foregroundStyle(Theme.primaryText)
            
            Toggle("", isOn: Binding(
                get: { schedule.isEnabled },
                set: { newVal in
                    schedule.isEnabled = newVal
                    try? context.save()
                }
            ))
            .tint(accent)
            .labelsHidden()
        }
        .cardStyle()
    }
    
    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: schedule.time)
    }
    
    private var repeatSummary: String {
        switch schedule.repeatType {
        case "once":
            let f = DateFormatter()
            f.dateFormat = "MMM d"
            return "Once · \(f.string(from: schedule.time))"
        case "daily":
            return "Daily"
        case "weekdays":
            let days = ["S", "M", "T", "W", "T", "F", "S"]
            let selected = schedule.selectedWeekdays.sorted().compactMap { i -> String? in
                guard i >= 1, i <= 7 else { return nil }
                return days[i - 1]
            }
            return selected.joined(separator: ", ")
        default:
            return ""
        }
    }
}
