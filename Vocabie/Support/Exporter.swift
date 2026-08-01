import Foundation
import SwiftData

/// Turns sets back into files — the mirror of `WordParser`.
///
/// Two shapes, because they answer different questions:
///
/// - **CSV** — "보내줘". Opens in Excel or Numbers, and a single set's CSV re-imports
///   through `WordParser` untouched. It carries only what a person would type back in:
///   단어 · 뜻 · 메모.
/// - **JSON** — "폰이 죽었어". Carries the scheduling state too, so restoring puts the
///   learner back where they were instead of at day zero. Not meant to be read by hand.
enum Exporter {

    // MARK: - CSV

    /// One set, ready to re-import. Deliberately headerless: `WordParser` has no notion
    /// of a header row, so a labelled first line would come back as a word called 단어.
    static func csv(for set: VocabSet) -> String {
        set.orderedWords
            .map { row([$0.term, $0.meaning, $0.note]) }
            .joined(separator: "\n")
    }

    /// Every set in one sheet. Carries 단어장 and 세트 columns so the rows stay
    /// self-describing, which also means this shape is for reading, not for
    /// re-importing — that is what the single-set CSV and the JSON backup are for.
    static func csv(forAll sets: [VocabSet]) -> String {
        let header = row(["단어장", "세트", "단어", "뜻", "메모"])
        let body = sets.flatMap { set in
            set.orderedWords.map {
                row([set.notebook?.title ?? "", set.title, $0.term, $0.meaning, $0.note])
            }
        }
        return ([header] + body).joined(separator: "\n")
    }

    private static func row(_ fields: [String]) -> String {
        fields.map(escape).joined(separator: ",")
    }

    private static func escape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") else {
            return field
        }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    // MARK: - JSON backup

    static func backupData(for sets: [VocabSet]) throws -> Data {
        let backup = Backup(exportedAt: Date(), sets: sets.map(SetPayload.init))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }

    static func decodeBackup(_ data: Data) throws -> Backup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Backup.self, from: data)
    }

    /// Inserts every set in the backup as a **new** set and returns how many landed.
    ///
    /// Restoring never merges into an existing set. Merging needs a rule for what wins
    /// when the same word has two different schedules, and guessing wrong quietly
    /// corrupts the learner's history — far worse than a duplicate they can delete.
    @MainActor
    @discardableResult
    static func restore(_ backup: Backup, into context: ModelContext) throws -> Int {
        // One new 단어장 per distinct name *in the file*. Same rule as the sets: a
        // restore adds, it never reaches into what is already here — a 단어장 that
        // happens to share a name may be a different term's work entirely.
        var notebooks: [String: Notebook] = [:]

        for (index, payload) in backup.sets.enumerated() {
            let set = VocabSet(title: payload.title, detail: payload.detail)
            set.createdAt = payload.createdAt
            set.updatedAt = payload.updatedAt
            set.isArchived = payload.isArchived
            // The file lists sets in library order, so its position *is* the order.
            set.order = index
            if let name = payload.notebook, !name.trimmed.isEmpty {
                let notebook = notebooks[name] ?? {
                    let made = Notebook(title: name)
                    context.insert(made)
                    notebooks[name] = made
                    return made
                }()
                set.notebook = notebook
            }
            context.insert(set)

            for word in payload.words {
                let card = word.makeVocab()
                card.set = set
                context.insert(card)
            }
        }
        try context.save()
        return backup.sets.count
    }

    // MARK: - Files

    /// Writes `text` / `data` into the temp directory so `ShareLink` has a real file to
    /// hand off — the share sheet names the attachment after the file, so a good
    /// filename here is what the recipient actually sees.
    static func temporaryFile(named name: String, text: String) throws -> URL {
        try temporaryFile(named: name, data: Data(text.utf8))
    }

    static func temporaryFile(named name: String, data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(safe(name))
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Today's date, for backup filenames.
    static var dateStamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    /// A set title can hold anything a keyboard produces, including path separators.
    private static func safe(_ filename: String) -> String {
        let cleaned = filename
            .components(separatedBy: CharacterSet(charactersIn: "/\\:*?\"<>|"))
            .joined(separator: "-")
            .trimmed
        return cleaned.isEmpty ? "Vocabie" : cleaned
    }
}

// MARK: - Backup payloads

extension Exporter {

    struct Backup: Codable {
        /// Bumped if the shape ever changes, so an old file can still be read.
        /// 2 added `SetPayload.notebook`; a version 1 file decodes with it absent,
        /// and its sets come back unfiled, which is exactly where they were.
        var version: Int = 2
        var exportedAt: Date
        var sets: [SetPayload]
    }

    struct SetPayload: Codable {
        var title: String
        var detail: String
        var isArchived: Bool
        var createdAt: Date
        var updatedAt: Date
        /// Title of the 단어장 this set sat on, or `nil` for an unfiled set. Stored by
        /// name rather than by id: the backup is a flat list of sets, and a name is
        /// the thing a learner would recognise if they ever opened the file.
        var notebook: String?
        var words: [WordPayload]

        init(_ set: VocabSet) {
            title = set.title
            detail = set.detail
            isArchived = set.isArchived
            createdAt = set.createdAt
            updatedAt = set.updatedAt
            notebook = set.notebook?.title
            words = set.orderedWords.map(WordPayload.init)
        }
    }

    /// Everything about a card that took effort to earn. Term and meaning could be
    /// retyped; `dueDate`, `ease` and the streaks could not.
    struct WordPayload: Codable {
        var term: String
        var meaning: String
        var note: String
        var order: Int
        var memorizeSeen: Bool
        var recallStreak: Int
        var spellStreak: Int
        var timesCorrect: Int
        var timesWrong: Int
        var lastStudied: Date?
        var dueDate: Date?
        var interval: Double
        var ease: Double
        var lapses: Int
        var reviewCount: Int
        var createdAt: Date

        init(_ card: Vocab) {
            term = card.term
            meaning = card.meaning
            note = card.note
            order = card.order
            memorizeSeen = card.memorizeSeen
            recallStreak = card.recallStreak
            spellStreak = card.spellStreak
            timesCorrect = card.timesCorrect
            timesWrong = card.timesWrong
            lastStudied = card.lastStudied
            dueDate = card.dueDate
            interval = card.interval
            ease = card.ease
            lapses = card.lapses
            reviewCount = card.reviewCount
            createdAt = card.createdAt
        }

        func makeVocab() -> Vocab {
            let card = Vocab(term: term, meaning: meaning, note: note, order: order)
            card.memorizeSeen = memorizeSeen
            card.recallStreak = recallStreak
            card.spellStreak = spellStreak
            card.timesCorrect = timesCorrect
            card.timesWrong = timesWrong
            card.lastStudied = lastStudied
            card.dueDate = dueDate
            card.interval = interval
            card.ease = ease
            card.lapses = lapses
            card.reviewCount = reviewCount
            card.createdAt = createdAt
            return card
        }
    }
}
