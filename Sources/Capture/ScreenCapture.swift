import CoreGraphics
#if os(macOS)
import AppKit

enum ScreenCaptureError: Error { case noScreen, imageFailed }

struct ScreenCapture {
    static func captureSelectedRegion(rectInScreenSpace: CGRect) throws -> NSImage {
        guard let screen = NSScreen.main else { throw ScreenCaptureError.noScreen }
        // Convert from flipped SwiftUI coords (origin top-left) to CGImage coords (origin bottom-left)
        let screenFrame = screen.frame
        let scale = screen.backingScaleFactor
        // Convert points to pixels for CG capture
        let converted = CGRect(x: rectInScreenSpace.minX * scale,
                               y: (screenFrame.height - rectInScreenSpace.maxY) * scale,
                               width: rectInScreenSpace.width * scale,
                               height: rectInScreenSpace.height * scale)

        // Use CGWindowListCreateImage for region capture
        guard let cgImage = CGWindowListCreateImage(converted, .optionOnScreenOnly, kCGNullWindowID, [.bestResolution]) else {
            throw ScreenCaptureError.imageFailed
        }
        return NSImage(cgImage: cgImage, size: .zero)
    }
}
#endif
