import Foundation

/// A keep-awake session: open-ended, or ending at a fixed time.
struct Session: Equatable {
    let startedAt: Date
    let endsAt: Date?

    init(startedAt: Date = Date(), duration: TimeInterval?) {
        self.startedAt = startedAt
        endsAt = duration.map { startedAt.addingTimeInterval($0) }
    }

    func remaining(at now: Date) -> TimeInterval? {
        endsAt.map { max(0, $0.timeIntervalSince(now)) }
    }

    func hasEnded(at now: Date) -> Bool {
        guard let endsAt else { return false }
        return now >= endsAt
    }
}

struct DurationPreset: Equatable {
    let title: String
    let seconds: TimeInterval

    static let all: [DurationPreset] = [
        DurationPreset(title: "15 Minutes", seconds: 15 * 60),
        DurationPreset(title: "30 Minutes", seconds: 30 * 60),
        DurationPreset(title: "1 Hour", seconds: 60 * 60),
        DurationPreset(title: "2 Hours", seconds: 2 * 60 * 60),
        DurationPreset(title: "4 Hours", seconds: 4 * 60 * 60),
        DurationPreset(title: "8 Hours", seconds: 8 * 60 * 60),
    ]
}

enum RemainingFormat {
    /// "1h 5m", "2h", "45m". Rounds up so the final minute reads "1m", never "0m".
    static func short(_ interval: TimeInterval) -> String {
        let minutes = max(1, Int((interval / 60).rounded(.up)))
        let hours = minutes / 60, rest = minutes % 60
        if hours == 0 { return "\(rest)m" }
        return rest == 0 ? "\(hours)h" : "\(hours)h \(rest)m"
    }
}
