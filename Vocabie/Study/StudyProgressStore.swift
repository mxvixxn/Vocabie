import Foundation

/// A resumable snapshot of a 리콜 / 스펠 session — enough to rebuild the queue and
/// pick up where the learner left off.
struct StudyProgress: Codable {
    /// Remaining cards, in the order they'll be shown next.
    var queueIDs: [UUID]
    /// Cards already cleared this session.
    var clearedIDs: [UUID]
    /// Misses per card so far (feeds spaced-repetition grading on the next clear).
    var misses: [UUID: Int]
    /// Total cards in the round, so progress reads N/total after resuming.
    var total: Int
}

/// Persists in-progress sessions so leaving 리콜 / 스펠 mid-way doesn't lose progress.
/// Keyed per (mode · set · round); cleared when the round is finished.
enum StudyProgressStore {
    private static let prefix = "studyProgress."

    static func load(_ key: String) -> StudyProgress? {
        guard let data = UserDefaults.standard.data(forKey: prefix + key) else { return nil }
        return try? JSONDecoder().decode(StudyProgress.self, from: data)
    }

    static func save(_ progress: StudyProgress, key: String) {
        guard let data = try? JSONEncoder().encode(progress) else { return }
        UserDefaults.standard.set(data, forKey: prefix + key)
    }

    static func clear(_ key: String) {
        UserDefaults.standard.removeObject(forKey: prefix + key)
    }
}
