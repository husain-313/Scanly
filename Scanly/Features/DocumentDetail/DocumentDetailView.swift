import SwiftUI
import SwiftData

struct DocumentDetailView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("searchablePDF") private var searchablePDF = true
    @Bindable var document: ScannedDocument

    @State private var selection = 0
    @State private var showScanner = false
    @State private var exporting = false
    @State private var shareItems: [Any]?
    @State private var showOCR = false

    private var pages: [ScanPage] { document.orderedPages }

    var body: some View {
        VStack(spacing: 0) {
            if pages.isEmpty {
                ContentUnavailableView("No pages", systemImage: "doc")
            } else {
                pager
                filterBar
            }
        }
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { showScanner = true } label: { Label("Add pages", systemImage: "plus.viewfinder") }
                    Button { showOCR = true } label: { Label("Extract text (OCR)", systemImage: "text.viewfinder") }
                    Button { Task { await exportPDF() } } label: { Label("Share PDF", systemImage: "square.and.arrow.up") }
                    Button { shareImages() } label: { Label("Share images", systemImage: "photo.stack") }
                    if !pages.isEmpty {
                        Button(role: .destructive) { deleteCurrentPage() } label: {
                            Label("Delete this page", systemImage: "trash")
                        }
                    }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .overlay { if exporting { exportOverlay } }
        .fullScreenCover(isPresented: $showScanner) {
            DocumentScannerView(onFinish: addPages, onCancel: { showScanner = false })
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showOCR) { OCRTextView(document: document) }
        .sheet(isPresented: Binding(get: { shareItems != nil }, set: { if !$0 { shareItems = nil } })) {
            if let shareItems { ShareSheet(items: shareItems) }
        }
    }

    private var pager: some View {
        TabView(selection: $selection) {
            ForEach(Array(pages.enumerated()), id: \.element.id) { idx, page in
                PageImageView(page: page, contentMode: .fit)
                    .padding()
                    .tag(idx)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: pages.count > 1 ? .automatic : .never))
        .background(Color(.systemGroupedBackground))
    }

    private var filterBar: some View {
        let current = pages.indices.contains(selection) ? pages[selection] : nil
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(PageFilter.allCases) { filter in
                    Button {
                        current?.filter = filter
                        document.updatedAt = .now
                        try? context.save()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: filter.symbol)
                            Text(filter.title).font(.caption2)
                        }
                        .frame(width: 70, height: 56)
                        .background((current?.filter == filter ? Color.accentColor.opacity(0.2) : Color(.secondarySystemBackground)),
                                    in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
                Divider().frame(height: 40)
                Button {
                    if let p = current { p.rotation = (p.rotation + 90) % 360; document.updatedAt = .now; try? context.save() }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "rotate.right")
                        Text("Rotate").font(.caption2)
                    }
                    .frame(width: 70, height: 56)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
        .background(.bar)
    }

    private var exportOverlay: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            VStack(spacing: 12) { ProgressView(); Text("Preparing…").font(.caption) }
                .padding(24)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: Actions

    private func addPages(_ images: [UIImage]) {
        showScanner = false
        let start = pages.count
        for (i, img) in images.enumerated() {
            let file = ImageStore.save(img)
            document.pages.append(ScanPage(index: start + i, originalFile: file))
        }
        document.updatedAt = .now
        try? context.save()
        Task {
            document.ocrText = await OCRService.recognize(document: document)
            try? context.save()
        }
    }

    private func deleteCurrentPage() {
        guard pages.indices.contains(selection) else { return }
        let page = pages[selection]
        ImageStore.delete(page.originalFile)
        context.delete(page)
        // Reindex remaining pages.
        for (i, p) in document.orderedPages.enumerated() { p.index = i }
        document.updatedAt = .now
        try? context.save()
        selection = max(0, selection - 1)
    }

    private func exportPDF() async {
        exporting = true
        defer { exporting = false }
        if let url = await PDFExporter.makePDF(for: document, searchable: searchablePDF) {
            shareItems = [url]
        }
    }

    private func shareImages() {
        let urls = PDFExporter.makeImages(for: document)
        if !urls.isEmpty { shareItems = urls }
    }
}

/// Shows recognized text with a copy button.
struct OCRTextView: View {
    @Environment(\.dismiss) private var dismiss
    let document: ScannedDocument

    @State private var text = ""
    @State private var loading = true

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    VStack(spacing: 12) { ProgressView(); Text("Recognizing text…") }
                } else if text.isEmpty {
                    ContentUnavailableView("No text found", systemImage: "text.badge.xmark")
                } else {
                    ScrollView { Text(text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding() }
                }
            }
            .navigationTitle("Extracted text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button { UIPasteboard.general.string = text } label: { Image(systemName: "doc.on.doc") }
                        .disabled(text.isEmpty)
                }
            }
            .task {
                loading = true
                text = document.ocrText.isEmpty ? await OCRService.recognize(document: document) : document.ocrText
                loading = false
            }
        }
    }
}
