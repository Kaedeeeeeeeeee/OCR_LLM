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

    func show(text: String, icon: String = "StatusIconTemplate", isError: Bool = false, mascotOverride: String? = nil) {
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
        let view = HUDView(text: text, icon: icon, isError: isError, mascotOverride: mascotOverride)
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

// MARK: - Mascot styles

private enum MascotStyle: String, CaseIterable {
    case classic   // green + dot eyes + smile
    case sleepy    // sky blue + closed arcs + big smile
    case starry    // lavender + sparkle eyes + O mouth
    case winky     // honey yellow + one wink + tongue
    case lovely    // sakura pink + heart eyes + blush
    case cheerful  // peach + squint + grin
    case sad       // red + x eyes + frown (error only)

    static var randomHappy: MascotStyle {
        [.classic, .sleepy, .starry, .winky, .lovely, .cheerful].randomElement()!
    }

    var color: Color {
        switch self {
        case .classic:  return .green
        case .sleepy:   return Color(red: 0.40, green: 0.70, blue: 0.95)
        case .starry:   return Color(red: 0.70, green: 0.55, blue: 0.95)
        case .winky:    return Color(red: 0.95, green: 0.78, blue: 0.35)
        case .lovely:   return Color(red: 0.98, green: 0.60, blue: 0.72)
        case .cheerful: return Color(red: 0.98, green: 0.60, blue: 0.35)
        case .sad:      return .red
        }
    }

    var leftEye: EyeKind {
        switch self {
        case .classic:  return .dot
        case .sleepy:   return .tiredArc
        case .starry:   return .sparkle
        case .winky:    return .dot
        case .lovely:   return .heart
        case .cheerful: return .squint
        case .sad:      return .x
        }
    }

    var rightEye: EyeKind {
        self == .winky ? .closedArc : leftEye
    }

    var mouth: MouthKind {
        switch self {
        case .classic:  return .smile
        case .sleepy:   return .sleep
        case .starry:   return .o
        case .winky:    return .smile
        case .lovely:   return .smile
        case .cheerful: return .grin
        case .sad:      return .frown
        }
    }

    var hasBlush: Bool { self == .lovely }
    var hasTongue: Bool { self == .winky }
    var hasZzz: Bool { self == .sleepy }
}

private enum EyeKind { case dot, closedArc, tiredArc, sparkle, heart, squint, x }
private enum MouthKind { case smile, bigSmile, o, grin, frown, sleep }

private enum Decoration: CaseIterable { case heart, star, sparkles }

// MARK: - User-facing mascot choice (Settings)

/// Stored in `AppConfig.mascotStyle` as a raw-value String.
/// `.random` (or nil in config) → random happy mascot each OCR.
enum MascotChoice: String, CaseIterable, Identifiable {
    case random, classic, sleepy, starry, winky, lovely, cheerful

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .random:   return "Random (Surprise Me)".localized
        case .classic:  return "Classic".localized
        case .sleepy:   return "Sleepy".localized
        case .starry:   return "Starry".localized
        case .winky:    return "Winky".localized
        case .lovely:   return "Lovely".localized
        case .cheerful: return "Cheerful".localized
        }
    }
}

// MARK: - Static Mascot Icon (for settings preview)

/// Non-animating mascot view used in the settings picker grid.
struct MascotIcon: View {
    let choice: MascotChoice

    var body: some View {
        Group {
            if choice == .random {
                RandomMascotView()
            } else if let style = MascotStyle(rawValue: choice.rawValue) {
                StaticMascotView(style: style)
            }
        }
        .frame(width: 28, height: 30)
    }
}

private struct StaticMascotView: View {
    let style: MascotStyle

    var body: some View {
        ZStack {
            ZStack(alignment: .topTrailing) {
                DocumentShape()
                    .stroke(style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .foregroundColor(style.color)
                FoldShape()
                    .stroke(style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .foregroundColor(style.color)
                    .frame(width: 6, height: 6)
            }
            .frame(width: 26, height: 28)

            EyeView(kind: style.leftEye, color: style.color)
                .frame(width: 5, height: 5)
                .position(x: 9, y: 14)
            EyeView(kind: style.rightEye, color: style.color)
                .frame(width: 5, height: 5)
                .position(x: 19, y: 14)
            MouthView(kind: style.mouth, color: style.color)
                .position(x: 14, y: 20)

            if style.hasBlush {
                Circle().fill(Color(red: 1, green: 0.55, blue: 0.6).opacity(0.55))
                    .frame(width: 3, height: 3).position(x: 5, y: 18)
                Circle().fill(Color(red: 1, green: 0.55, blue: 0.6).opacity(0.55))
                    .frame(width: 3, height: 3).position(x: 23, y: 18)
            }
            if style.hasTongue {
                Circle().fill(Color(red: 1, green: 0.5, blue: 0.55))
                    .frame(width: 2.5, height: 2.5).position(x: 16, y: 22)
            }
            if style.hasZzz {
                Image(systemName: "zzz")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(style.color)
                    .position(x: 26, y: -2)
            }
        }
        .frame(width: 28, height: 30)
    }
}

private struct RandomMascotView: View {
    var body: some View {
        ZStack {
            ZStack(alignment: .topTrailing) {
                DocumentShape()
                    .stroke(style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .foregroundColor(.gray)
                FoldShape()
                    .stroke(style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .foregroundColor(.gray)
                    .frame(width: 6, height: 6)
            }
            .frame(width: 26, height: 28)

            Image(systemName: "questionmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.gray)
                .position(x: 14, y: 17)
        }
        .frame(width: 28, height: 30)
    }
}

// MARK: - Animated Icon
private struct AnimatedDocSmileIcon: View {
    let style: MascotStyle
    let decoration: Decoration?

    @State private var showDoc = false
    @State private var showFace = false
    @State private var showDeco = false

    var body: some View {
        ZStack {
            // Document Outline with Folded Corner
            ZStack(alignment: .topTrailing) {
                DocumentShape()
                    .stroke(style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .foregroundColor(style.color)

                FoldShape()
                    .stroke(style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .foregroundColor(style.color)
                    .frame(width: 6, height: 6)
            }
            .frame(width: 26, height: 28)
            .opacity(showDoc ? 1 : 0)
            .scaleEffect(showDoc ? 1 : 0.5)
            .rotationEffect(.degrees(showDoc ? 0 : -15))

            // Face Features — shifted right by 1pt to visually center against the folded corner
            Group {
                // Left Eye
                EyeView(kind: style.leftEye, color: style.color)
                    .frame(width: 5, height: 5)
                    .position(x: 9, y: 14)
                    .offset(x: showFace ? 0 : -10, y: showFace ? 0 : -4)
                    .rotationEffect(.degrees(showFace ? 0 : -180))

                // Right Eye
                EyeView(kind: style.rightEye, color: style.color)
                    .frame(width: 5, height: 5)
                    .position(x: 19, y: 14)
                    .offset(x: showFace ? 0 : 10, y: showFace ? 0 : -4)
                    .rotationEffect(.degrees(showFace ? 0 : 180))

                // Mouth
                MouthView(kind: style.mouth, color: style.color)
                    .position(x: 14, y: 20)
                    .offset(y: showFace ? 0 : 8)
                    .scaleEffect(showFace ? 1 : 0.1)
            }
            .opacity(showFace ? 1 : 0)

            // Blush (lovely only)
            if style.hasBlush {
                Group {
                    Circle()
                        .fill(Color(red: 1, green: 0.55, blue: 0.6).opacity(0.55))
                        .frame(width: 3, height: 3)
                        .position(x: 5, y: 18)
                    Circle()
                        .fill(Color(red: 1, green: 0.55, blue: 0.6).opacity(0.55))
                        .frame(width: 3, height: 3)
                        .position(x: 23, y: 18)
                }
                .opacity(showFace ? 1 : 0)
            }

            // Tongue (winky only)
            if style.hasTongue {
                Circle()
                    .fill(Color(red: 1, green: 0.5, blue: 0.55))
                    .frame(width: 2.5, height: 2.5)
                    .position(x: 16, y: 22)
                    .opacity(showFace ? 1 : 0)
            }

            // Zzz (sleepy only)
            if style.hasZzz {
                Image(systemName: "zzz")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(style.color)
                    .position(x: 26, y: -2)
                    .opacity(showFace ? 1 : 0)
            }

            // Easter-egg decoration (rare)
            if let deco = decoration {
                DecorationView(kind: deco)
                    .position(x: 24, y: -2)
                    .opacity(showDeco ? 1 : 0)
                    .scaleEffect(showDeco ? 1 : 0.3)
                    .offset(y: showDeco ? 0 : 6)
            }
        }
        .frame(width: 28, height: 30)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showDoc = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.15)) {
                showFace = true
            }
            if decoration != nil {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.55).delay(0.45)) {
                    showDeco = true
                }
            }
        }
    }
}

// MARK: - Eye / Mouth / Decoration rendering

private struct EyeView: View {
    let kind: EyeKind
    let color: Color

    var body: some View {
        Group {
            switch kind {
            case .dot:
                Circle()
                    .frame(width: 2.5, height: 2.5)
            case .closedArc:
                ClosedArcShape()
                    .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .frame(width: 4, height: 2)
            case .tiredArc:
                TiredArcShape()
                    .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .frame(width: 4, height: 2)
            case .sparkle:
                Image(systemName: "sparkle")
                    .font(.system(size: 6, weight: .bold))
            case .heart:
                Image(systemName: "heart.fill")
                    .font(.system(size: 5))
            case .squint:
                SquintShape()
                    .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                    .frame(width: 4, height: 2)
            case .x:
                XShape()
                    .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .frame(width: 4, height: 4)
            }
        }
        .foregroundColor(color)
    }
}

private struct MouthView: View {
    let kind: MouthKind
    let color: Color

    var body: some View {
        Group {
            switch kind {
            case .smile:
                SmilePath()
                    .stroke(style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .frame(width: 6, height: 3)
            case .bigSmile:
                SmilePath()
                    .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 8, height: 4)
            case .o:
                Circle()
                    .stroke(lineWidth: 1.8)
                    .frame(width: 3.5, height: 3.5)
            case .grin:
                SmilePath()
                    .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 9, height: 4)
            case .frown:
                FrownPath()
                    .stroke(style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .frame(width: 6, height: 3)
            case .sleep:
                // Sleeping slack-jawed mouth — small horizontal oval
                Ellipse()
                    .stroke(lineWidth: 1.5)
                    .frame(width: 4, height: 2.5)
            }
        }
        .foregroundColor(color)
    }
}

private struct DecorationView: View {
    let kind: Decoration

    var body: some View {
        switch kind {
        case .heart:
            Image(systemName: "heart.fill")
                .font(.system(size: 8))
                .foregroundColor(Color(red: 1, green: 0.45, blue: 0.6))
        case .star:
            Image(systemName: "star.fill")
                .font(.system(size: 8))
                .foregroundColor(Color(red: 1, green: 0.82, blue: 0.3))
        case .sparkles:
            Image(systemName: "sparkles")
                .font(.system(size: 9))
                .foregroundColor(Color(red: 1, green: 0.85, blue: 0.4))
        }
    }
}

// MARK: - Shapes

private struct DocumentShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r: CGFloat = 3
        let fold: CGFloat = 6

        path.move(to: CGPoint(x: r, y: 0))
        path.addLine(to: CGPoint(x: rect.width - fold, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: fold))
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
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
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

private struct FrownPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addQuadCurve(to: CGPoint(x: rect.width, y: rect.height), control: CGPoint(x: rect.width / 2, y: 0))
        return path
    }
}

private struct ClosedArcShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addQuadCurve(to: CGPoint(x: rect.width, y: rect.height), control: CGPoint(x: rect.width / 2, y: 0))
        return path
    }
}

private struct TiredArcShape: Shape {
    // Downward-sagging arc — tired / drowsy closed eye
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addQuadCurve(to: CGPoint(x: rect.width, y: 0), control: CGPoint(x: rect.width / 2, y: rect.height))
        return path
    }
}

private struct SquintShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: rect.width / 2, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        return path
    }
}

private struct XShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.move(to: CGPoint(x: rect.width, y: 0))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        return path
    }
}

// MARK: - HUD View

private struct HUDView: View {
    let text: String
    let icon: String // If "StatusIconTemplate", we use the animated mascot
    let isError: Bool

    private let style: MascotStyle
    private let decoration: Decoration?

    init(text: String, icon: String, isError: Bool, mascotOverride: String?) {
        self.text = text
        self.icon = icon
        self.isError = isError
        if isError {
            self.style = .sad
            self.decoration = nil
        } else {
            if let raw = mascotOverride,
               let fixed = MascotStyle(rawValue: raw),
               fixed != .sad {
                self.style = fixed
            } else {
                self.style = MascotStyle.randomHappy
            }
            // ~4% easter-egg chance — rare enough to feel special
            self.decoration = Double.random(in: 0..<1) < 0.04
                ? Decoration.allCases.randomElement()
                : nil
        }
    }

    var body: some View {
        HStack(spacing: 18) {
            if icon == "StatusIconTemplate" {
                AnimatedDocSmileIcon(style: style, decoration: decoration)
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
