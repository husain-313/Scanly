import SwiftUI
import PencilKit

/// Draw a signature, then drag/scale it onto the current page and composite.
struct SignatureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let page: ScanPage

    @State private var canvas = PKCanvasView()
    @State private var signature: UIImage?
    @State private var pageImage: UIImage?

    // Placement in normalized page coordinates.
    @State private var center = CGPoint(x: 0.7, y: 0.85)
    @State private var scale: CGFloat = 0.3

    var body: some View {
        NavigationStack {
            Group {
                if signature == nil {
                    drawStage
                } else {
                    placeStage
                }
            }
            .navigationTitle(signature == nil ? "Draw signature" : "Place signature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                if signature == nil {
                    ToolbarItem(placement: .confirmationAction) { Button("Next", action: capture) }
                } else {
                    ToolbarItem(placement: .confirmationAction) { Button("Apply", action: apply) }
                }
            }
            .task { pageImage = ImageStore.load(page.originalFile) }
        }
    }

    private var drawStage: some View {
        VStack {
            Text("Sign inside the box").font(.caption).foregroundStyle(.secondary)
            PencilCanvas(canvas: canvas)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .frame(height: 240)
                .padding()
            Button("Clear") { canvas.drawing = PKDrawing() }
            Spacer()
        }
    }

    private var placeStage: some View {
        GeometryReader { geo in
            if let pageImage, let signature {
                let rect = fitRect(pageImage.size, in: geo.size)
                ZStack {
                    Color(.systemBackground)
                    Image(uiImage: pageImage).resizable()
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                    let sigW = rect.width * scale
                    let sigH = sigW * (signature.size.height / max(signature.size.width, 1))
                    Image(uiImage: signature).resizable().scaledToFit()
                        .frame(width: sigW, height: sigH)
                        .position(x: rect.minX + center.x * rect.width,
                                  y: rect.minY + center.y * rect.height)
                        .gesture(DragGesture().onChanged { v in
                            center = CGPoint(x: min(max((v.location.x - rect.minX)/rect.width,0),1),
                                             y: min(max((v.location.y - rect.minY)/rect.height,0),1))
                        })
                }
                .overlay(alignment: .bottom) {
                    HStack {
                        Image(systemName: "minus.magnifyingglass")
                        Slider(value: $scale, in: 0.1...0.8)
                        Image(systemName: "plus.magnifyingglass")
                    }
                    .padding()
                    .background(.bar)
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func capture() {
        let drawing = canvas.drawing
        guard !drawing.bounds.isEmpty else { dismiss(); return }
        let img = drawing.image(from: drawing.bounds, scale: UIScreen.main.scale)
        signature = img
    }

    private func apply() {
        guard let pageImage, let signature else { return }
        let w = scale
        let h = w * (signature.size.height / max(signature.size.width, 1))
            * (pageImage.size.width / max(pageImage.size.height, 1))
        let rect = CGRect(x: center.x - w/2, y: center.y - h/2, width: w, height: h)
        let result = ImageProcessing.overlay(signature, on: pageImage, atNormalizedRect: rect)
        ImageStore.delete(page.originalFile)
        page.originalFile = ImageStore.save(result)
        page.filter = .original // keep the composited pixels as-is
        page.document?.updatedAt = .now
        ImageFilters.shared.clearCache()
        try? context.save()
        dismiss()
    }

    private func fitRect(_ size: CGSize, in container: CGSize) -> CGRect {
        let fit = ImageProcessing.aspectFit(size, in: CGSize(width: container.width - 32,
                                                             height: container.height - 80))
        return CGRect(x: (container.width - fit.width)/2, y: (container.height - fit.height)/2,
                      width: fit.width, height: fit.height)
    }
}

/// PencilKit canvas that also accepts finger drawing.
struct PencilCanvas: UIViewRepresentable {
    let canvas: PKCanvasView
    func makeUIView(context: Context) -> PKCanvasView {
        canvas.drawingPolicy = .anyInput
        canvas.tool = PKInkingTool(.pen, color: .black, width: 4)
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        return canvas
    }
    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}
