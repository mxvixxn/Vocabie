import SwiftUI

// MARK: - Buttons
//
// Two button shapes for the whole app: a solid primary and a soft secondary.
// Both are capsules tinted with the app accent, so CTAs read the same everywhere.

struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.tint

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity)
            .background(tint, in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.tint

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(tint.opacity(0.12), in: Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Sharing

/// The system share sheet, for handing an exported file to Files, Mail, AirDrop…
///
/// A plain `ShareLink` would need the file to exist before the view body runs, which
/// means writing to disk on every render. Presenting this from a button instead lets
/// the file be written once, when the learner actually asks for it.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) { }
}

/// A file waiting to be shared. Wrapped so `.sheet(item:)` can drive the share sheet.
struct ShareableFile: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Empty state
//
// One shape for every "nothing here yet" screen — Home, Sets, Archive, Set detail.

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    var message: String? = nil
    var tint: Color = Theme.tint
    /// Optional call-to-action.
    var actionTitle: String? = nil
    var actionImage: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 52))
                .foregroundStyle(tint.gradient)
            Text(title)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                Button(action: action) {
                    Label(actionTitle, systemImage: actionImage ?? "plus")
                }
                .buttonStyle(PrimaryButtonStyle(tint: tint))
                .fixedSize()
                .padding(.top, 4)
            }
        }
        .padding(40)
    }
}
