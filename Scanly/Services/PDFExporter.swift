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
        var recognized: [String] = []
        for page in pages {
            guard let image = ImageFilters.shared.render(page: page) else { continue }
            guard let pdfPage = PDFPage(image: image) else { continue }

            if searchable {
                let text = await OCRService.recognize(image)
                if !text.isEmpty {
                    recognized.append(text)
                    // Invisible text note keeps the content selectable/searchable.
                    let annotation = PDFAnnotation(
                        bounds: pdfPage.bounds(for: .mediaBox),
                        forType: .freeText, withProperties: nil)
                    annotation.contents = text
                    annotation.color = .clear
                    annotation.fontColor = .clear
                    annotation.font = .systemFont(ofSize: 1)
                    pdfPage.addAnnotation(annotation)
                }
            }
            pdf.insert(pdfPage, at: pageIndex)
            pageIndex += 1
        }

        guard pageIndex > 0 else { return nil }

        // Store recognized text in document metadata for app/file search too.
        if searchable && !recognized.isEmpty {
            var attrs = pdf.documentAttributes ?? [:]
            attrs[PDFDocumentAttribute.keywordsAttribute] = recognized
            pdf.documentAttributes = attrs
        }
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
