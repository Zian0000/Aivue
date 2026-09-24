import Combine
import Foundation
import WebKit

@MainActor
final class ClaudeSessionController: NSObject, ObservableObject {
    @Published private(set) var isConnected = false
    @Published private(set) var isLoading = false
    @Published private(set) var currentURL: URL?

    let webView: WKWebView
    private var oauthWindowController: NSWindowController?
    private var connectionHandler: (() -> Void)?

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        webView = WKWebView(frame: .zero, configuration: configuration)

        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        loadUsagePageIfNeeded()
    }

    func loadUsagePageIfNeeded() {
        Diagnostics.log("loadUsagePageIfNeeded; currentURL=\(Diagnostics.safeURL(webView.url))")
        guard webView.url == nil,
              let url = URL(string: "https://claude.ai/settings/usage")
        else {
            return
        }
        webView.load(URLRequest(url: url))
    }

    func reload() {
        if webView.url == nil {
            loadUsagePageIfNeeded()
        } else {
            webView.reload()
        }
    }

    func disconnect() async {
        let store = webView.configuration.websiteDataStore
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        await withCheckedContinuation { continuation in
            store.removeData(ofTypes: types, modifiedSince: .distantPast) {
                continuation.resume()
            }
        }
        isConnected = false
        currentURL = nil
        if let url = URL(string: "https://claude.ai/login") {
            webView.load(URLRequest(url: url))
        }
        Diagnostics.log("Claude session 已清除")
    }

    func setConnectionHandler(_ handler: @escaping () -> Void) {
        connectionHandler = handler
        if isConnected {
            connectionHandler = nil
            Diagnostics.log("Claude 已在連結狀態，立即觸發用量更新")
            handler()
        }
    }

    func fetchUsage() async throws -> UsageSnapshot {
        Diagnostics.log("fetchUsage 開始; URL=\(Diagnostics.safeURL(currentURL)), connected=\(isConnected), loading=\(isLoading)")
        guard currentURL?.host?.hasSuffix("claude.ai") == true else {
            throw ClaudeUsageError.notConnected
        }
        guard !isLoading else {
            throw ClaudeUsageError.pageNotReady
        }

        let script = #"""
        const organizationsResponse = await fetch('/api/organizations', {
          credentials: 'include',
          headers: { 'accept': 'application/json' }
        });
        if (organizationsResponse.status === 401 || organizationsResponse.status === 403) {
          return JSON.stringify({ error: 'not_authenticated' });
        }
        if (!organizationsResponse.ok) {
          return JSON.stringify({ error: `organizations_http_${organizationsResponse.status}` });
        }

        const organizationsPayload = await organizationsResponse.json();
        const organizations = Array.isArray(organizationsPayload)
          ? organizationsPayload
          : (organizationsPayload.organizations || []);
        const organization = organizations.find(item => item && item.uuid) || organizations[0];
        if (!organization || !organization.uuid) {
          return JSON.stringify({ error: 'organization_not_found' });
        }

        const usageResponse = await fetch(
          `/api/organizations/${encodeURIComponent(organization.uuid)}/usage?source=claude_ai`,
          { credentials: 'include', headers: { 'accept': 'application/json' } }
        );
        if (usageResponse.status === 401 || usageResponse.status === 403) {
          return JSON.stringify({ error: 'not_authenticated' });
        }
        if (!usageResponse.ok) {
          return JSON.stringify({ error: `usage_http_${usageResponse.status}` });
        }

        const usage = await usageResponse.json();
        const planName = organization.rate_limit_tier
          || organization.subscription_type
          || organization.billing_type
          || null;
        return JSON.stringify({ usage, planName });
        """#

        let result = try await webView.callAsyncJavaScript(
            script,
            arguments: [:],
            contentWorld: .page
        )

        guard let json = result as? String else {
            Diagnostics.log("fetchUsage 失敗：JavaScript 回傳不是文字")
            throw ClaudeUsageError.invalidResponse
        }
        do {
            let snapshot = try ClaudeResponseParser.parseUsageJSON(json)
            Diagnostics.log("fetchUsage 成功；primary=\(snapshot.primary.usedPercent)%, secondary=\(snapshot.secondary.usedPercent)%")
            return snapshot
        } catch {
            let summary = String(json.prefix(240))
            Diagnostics.log("fetchUsage 解析失敗: \(error.localizedDescription); response=\(summary)")
            throw error
        }
    }
}

extension ClaudeSessionController: WKUIDelegate {
    nonisolated func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        MainActor.assumeIsolated {
            guard navigationAction.targetFrame == nil else { return nil }

            // OAuth relies on window.opener/postMessage. It must remain a real
            // child web view rather than replacing Claude's main web view.
            let popup = WKWebView(frame: .zero, configuration: configuration)
            popup.navigationDelegate = self
            popup.uiDelegate = self

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 720, height: 760),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Claude 登入驗證"
            window.contentMinSize = NSSize(width: 560, height: 640)
            window.contentView = popup
            window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            window.level = .floating
            window.center()

            let controller = NSWindowController(window: window)
            oauthWindowController?.close()
            oauthWindowController = controller
            controller.showWindow(nil)
            window.makeKeyAndOrderFront(nil)
            Diagnostics.log("建立 OAuth 子視窗: \(navigationAction.request.url?.host ?? "unknown")")
            return popup
        }
    }

    nonisolated func webViewDidClose(_ webView: WKWebView) {
        Task { @MainActor in
            guard webView !== self.webView else { return }
            Diagnostics.log("OAuth 子視窗已關閉，回到 Claude 主視窗")
            oauthWindowController?.close()
            oauthWindowController = nil
            self.webView.window?.makeKeyAndOrderFront(nil)
            // Claude handles Google's result through postMessage without a
            // normal page navigation. Give it a moment to persist the session,
            // then load the usage page explicitly so connection detection and
            // the first usage refresh always run.
            try? await Task.sleep(for: .seconds(1))
            if let usageURL = URL(string: "https://claude.ai/settings/usage") {
                Diagnostics.log("OAuth 完成後主動載入 Claude 用量頁")
                self.webView.load(URLRequest(url: usageURL))
            }
        }
    }
}

extension ClaudeSessionController: WKNavigationDelegate {
    nonisolated func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        Task { @MainActor in
            Diagnostics.log("Claude WebView 開始導覽: \(Diagnostics.safeURL(webView.url))")
            guard webView === self.webView else { return }
            isLoading = true
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            Diagnostics.log("Claude WebView 導覽完成: \(Diagnostics.safeURL(webView.url))")
            guard webView === self.webView else { return }
            isLoading = false
            currentURL = webView.url
            updateConnectionState(for: webView.url)
            if isConnected, let handler = connectionHandler {
                connectionHandler = nil
                Diagnostics.log("Claude 連結完成，觸發首次用量更新")
                handler()
            }
        }
    }

    nonisolated func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        Task { @MainActor in
            Diagnostics.log("Claude WebView 導覽失敗: \(error.localizedDescription)")
            guard webView === self.webView else { return }
            isLoading = false
            currentURL = webView.url
            updateConnectionState(for: webView.url)
        }
    }

    nonisolated func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        Task { @MainActor in
            Diagnostics.log("Claude WebView 預備導覽失敗: \(error.localizedDescription)")
            guard webView === self.webView else { return }
            isLoading = false
            currentURL = webView.url
            updateConnectionState(for: webView.url)
        }
    }

    private func updateConnectionState(for url: URL?) {
        guard let url, url.host?.hasSuffix("claude.ai") == true else {
            isConnected = false
            return
        }
        isConnected = !url.path.hasPrefix("/login") && !url.path.hasPrefix("/oauth")
    }
}
