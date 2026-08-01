import SwiftUI
import SwiftData

@main
struct VocabieApp: App {
    /// Shared SwiftData stack for the whole app.
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Notebook.self, VocabSet.self, Vocab.self)
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
