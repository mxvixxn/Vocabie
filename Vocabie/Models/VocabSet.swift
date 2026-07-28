import Foundation
import SwiftData

/// A study set (단어장) — a named collection of vocabulary cards.
@Model
final class VocabSet {
    var id: UUID = UUID()
    var title: String = ""
    /// Free-form note shown under the title (source, chapter, etc.)
    var detail: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    /// Archived sets are hidden from the main list and from today's review,
    /// but kept so they can be restored later.
    var isArchived: Bool = false

    /// Cards belonging to this set. Deleting the set deletes its cards.
    @Relationship(deleteRule: .cascade, inverse: \Vocab.set)
    var words: [Vocab] = []

    init(title: String, detail: String = "") {
        self.id = UUID()
        self.title = title
        self.detail = detail
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

extension VocabSet {
    /// Cards in their stored display order.
    var orderedWords: [Vocab] {
        words.sorted { $0.order < $1.order }
    }

    var wordCount: Int { words.count }

    /// 0.0 ... 1.0 — share of cards that have reached full mastery (3 stars).
    var masteryProgress: Double {
        guard !words.isEmpty else { return 0 }
        let mastered = words.reduce(0) { $0 + ($1.starRating >= 3 ? 1 : 0) }
        return Double(mastered) / Double(words.count)
    }

    /// Total stars earned across all cards (used for the set summary).
    var totalStars: Int {
        words.reduce(0) { $0 + $1.starRating }
    }

    /// Cards whose review date has arrived.
    func dueWords(asOf now: Date = Date()) -> [Vocab] {
        words.filter { $0.isDue(asOf: now) }
    }

    func dueCount(asOf now: Date = Date()) -> Int {
        dueWords(asOf: now).count
    }

    func touch() {
        updatedAt = Date()
    }
}
