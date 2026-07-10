import SwiftUI
import Charts
import AppKit

final class StatsWindowController: NSObject, NSWindowDelegate {
    static let shared = StatsWindowController()
    private var window: NSWindow?

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let hosting = NSHostingController(rootView: StatsWidgetView())
        let win = NSWindow(contentViewController: hosting)
        win.title = "Timer Stats"
        win.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        win.setContentSize(NSSize(width: 480, height: 360))
        win.minSize = NSSize(width: 380, height: 300)
        win.center()
        win.isReleasedWhenClosed = false
        win.delegate = self
        window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}

enum StatsRange: String, CaseIterable, Identifiable, Hashable {
    case sevenDays = "Last 7 Days"
    case thirtyDays = "Last 30 Days"

    var id: String { rawValue }
    var dayCount: Int { self == .sevenDays ? 7 : 30 }
}

private struct DailyTotal: Identifiable {
    let day: Date
    let totalSeconds: TimeInterval
    var id: Date { day }
    var totalHours: Double { totalSeconds / 3600 }
}

struct StatsWidgetView: View {
    @State private var range: StatsRange = .sevenDays
    @State private var dailyTotals: [DailyTotal] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Timer Usage")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Picker("", selection: $range) {
                    ForEach(StatsRange.allCases) { r in
                        Text(r.rawValue).tag(r)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 150)
            }

            HStack(spacing: 28) {
                statTile(title: "Total", value: formatDuration(totalSeconds))
                statTile(title: "Daily Avg", value: formatDuration(averageSeconds))
                statTile(title: "Active Days", value: "\(activeDayCount)/\(range.dayCount)")
            }

            Chart(dailyTotals) { entry in
                BarMark(
                    x: .value("Day", entry.day, unit: .day),
                    y: .value("Hours", entry.totalHours)
                )
                .foregroundStyle(Color.accentColor)
                .cornerRadius(3)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: range == .sevenDays ? 1 : 5)) { value in
                    AxisGridLine()
                    if let date = value.as(Date.self) {
                        AxisValueLabel(dateLabel(date))
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(minHeight: 180)
        }
        .padding(18)
        .frame(minWidth: 420, minHeight: 320)
        .onAppear { reload() }
        .onChange(of: range) { _ in reload() }
    }

    private func reload() {
        dailyTotals = Self.buildDailyTotals(for: range)
    }

    private var totalSeconds: TimeInterval { dailyTotals.reduce(0) { $0 + $1.totalSeconds } }
    private var activeDayCount: Int { dailyTotals.filter { $0.totalSeconds > 0 }.count }
    private var averageSeconds: TimeInterval {
        guard !dailyTotals.isEmpty else { return 0 }
        return totalSeconds / Double(dailyTotals.count)
    }

    private func dateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = range == .sevenDays ? "EEE" : "M/d"
        return formatter.string(from: date)
    }

    private func statTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    private static func buildDailyTotals(for range: StatsRange) -> [DailyTotal] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let grouped = UsageLogger.shared.runsGroupedByDay()
        let totalsByDay = Dictionary(uniqueKeysWithValues: grouped.map { entry -> (Date, TimeInterval) in
            (entry.day, entry.runs.reduce(0) { $0 + $1.completedSeconds })
        })

        return (0..<range.dayCount).reversed().compactMap { offset -> DailyTotal? in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DailyTotal(day: day, totalSeconds: totalsByDay[day] ?? 0)
        }
    }
}
