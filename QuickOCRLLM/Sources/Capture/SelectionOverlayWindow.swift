import SwiftUI
#if os(macOS)
import AppKit

final class SelectionOverlayWindow: NSWindow, NSWindowDelegate {
    private var onComplete: ((CGRect?) -> Void)?

    convenience init(onComplete: @escaping (CGRect?) -> Void) {
        let screenFrame = NSScreen.main?.frame ?? .zero
        self.init(contentRect: screenFrame, styleMask: [.borderless], backing: .buffered, defer: false)
        self.level = .screenSaver
        self.isOpaque = false
        self.backgroundColor = .clear
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        self.collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces]
        self.isReleasedWhenClosed = false
        self.delegate = self
        self.onComplete = onComplete

        let hosting = NSHostingView(rootView: SelectionOverlayView { [weak self] rect in
            self?.close()
            onComplete(rect)
        })
        hosting.frame = screenFrame
        self.contentView = hosting
        self.makeKeyAndOrderFront(nil)
        self.orderFrontRegardless()
    }

    func cancel() {
        onComplete?(nil)
        close()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

struct SelectionOverlayView: View {
    var onComplete: (CGRect?) -> Void
    @State private var startPoint: CGPoint? = nil
    @State private var currentPoint: CGPoint? = nil

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()

                if let rect = selectionRect(in: geo.size) {
                    Rectangle()
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
                        .foregroundColor(.white)
                        .background(Color.blue.opacity(0.2))
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                }

                Text("Drag to select area • Esc to cancel")
                    .font(.system(size: 14, weight: .medium))
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                    .padding(.top, 24)
                    .frame(maxWidth: .infinity)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if startPoint == nil { startPoint = value.startLocation }
                    currentPoint = value.location
                }
                .onEnded { _ in
                    onComplete(selectionRect(in: geo.size))
                    startPoint = nil
                    currentPoint = nil
                }
            )
            .onExitCommand { onComplete(nil) }
        }
    }

    private func selectionRect(in container: CGSize) -> CGRect? {
        guard let s = startPoint, let c = currentPoint else { return nil }
        let x = min(s.x, c.x)
        let y = min(s.y, c.y)
        let w = abs(c.x - s.x)
        let h = abs(c.y - s.y)
        if w < 5 || h < 5 { return nil }
        return CGRect(x: x, y: y, width: w, height: h)
    }
}

#endif
