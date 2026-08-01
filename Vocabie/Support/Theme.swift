import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Vocabie's visual language.
///
/// Layering rule — the whole design depends on it:
/// - **Content layer** (the word, its meaning) sits directly on the background. No material.
/// - **Control layer** (progress pill, option panel, buttons) floats above in Liquid Glass.
///
/// Putting glass behind the word lets the background bleed through and makes it harder to
/// read, which is the opposite of what a vocabulary app needs.
enum Theme {
    // MARK: Theme storage

    static let appearanceKey = "themeAppearance"
    static let accentKey = "themeAccent"

    /// The accent the learner picked. Read from storage rather than held in the
    /// environment so the hundreds of `Theme.tint` call sites need no changes; the
    /// root observes the key and re-renders the tree when it changes.
    static var accent: AccentTheme {
        AccentTheme(rawValue: UserDefaults.standard.string(forKey: accentKey) ?? "")
            ?? .periwinkle
    }

    // MARK: Palette

    /// The app accent — buttons, progress, selected states. Follows the chosen theme.
    static var tint: Color { accent.color }

    // The three study modes keep their own colours whatever the accent is: 암기 / 리콜 /
    // 스펠 are told apart by hue during a session, and re-tinting them to match the
    // theme would erase that.
    static let memorize = Color(red: 0.44, green: 0.55, blue: 0.96)  // 암기 — blue
    static let recall = Color(red: 0.58, green: 0.47, blue: 0.94)    // 리콜 — violet
    static let spell = Color(red: 0.36, green: 0.66, blue: 0.72)     // 스펠 — teal
    static let correct = Color(red: 0.36, green: 0.72, blue: 0.55)
    static let wrong = Color(red: 0.91, green: 0.35, blue: 0.38)
    static let star = Color(red: 0.98, green: 0.78, blue: 0.36)

    /// The same verdicts, darkened for surfaces that carry white text. The accent
    /// versions above are tuned for text and icons *on* the background; filling a
    /// whole row with them leaves white at 2.4:1, well under the 4.5:1 floor.
    static let correctFill = Color(red: 0.18, green: 0.52, blue: 0.36)
    static let wrongFill = Color(red: 0.76, green: 0.20, blue: 0.24)

    /// The soft sky backdrop. Everything else floats above this.
    ///
    /// Carries a breath of the accent — enough that switching theme changes the room
    /// rather than just the buttons, far too little to compete with the words on top.
    static func background(_ scheme: ColorScheme) -> LinearGradient {
        let wash = accent.color
        let colors: [Color] = scheme == .dark
            ? [Color(red: 0.09, green: 0.10, blue: 0.17).mixed(with: wash, 0.10),
               Color(red: 0.13, green: 0.14, blue: 0.22).mixed(with: wash, 0.06)]
            : [Color(red: 0.94, green: 0.95, blue: 0.99).mixed(with: wash, 0.10),
               Color(red: 0.98, green: 0.98, blue: 1.0).mixed(with: wash, 0.04)]
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }

    // MARK: Metrics
    //
    // Corners come in two tiers only: cards and the controls that sit on them.
    /// Floating glass cards and panels.
    static let panelCorner: CGFloat = 22
    /// Buttons, small controls, and inset rows.
    static let innerCorner: CGFloat = 14
    /// Inset that keeps floating glass clear of the screen edges.
    static let floatInset: CGFloat = 14

    /// Standard gap between stacked sections, and padding inside a card.
    static let sectionGap: CGFloat = 20
    static let contentPad: CGFloat = 16

    /// The one flat translucent fill for list rows and insets — so surfaces stop
    /// drifting between 0.03 / 0.04 / 0.05 / 0.06.
    static let rowFill = Color.primary.opacity(0.05)
}

// MARK: - Theme choices

/// Light, dark, or whatever the phone is doing.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var korean: String {
        switch self {
        case .system: "시스템"
        case .light: "밝게"
        case .dark: "어둡게"
        }
    }

    var systemImage: String {
        switch self {
        case .system: "iphone"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }

    /// `nil` hands the decision back to the system.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// The accent colour. Every option is tuned to stay legible as white-on-colour at
/// button size and as colour-on-background for small text, in both schemes.
enum AccentTheme: String, CaseIterable, Identifiable {
    case periwinkle, lavender, teal, coral, forest

    var id: String { rawValue }

    var korean: String {
        switch self {
        case .periwinkle: "페리윙클"
        case .lavender: "라벤더"
        case .teal: "민트"
        case .coral: "코랄"
        case .forest: "포레스트"
        }
    }

    var color: Color {
        switch self {
        case .periwinkle: Color(red: 0.40, green: 0.52, blue: 0.96)
        case .lavender: Color(red: 0.58, green: 0.47, blue: 0.94)
        case .teal: Color(red: 0.20, green: 0.62, blue: 0.68)
        case .coral: Color(red: 0.91, green: 0.44, blue: 0.42)
        case .forest: Color(red: 0.25, green: 0.60, blue: 0.45)
        }
    }
}

extension Color {
    /// Blend towards another colour by `amount` (0...1). Used to wash the backdrop
    /// with a trace of the accent.
    func mixed(with other: Color, _ amount: Double) -> Color {
        mix(with: other, by: amount)
    }
}

// MARK: - Liquid Glass

/// Wraps the iOS 26 `glassEffect` so the whole app has one place to adjust —
/// and one place to fix if the SDK signature differs from what's written here.
extension View {
    /// A floating rounded glass panel (the option list, the button tray).
    func glassPanel(corner: CGFloat = Theme.panelCorner, tint: Color? = nil) -> some View {
        modifier(GlassSurface(shape: .rounded(corner), tint: tint))
    }

    /// A floating glass capsule (the top progress pill).
    func glassCapsule(tint: Color? = nil) -> some View {
        modifier(GlassSurface(shape: .capsule, tint: tint))
    }
}

struct GlassSurface: ViewModifier {
    enum ShapeKind {
        case capsule
        case rounded(CGFloat)
    }

    let shape: ShapeKind
    var tint: Color?

    func body(content: Content) -> some View {
        switch shape {
        case .capsule:
            content.glassEffect(glass, in: Capsule(style: .continuous))
        case .rounded(let r):
            content.glassEffect(glass, in: RoundedRectangle(cornerRadius: r, style: .continuous))
        }
    }

    /// A whisper of the mode's colour so 암기 / 리콜 / 스펠 feel distinct
    /// without the glass turning into a coloured slab.
    private var glass: Glass {
        guard let tint else { return .regular }
        return .regular.tint(tint.opacity(0.16))
    }
}

// MARK: - Haptics

enum Haptics {
    static func success() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
    static func soft() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        #endif
    }
    /// A firm single tap — the "뚝" when a Memorize card is flipped.
    static func rigid() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        #endif
    }
    /// Used for a missed answer. Deliberately gentle — a miss is not a punishment.
    static func nudge() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    /// Light tick when a swipe action arms something. Matches Moodie Sky's
    /// `triggerSelectionHaptic()`.
    static func selection() {
        #if canImport(UIKit)
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
        #endif
    }

    /// Destructive confirmation — two error taps 0.1s apart, so deleting *feels*
    /// irreversible. Mirrors Moodie Sky's `triggerIntenseErrorHaptic()`.
    static func intenseError() {
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            generator.notificationOccurred(.error)
        }
        #endif
    }
}
