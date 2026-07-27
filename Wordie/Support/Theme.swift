import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Wordie's visual language.
///
/// Layering rule — the whole design depends on it:
/// - **Content layer** (the word, its meaning) sits directly on the background. No material.
/// - **Control layer** (progress pill, option panel, buttons) floats above in Liquid Glass.
///
/// Putting glass behind the word lets the background bleed through and makes it harder to
/// read, which is the opposite of what a vocabulary app needs.
enum Theme {
    // MARK: Palette
    static let tint = Color(red: 0.40, green: 0.52, blue: 0.96)      // periwinkle
    static let memorize = Color(red: 0.44, green: 0.55, blue: 0.96)  // 암기 — blue
    static let recall = Color(red: 0.58, green: 0.47, blue: 0.94)    // 리콜 — violet
    static let spell = Color(red: 0.36, green: 0.66, blue: 0.72)     // 스펠 — teal
    static let correct = Color(red: 0.36, green: 0.72, blue: 0.55)
    static let wrong = Color(red: 0.91, green: 0.35, blue: 0.38)
    static let star = Color(red: 0.98, green: 0.78, blue: 0.36)

    /// The soft sky backdrop. Everything else floats above this.
    static func background(_ scheme: ColorScheme) -> LinearGradient {
        let colors: [Color] = scheme == .dark
            ? [Color(red: 0.09, green: 0.10, blue: 0.17), Color(red: 0.13, green: 0.14, blue: 0.22)]
            : [Color(red: 0.93, green: 0.95, blue: 1.0), Color(red: 0.97, green: 0.96, blue: 1.0)]
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }

    // MARK: Metrics
    static let panelCorner: CGFloat = 28
    static let innerCorner: CGFloat = 20
    /// Inset that keeps floating glass clear of the screen edges.
    static let floatInset: CGFloat = 14
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
