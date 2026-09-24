import AppKit
import SwiftUI
import WebKit

@MainActor
final class ClaudeLoginWindowController: NSWindowController, NSWindowDelegate {
    private static var retainedController: ClaudeLoginWindowController?

    static func present(
        session: ClaudeSessionController,
        onConnected: @escaping () -> Void
    ) {
        Diagnostics.log("ClaudeLoginWindowController.present 開始; active=\(NSApp.isActive), policy=\(NSApp.activationPolicy().rawValue), windows=\(NSApp.windows.count)")
        session.setConnectionHandler(onConnected)
        let controller: ClaudeLoginWindowController
        if let existing = retainedController {
            Diagnostics.log("重用既有 Claude 視窗控制器")
            controller = existing
            controller.contentViewController = NSHostingController(
                rootView: ClaudeLoginView(session: session, onConnected: onConnected)
            )
        } else {
            Diagnostics.log("建立新 Claude NSWindowController")
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 920, height: 720),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "連結 Claude"
            window.contentMinSize = NSSize(width: 860, height: 640)
            window.level = .floating
            window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            window.isReleasedWhenClosed = false
            controller = ClaudeLoginWindowController(window: window)
            controller.window?.delegate = controller
            controller.contentViewController = NSHostingController(
                rootView: ClaudeLoginView(session: session, onConnected: onConnected)
            )
            retainedController = controller
        }

        if NSApp.activationPolicy() == .prohibited {
            let changed = NSApp.setActivationPolicy(.accessory)
            Diagnostics.log("啟用 accessory activation policy: \(changed)")
        }
        moveToVisibleArea(controller.window)
        NSApp.activate(ignoringOtherApps: true)
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        controller.window?.makeFirstResponder(session.webView)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            let window = controller.window
            moveToVisibleArea(window)
            window?.orderFrontRegardless()
            window?.makeKey()
            let frame = window?.frame.debugDescription ?? "nil"
            let screen = window?.screen?.localizedName ?? "nil"
            let occluded = window?.occlusionState.contains(.visible) == false
            Diagnostics.log("Claude 視窗檢查; exists=\(window != nil), visible=\(window?.isVisible ?? false), key=\(window?.isKeyWindow ?? false), main=\(window?.isMainWindow ?? false), appActive=\(NSApp.isActive), webViewWindow=\(session.webView.window != nil), occluded=\(occluded), screen=\(screen), frame=\(frame)")
        }
    }

    private static func moveToVisibleArea(_ window: NSWindow?) {
        guard let window, let screen = NSScreen.main ?? NSScreen.screens.first else {
            Diagnostics.log("無法取得目前螢幕位置")
            return
        }
        let visible = screen.visibleFrame
        let size = NSSize(
            width: min(window.frame.width, visible.width),
            height: min(window.frame.height, visible.height)
        )
        let origin = NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2
        )
        window.setFrame(NSRect(origin: origin, size: size), display: true)
        Diagnostics.log("將 Claude 視窗移到作用螢幕 \(screen.localizedName): \(window.frame.debugDescription)")
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        Diagnostics.log("Claude 視窗關閉：改為隱藏")
        sender.orderOut(nil)
        return false
    }
}

struct ClaudeLoginView: View {
    @ObservedObject var session: ClaudeSessionController
    let onConnected: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("連結 Claude")
                        .font(.headline)
                    Text("登入資料只會送往 claude.ai")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                if session.isConnected {
                    Label("已連結", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else if session.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }

                Button {
                    session.reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("重新載入")
            }
            .padding(12)

            Divider()
            ClaudeWebView(webView: session.webView)

            if session.isConnected {
                Divider()
                HStack {
                    Text("連結完成後可關閉此視窗。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("讀取用量") {
                        onConnected()
                    }
                }
                .padding(12)
            }
        }
        .frame(minWidth: 860, idealWidth: 1000, minHeight: 640, idealHeight: 760)
        .onAppear {
            focusLoginWindow()
        }
    }

    private func focusLoginWindow() {
        // openWindow() returns before AppKit has finished creating its NSWindow.
        // Focusing on the next run-loop makes text fields accept keyboard input.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            NSApp.activate(ignoringOtherApps: true)
            guard let window = session.webView.window else { return }
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(session.webView)
        }
    }
}

private struct ClaudeWebView: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> WKWebView {
        DispatchQueue.main.async {
            webView.window?.makeFirstResponder(webView)
        }
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
