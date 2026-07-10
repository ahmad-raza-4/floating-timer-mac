import Foundation
import AppKit

enum RunState: Equatable {
    case idle
    case running
    case paused
    case finished
}

final class TimerModel: ObservableObject {
    @Published var totalDuration: TimeInterval
    @Published var remaining: TimeInterval
    @Published var state: RunState = .idle

    private var timer: Timer?
    private var endDate: Date?
    private var pausedRemaining: TimeInterval
    private var runStartedAt: Date?

    static let presets: [(label: String, seconds: TimeInterval)] = [
        ("5 min", 5 * 60),
        ("10 min", 10 * 60),
        ("15 min", 15 * 60),
        ("25 min", 25 * 60),
        ("30 min", 30 * 60),
        ("45 min", 45 * 60),
        ("1 hr", 1 * 3600),
        ("2 hr", 2 * 3600),
        ("4 hr", 4 * 3600),
        ("6 hr", 6 * 3600),
        ("8 hr", 8 * 3600),
        ("9 hr", 9 * 3600),
        ("10 hr", 10 * 3600),
        ("12 hr", 12 * 3600)
    ]

    private static let durationDefaultsKey = "totalDurationSeconds"
    private static let activeStartedAtKey = "activeRun.startedAt"
    private static let activePlannedSecondsKey = "activeRun.plannedSeconds"
    private static let activeLastRemainingKey = "activeRun.lastRemaining"
    private var lastPersistedWholeSecond: Int = -1

    init() {
        let saved = UserDefaults.standard.double(forKey: Self.durationDefaultsKey)
        let initial = saved > 0 ? saved : 9 * 3600
        self.totalDuration = initial
        self.remaining = initial
        self.pausedRemaining = initial
        recoverInterruptedRunIfNeeded()
    }

    /// If the app was killed without a graceful quit (crash, force-quit, Mac restart)
    /// while a timer was running, the in-progress run never got logged. Recover it here
    /// so that history isn't silently lost; the new session still starts fresh from idle.
    private func recoverInterruptedRunIfNeeded() {
        let defaults = UserDefaults.standard
        guard let startedAt = defaults.object(forKey: Self.activeStartedAtKey) as? Date else { return }
        let planned = defaults.double(forKey: Self.activePlannedSecondsKey)
        let lastRemaining = defaults.double(forKey: Self.activeLastRemainingKey)
        let completed = max(0, planned - lastRemaining)
        UsageLogger.shared.record(
            startedAt: startedAt,
            plannedSeconds: planned,
            completedSeconds: completed,
            finishedNaturally: false
        )
        clearPersistedActiveRun()
    }

    private func persistActiveRun() {
        guard let runStartedAt else { return }
        let defaults = UserDefaults.standard
        defaults.set(runStartedAt, forKey: Self.activeStartedAtKey)
        defaults.set(totalDuration, forKey: Self.activePlannedSecondsKey)
        defaults.set(remaining, forKey: Self.activeLastRemainingKey)
    }

    private func clearPersistedActiveRun() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Self.activeStartedAtKey)
        defaults.removeObject(forKey: Self.activePlannedSecondsKey)
        defaults.removeObject(forKey: Self.activeLastRemainingKey)
        lastPersistedWholeSecond = -1
    }

    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return max(0, min(1, remaining / totalDuration))
    }

    func toggle() {
        switch state {
        case .idle, .paused:
            start()
        case .running:
            pause()
        case .finished:
            restart()
        }
    }

    func start() {
        guard state != .running else { return }
        if runStartedAt == nil {
            runStartedAt = Date()
        }
        endDate = Date().addingTimeInterval(pausedRemaining)
        state = .running
        persistActiveRun()
        scheduleTimer()
    }

    func pause() {
        guard state == .running else { return }
        pausedRemaining = remaining
        state = .paused
        timer?.invalidate()
        timer = nil
        persistActiveRun()
    }

    func stop() {
        logCurrentRun(finishedNaturally: false)
        state = .idle
        timer?.invalidate()
        timer = nil
        pausedRemaining = totalDuration
        remaining = totalDuration
    }

    /// Records an in-progress session without resetting state; call when the app is quitting.
    func logInProgressRunOnQuit() {
        logCurrentRun(finishedNaturally: false)
    }

    private func logCurrentRun(finishedNaturally: Bool) {
        guard let startedAt = runStartedAt else { return }
        let completed = totalDuration - remaining
        UsageLogger.shared.record(
            startedAt: startedAt,
            plannedSeconds: totalDuration,
            completedSeconds: completed,
            finishedNaturally: finishedNaturally
        )
        runStartedAt = nil
        clearPersistedActiveRun()
    }

    func restart() {
        stop()
        start()
    }

    func setDuration(_ seconds: TimeInterval) {
        totalDuration = seconds
        UserDefaults.standard.set(seconds, forKey: Self.durationDefaultsKey)
        stop()
    }

    private func scheduleTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        guard let endDate else { return }
        let rem = endDate.timeIntervalSinceNow
        if rem <= 0 {
            remaining = 0
            pausedRemaining = 0
            state = .finished
            timer?.invalidate()
            timer = nil
            NSSound.beep()
            logCurrentRun(finishedNaturally: true)
        } else {
            remaining = rem
            let whole = Int(rem)
            if whole != lastPersistedWholeSecond {
                lastPersistedWholeSecond = whole
                persistActiveRun()
            }
        }
    }
}
