import SwiftUI
import AppKit
import UserNotifications

// MARK: - HUDManager
@MainActor
final class HUDManager {
    static let shared = HUDManager()
    
    private var window: NSWindow?
    private var hideTask: Task<Void, Never>?
    
    private init() {}
    
    func show(text: String, icon: String = "StatusIconTemplate", isError: Bool = false) {
        hideTask?.cancel()
        
        if window == nil {
            let win = NSWindow(
                contentRect: .zero,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            win.level = .floating
            win.backgroundColor = .clear
            win.isOpaque = false
            win.hasShadow = false
            win.ignoresMouseEvents = true // Let clicks pass through
            win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            self.window = win
        }
        
        guard let window = window else { return }
        
        // Ensure UI updates happen on main thread
        let view = HUDView(text: text, icon: icon, isError: isError)
        let hosting = NSHostingView(rootView: view)
        window.contentView = hosting
        
        let size = hosting.fittingSize
        
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = screenRect.midX - (size.width / 2)
            let y = screenRect.minY + 140
            
            window.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
        }
        
        window.alphaValue = 1.0
        window.orderFront(nil)
        
        hideTask = Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.5
                window.animator().alphaValue = 0
            } completionHandler: { [weak self] in
                guard let self = self else { return }
                guard self.hideTask?.isCancelled == false else { return }
                self.window?.orderOut(nil)
            }
        }
    }
}

// MARK: - Animated Icon
private struct AnimatedDocSmileIcon: View {
    let color: Color
    @State private var showDoc = false
    @State private var showFace = false
    
    var body: some View {
        ZStack {
            // Document Outline with Folded Corner
            ZStack(alignment: .topTrailing) {
                DocumentShape()
                    .stroke(style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .foregroundColor(color)
                
                // The little fold detail
                FoldShape()
                    .stroke(style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .foregroundColor(color)
                    .frame(width: 6, height: 6)
            }
            .frame(width: 26, height: 28) // Widened the face (was 22)
            .opacity(showDoc ? 1 : 0)
            .scaleEffect(showDoc ? 1 : 0.5)
            .rotationEffect(.degrees(showDoc ? 0 : -15))
            
            // Face Features
            Group {
                // Left Eye
                Circle()
                    .frame(width: 2.5, height: 2.5)
                    .position(x: 8, y: 14) // Adjusted x for wider face (center is 13)
                    .offset(x: showFace ? 0 : -10, y: showFace ? 0 : -4)
                    .rotationEffect(.degrees(showFace ? 0 : -180))
                
                // Right Eye
                Circle()
                    .frame(width: 2.5, height: 2.5)
                    .position(x: 18, y: 14) // Adjusted x for wider face
                    .offset(x: showFace ? 0 : 10, y: showFace ? 0 : -4)
                    .rotationEffect(.degrees(showFace ? 0 : 180))
                
                // Mouth
                SmilePath()
                    .stroke(style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .frame(width: 6, height: 3)
                    .position(x: 13, y: 20) // Centered at 13
                    .offset(y: showFace ? 0 : 8)
                    .scaleEffect(showFace ? 1 : 0.1)
            }
            .foregroundColor(color)
            .opacity(showFace ? 1 : 0)
        }
        .frame(width: 28, height: 30) // Adjusted outer frame width
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showDoc = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.15)) {
                showFace = true
            }
        }
    }
}

private struct DocumentShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r: CGFloat = 3
        let fold: CGFloat = 6
        
        path.move(to: CGPoint(x: r, y: 0))
        path.addLine(to: CGPoint(x: rect.width - fold, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: fold)) // Cut corner
        path.addLine(to: CGPoint(x: rect.width, y: rect.height - r))
        path.addArc(center: CGPoint(x: rect.width - r, y: rect.height - r), radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: r, y: rect.height))
        path.addArc(center: CGPoint(x: r, y: rect.height - r), radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: 0, y: r))
        path.addArc(center: CGPoint(x: r, y: r), radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        
        return path
    }
}

private struct FoldShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Draw the fold line: starts at top-left of the fold rect, goes to bottom-right (corner of document), but here we want the "inner" fold look.
        // Usually it's a triangle or L shape.
        // Let's do a simple L shape to simulate the fold flap.
        // rect is 6x6 positioned at top right.
        
        // Start from top-left of this small rect (which is on the top edge of doc)
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 0, y: rect.height)) // Down
        path.addLine(to: CGPoint(x: rect.width, y: rect.height)) // Right
        // This forms the bottom-left corner of the fold flap.
        
        return path
    }
}

private struct SmilePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addQuadCurve(to: CGPoint(x: rect.width, y: 0), control: CGPoint(x: rect.width / 2, y: rect.height))
        return path
    }
}

private struct HUDView: View {
    let text: String
    let icon: String // If "StatusIconTemplate", we use the animated view
    let isError: Bool
    
    var body: some View {
        HStack(spacing: 18) {
            if icon == "StatusIconTemplate" {
                AnimatedDocSmileIcon(color: isError ? .red : .green)
                    .frame(width: 20, height: 24)
            } else {
                // Fallback for system symbols or other assets
                if let nsImage = NSImage(named: icon) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .foregroundColor(isError ? .red : .green)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(isError ? .red : .green)
                }
            }
            
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.85))
                .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 5)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                )
        )
        .padding(16)
        .fixedSize(horizontal: true, vertical: true)
    }
}

// MARK: - Compatibility
enum Notifications {
    static func requestAuthorizationIfNeeded() {
        // No-op for HUD
    }
    
    static func show(text: String) {
        Task { @MainActor in
            HUDManager.shared.show(text: text)
        }
    }
}
