import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ScannedDocument.updatedAt, order: .reverse) private var documents: [ScannedDocument]

    @State private var search = ""
    @State private var showScanner = false
    @State private var newDocument: ScannedDocument?
    @State private var renaming: ScannedDocument?
    @State private var renameText = ""
    @State private var showSettings = false

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 16)]

    private var filtered: [ScannedDocument] {
        guard !search.isEmpty else { return documents }
        let q = search.lowercased()
        return documents.filter {
            $0.title.lowercased().contains(q) || $0.ocrText.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if documents.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(filtered) { doc in
                                NavigationLink {
                                    DocumentDetailView(document: doc)
                                } label: {
                                    DocumentCard(document: doc)
                                }
                                .buttonStyle(.plain)
                                .contextMenu { menu(for: doc) }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Scanly")
            .searchable(text: $search, prompt: "Search title or text")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showScanner = true } label: {
                        Image(systemName: "doc.viewfinder").font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .safeAreaInset(edge: .bottom) { scanButton }
            .fullScreenCover(isPresented: $showScanner) {
                DocumentScannerView(onFinish: handleScan, onCancel: { showScanner = false })
                    .ignoresSafeArea()
            }
            .navigationDestination(item: $newDocument) { DocumentDetailView(document: $0) }
            .alert("Rename", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
                TextField("Title", text: $renameText)
                Button("Save") {
                    renaming?.title = renameText
                    renaming?.updatedAt = .now
                    try? context.save()
                    renaming = nil
                }
                Button("Cancel", role: .cancel) { renaming = nil }
            }
        }
    }

    private var scanButton: some View {
        Button {
            showScanner = true
        } label: {
            Label("Scan", systemImage: "camera.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor, in: Capsule())
                .foregroundStyle(.white)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No documents yet", systemImage: "doc.text.image")
        } description: {
            Text("Tap Scan to capture your first document.")
        }
    }

    @ViewBuilder private func menu(for doc: ScannedDocument) -> some View {
        Button { renaming = doc; renameText = doc.title } label: { Label("Rename", systemImage: "pencil") }
        Button(role: .destructive) { delete(doc) } label: { Label("Delete", systemImage: "trash") }
    }

    private func handleScan(_ images: [UIImage]) {
        showScanner = false
        guard !images.isEmpty else { return }
        let doc = ScannedDocument(title: "Scan \(DateFormatter.short.string(from: .now))")
        for (i, img) in images.enumerated() {
            let file = ImageStore.save(img)
            doc.pages.append(ScanPage(index: i, originalFile: file))
        }
        context.insert(doc)
        try? context.save()
        // Recognize text in the background for search.
        Task {
            let text = await OCRService.recognize(document: doc)
            doc.ocrText = text
            try? context.save()
        }
        newDocument = doc
    }

    private func delete(_ doc: ScannedDocument) {
        for page in doc.pages { ImageStore.delete(page.originalFile) }
        context.delete(doc)
        try? context.save()
    }
}

/// A document thumbnail card in the grid.
struct DocumentCard: View {
    let document: ScannedDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground))
                if let first = document.orderedPages.first {
                    PageImageView(page: first)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Image(systemName: "doc").font(.largeTitle).foregroundStyle(.secondary)
                }
                if document.pageCount > 1 {
                    Text("\(document.pageCount)")
                        .font(.caption2.bold())
                        .padding(6)
                        .background(.ultraThinMaterial, in: Circle())
                        .padding(6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }
            }
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(document.title).font(.subheadline.weight(.medium)).lineLimit(1)
            Text(document.updatedAt, format: .dateTime.month().day())
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
