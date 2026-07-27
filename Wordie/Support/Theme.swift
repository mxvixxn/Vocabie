import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Wordie's calm, "ie-family" visual language: soft sky gradients, rounded cards, gentle tints.
enum Theme {
    // MARK: Palette
    static let ink = Color(red: 0.16, green: 0.18, blue: 0.28)
    static let tint = Color(red: 0.40, green: 0.52, blue: 0.96)      // periwinkle blue
    static let memorize = Color(red: 0.44, green: 0.55, blue: 0.96)  // 암기 — blue
    static let recall = Color(red: 0.58, green: 0.47, blue: 0.94)    // 리콜 — violet
    static let spell = Color(red: 0.36, green: 0.66, blue: 0.72)     // 스펠 — teal
    static let correct = Color(red: 0.36, green: 0.72, blue: 0.55)
    static let star = Color(red: 0.98, green: 0.78, blue: 0.36)

    /// The soft sky backdrop used across the app.
    static func background(_ scheme: ColorScheme) -> LinearGradient {
        let colors: [Color] = scheme == .dark
            ? [Color(red: 0.09, green: 0.10, blue: 0.17), Color(red: 0.13, green: 0.14, blue: 0.22)]
            : [Color(red: 0.93, green: 0.95, blue: 1.0), Color(red: 0.97, green: 0.96, blue: 1.0)]
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }

    static let cardCorner: CGFloat = 22
}

/// A reusable frosted card surface.
struct CardSurface: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    var padding: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous)
                    .strokeBorder(Color.white.opacity(scheme == .dark ? 0.06 : 0.5), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(scheme == .dark ? 0.35 : 0.08),
                    radius: 14, x: 0, y: 8)
    }
}

extension View {
    func cardSurface(padding: CGFloat = 18) -> some View {
        modifier(CardSurface(padding: padding))
    }
}

/// Light haptic helpers so success/error feel physical.
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
    static func rigid() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        #endif
    }
}
