import Foundation
#if os(macOS)
import AppKit

enum ImageCompression {
    static func downscaleAndEncodePNGOrJPEG(_ image: NSImage, maxDimension: CGFloat, jpegQuality: Double) -> Data? {
        guard let rep = image.bestRepresentation(for: NSRect(origin: .zero, size: image.size), context: nil, hints: nil) else { return nil }
        let srcW = rep.pixelsWide
        let srcH = rep.pixelsHigh
        let scale = min(1.0, maxDimension / CGFloat(max(srcW, srcH)))
        let dstW = Int(CGFloat(srcW) * scale)
        let dstH = Int(CGFloat(srcH) * scale)

        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: dstW, pixelsHigh: dstH, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bitmapFormat: [], bytesPerRow: 0, bitsPerPixel: 0)
        NSGraphicsContext.saveGraphicsState()
        if let ctx = bitmap.flatMap({ NSGraphicsContext(bitmapImageRep: $0) }) {
            NSGraphicsContext.current = ctx
            NSColor.clear.setFill()
            NSBezierPath(rect: NSRect(x: 0, y: 0, width: dstW, height: dstH)).fill()
            let dstRect = NSRect(x: 0, y: 0, width: dstW, height: dstH)
            image.draw(in: dstRect, from: .zero, operation: .copy, fraction: 1.0)
        }
        NSGraphicsContext.restoreGraphicsState()

        guard let finalRep = bitmap else { return nil }
        // For OCR, PNG preserves crisp text edges better than JPEG.
        return finalRep.representation(using: .png, properties: [:])
    }
}

#endif
