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

    /// Whether the card has been seen at least once in 암기 (Memorize).
    var memorizeSeen: Bool = false
    /// Consecutive correct answers in 리콜 (Recall).
    var recallStreak: Int = 0
    /// Consecutive correct answers in 스펠 (Spell).
    var spellStreak: Int = 0

    /// Lifetime tallies for the stats view.
    var timesCorrect: Int = 0
    var timesWrong: Int = 0
    var lastStudied: Date?

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
    /// Overall mastery, 0...3 stars.
    /// One star for having been seen, one for a recall streak, one for a spell streak.
    var starRating: Int {
        var stars = 0
        if memorizeSeen { stars += 1 }
        if recallStreak >= 1 { stars += 1 }
        if spellStreak >= 1 { stars += 1 }
        return stars
    }

    func recordCorrect() {
        timesCorrect += 1
        lastStudied = Date()
    }

    func recordWrong() {
        timesWrong += 1
        lastStudied = Date()
    }
}
