import Foundation

/// Lenient grading for 스펠 (Spell) answers, matching ClassCard's forgiving behaviour:
/// punctuation, slashes, and spacing are ignored, and comparison is case-insensitive.
enum SpellNormalizer {

    /// Reduces an answer to its comparable core.
    static func normalize(_ text: String) -> String {
        let lowered = text.lowercased()
        let scalars = lowered.unicodeScalars.filter { scalar in
            CharacterSet.alphanumerics.contains(scalar)
        }
        return String(String.UnicodeScalarView(scalars))
    }

    /// True when `answer` matches the `expected` term under lenient rules.
    ///
    /// A term may list several acceptable spellings separated by `/` or `,`
    /// (e.g. "color / colour") — any one of them counts as correct.
    static func matches(answer: String, expected: String) -> Bool {
        let normAnswer = normalize(answer)
        guard !normAnswer.isEmpty else { return false }

        let candidates = expected
            .components(separatedBy: CharacterSet(charactersIn: "/,;"))
            .map { normalize($0) }
            .filter { !$0.isEmpty }

        if candidates.contains(normAnswer) { return true }
        // Also accept a match against the whole expected string (no split).
        return normAnswer == normalize(expected)
    }
}
