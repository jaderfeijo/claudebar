import AppKit

/// Plain AppKit entry point: a SwiftUI `App` needs at least one scene, and
/// macOS opens that scene's (empty) window when the app is launched again.
@main
enum ClaudeBarApp {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        if DevTools.runIfRequested() { return }
        #endif
        statusBar = StatusBarController(model: UsageModel())
    }

    /// Opening the app again (Finder, Spotlight, `open`) shows the dropdown.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusBar?.showPanel()
        return false
    }
}
