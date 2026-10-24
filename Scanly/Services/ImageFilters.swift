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
        case .magic:
            // The "clear scan" pipeline: even out the lighting, then lift
            // contrast and sharpen the text edges.
            let flat = flattenIllumination(ci)
            let cc = CIFilter.colorControls()
            cc.inputImage = flat
            cc.contrast = 1.12
            cc.brightness = 0.02
            cc.saturation = 1.08
            let sharp = CIFilter.sharpenLuminance()
            sharp.inputImage = cc.outputImage ?? flat
            sharp.sharpness = 0.7
            out = sharp.outputImage ?? flat
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
            f.inputImage = flattenIllumination(ci)
            out = f.outputImage ?? ci
        case .blackWhite:
            // Flatten lighting first so thresholding gives crisp black text on
            // clean white, without shadow blotches.
            let flat = flattenIllumination(ci)
            let mono = CIFilter.photoEffectNoir()
            mono.inputImage = flat
            let c = CIFilter.colorControls()
            c.inputImage = mono.outputImage ?? flat
            c.contrast = 2.6
            c.brightness = 0.15
            out = c.outputImage ?? flat
        }
        let rect = ci.extent
        guard let cg = context.createCGImage(out, from: rect.isInfinite ? out.extent : rect) else { return image }
        return UIImage(cgImage: cg, scale: image.scale, orientation: .up)
    }

    /// Divides the image by a blurred copy of itself to cancel uneven lighting
    /// and shadows — the key step behind a clean, bright document scan.
    private func flattenIllumination(_ ci: CIImage) -> CIImage {
        let extent = ci.extent
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = ci.clampedToExtent()
        blur.radius = Float(max(extent.width, extent.height) / 25)
        guard let background = blur.outputImage?.cropped(to: extent) else { return ci }
        // Divide blend = background(base) / foreground(blend) → original / blurred.
        let divide = CIFilter.divideBlendMode()
        divide.inputImage = background      // blend (denominator)
        divide.backgroundImage = ci         // base (numerator)
        return divide.outputImage?.cropped(to: extent) ?? ci
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
