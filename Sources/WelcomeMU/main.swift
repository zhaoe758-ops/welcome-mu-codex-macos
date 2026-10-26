import AppKit
import QuartzCore
import WebKit

private struct Settings: Decodable {
    var codexPath: String?
    var codexBundleIdentifier: String?

    enum CodingKeys: String, CodingKey {
        case codexPath = "CodexPath"
        case codexBundleIdentifier = "CodexBundleIdentifier"
    }
}

private final class SplashWindowController: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private let webView: WKWebView
    private let window: NSWindow
    private var watchdog: Timer?
    private var isFinishing = false
    private let previewOnly: Bool
    private let terminateOnFinish: Bool
    var onFinished: (() -> Void)?

    init(previewOnly: Bool, terminateOnFinish: Bool = true) {
        self.previewOnly = previewOnly
        self.terminateOnFinish = terminateOnFinish

        let configuration = WKWebViewConfiguration()
        configuration.suppressesIncrementalRendering = false
        let contentController = WKUserContentController()
        let bridge = """
        (() => {
          const skip = () => window.webkit.messageHandlers.boot.postMessage('skip');
          addEventListener('keydown', event => { if (event.key === 'Escape') skip(); });
          addEventListener('click', skip);
        })();
        """
        contentController.addUserScript(WKUserScript(source: bridge, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        configuration.userContentController = contentController

        self.webView = WKWebView(frame: .zero, configuration: configuration)
        self.webView.wantsLayer = true
        self.webView.layer?.backgroundColor = NSColor.white.cgColor
        self.webView.setValue(false, forKey: "drawsBackground")

        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        self.window = NSWindow(contentRect: screenFrame, styleMask: .borderless, backing: .buffered, defer: false)
        super.init()

        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isOpaque = true
        window.backgroundColor = .white
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.contentView = webView
        webView.frame = window.contentView?.bounds ?? .zero
        webView.autoresizingMask = [.width, .height]
        webView.navigationDelegate = self
        window.alphaValue = 0
        contentController.add(self, name: "boot")
    }

    func show() {
        guard let animationDirectory = Bundle.module.resourceURL,
              let html = Bundle.module.url(forResource: "preview", withExtension: "html") else {
            finish()
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        webView.loadFileURL(html, allowingReadAccessTo: animationDirectory)
        watchdog = Timer.scheduledTimer(withTimeInterval: 25, repeats: false) { [weak self] _ in self?.finish() }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "boot", let value = message.body as? String else { return }
        if value == "ready" {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.9
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().alphaValue = 1
            }
        } else if value == "complete" || value == "skip" {
            finish()
        }
    }

    private func finish() {
        guard !isFinishing else { return }
        isFinishing = true
        watchdog?.invalidate()
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.8
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self else { return }
            self.window.orderOut(nil)
            self.onFinished?()
            if self.terminateOnFinish { NSApp.terminate(nil) }
        })
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    private var splash: SplashWindowController?
    private var previewOnly = false
    private var monitorMode = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        previewOnly = CommandLine.arguments.contains("--preview")
        monitorMode = CommandLine.arguments.contains("--monitor")
        if monitorMode {
            observeCodexLaunches()
            return
        }
        if !previewOnly && launchCodexIfNeeded() == .alreadyRunning {
            NSApp.terminate(nil)
            return
        }
        splash = SplashWindowController(previewOnly: previewOnly)
        splash?.show()
    }

    private func observeCodexLaunches() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  application.bundleIdentifier == "com.openai.codex" else { return }
            self?.showSplashForLaunchedCodex()
        }
    }

    private func showSplashForLaunchedCodex() {
        guard splash == nil else { return }
        let controller = SplashWindowController(previewOnly: false, terminateOnFinish: false)
        controller.onFinished = { [weak self, weak controller] in
            guard let self, self.splash === controller else { return }
            self.splash = nil
        }
        splash = controller
        controller.show()
    }

    private enum LaunchResult { case launched, alreadyRunning }

    private func launchCodexIfNeeded() -> LaunchResult {
        let settings = loadSettings()
        let candidate = codexURL(settings: settings)
        let running = NSWorkspace.shared.runningApplications.first { app in
            guard !app.isTerminated else { return false }
            if let id = settings.codexBundleIdentifier, app.bundleIdentifier == id { return true }
            return ["com.openai.codex", "com.openai.ChatGPT"].contains(app.bundleIdentifier) ||
                ["Codex", "ChatGPT"].contains(app.localizedName)
        }
        if let running {
            running.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            return .alreadyRunning
        }
        guard let candidate else { return .launched }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        NSWorkspace.shared.openApplication(at: candidate, configuration: configuration, completionHandler: nil)
        return .launched
    }

    private func loadSettings() -> Settings {
        let path = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/WelcomeMU/settings.json")
        guard let data = try? Data(contentsOf: path), let settings = try? JSONDecoder().decode(Settings.self, from: data) else {
            return Settings(codexPath: nil, codexBundleIdentifier: "com.openai.codex")
        }
        return settings
    }

    private func codexURL(settings: Settings) -> URL? {
        if let path = settings.codexPath, !path.isEmpty, FileManager.default.fileExists(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        if let id = settings.codexBundleIdentifier,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) { return url }
        for name in ["Codex.app", "ChatGPT.app"] {
            let url = URL(fileURLWithPath: "/Applications/").appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return nil
    }
}

let app = NSApplication.shared
private let delegate = AppDelegate()
app.delegate = delegate
app.run()
