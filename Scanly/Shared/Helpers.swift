import SwiftUI
import UIKit

/// Renders a page's processed image, loading off the main thread.
struct PageImageView: View {
    let page: ScanPage
    var contentMode: ContentMode = .fit
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Rectangle().fill(Color(.secondarySystemBackground))
                    .overlay(ProgressView())
            }
        }
        .task(id: "\(page.id)|\(page.filterRaw)|\(page.rotation)") {
            let rendered = await Task.detached(priority: .userInitiated) {
                ImageFilters.shared.render(page: page)
            }.value
            image = rendered
        }
    }
}

/// UIActivityViewController wrapper for sharing PDFs/images.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

extension DateFormatter {
    static let short: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}
