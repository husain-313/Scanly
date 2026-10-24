import Foundation
import SwiftData

/// A scanned document: a title plus an ordered list of pages.
@Model
final class ScannedDocument {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var folder: String?
    var isLocked: Bool

    /// Full OCR text across all pages, used for search.
    var ocrText: String

    @Relationship(deleteRule: .cascade, inverse: \ScanPage.document)
    var pages: [ScanPage]

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        folder: String? = nil,
        isLocked: Bool = false,
        ocrText: String = "",
        pages: [ScanPage] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.folder = folder
        self.isLocked = isLocked
        self.ocrText = ocrText
        self.pages = pages
    }

    var orderedPages: [ScanPage] { pages.sorted { $0.index < $1.index } }
    var pageCount: Int { pages.count }
}

/// One page of a document. The image bytes live on disk; the model keeps the
/// file name and the processing choice so pages can be re-rendered.
@Model
final class ScanPage {
    @Attribute(.unique) var id: UUID
    var index: Int
    /// File name (not full path) of the original captured image in the store.
    var originalFile: String
    /// Selected filter, see `PageFilter`.
    var filterRaw: String
    /// Clockwise rotation in degrees (0/90/180/270).
    var rotation: Int
    var createdAt: Date

    var document: ScannedDocument?

    var filter: PageFilter {
        get { PageFilter(rawValue: filterRaw) ?? .enhance }
        set { filterRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        index: Int,
        originalFile: String,
        filter: PageFilter = .magic,
        rotation: Int = 0,
        createdAt: Date = .now
    ) {
        self.id = id
        self.index = index
        self.originalFile = originalFile
        self.filterRaw = filter.rawValue
        self.rotation = rotation
        self.createdAt = createdAt
    }
}

enum PageFilter: String, CaseIterable, Identifiable {
    case original, magic, enhance, grayscale, blackWhite
    var id: String { rawValue }
    var title: String {
        switch self {
        case .original: return "Original"
        case .magic: return "Magic"
        case .enhance: return "Enhance"
        case .grayscale: return "Grayscale"
        case .blackWhite: return "B&W"
        }
    }
    var symbol: String {
        switch self {
        case .original: return "photo"
        case .magic: return "wand.and.rays"
        case .enhance: return "wand.and.stars"
        case .grayscale: return "circle.lefthalf.filled"
        case .blackWhite: return "doc.text"
        }
    }
}
