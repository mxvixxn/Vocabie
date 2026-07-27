import SwiftUI
import SwiftData

@main
struct WordieApp: App {
    /// Shared SwiftData stack for the whole app.
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: VocabSet.self, Vocab.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(container)
    }
}
