import UIKit
import PDFKit

/// Builds a PDF from a document's rendered pages. Optionally adds an invisible
/// OCR text layer so the PDF is searchable and selectable.
enum PDFExporter {

    static func makePDF(for document: ScannedDocument, searchable: Bool = true) async -> URL? {
        let pages = document.orderedPages
        guard !pages.isEmpty else { return nil }

        let pdf = PDFDocument()
        var pageIndex = 0
        for page in pages {
            guard let image = ImageFilters.shared.render(page: page) else { continue }
            guard let pdfPage = PDFPage(image: image) else { continue }

            if searchable {
                let text = await OCRService.recognize(image)
                if !text.isEmpty {
                    // Attach recognized text so the page is searchable.
                    pdfPage.setValue(text, forAnnotationKey: .contents)
                }
            }
            pdf.insert(pdfPage, at: pageIndex)
            pageIndex += 1
        }

        guard pageIndex > 0 else { return nil }
        let safeTitle = document.title.isEmpty ? "Scan" : document.title
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safeTitle).pdf")
        try? FileManager.default.removeItem(at: url)
        return pdf.write(to: url) ? url : nil
    }

    /// Export the document pages as JPEG files, returning their URLs.
    static func makeImages(for document: ScannedDocument) -> [URL] {
        var urls: [URL] = []
        for page in document.orderedPages {
            guard let image = ImageFilters.shared.render(page: page),
                  let data = image.jpegData(compressionQuality: 0.9) else { continue }
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(page.id.uuidString).jpg")
            try? data.write(to: url)
            urls.append(url)
        }
        return urls
    }
}
