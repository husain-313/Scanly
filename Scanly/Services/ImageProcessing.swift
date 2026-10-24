import UIKit
import CoreImage

/// Geometry + compositing helpers for cropping, signatures and ID cards.
enum ImageProcessing {
    private static let context = CIContext()

    /// Apply a perspective correction given four corners in the image's own
    /// pixel space (top-left origin, in points matching `image.size`).
    static func perspectiveCorrect(_ image: UIImage,
                                   topLeft: CGPoint, topRight: CGPoint,
                                   bottomLeft: CGPoint, bottomRight: CGPoint) -> UIImage {
        guard let ci = CIImage(image: image) else { return image }
        let h = ci.extent.height
        // Core Image uses a bottom-left origin, so flip Y.
        func v(_ p: CGPoint) -> CIVector { CIVector(x: p.x, y: h - p.y) }

        let filter = CIFilter(name: "CIPerspectiveCorrection")!
        filter.setValue(ci, forKey: kCIInputImageKey)
        filter.setValue(v(topLeft), forKey: "inputTopLeft")
        filter.setValue(v(topRight), forKey: "inputTopRight")
        filter.setValue(v(bottomLeft), forKey: "inputBottomLeft")
        filter.setValue(v(bottomRight), forKey: "inputBottomRight")
        guard let out = filter.outputImage,
              let cg = context.createCGImage(out, from: out.extent) else { return image }
        return UIImage(cgImage: cg)
    }

    /// Draw a transparent overlay (e.g. a signature) onto a base image at the
    /// given rect, expressed in normalized [0,1] coordinates of the base.
    static func overlay(_ overlay: UIImage, on base: UIImage, atNormalizedRect rect: CGRect) -> UIImage {
        let size = base.size
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            base.draw(in: CGRect(origin: .zero, size: size))
            let target = CGRect(x: rect.origin.x * size.width,
                                y: rect.origin.y * size.height,
                                width: rect.width * size.width,
                                height: rect.height * size.height)
            overlay.draw(in: target)
        }
    }

    /// Place two images (front/back of a card) centered on a white A4-like page.
    static func idCardPage(front: UIImage, back: UIImage?) -> UIImage {
        let pageSize = CGSize(width: 1240, height: 1754) // ~A4 @150dpi
        let renderer = UIGraphicsImageRenderer(size: pageSize)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: pageSize))
            let margin: CGFloat = 80
            let slotW = pageSize.width - margin * 2
            let images = [front, back].compactMap { $0 }
            let slotH = (pageSize.height - margin * CGFloat(images.count + 1)) / CGFloat(max(images.count, 1))
            for (i, img) in images.enumerated() {
                let fit = aspectFit(img.size, in: CGSize(width: slotW, height: slotH))
                let x = (pageSize.width - fit.width) / 2
                let y = margin + CGFloat(i) * (slotH + margin) + (slotH - fit.height) / 2
                img.draw(in: CGRect(x: x, y: y, width: fit.width, height: fit.height))
            }
        }
    }

    static func aspectFit(_ size: CGSize, in box: CGSize) -> CGSize {
        guard size.width > 0, size.height > 0 else { return box }
        let scale = min(box.width / size.width, box.height / size.height)
        return CGSize(width: size.width * scale, height: size.height * scale)
    }
}
