import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// Applies document filters with Core Image and handles rotation.
/// Results are cached per (file, filter, rotation) to keep scrolling smooth.
final class ImageFilters {
    static let shared = ImageFilters()
    private let context = CIContext()
    private let cache = NSCache<NSString, UIImage>()

    func render(page: ScanPage) -> UIImage? {
        let key = "\(page.originalFile)|\(page.filterRaw)|\(page.rotation)" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        guard let base = ImageStore.load(page.originalFile) else { return nil }
        let filtered = apply(page.filter, to: base)
        let rotated = rotate(filtered, degrees: page.rotation)
        cache.setObject(rotated, forKey: key)
        return rotated
    }

    func apply(_ filter: PageFilter, to image: UIImage) -> UIImage {
        guard filter != .original, let ci = CIImage(image: image) else { return image }
        let out: CIImage
        switch filter {
        case .original:
            out = ci
        case .enhance:
            // Boost contrast and brightness for a clean "document" look.
            let f = CIFilter.colorControls()
            f.inputImage = ci
            f.contrast = 1.15
            f.brightness = 0.06
            f.saturation = 1.05
            out = f.outputImage ?? ci
        case .grayscale:
            let f = CIFilter.photoEffectMono()
            f.inputImage = ci
            out = f.outputImage ?? ci
        case .blackWhite:
            // High-contrast scan: desaturate then push to near black/white.
            let mono = CIFilter.photoEffectNoir()
            mono.inputImage = ci
            let c = CIFilter.colorControls()
            c.inputImage = mono.outputImage
            c.contrast = 2.2
            c.brightness = 0.1
            out = c.outputImage ?? ci
        }
        guard let cg = context.createCGImage(out, from: out.extent) else { return image }
        return UIImage(cgImage: cg, scale: image.scale, orientation: .up)
    }

    func rotate(_ image: UIImage, degrees: Int) -> UIImage {
        let normalized = ((degrees % 360) + 360) % 360
        guard normalized != 0, let cg = image.cgImage else { return image }
        let orientation: UIImage.Orientation
        switch normalized {
        case 90: orientation = .right
        case 180: orientation = .down
        case 270: orientation = .left
        default: orientation = .up
        }
        return UIImage(cgImage: cg, scale: image.scale, orientation: orientation)
    }

    func clearCache() { cache.removeAllObjects() }
}
