import SwiftUI

/// App root. Instagram-style bottom bar — icons only, no text labels.
struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Image(systemName: "house.fill") }

            SetsView()
                .tabItem { Image(systemName: "square.stack.fill") }

            SettingsView()
                .tabItem { Image(systemName: "gearshape.fill") }
        }
        .tint(Theme.tint)
    }
}
