import Foundation
import Observation

/// Drives a 리콜 / 스펠 study session with ClassCard's "positive repetition" logic:
/// every card must be answered correctly once; wrong cards are pushed to the back
/// of the queue and revisited until the whole set is cleared.
@MainActor
@Observable
final class StudySession {
    let mode: StudyMode
    let direction: StudyDirection

    /// Cards still to be cleared, in the order they'll be shown.
    private var queue: [Vocab]
    /// Cards already answered correctly this session.
    private(set) var clearedIDs: Set<UUID> = []
    private let totalCount: Int

    /// Multiple-choice options for the current recall card (empty for spell).
    private(set) var options: [String] = []

    private let allCards: [Vocab]

    // MARK: Live state

    private(set) var isFinished = false
    /// Feedback for the answer just submitted, cleared when advancing.
    private(set) var lastResult: AnswerResult?

    enum AnswerResult: Equatable {
        case correct
        case wrong(correctAnswer: String)
    }

    init(cards: [Vocab], mode: StudyMode, direction: StudyDirection) {
        self.mode = mode
        self.direction = direction
        self.allCards = cards
        self.queue = cards.shuffled()
        self.totalCount = cards.count
        prepareCurrent()
    }

    // MARK: Derived

    var current: Vocab? { queue.first }

    var prompt: String {
        guard let c = current else { return "" }
        return direction == .termToMeaning ? c.term : c.meaning
    }

    var expectedAnswer: String {
        guard let c = current else { return "" }
        return direction == .termToMeaning ? c.meaning : c.term
    }

    var promptNote: String { current?.note ?? "" }

    /// 0.0 ... 1.0 — how many unique cards have been cleared.
    var progress: Double {
        guard totalCount > 0 else { return 1 }
        return Double(clearedIDs.count) / Double(totalCount)
    }

    var clearedCount: Int { clearedIDs.count }
    var remainingCount: Int { totalCount - clearedIDs.count }
    var total: Int { totalCount }

    /// The original cards, for restarting a fresh session.
    var snapshotCards: [Vocab] { allCards }

    // MARK: Answering

    /// Recall: submit the chosen option text.
    func submitChoice(_ choice: String) {
        grade(isCorrect: choice == expectedAnswer)
    }

    /// Spell: submit typed text (graded leniently).
    func submitSpelling(_ typed: String) {
        grade(isCorrect: SpellNormalizer.matches(answer: typed, expected: expectedAnswer))
    }

    /// Using a hint counts as an incorrect attempt (matches ClassCard).
    func revealAsHint() {
        grade(isCorrect: false)
    }

    private func grade(isCorrect: Bool) {
        guard let card = current else { return }

        if isCorrect {
            card.recordCorrect()
            bumpStreak(card, up: true)
            clearedIDs.insert(card.id)
            queue.removeFirst()
            lastResult = .correct
        } else {
            card.recordWrong()
            bumpStreak(card, up: false)
            // Move to the back so it comes around again this session.
            let missed = queue.removeFirst()
            queue.append(missed)
            lastResult = .wrong(correctAnswer: expectedAnswer)
        }
    }

    private func bumpStreak(_ card: Vocab, up: Bool) {
        switch mode {
        case .recall:
            card.recallStreak = up ? card.recallStreak + 1 : 0
        case .spell:
            card.spellStreak = up ? card.spellStreak + 1 : 0
        case .memorize:
            break
        }
    }

    /// Advance to the next card after showing feedback.
    func advance() {
        lastResult = nil
        if queue.isEmpty {
            isFinished = true
            return
        }
        prepareCurrent()
    }

    private func prepareCurrent() {
        guard mode == .recall, let card = current else {
            options = []
            return
        }
        options = makeOptions(for: card)
    }

    /// Build four distinct options: the correct answer plus three distractors.
    private func makeOptions(for card: Vocab) -> [String] {
        let correct = direction == .termToMeaning ? card.meaning : card.term
        let pool = allCards
            .filter { $0.id != card.id }
            .map { direction == .termToMeaning ? $0.meaning : $0.term }
            .filter { $0 != correct }

        var distractors = Array(Set(pool)).shuffled().prefix(3)
        // If the set is tiny, pad with whatever we have.
        if distractors.count < 3 {
            let extra = pool.shuffled().prefix(3 - distractors.count)
            distractors.append(contentsOf: extra)
        }
        return (Array(distractors) + [correct]).shuffled()
    }
}
