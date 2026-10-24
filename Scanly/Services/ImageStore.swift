import Foundation
import UIKit

/// Stores page images as JPEG files in the app's Documents/Pages directory.
/// The database only keeps file names, keeping the store small and portable.
enum ImageStore {
    static let folderName = "Pages"

    static var root: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent(folderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Save an image and return its generated file name.
    @discardableResult
    static func save(_ image: UIImage, quality: CGFloat = 0.85) -> String {
        let name = "\(UUID().uuidString).jpg"
        if let data = image.jpegData(compressionQuality: quality) {
            try? data.write(to: root.appendingPathComponent(name))
        }
        return name
    }

    static func load(_ fileName: String) -> UIImage? {
        UIImage(contentsOfFile: root.appendingPathComponent(fileName).path)
    }

    static func url(_ fileName: String) -> URL {
        root.appendingPathComponent(fileName)
    }

    static func delete(_ fileName: String) {
        try? FileManager.default.removeItem(at: root.appendingPathComponent(fileName))
    }
}
