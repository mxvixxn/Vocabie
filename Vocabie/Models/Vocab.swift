import Foundation
import SwiftData

/// A single vocabulary card: a term (영단어) paired with its meaning (뜻).
@Model
final class Vocab {
    var id: UUID = UUID()

    /// The word to learn — typically the English term.
    var term: String = ""
    /// The meaning — typically the Korean definition.
    var meaning: String = ""
    /// Optional extra: pronunciation, part of speech, or an example sentence.
    var note: String = ""

    /// Display / study order within the set.
    var order: Int = 0

    // MARK: Per-mode mastery tracking

    // Tracked per direction: knowing 영단어 → 뜻 is not the same skill as producing the
    // word from its meaning, so each direction earns its own stars. The unsuffixed
    // fields are 영단어 → 뜻 (what every card already carried before the split).

    /// Whether the card has been seen at least once in 암기 (Memorize), 영단어 → 뜻.
    var memorizeSeen: Bool = false
    /// Consecutive correct answers in 리콜 (Recall), 영단어 → 뜻.
    var recallStreak: Int = 0
    /// Consecutive correct answers in 스펠 (Spell), 영단어 → 뜻.
    var spellStreak: Int = 0

    /// 암기 seen in the 뜻 → 영단어 direction.
    var memorizeSeenReverse: Bool = false
    /// 리콜 streak in the 뜻 → 영단어 direction.
    var recallStreakReverse: Int = 0
    /// 스펠 streak in the 뜻 → 영단어 direction.
    var spellStreakReverse: Int = 0

    /// Lifetime tallies for the stats view.
    var timesCorrect: Int = 0
    var timesWrong: Int = 0
    var lastStudied: Date?

    // MARK: Spaced repetition
    //
    // Session repetition ("keep going until you clear it") only fixes a word for today.
    // These fields carry it across days: each successful retrieval pushes the next
    // review further out, each lapse pulls it back in.

    /// When this card should next be reviewed. `nil` means it has never been graded.
    var dueDate: Date?
    /// Current spacing in days. 0 means not yet scheduled.
    var interval: Double = 0
    /// How fast the interval grows. Starts at 2.5 and drifts with performance.
    var ease: Double = 2.5
    /// Times the card was forgotten after having been learned.
    var lapses: Int = 0
    /// Completed graded reviews.
    var reviewCount: Int = 0

    var createdAt: Date = Date()

    var set: VocabSet?

    init(term: String, meaning: String, note: String = "", order: Int = 0) {
        self.id = UUID()
        self.term = term
        self.meaning = meaning
        self.note = note
        self.order = order
        self.createdAt = Date()
    }
}

extension Vocab {
    /// The voice this card is read in — taken from its set, so a mixed review still
    /// pronounces each word in its own language.
    var voiceCode: String { self.set?.language.voiceCode ?? StudyLanguage.english.voiceCode }

    /// Whether this card can be asked for in 스펠 — decided by its set's language.
    var voiceSupportsSpell: Bool { self.set?.language.supportsSpell ?? true }

    /// Key used to decide whether two cards are "the same word" — case- and
    /// whitespace-insensitive on the term. Used to spot duplicates when adding words.
    static func dedupKey(_ term: String) -> String {
        term.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var dedupKey: String { Vocab.dedupKey(term) }

    /// Mastery in one direction, 0...3 stars.
    /// One star for having been seen, one for a recall streak, one for a spell streak.
    func starRating(for direction: StudyDirection) -> Int {
        var stars = 0
        if memorizeSeen(direction) { stars += 1 }
        if recallStreak(direction) >= 1 { stars += 1 }
        if spellStreak(direction) >= 1 { stars += 1 }
        return stars
    }

    /// Mastery across both directions, 0...6 — what set- and shelf-level progress counts.
    var starRating: Int {
        StudyDirection.allCases.reduce(0) { $0 + starRating(for: $1) }
    }

    // MARK: Per-direction accessors

    func memorizeSeen(_ d: StudyDirection) -> Bool {
        d == .termToMeaning ? memorizeSeen : memorizeSeenReverse
    }

    func recallStreak(_ d: StudyDirection) -> Int {
        d == .termToMeaning ? recallStreak : recallStreakReverse
    }

    func spellStreak(_ d: StudyDirection) -> Int {
        d == .termToMeaning ? spellStreak : spellStreakReverse
    }

    func setMemorizeSeen(_ value: Bool, _ d: StudyDirection) {
        if d == .termToMeaning { memorizeSeen = value } else { memorizeSeenReverse = value }
    }

    func setRecallStreak(_ value: Int, _ d: StudyDirection) {
        if d == .termToMeaning { recallStreak = value } else { recallStreakReverse = value }
    }

    func setSpellStreak(_ value: Int, _ d: StudyDirection) {
        if d == .termToMeaning { spellStreak = value } else { spellStreakReverse = value }
    }

    func recordCorrect() {
        timesCorrect += 1
        lastStudied = Date()
    }

    func recordWrong() {
        timesWrong += 1
        lastStudied = Date()
    }

    // MARK: Review state

    /// Due for review now. Cards never graded are not due — they belong in a first pass.
    func isDue(asOf now: Date = Date()) -> Bool {
        guard let dueDate else { return false }
        return dueDate <= now
    }

    /// Graded at least once, so it has a place in the review schedule.
    var isScheduled: Bool { dueDate != nil }

    /// Repeatedly forgotten — worth surfacing separately.
    var isLeech: Bool { lapses >= 4 }
}
