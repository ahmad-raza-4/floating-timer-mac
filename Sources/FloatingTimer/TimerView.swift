import SwiftUI
import AppKit

struct TimerView: View {
    @ObservedObject var model: TimerModel

    @State private var window: NSWindow?
    @State private var dragStartMouseLocation: CGPoint?
    @State private var dragStartWindowOrigin: CGPoint?
    @State private var isHovering = false
    @State private var pulse = false
    @State private var lowTimePulse = false

    static let pillWidth: CGFloat = 112
    static let pillHeight: CGFloat = 40
    private let ringWidth: CGFloat = 3.5

    private var shape: Rectangle {
        Rectangle()
    }

    var body: some View {
        ZStack {
            shape
                .fill(.ultraThinMaterial)
                .overlay(shape.fill(Color.black.opacity(0.18)))

            shape
                .strokeBorder(Color.white.opacity(0.14), lineWidth: ringWidth)

            shape
                .trim(from: 0, to: model.progress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                .opacity(lowTimePulse ? 0.45 : 1.0)
                .animation(.linear(duration: 0.12), value: model.progress)

            if isHovering {
                controlRow
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else {
                Text(model.state == .finished ? "Done" : timeString)
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .frame(width: Self.pillWidth, height: Self.pillHeight)
        .scaleEffect(pulse ? 1.06 : 1.0)
        .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
        .background(WindowAccessor(window: $window))
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) { isHovering = hovering }
        }
        .gesture(dragGesture)
        .contextMenu { contextMenuContent }
        .onChange(of: model.state) { newValue in
            if newValue == .finished {
                startFinishPulse()
            } else {
                pulse = false
            }
        }
        .onChange(of: isLowTime) { low in
            if low {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    lowTimePulse = true
                }
            } else {
                withAnimation(.easeOut(duration: 0.15)) { lowTimePulse = false }
            }
        }
    }

    private var isLowTime: Bool {
        model.state == .running && model.progress < 0.1
    }

    // MARK: - Controls

    private var controlRow: some View {
        HStack(spacing: 8) {
            iconButton("arrow.counterclockwise", help: "Reset") {
                model.stop()
            }
            iconButton(model.state == .running ? "pause.fill" : "play.fill", size: 11, filled: true, help: model.state == .running ? "Pause" : "Resume") {
                model.toggle()
            }
        }
    }

    private func iconButton(_ systemName: String, size: CGFloat = 9, filled: Bool = false, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: filled ? 22 : 18, height: filled ? 22 : 18)
                .background(
                    Circle().fill(filled ? Color.white.opacity(0.22) : Color.white.opacity(0.10))
                )
        }
        .buttonStyle(PressableButtonStyle())
        .help(help)
    }

    // MARK: - Context menu

    @ViewBuilder
    private var contextMenuContent: some View {
        ForEach(TimerModel.presets, id: \.label) { preset in
            Button(preset.label) {
                model.setDuration(preset.seconds)
                model.start()
            }
        }
        Divider()
        Button("Custom Duration…") { showCustomDurationPrompt() }
        Divider()
        Button(model.state == .running ? "Pause" : "Resume") { model.toggle() }
        Button("Reset") { model.stop() }
        Divider()
        Button("Timer Stats…") { StatsWindowController.shared.show() }
        Button("Usage History…") { HistoryWindowController.shared.show() }
        Button(LaunchAtLogin.isEnabled ? "✓ Launch at Login" : "Launch at Login") {
            LaunchAtLogin.toggle()
        }
        Divider()
        Button("Quit Floating Timer") { NSApp.terminate(nil) }
    }

    private func showCustomDurationPrompt() {
        let alert = NSAlert()
        alert.messageText = "Set Timer Duration"
        alert.informativeText = "Enter minutes"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Set")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        field.stringValue = String(Int(model.totalDuration / 60))
        field.alignment = .center
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn, let minutes = Double(field.stringValue), minutes > 0 {
            model.setDuration(minutes * 60)
            model.start()
        }
    }

    // MARK: - Drag / tap

    /// Uses absolute screen-space mouse position (NSEvent.mouseLocation) rather than
    /// the gesture's own `translation`, which is measured relative to a view that is
    /// itself moving as the window drags — that self-referential feedback loop is what
    /// caused the earlier lag/jitter.
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { _ in
                // Dismissing the context menu can replay a stale mouse-moved event into
                // this gesture with the left button no longer actually held down, which
                // was flinging the window to wherever the pointer ended up over the menu.
                // Ignore any update that isn't backed by a real, currently-held left click.
                guard NSEvent.pressedMouseButtons & 0x1 != 0 else { return }
                guard let window else { return }
                let current = NSEvent.mouseLocation
                if dragStartMouseLocation == nil {
                    dragStartMouseLocation = current
                    dragStartWindowOrigin = window.frame.origin
                }
                guard let startMouse = dragStartMouseLocation, let startOrigin = dragStartWindowOrigin else { return }
                let proposed = CGPoint(
                    x: startOrigin.x + (current.x - startMouse.x),
                    y: startOrigin.y + (current.y - startMouse.y)
                )
                window.setFrameOrigin(clampedOrigin(proposed, for: window))
            }
            .onEnded { _ in
                let current = NSEvent.mouseLocation
                let distance = dragStartMouseLocation.map { hypot(current.x - $0.x, current.y - $0.y) } ?? 0
                dragStartMouseLocation = nil
                dragStartWindowOrigin = nil
                if distance < 3 {
                    model.toggle()
                } else if let window {
                    UserDefaults.standard.set(Double(window.frame.origin.x), forKey: "windowOriginX")
                    UserDefaults.standard.set(Double(window.frame.origin.y), forKey: "windowOriginY")
                }
            }
    }

    /// Keeps the pill fully within the visible area of whichever screen it's on, so a
    /// bad delta can never send it fully off-screen where it'd appear to "disappear".
    private func clampedOrigin(_ origin: CGPoint, for window: NSWindow) -> CGPoint {
        guard let screen = window.screen ?? NSScreen.main else { return origin }
        let visible = screen.visibleFrame
        let size = window.frame.size
        let x = min(max(origin.x, visible.minX), max(visible.minX, visible.maxX - size.width))
        let y = min(max(origin.y, visible.minY), max(visible.minY, visible.maxY - size.height))
        return CGPoint(x: x, y: y)
    }

    // MARK: - Formatting

    private var timeString: String {
        let total = Int(model.remaining.rounded(.up))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    private var ringColor: Color {
        switch model.state {
        case .idle: return .white
        case .running: return model.progress < 0.15 ? .red : .accentColor
        case .paused: return .orange
        case .finished: return .red
        }
    }

    private func startFinishPulse() {
        withAnimation(.easeInOut(duration: 0.5).repeatCount(4, autoreverses: true)) {
            pulse = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) {
            pulse = false
        }
    }
}

private struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
