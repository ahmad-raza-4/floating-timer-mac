import SwiftUI
import AppKit

final class HistoryWindowController: NSObject, NSWindowDelegate {
    static let shared = HistoryWindowController()
    private var window: NSWindow?

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let hosting = NSHostingController(rootView: UsageHistoryView())
        let win = NSWindow(contentViewController: hosting)
        win.title = "Timer Usage — Last 30 Days"
        win.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        win.setContentSize(NSSize(width: 420, height: 480))
        win.minSize = NSSize(width: 340, height: 300)
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

struct UsageHistoryView: View {
    @State private var days: [(day: Date, runs: [TimerRunLog])] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if days.isEmpty {
                    Text("No timer sessions recorded yet.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else {
                    ForEach(days, id: \.day) { entry in
                        DaySummaryView(day: entry.day, runs: entry.runs)
                    }
                }
            }
            .padding(16)
        }
        .frame(minWidth: 380, minHeight: 420)
        .onAppear { days = UsageLogger.shared.runsGroupedByDay() }
    }
}

private struct DaySummaryView: View {
    let day: Date
    let runs: [TimerRunLog]
    @State private var expanded = false

    private var totalPlanned: TimeInterval { runs.reduce(0) { $0 + $1.plannedSeconds } }
    private var totalCompleted: TimeInterval { runs.reduce(0) { $0 + $1.completedSeconds } }
    private var completionRatio: Double { totalPlanned > 0 ? min(1, totalCompleted / totalPlanned) : 0 }

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(runs) { run in
                    HStack(spacing: 8) {
                        Image(systemName: run.finishedNaturally ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundStyle(run.finishedNaturally ? .green : .secondary)
                            .font(.system(size: 11))
                        Text(run.startedAt, style: .time)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Self.formatDuration(run.completedSeconds)) / \(Self.formatDuration(run.plannedSeconds))")
                            .font(.system(size: 12, design: .monospaced))
                    }
                }
            }
            .padding(.top, 6)
            .padding(.leading, 2)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(day, style: .date)
                        .font(.system(size: 14, weight: .semibold))
                    Text("\(runs.count) session\(runs.count == 1 ? "" : "s") · \(Self.formatDuration(totalCompleted)) of \(Self.formatDuration(totalPlanned))")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                ProgressBar(progress: completionRatio)
                    .frame(width: 50, height: 5)
            }
        }
    }

    static func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%dh %02dm", h, m) }
        if m > 0 { return String(format: "%dm %02ds", m, s) }
        return String(format: "%ds", s)
    }
}

private struct ProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.gray.opacity(0.25))
                Capsule().fill(Color.accentColor).frame(width: geo.size.width * progress)
            }
        }
        .clipShape(Capsule())
    }
}
