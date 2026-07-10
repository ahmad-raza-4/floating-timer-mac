import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: TimerPanel!
    private let model = TimerModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let size = CGSize(width: TimerView.pillWidth, height: TimerView.pillHeight)
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let origin = Self.savedOrigin(fallbackScreenFrame: screenFrame, size: size)

        panel = TimerPanel(contentRect: NSRect(origin: origin, size: size))
        let hosting = NSHostingView(rootView: TimerView(model: model))
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = hosting
        panel.orderFrontRegardless()

        // The window's drop shadow is computed from the content's opaque pixels;
        // force a recompute once SwiftUI has actually laid out the rounded shape.
        DispatchQueue.main.async {
            self.panel.invalidateShadow()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // This is an accessory (menu-bar-style) app: the floating timer panel is a
        // borderless .nonactivatingPanel, which AppKit does not count as a "real" window
        // for this check. Without this override, closing an auxiliary window (History,
        // Stats) while the panel is still up would be seen as "last window closed" and
        // quit the whole app — killing a running timer. Only the explicit Quit menu item
        // should terminate the app.
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.logInProgressRunOnQuit()
    }

    private static func savedOrigin(fallbackScreenFrame: NSRect, size: CGSize) -> CGPoint {
        let defaults = UserDefaults.standard
        if let x = defaults.object(forKey: "windowOriginX") as? Double,
           let y = defaults.object(forKey: "windowOriginY") as? Double {
            let saved = CGPoint(x: x, y: y)
            let reachable = NSScreen.screens.contains { $0.frame.insetBy(dx: -size.width, dy: -size.height).contains(saved) }
            if reachable {
                return saved
            }
        }
        return CGPoint(
            x: fallbackScreenFrame.maxX - size.width - 40,
            y: fallbackScreenFrame.maxY - size.height - 60
        )
    }
}
