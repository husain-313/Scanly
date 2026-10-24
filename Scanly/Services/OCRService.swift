import Foundation
import Vision
import UIKit

/// On-device text recognition with Apple's Vision. Supports multiple languages
/// including Arabic and English, no network and no API key.
enum OCRService {

    /// Recognize text in one image; returns the joined text.
    static func recognize(_ image: UIImage,
                          languages: [String] = ["ar-SA", "en-US"]) async -> String {
        guard let cg = image.cgImage else { return "" }
        return await withCheckedContinuation { cont in
            let request = VNRecognizeTextRequest { req, _ in
                let lines = (req.results as? [VNRecognizedTextObservation] ?? [])
                    .compactMap { $0.topCandidates(1).first?.string }
                cont.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = languages
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do { try handler.perform([request]) }
                catch { cont.resume(returning: "") }
            }
        }
    }

    /// Recognize text across a document's pages and join it.
    static func recognize(document: ScannedDocument) async -> String {
        var parts: [String] = []
        for page in document.orderedPages {
            if let img = ImageFilters.shared.render(page: page) {
                let text = await recognize(img)
                if !text.isEmpty { parts.append(text) }
            }
        }
        return parts.joined(separator: "\n\n")
    }
}
