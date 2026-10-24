import SwiftUI

/// Drag the four corners to re-crop a page, then apply perspective correction.
struct CropEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let page: ScanPage

    @State private var image: UIImage?
    // Corners in normalized [0,1] space: TL, TR, BL, BR.
    @State private var corners: [CGPoint] = [
        .init(x: 0.05, y: 0.05), .init(x: 0.95, y: 0.05),
        .init(x: 0.05, y: 0.95), .init(x: 0.95, y: 0.95)
    ]

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                if let image {
                    let rect = fitRect(image.size, in: geo.size)
                    ZStack {
                        Color(.systemBackground)
                        Image(uiImage: image)
                            .resizable()
                            .frame(width: rect.width, height: rect.height)
                            .position(x: rect.midX, y: rect.midY)
                        CropOverlay(corners: corners, rect: rect)
                        ForEach(0..<4, id: \.self) { i in
                            handle(index: i, rect: rect)
                        }
                    }
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Adjust edges")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Apply", action: apply) }
            }
            .task { image = ImageStore.load(page.originalFile) }
        }
    }

    private func handle(index i: Int, rect: CGRect) -> some View {
        let pos = CGPoint(x: rect.minX + corners[i].x * rect.width,
                          y: rect.minY + corners[i].y * rect.height)
        return Circle()
            .fill(Color.accentColor)
            .frame(width: 26, height: 26)
            .overlay(Circle().stroke(.white, lineWidth: 3))
            .position(pos)
            .gesture(DragGesture().onChanged { value in
                let nx = min(max((value.location.x - rect.minX) / rect.width, 0), 1)
                let ny = min(max((value.location.y - rect.minY) / rect.height, 0), 1)
                corners[i] = CGPoint(x: nx, y: ny)
            })
    }

    private func fitRect(_ size: CGSize, in container: CGSize) -> CGRect {
        let fit = ImageProcessing.aspectFit(size, in: CGSize(width: container.width - 32,
                                                             height: container.height - 32))
        return CGRect(x: (container.width - fit.width) / 2,
                      y: (container.height - fit.height) / 2,
                      width: fit.width, height: fit.height)
    }

    private func apply() {
        guard let image else { return }
        let s = image.size
        func pt(_ n: CGPoint) -> CGPoint { CGPoint(x: n.x * s.width, y: n.y * s.height) }
        let result = ImageProcessing.perspectiveCorrect(
            image,
            topLeft: pt(corners[0]), topRight: pt(corners[1]),
            bottomLeft: pt(corners[2]), bottomRight: pt(corners[3])
        )
        // Replace the stored image, keep the same file name reference fresh.
        ImageStore.delete(page.originalFile)
        page.originalFile = ImageStore.save(result)
        page.document?.updatedAt = .now
        ImageFilters.shared.clearCache()
        try? context.save()
        dismiss()
    }
}

/// Draws the crop quadrilateral.
private struct CropOverlay: View {
    let corners: [CGPoint]
    let rect: CGRect

    var body: some View {
        Path { path in
            let pts = corners.map { CGPoint(x: rect.minX + $0.x * rect.width,
                                            y: rect.minY + $0.y * rect.height) }
            // order TL, TR, BR, BL for a closed quad
            path.move(to: pts[0])
            path.addLine(to: pts[1])
            path.addLine(to: pts[3])
            path.addLine(to: pts[2])
            path.closeSubpath()
        }
        .stroke(Color.accentColor, lineWidth: 2)
        .background(
            Path { path in
                let pts = corners.map { CGPoint(x: rect.minX + $0.x * rect.width,
                                                y: rect.minY + $0.y * rect.height) }
                path.move(to: pts[0]); path.addLine(to: pts[1])
                path.addLine(to: pts[3]); path.addLine(to: pts[2]); path.closeSubpath()
            }
            .fill(Color.accentColor.opacity(0.1))
        )
    }
}
