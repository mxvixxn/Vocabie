import Foundation

/// How a card went during a study session.
///
/// Unlike Anki, Vocabie doesn't ask the learner to rate themselves — it already knows.
/// Recall and spell produce an objective record of how many attempts a card took,
/// which is a better signal than self-assessment.
enum ReviewGrade {
    /// Cleared on the first attempt.
    case recalled
    /// Missed once, then cleared.
    case struggled
    /// Missed repeatedly, or the answer had to be revealed.
    case forgot

    init(missCount: Int) {
        switch missCount {
        case 0: self = .recalled
        case 1: self = .struggled
        default: self = .forgot
        }
    }
}

/// SM-2 style spacing, tuned for vocabulary.
///
/// The shape: a cleared card's interval grows by its ease factor, a forgotten card
/// drops back to a day and loses a little ease, so hard words come around often and
/// easy ones drift out of the way.
enum Scheduler {

    /// Ease never drops below this, or a difficult card would be scheduled forever.
    static let minimumEase: Double = 1.3
    static let maximumEase: Double = 2.8
    /// No point scheduling a word beyond half a year out.
    static let maximumInterval: Double = 180

    /// The first two steps are fixed so a new card is seen again soon.
    static let firstInterval: Double = 1
    static let secondInterval: Double = 3

    /// Applies a grade to a card, updating its interval, ease and due date.
    static func apply(_ grade: ReviewGrade, to card: Vocab, now: Date = Date()) {
        let (interval, ease) = next(
            interval: card.interval,
            ease: card.ease,
            grade: grade
        )

        card.interval = interval
        card.ease = ease
        card.dueDate = date(afterDays: interval, from: now)
        card.reviewCount += 1
        card.lastStudied = now
        if grade == .forgot && card.reviewCount > 1 {
            card.lapses += 1
        }
    }

    /// The scheduling maths, split out so it can be reasoned about on its own.
    static func next(interval: Double, ease: Double, grade: ReviewGrade) -> (Double, Double) {
        switch grade {
        case .forgot:
            // Back to the start, and make future growth a little more cautious.
            return (firstInterval, clampEase(ease - 0.20))

        case .struggled:
            // Hold roughly where it is rather than pushing further out.
            let grown = max(firstInterval, interval * 1.2)
            return (clampInterval(grown), clampEase(ease - 0.05))

        case .recalled:
            let grown: Double
            if interval < firstInterval {
                grown = firstInterval
            } else if interval < secondInterval {
                grown = secondInterval
            } else {
                grown = interval * ease
            }
            return (clampInterval(grown), clampEase(ease + 0.05))
        }
    }

    // MARK: Helpers

    private static func clampEase(_ value: Double) -> Double {
        min(maximumEase, max(minimumEase, value))
    }

    private static func clampInterval(_ value: Double) -> Double {
        min(maximumInterval, max(firstInterval, value))
    }

    /// Due dates land at the start of the target day, so "due tomorrow" means
    /// available from midnight rather than at the exact time of day you studied.
    private static func date(afterDays days: Double, from now: Date) -> Date {
        let calendar = Calendar.current
        let whole = Int(days.rounded())
        let target = calendar.date(byAdding: .day, value: max(1, whole), to: now) ?? now
        return calendar.startOfDay(for: target)
    }
}

// MARK: - Human-readable spacing

extension Vocab {
    /// "내일", "3일 뒤", "2주 뒤" — for the review summary.
    var dueDescription: String {
        guard let dueDate else { return "미학습" }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let due = calendar.startOfDay(for: dueDate)
        let days = calendar.dateComponents([.day], from: today, to: due).day ?? 0

        switch days {
        case ..<0: return "복습 필요"
        case 0: return "오늘"
        case 1: return "내일"
        case 2...13: return "\(days)일 뒤"
        case 14...59: return "\(days / 7)주 뒤"
        default: return "\(days / 30)개월 뒤"
        }
    }
}
