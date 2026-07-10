import Foundation

struct TimerRunLog: Codable, Identifiable {
    let id: UUID
    let startedAt: Date
    let plannedSeconds: TimeInterval
    let completedSeconds: TimeInterval
    let finishedNaturally: Bool
}

final class UsageLogger {
    static let shared = UsageLogger()

    private let fileURL: URL
    private var runs: [TimerRunLog] = []

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FloatingTimer", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("usage_log.json")
        load()
    }

    private static let minimumLoggableSeconds: TimeInterval = 60

    func record(startedAt: Date, plannedSeconds: TimeInterval, completedSeconds: TimeInterval, finishedNaturally: Bool) {
        guard completedSeconds >= Self.minimumLoggableSeconds else { return }
        runs.append(TimerRunLog(
            id: UUID(),
            startedAt: startedAt,
            plannedSeconds: plannedSeconds,
            completedSeconds: completedSeconds,
            finishedNaturally: finishedNaturally
        ))
        prune()
        save()
    }

    func runsGroupedByDay() -> [(day: Date, runs: [TimerRunLog])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: runs) { calendar.startOfDay(for: $0.startedAt) }
        return grouped
            .map { (day: $0.key, runs: $0.value.sorted { $0.startedAt > $1.startedAt }) }
            .sorted { $0.day > $1.day }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        runs = (try? JSONDecoder().decode([TimerRunLog].self, from: data)) ?? []
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(runs) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func prune() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? .distantPast
        runs.removeAll { $0.startedAt < cutoff }
    }
}
