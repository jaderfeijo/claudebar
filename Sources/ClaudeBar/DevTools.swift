#if DEBUG
import AppKit

/// Debug-build-only flags:
///   --dump-usage   print the raw usage API response (never the token) and exit
///   --preview <out.png> [--mock | --disconnected]   capture the dropdown panel to a PNG and exit
@MainActor
enum DevTools {
    /// Returns true when a dev flag handled the launch and the normal app should not start.
    static func runIfRequested() -> Bool {
        let args = CommandLine.arguments
        if args.contains("--dump-usage") {
            Task.detached {
                do {
                    if let (data, status) = try await UsageModel.fetchUsage() {
                        print("HTTP \(status)")
                        print(String(decoding: data, as: UTF8.self))
                    } else {
                        print("not connected")
                    }
                } catch {
                    print("error: \(error)")
                }
                exit(0)
            }
            return true
        }
        if let i = args.firstIndex(of: "--preview"), args.count > i + 1 {
            preview(to: args[i + 1], mock: args.contains("--mock") || args.contains("--disconnected"))
            return true
        }
        return false
    }

    private static var keepAlive: [AnyObject] = []

    /// Opens the dropdown panel off-screen and captures it with `screencapture -l`.
    private static func preview(to path: String, mock: Bool) {
        let args = CommandLine.arguments
        let model = UsageModel(live: !mock)
        if args.contains("--disconnected") {
            model.connected = false
            model.pendingAuth = OAuth.PKCE()
        } else if mock {
            model.connected = true
            let now = Date()
            model.windows = [
                UsageWindow(id: "five_hour", label: "Session (5h)", utilization: 32,
                            resetsAt: now.addingTimeInterval(3 * 3600)),
                UsageWindow(id: "seven_day", label: "Weekly", utilization: 19,
                            resetsAt: now.addingTimeInterval(3 * 86400)),
                UsageWindow(id: "extra_usage", label: "Extra Usage", utilization: 0, resetsAt: nil),
            ]
        }
        let panel = DropdownPanel(rootView: MenuView(model: model))
        keepAlive = [model, panel]
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            // on-screen (so the window server composites it) but under the wallpaper, so it's never seen
            let screen = NSScreen.main!.frame
            panel.level = NSWindow.Level(Int(CGWindowLevelForKey(.desktopWindow)) - 1)
            panel.show(below: NSRect(x: screen.midX, y: screen.midY, width: 40, height: 24), on: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                p.arguments = ["-x", "-o", "-l", String(panel.windowNumber), path]
                try? p.run()
                p.waitUntilExit()
                print("frame \(panel.frame) -> \(path)")
                exit(p.terminationStatus)
            }
        }
    }
}
#endif
