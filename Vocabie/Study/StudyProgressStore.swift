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

    /// Drop every saved round for one set — used when the set itself is deleted, so a
    /// set's progress doesn't outlive it in `UserDefaults`.
    static func clearAll(setID: UUID) {
        let marker = "|\(setID.uuidString)|"
        for key in UserDefaults.standard.dictionaryRepresentation().keys
        where key.hasPrefix(prefix) && key.contains(marker) {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}

/// Remembers which 묶음 a mode was last studied on, per set.
///
/// Progress *inside* a round is `StudyProgressStore`'s job. This is the coarser question
/// the learner actually asks on the way back in — "where was I?" — and it has to survive
/// finishing a round, which is exactly when the in-round progress is thrown away.
enum StudyPlaceStore {
    private static let prefix = "studyPlace."

    private static func key(_ mode: StudyMode, _ setID: UUID) -> String {
        "\(prefix)\(mode.rawValue)|\(setID.uuidString)"
    }

    /// The saved round index, or `nil` if this mode has never run on this set.
    static func load(mode: StudyMode, setID: UUID) -> Int? {
        let k = key(mode, setID)
        guard UserDefaults.standard.object(forKey: k) != nil else { return nil }
        return UserDefaults.standard.integer(forKey: k)
    }

    static func save(round: Int, mode: StudyMode, setID: UUID) {
        UserDefaults.standard.set(round, forKey: key(mode, setID))
    }

    static func clear(mode: StudyMode, setID: UUID) {
        UserDefaults.standard.removeObject(forKey: key(mode, setID))
    }

    /// Forget every mode's place for one set, for when the set is deleted.
    static func clearAll(setID: UUID) {
        for mode in StudyMode.allCases { clear(mode: mode, setID: setID) }
    }
}
