import SwiftUI

/// App root. Three tabs, each labelled — an icon alone leaves the middle tab
/// ambiguous (a stack of what?), and the label is what makes 단어장 findable.
///
/// This is also where the chosen theme lands: the appearance mode and the accent are
/// read here so that changing either re-renders the whole tree beneath.
struct MainTabView: View {
    @AppStorage(Theme.appearanceKey) private var appearanceRaw = AppearanceMode.system.rawValue
    @AppStorage(Theme.accentKey) private var accentRaw = AccentTheme.periwinkle.rawValue

    private var appearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceRaw) ?? .system
    }

    var body: some View {
        TabView {
            HomeView(theme: accentRaw)
                .tabItem { Label("홈", systemImage: "house.fill") }

            SetsView(theme: accentRaw)
                .tabItem { Label("단어장", systemImage: "books.vertical.fill") }

            SettingsView(theme: accentRaw)
                .tabItem { Label("설정", systemImage: "gearshape.fill") }
        }
        .tint(Theme.tint)
        .preferredColorScheme(appearance.colorScheme)
    }
}

// The accent is handed to each tab as a plain value — see `theme` on the three roots.
//
// `Theme.tint` resolves from storage rather than from the environment, so nothing
// would redraw on its own when the accent changes. Passing the raw value down makes
// each root *structurally* different, which re-runs its body and everything under it.
// Re-tagging the whole `TabView` with `.id` would do the same, but it rebuilds the
// navigation stacks too — changing a colour would throw the learner back to the 홈 tab.
