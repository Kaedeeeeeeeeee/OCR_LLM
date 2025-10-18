import AppKit

extension NSImage {
    func resized(to newSize: NSSize) -> NSImage {
        let img = NSImage(size: newSize)
        img.lockFocus()
        defer { img.unlockFocus() }
        let rect = NSRect(origin: .zero, size: newSize)
        self.draw(in: rect, from: .zero, operation: .copy, fraction: 1.0)
        return img
    }
}

