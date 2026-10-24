import SwiftUI
import SwiftData

@main
struct ScanlyApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([ScannedDocument.self, ScanPage.self])
        do {
            container = try ModelContainer(for: schema)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
