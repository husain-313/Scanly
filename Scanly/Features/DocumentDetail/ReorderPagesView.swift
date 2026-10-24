import SwiftUI
import SwiftData

/// Drag to reorder (or swipe to delete) the pages of a document.
struct ReorderPagesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var document: ScannedDocument

    @State private var editMode: EditMode = .active

    var body: some View {
        NavigationStack {
            List {
                ForEach(document.orderedPages) { page in
                    HStack(spacing: 12) {
                        PageImageView(page: page)
                            .frame(width: 54, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        Text("Page \(page.index + 1)")
                        Spacer()
                    }
                }
                .onMove(perform: move)
                .onDelete(perform: delete)
            }
            .environment(\.editMode, $editMode)
            .navigationTitle("Reorder pages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var pages = document.orderedPages
        pages.move(fromOffsets: source, toOffset: destination)
        for (i, page) in pages.enumerated() { page.index = i }
        document.updatedAt = .now
        try? context.save()
    }

    private func delete(at offsets: IndexSet) {
        let pages = document.orderedPages
        for i in offsets {
            ImageStore.delete(pages[i].originalFile)
            context.delete(pages[i])
        }
        for (i, page) in document.orderedPages.enumerated() { page.index = i }
        document.updatedAt = .now
        try? context.save()
    }
}
