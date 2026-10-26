import Foundation

/// The language a 세트 teaches.
///
/// Chosen per set rather than per 단어장 or per app: one learner keeps an English deck
/// and a Chinese deck side by side, and mixing scripts inside a single set would break
/// both the pronunciation voice and the shape of a spelling answer.
///
/// It decides three things — how a card is read aloud, what the direction picker calls
/// the term side, and whether 스펠 is offered at all.
enum StudyLanguage: String, CaseIterable, Identifiable, Codable {
    case english
    case japanese
    case chinese

    var id: String { rawValue }

    /// Name of the language itself, for pickers.
    var label: String {
        switch self {
        case .english:  "영어"
        case .japanese: "일본어"
        case .chinese:  "중국어"
        }
    }

    /// What the term side is called in study UI — the other half is always 뜻.
    var termLabel: String {
        switch self {
        case .english:  "영단어"
        case .japanese: "일본어"
        case .chinese:  "중국어"
        }
    }

    /// BCP-47 tag handed to speech synthesis.
    var voiceCode: String {
        switch self {
        case .english:  "en-US"
        case .japanese: "ja-JP"
        case .chinese:  "zh-CN"
        }
    }

    /// Whether 스펠 (typing the term back) makes sense here.
    ///
    /// Off for 한자 and 가나: typing those is a test of the IME, not of the word, and
    /// the answer has no "spelling" to grade leniently the way `SpellNormalizer` does
    /// for Latin script. 암기 and 리콜 still work, and a set can carry its 병음 /
    /// 로마자 in the card's note. A future in-app keyboard could lift this.
    var supportsSpell: Bool { self == .english }

    /// Why 스펠 is missing, shown where the mode card would have been.
    var spellUnavailableReason: String {
        "\(label) 세트는 철자 입력 대신 암기 · 리콜로 학습해요"
    }

    /// Short tag for list rows.
    var badge: String {
        switch self {
        case .english:  "영어"
        case .japanese: "일본어"
        case .chinese:  "중국어"
        }
    }

    /// The greyed-out sample in the 단어 붙여넣기 box.
    ///
    /// Written in the language being imported, because the sample is doing real work:
    /// it shows where the columns split. A 중국어 learner pasting `苹果 píngguǒ 사과`
    /// needs to see that the 병음 stays on the word side — an `apple 사과` example
    /// answers a question they didn't have.
    var pasteSample: String {
        switch self {
        case .english:
            "여기에 붙여넣기\n\napple\t사과\nbanana\t바나나\n\n또는  apple, 사과  /  apple - 사과"
        case .japanese:
            "여기에 붙여넣기\n\n学校 がっこう\t학교\nりんご\t사과\n\n또는  学校, 학교  /  学校 - 학교"
        case .chinese:
            "여기에 붙여넣기\n\n苹果 píngguǒ\t사과\n学校 xuéxiào\t학교\n\n또는  苹果, 사과  /  苹果 - 사과"
        }
    }

    /// The sample for a paste that lays down several 세트 at once.
    var sectionsSample: String {
        switch self {
        case .english:
            "회차 전체를 그대로 붙여넣기\n\n18~23번 (24)\n1. struggle — 노력\n…\n\n24-30번 (18)\n1. inhibit — 방해하다"
        case .japanese:
            "과 전체를 그대로 붙여넣기\n\n1과\n1. 学校 がっこう — 학교\n…\n\n2과\n1. 電車 でんしゃ — 전철"
        case .chinese:
            "과 전체를 그대로 붙여넣기\n\n1과\n1. 苹果 píngguǒ — 사과\n…\n\n2과\n1. 学校 xuéxiào — 학교"
        }
    }

    var placeholderExample: String {
        switch self {
        case .english:  "제목 (예: 1번-10번)"
        case .japanese: "제목 (예: 1과 단어)"
        case .chinese:  "제목 (예: HSK 3급 1과)"
        }
    }
}
