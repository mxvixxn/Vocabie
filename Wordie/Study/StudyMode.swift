import SwiftUI

/// The three ClassCard-style learning stages, in order of increasing difficulty.
enum StudyMode: String, CaseIterable, Identifiable {
    case memorize   // 암기 — passive recognition (flashcards)
    case recall     // 리콜 — active recall (multiple choice)
    case spell      // 스펠 — production (typing)

    var id: String { rawValue }

    var korean: String {
        switch self {
        case .memorize: "암기"
        case .recall:   "리콜"
        case .spell:    "스펠"
        }
    }

    var english: String {
        switch self {
        case .memorize: "Memorize"
        case .recall:   "Recall"
        case .spell:    "Spell"
        }
    }

    var subtitle: String {
        switch self {
        case .memorize: "카드를 넘기며 뜻을 익혀요"
        case .recall:   "보기에서 알맞은 뜻을 골라요"
        case .spell:    "뜻을 보고 철자를 입력해요"
        }
    }

    var systemImage: String {
        switch self {
        case .memorize: "rectangle.on.rectangle.angled"
        case .recall:   "checklist"
        case .spell:    "keyboard"
        }
    }

    var color: Color {
        switch self {
        case .memorize: Theme.memorize
        case .recall:   Theme.recall
        case .spell:    Theme.spell
        }
    }
}

/// Which side of the card is shown as the prompt.
enum StudyDirection: String, CaseIterable, Identifiable {
    case termToMeaning   // 영단어 → 뜻
    case meaningToTerm   // 뜻 → 영단어

    var id: String { rawValue }

    var label: String {
        switch self {
        case .termToMeaning: "영단어 → 뜻"
        case .meaningToTerm: "뜻 → 영단어"
        }
    }
}
