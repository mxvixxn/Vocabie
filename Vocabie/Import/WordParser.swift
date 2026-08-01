import Foundation

/// One parsed row before it becomes a `Vocab`.
struct ParsedRow: Identifiable, Equatable {
    let id = UUID()
    var term: String
    var meaning: String
    var note: String = ""

    var isUsable: Bool { !term.trimmed.isEmpty && !meaning.trimmed.isEmpty }
}

/// A run of rows that sat under one heading in the pasted text.
///
/// Study material arrives in labelled chunks — a mock exam's `43~45번`, a textbook's
/// `3강` — and those labels are exactly the 세트 boundaries a learner would draw by
/// hand. Keeping them lets an import lay down several sets in one paste.
struct ParsedSection: Identifiable {
    let id = UUID()
    /// The heading, tidied for use as a set title ("43~45번 (13)" → "43~45번").
    /// Empty for rows that appeared before any heading.
    var title: String
    var rows: [ParsedRow]
}

/// How columns are separated in the pasted / imported text.
enum Delimiter: String, CaseIterable, Identifiable {
    case auto = "자동 감지"
    case script = "영어 / 한글 경계"
    case tab = "탭"
    case comma = "쉼표 ,"
    case dash = "대시 -"
    case colon = "콜론 :"
    case equals = "등호 ="

    var id: String { rawValue }
}

/// Parses free-form text into vocabulary rows.
///
/// Handles the shapes people actually paste:
/// - Tab-separated (copying cells out of Excel / Numbers / Google Sheets)
/// - CSV, including quoted fields with embedded commas
/// - Markdown tables (`| term | meaning |`) and separator rows are skipped
/// - Markdown / bullet lists (`- term : meaning`)
/// - Plain lines split on a chosen or auto-detected delimiter
enum WordParser {

    /// Every word in the text, headings dropped.
    static func parse(_ raw: String, delimiter: Delimiter = .auto, swapColumns: Bool = false) -> [ParsedRow] {
        sections(raw, delimiter: delimiter, swapColumns: swapColumns).flatMap(\.rows)
    }

    /// The same words, still grouped under the headings they were pasted with.
    ///
    /// Sections that end up empty are dropped, so a heading with nothing under it —
    /// a page number, a stray line — never becomes a set.
    static func sections(_ raw: String, delimiter: Delimiter = .auto,
                         swapColumns: Bool = false) -> [ParsedSection] {
        let lines = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")

        var sections: [ParsedSection] = []
        var current = ParsedSection(title: "", rows: [])

        for rawLine in lines {
            let line = rawLine.trimmed
            guard !line.isEmpty else { continue }
            guard !isMarkdownSeparator(line) else { continue }

            if isSectionHeader(line) {
                if !current.rows.isEmpty { sections.append(current) }
                current = ParsedSection(title: sectionTitle(line), rows: [])
                continue
            }

            if var row = parseLine(line, delimiter: delimiter) {
                if swapColumns { swap(&row.term, &row.meaning) }
                if row.isUsable { current.rows.append(row) }
            }
        }
        if !current.rows.isEmpty { sections.append(current) }
        return sections
    }

    // MARK: - Line parsing

    private static func parseLine(_ line: String, delimiter: Delimiter) -> ParsedRow? {
        // Markdown table row: | a | b | c |
        if line.hasPrefix("|") {
            let cells = line
                .trimmingCharacters(in: CharacterSet(charactersIn: "|"))
                .components(separatedBy: "|")
                .map { $0.trimmed }
                .filter { !$0.isEmpty }
            return rowFromCells(cells)
        }

        // Leading bullet markers from markdown / plain lists.
        let cleaned = stripBullet(line)

        switch delimiter {
        case .tab:    return splitOnce(cleaned, "\t")
        case .comma:  return csvRow(cleaned)
        case .dash:   return splitOnDash(cleaned)
        case .colon:  return splitSeparated(cleaned, ":")
        case .equals: return splitSeparated(cleaned, "=")
        case .script: return splitAtScriptBoundary(cleaned)
        case .auto:   return autoSplit(cleaned)
        }
    }

    /// Tries the most reliable separators in order.
    private static func autoSplit(_ line: String) -> ParsedRow? {
        // A tab is an explicit column break — pasted straight out of a spreadsheet.
        if line.contains("\t") { return splitOnce(line, "\t") }

        // So is a quoted field. Trust it over the script boundary below, which would
        // otherwise split *inside* the quotes and leave the term as `deposit,"`.
        // This is the shape Excel writes, and the shape Vocabie's own CSV export uses.
        if line.contains("\""), let row = csvRow(line), row.isUsable { return row }

        // For an English↔Korean deck, the point where the script changes is the most
        // reliable boundary there is. It survives hyphens inside the term
        // ("well-known", "hold on-") and commas inside the meaning ("기다려, 잠깐만"),
        // both of which defeat splitting on punctuation.
        if let row = splitAtScriptBoundary(line) { return row }

        // Decks that aren't English↔Korean fall back to punctuation.
        if line.contains(",") { return csvRow(line) }
        if line.contains(" - ") { return splitSeparated(line, " - ") }
        if line.contains(" : ") { return splitSeparated(line, " : ") }
        if line.contains("=") { return splitSeparated(line, "=") }
        if line.contains(":") { return splitSeparated(line, ":") }
        // Fall back to two or more spaces acting as a column gap.
        if let r = splitOnRuns(line) { return r }
        return nil
    }

    /// Splits at the first Korean character: everything before it is the term,
    /// everything from it on is the meaning.
    ///
    /// Any separator the writer left between the two — a dash, colon, comma, bullet —
    /// is trimmed off the end of the term. A hyphen *inside* the term survives because
    /// only trailing punctuation is removed.
    private static func splitAtScriptBoundary(_ line: String) -> ParsedRow? {
        guard let firstHangul = line.firstIndex(where: { $0.isHangul }) else { return nil }
        // A line that opens in Korean is meaning-first; let the other rules
        // (and the swap toggle) handle it.
        guard firstHangul != line.startIndex else { return nil }

        // A gloss often opens with punctuation that belongs to the meaning rather than
        // the term — a placeholder tilde ("~을 복습하다") or a bracketed qualifier
        // ("(놓여)있다", "(온도 단위인)도"). Without this the boundary lands *inside*
        // the bracket and the term keeps a stray "(".
        var boundary = firstHangul
        while boundary > line.startIndex {
            let prior = line.index(before: boundary)
            guard placeholders.contains(line[prior]) else { break }
            boundary = prior
        }
        guard boundary != line.startIndex else { return nil }

        let term = String(line[..<boundary])
            .trimmingCharacters(in: separatorTrim)
        let meaning = String(line[boundary...]).trimmed

        guard !term.isEmpty, !meaning.isEmpty else { return nil }
        return ParsedRow(term: term, meaning: meaning)
    }

    /// Trailing junk left between the two columns.
    private static let separatorTrim = CharacterSet(charactersIn: " \t-–—―:=,;·••|/\\>")

    /// Marks that open a Korean gloss rather than close the term, so the split point
    /// belongs before them, not after.
    private static let placeholders: Set<Character> = [
        "~", "∼", "〜", "～",                          // placeholder tilde
        "(", "[", "{", "（", "［", "｛", "〔", "「", "『",  // bracketed qualifier
        "\u{201C}", "\u{2018}",                        // smart quotes
    ]

    // MARK: - Splitters

    private static func splitOnce(_ line: String, _ sep: Character) -> ParsedRow? {
        guard let idx = line.firstIndex(of: sep) else { return nil }
        let term = String(line[..<idx]).trimmed
        let rest = String(line[line.index(after: idx)...])
        return rowFromCells([term] + rest.components(separatedBy: String(sep)).map { $0.trimmed })
    }

    /// Dash separation, tolerant of how people actually type it.
    ///
    /// A spaced dash (`hold on - 기다려`) is unambiguous, so it wins. Without spaces
    /// the dash could belong to the term itself (`well-known`), so we split on the
    /// **last** one — a separator sits between the columns, and hyphenated words
    /// keep their earlier hyphens.
    private static func splitOnDash(_ line: String) -> ParsedRow? {
        for spaced in [" - ", " – ", " — ", " -", "- "] {
            if let row = splitSeparated(line, spaced) { return row }
        }
        guard let last = line.lastIndex(where: { $0 == "-" || $0 == "–" || $0 == "—" }) else {
            return nil
        }
        let term = String(line[..<last]).trimmed
        let meaning = String(line[line.index(after: last)...]).trimmed
        guard !term.isEmpty, !meaning.isEmpty else { return nil }
        return ParsedRow(term: term, meaning: meaning)
    }

    private static func splitSeparated(_ line: String, _ sep: String) -> ParsedRow? {
        guard let range = line.range(of: sep) else { return nil }
        let term = String(line[..<range.lowerBound]).trimmed
        let meaning = String(line[range.upperBound...]).trimmed
        // Both halves must carry something. Returning a half-empty row here would
        // stop `autoSplit` from trying the next separator and the line would vanish.
        guard !term.isEmpty, !meaning.isEmpty else { return nil }
        return ParsedRow(term: term, meaning: meaning)
    }

    /// Split on the first run of 2+ spaces (common when text is column-aligned).
    private static func splitOnRuns(_ line: String) -> ParsedRow? {
        guard let range = line.range(of: "  +", options: .regularExpression) else { return nil }
        let term = String(line[..<range.lowerBound]).trimmed
        let meaning = String(line[range.upperBound...]).trimmed
        guard !term.isEmpty, !meaning.isEmpty else { return nil }
        return ParsedRow(term: term, meaning: meaning)
    }

    /// A CSV row with basic quote handling.
    private static func csvRow(_ line: String) -> ParsedRow? {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        let chars = Array(line)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "\"" {
                if inQuotes && i + 1 < chars.count && chars[i + 1] == "\"" {
                    current.append("\"") // escaped quote
                    i += 1
                } else {
                    inQuotes.toggle()
                }
            } else if c == "," && !inQuotes {
                fields.append(current.trimmed)
                current = ""
            } else {
                current.append(c)
            }
            i += 1
        }
        fields.append(current.trimmed)
        return rowFromCells(fields)
    }

    private static func rowFromCells(_ cells: [String]) -> ParsedRow? {
        let cleaned = cells.map { $0.trimmed }.filter { !$0.isEmpty }
        guard let term = cleaned.first else { return nil }
        guard cleaned.count >= 2 else { return nil }
        let meaning = cleaned[1]
        let note = cleaned.count >= 3 ? cleaned[2...].joined(separator: ", ") : ""
        return ParsedRow(term: term, meaning: meaning, note: note)
    }

    // MARK: - Helpers

    /// Removes list numbering and leading decoration from a line.
    ///
    /// Study material marks its hard words with asterisks or stars (`* term`,
    /// `** term`, `*** term`) — importance, not part of the word, so it goes. The two
    /// shapes interleave freely (`15. ** sentient`), so this strips in a loop rather
    /// than assuming an order; each pass consumes at least one character, so it ends.
    private static func stripBullet(_ line: String) -> String {
        var s = line.trimmed
        var keepGoing = true
        while keepGoing {
            keepGoing = false
            for pattern in [markerPrefix, numberingPrefix] {
                guard let range = s.range(of: pattern, options: .regularExpression) else { continue }
                s = String(s[range.upperBound...]).trimmed
                keepGoing = true
            }
        }
        return s
    }

    /// Importance marks and bullets. Asterisks and stars come in runs and often sit
    /// tight against the word (`**sentient`), so the space is optional for them; a
    /// dash needs one, or it would eat the hyphen off a term like `-ology`.
    private static let markerPrefix = #"^(?:[*★☆✦•·]+\s*|[-–—]\s+)"#

    /// Numbered lists: "1. term …", "12) term …"
    private static let numberingPrefix = #"^\d+[.)]\s+"#

    /// A question-number heading that rides along when a learner copies a mock exam
    /// section by section — `43~45번 (13)`, `39번 (15)`, `[41~42]번`.
    ///
    /// These have to be caught here, before splitting: `43~45번 (13)` divides at the
    /// script boundary into a perfectly well-formed row (term `43~45`, meaning
    /// `번 (13)`) and lands in the deck as a word.
    ///
    /// Deliberately narrow — the line must open with a number and a Korean counter
    /// *and* carry no word letters beyond that counter. A real card like
    /// `1번 타자 - leadoff hitter` keeps its Latin half and survives.
    private static func isSectionHeader(_ line: String) -> Bool {
        let s = stripBullet(line)
        guard s.range(of: sectionHeading, options: .regularExpression) != nil else { return false }
        return !s.contains { $0.isWordLetter }
    }

    /// A heading turned into a set title: numbering and decoration stripped, and the
    /// trailing tally a mock-exam listing carries — `43~45번 (13)` — dropped, since 13
    /// is how many words followed, not part of the name.
    private static func sectionTitle(_ line: String) -> String {
        var s = stripBullet(line)
        if let range = s.range(of: #"\s*[\(（]\s*\d+\s*[\)）]\s*$"#, options: .regularExpression) {
            s.removeSubrange(range)
        }
        // `[41~42]번` reads as a name once the wrapper is gone. Only the leading
        // bracket and its closer go, so a qualifier like `3강 (심화)` survives.
        if let open = s.range(of: #"^[\[\(（【<]\s*"#, options: .regularExpression) {
            s.removeSubrange(open)
            if let close = s.range(of: #"\s*[\]\)）】>]"#, options: .regularExpression) {
                s.removeSubrange(close)
            }
        }
        let cleaned = s.trimmingCharacters(in: separatorTrim)
        return cleaned.isEmpty ? line.trimmed : cleaned
    }

    private static let sectionHeading =
        #"^[\[\(（【<]?\s*\d+\s*(?:[~∼〜～\-–—]\s*\d+\s*)?[\]\)）】>]?\s*(?:번|강|과|회|일차|차시)"#

    /// Markdown table divider like `|---|:--:|` — carries no data.
    private static func isMarkdownSeparator(_ line: String) -> Bool {
        let stripped = line.replacingOccurrences(of: " ", with: "")
        guard stripped.contains("-") else { return false }
        let allowed = Set("|:-")
        return stripped.allSatisfy { allowed.contains($0) } && stripped.count >= 3
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

extension Character {
    /// A letter that could carry meaning in a term, i.e. anything but Hangul.
    /// Used to tell a bare Korean heading from a real card with an English half.
    var isWordLetter: Bool { isLetter && !isHangul }

    /// Any Korean letter — precomposed syllables plus both Jamo blocks.
    var isHangul: Bool {
        unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0xAC00...0xD7A3,   // 가–힣
                 0x1100...0x11FF,   // Hangul Jamo
                 0x3130...0x318F,   // compatibility Jamo (ㄱ, ㅏ …)
                 0xA960...0xA97F,   // Jamo Extended-A
                 0xD7B0...0xD7FF:   // Jamo Extended-B
                return true
            default:
                return false
            }
        }
    }
}
