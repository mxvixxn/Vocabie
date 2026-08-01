import Foundation
import SwiftData

/// A 단어장 — the shelf a group of sets sits on.
///
/// One mock exam, one textbook, one semester: material arrives in chunks that belong
/// together but are studied a chunk at a time. The 세트 stays the unit of study; this
/// is only the thing that keeps a term's worth of them from filling the whole list.
///
/// Membership is optional on purpose — see `VocabSet.notebook`.
@Model
final class Notebook {
    var id: UUID = UUID()
    var title: String = ""
    /// Free-form note shown under the title (source, year, etc.)
    var detail: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    /// Where the learner dragged this 단어장 to. Ties fall back to `updatedAt`, so a
    /// library that has never been rearranged still reads newest-first, and one that
    /// has keeps the arrangement across launches. See `Reorder.apply`.
    var order: Int = 0
    /// Archiving a 단어장 takes its sets out of the list and out of today's review
    /// without touching their own archive flag, so restoring brings back exactly
    /// what was there. See `VocabSet.isActive`.
    var isArchived: Bool = false

    /// Sets on this shelf. Deleting the 단어장 deletes them, and their words with them.
    @Relationship(deleteRule: .cascade, inverse: \VocabSet.notebook)
    var sets: [VocabSet] = []

    init(title: String, detail: String = "") {
        self.id = UUID()
        self.title = title
        self.detail = detail
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

extension Notebook {
    /// Same rule as `VocabSet.inListOrder`, for the 단어장 list.
    static func inListOrder(_ a: Notebook, _ b: Notebook) -> Bool {
        a.order == b.order ? a.updatedAt > b.updatedAt : a.order < b.order
    }

    /// Sets in the order the list shows them: as arranged, newest-first among ties.
    var orderedSets: [VocabSet] {
        sets.sorted(by: VocabSet.inListOrder)
    }

    var setCount: Int { sets.count }

    /// Every card on the shelf, so the summary counts match what tapping through shows.
    var allWords: [Vocab] { sets.flatMap(\.words) }

    var wordCount: Int { allWords.count }

    var totalStars: Int { allWords.reduce(0) { $0 + $1.starRating } }

    /// 0.0 ... 1.0 — stars earned out of stars on offer, same measure as `VocabSet`.
    ///
    /// Weighted by card, not by set: a 100-word set and a 5-word set shouldn't count
    /// the same when the number is meant to answer "how far through this am I".
    var masteryProgress: Double {
        let count = wordCount
        guard count > 0 else { return 0 }
        return Double(totalStars) / Double(count * 3)
    }

    func dueCount(asOf now: Date = Date()) -> Int {
        sets.reduce(0) { $0 + $1.dueCount(asOf: now) }
    }

    func touch() {
        updatedAt = Date()
    }
}
