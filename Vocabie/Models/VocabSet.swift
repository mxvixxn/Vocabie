import Foundation
import SwiftData

/// A study set (세트) — a named collection of vocabulary cards, and the unit everything
/// about studying is built on: rounds, progress, review scheduling.
///
/// A set may sit inside a `Notebook` (단어장) or on its own. Optional membership is what
/// keeps "just make me a set" a one-tap path, and it is why every set that existed
/// before 단어장 did needs no migration — it simply has no shelf yet.
@Model
final class VocabSet {
    var id: UUID = UUID()
    var title: String = ""
    /// Free-form note shown under the title (source, chapter, etc.)
    var detail: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    /// Where the learner dragged this 세트 to, within its 단어장 (or within 미분류).
    /// Ties fall back to `updatedAt`. See `Reorder.apply`.
    var order: Int = 0
    /// Archived sets are hidden from the main list and from today's review,
    /// but kept so they can be restored later.
    var isArchived: Bool = false

    /// The 단어장 this set belongs to. `nil` means it stands alone (미분류).
    var notebook: Notebook?

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
    /// The order the library lists sets in. Sets that have never been dragged all share
    /// `order == 0`, so they keep falling back to newest-first — the arrangement only
    /// takes over once there is one.
    static func inListOrder(_ a: VocabSet, _ b: VocabSet) -> Bool {
        a.order == b.order ? a.updatedAt > b.updatedAt : a.order < b.order
    }

    /// In play — neither the set nor the shelf it sits on is archived.
    ///
    /// Archiving is meant to mean "out of sight for now", and a learner who put a whole
    /// 단어장 away expects today's review to honour that. `@Query` can't follow an
    /// optional relationship in a predicate, so callers filter with this in Swift.
    var isActive: Bool { !isArchived && notebook?.isArchived != true }

    /// Cards in their stored display order.
    var orderedWords: [Vocab] {
        words.sorted { $0.order < $1.order }
    }

    var wordCount: Int { words.count }

    /// 0.0 ... 1.0 — how much of the set's study is done, counted in stars earned
    /// out of the stars on offer (3 per card: 암기 · 리콜 · 스펠).
    ///
    /// Not "share of fully mastered cards". That older reading stayed at 0% until a
    /// card had been through all three modes, so finishing 리콜 across a whole set
    /// moved nothing and the bar looked broken. Every mode a learner finishes should
    /// show up; clearing one of the three now reads as a third of the way.
    var masteryProgress: Double {
        guard !words.isEmpty else { return 0 }
        return Double(totalStars) / Double(words.count * 3)
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
