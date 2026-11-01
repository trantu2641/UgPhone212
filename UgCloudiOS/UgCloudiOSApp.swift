
import SwiftUI
import WebKit
import UIKit

@main
struct UgCloudiOSApp: App {
    var body: some Scene {
        WindowGroup {
            UgPhoneScreen()
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
        }
    }
}

// MARK: - Session

enum UgPhoneSession {
    private static let savedURLKey = "UgPhone.LastURL"

    static func savedURL() -> URL? {
        guard
            let value = UserDefaults.standard.string(forKey: savedURLKey),
            let url = URL(string: value),
            let host = url.host,
            isUgPhoneHost(host)
        else {
            return nil
        }

        return url
    }

    static func saveURL(_ url: URL) {
        guard let host = url.host, isUgPhoneHost(host) else {
            return
        }

        UserDefaults.standard.set(url.absoluteString, forKey: savedURLKey)
    }

    private static func isUgPhoneHost(_ host: String) -> Bool {
        host == "ugphone.com" || host.hasSuffix(".ugphone.com")
    }
}

// MARK: - Main Screen

struct UgPhoneScreen: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var diagnosticText = "Đang kiểm tra UgPhone..."

    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let availableHeight = geometry.size.height

            // Giữ nguyên tỷ lệ 9:17.5.
            let screenWidth = min(
                availableWidth,
                availableHeight * 9.0 / 16.0
            )

            let screenHeight = screenWidth * 16.0 / 9.0

            ZStack {
                Color.black
                    .ignoresSafeArea()

                UgPhoneWebView(
                    isActive: scenePhase == .active,
                    diagnosticText: $diagnosticText
                )
                .frame(
                    width: screenWidth,
                    height: screenHeight
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 10,
                        style: .continuous
                    )
                )
                .overlay(alignment: .topLeading) {
                    DiagnosticHUD(text: diagnosticText)
                        .padding(7)
                        .allowsHitTesting(false)
                }
                .position(
                    x: availableWidth / 2,
                    y: availableHeight / 2
                )
            }
            .frame(
                width: availableWidth,
                height: availableHeight
            )
            .clipped()
        }
        .background(Color.black)
        .ignoresSafeArea()
    }
}

// MARK: - Diagnostic HUD

struct DiagnosticHUD: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(
                size: 9,
                weight: .medium,
                design: .monospaced
            ))
            .foregroundColor(.white)
            .padding(7)
            .background(Color.black.opacity(0.82))
            .clipShape(
                RoundedRectangle(cornerRadius: 8)
            )
            .lineLimit(12)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - UgPhone WebView

struct UgPhoneWebView: UIViewRepresentable {
    let isActive: Bool

    @Binding var diagnosticText: String

    private let homeURL = URL(
        string: "https://www.ugphone.com/"
    )!

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()

        configuration.websiteDataStore = .default()
        configuration.allowsInlineMediaPlayback = true

        let contentController = WKUserContentController()

        contentController.add(
            context.coordinator,
            name: "ugDiag"
        )

        // MARK: Rendering and color optimization

        let optimizationScript = """
        (function() {
            if (window.__ugOptimizationInstalled) return;
            window.__ugOptimizationInstalled = true;

            // =========================================
            // 1. TARGET 40 FPS FOR PAGE ANIMATION CALLBACKS
            // =========================================

            (function() {
                var nativeRAF = window.requestAnimationFrame.bind(window);
                var nativeCancelRAF = window.cancelAnimationFrame.bind(window);

                var frameDuration = 1000 / 40;
                var lastFrameTime = 0;
                var nextID = 1;
                var callbacks = new Map();
                var scheduled = false;

                function scheduleFrame() {
                    if (scheduled || callbacks.size === 0) return;

                    scheduled = true;

                    nativeRAF(function(timestamp) {
                        scheduled = false;

                        if (
                            lastFrameTime === 0 ||
                            timestamp - lastFrameTime >= frameDuration - 0.5
                        ) {
                            lastFrameTime = timestamp;

                            var ids = Array.from(callbacks.keys());

                            ids.forEach(function(id) {
                                var callback = callbacks.get(id);

                                if (!callback) return;

                                callbacks.delete(id);

                                try {
                                    callback(timestamp);
                                } catch(error) {
                                    setTimeout(function() {
                                        throw error;
                                    }, 0);
                                }
                            });
                        }

                        scheduleFrame();
                    });
                }

                window.requestAnimationFrame = function(callback) {
                    var id = nextID++;

                    callbacks.set(id, callback);
                    scheduleFrame();

                    return id;
                };

                window.cancelAnimationFrame = function(id) {
                    callbacks.delete(id);
                };

                window.__ugFPSController = {
                    target: 40,
                    enabled: true
                };
            })();

            // =========================================
            // 2. COLOR AND CONTRAST
            // =========================================

            function installStyle() {
                if (!document.documentElement) return;

                if (document.getElementById('ug-cloud-style')) {
                    return;
                }

                var style = document.createElement('style');
                style.id = 'ug-cloud-style';

                style.textContent = `
                    html {
                        overscroll-behavior: none !important;
                        scroll-behavior: auto !important;
                    }

                    body {
                        overscroll-behavior: none !important;
                    }

                    ::-webkit-scrollbar {
                        width: 0 !important;
                        height: 0 !important;
                    }

                    /*
                       Tăng nhẹ màu sắc và tương phản.
                       Áp dụng lên Canvas của cloud phone.
                    */

                    canvas {
                        filter:
                            saturate(1.12)
                            contrast(1.08)
                            brightness(1.02);
                    }
                `;

                (document.head || document.documentElement)
                    .appendChild(style);

                var viewport = document.querySelector(
                    'meta[name="viewport"]'
                );

                if (!viewport) {
                    viewport = document.createElement('meta');
                    viewport.name = 'viewport';

                    if (document.head) {
                        document.head.appendChild(viewport);
                    }
                }

                if (viewport) {
                    viewport.content =
                        'width=device-width, initial-scale=1.0, ' +
                        'maximum-scale=1.0, user-scalable=no';
                }
            }

            installStyle();

            // =========================================
            // 3. PAUSE VIDEO WHEN APP GOES BACKGROUND
            // =========================================

            window.__ugPauseMedia = function() {
                document.querySelectorAll('video').forEach(function(video) {
                    video.dataset.ugWasPlaying =
                        (!video.paused && !video.ended) ? '1' : '0';

                    if (!video.paused) {
                        video.pause();
                    }
                });
            };

            window.__ugResumeMedia = function() {
                document.querySelectorAll('video').forEach(function(video) {
                    if (video.dataset.ugWasPlaying === '1') {
                        delete video.dataset.ugWasPlaying;

                        var result = video.play();

                        if (result && result.catch) {
                            result.catch(function() {});
                        }
                    } else {
                        delete video.dataset.ugWasPlaying;
                    }
                });
            };

            window.__ugApplyStyle = installStyle;
        })();
        """

        contentController.addUserScript(
            WKUserScript(
                source: optimizationScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )

        // MARK: Diagnostic script

        let diagnosticScript = """
        (function() {
            if (window.__ugDiagnosticInstalled) return;
            window.__ugDiagnosticInstalled = true;

            var lastVideoFrames = new WeakMap();
            var lastVideoTime = performance.now();

            async function collectDiagnostics() {
                try {
                    var videos = Array.from(
                        document.querySelectorAll('video')
                    );

                    var canvases = Array.from(
                        document.querySelectorAll('canvas')
                    );

                    var now = performance.now();
                    var elapsed = (now - lastVideoTime) / 1000;

                    var reports = [];

                    videos.forEach(function(video, index) {
                        var quality = null;

                        try {
                            if (video.getVideoPlaybackQuality) {
                                quality = video.getVideoPlaybackQuality();
                            }
                        } catch(e) {}

                        var totalFrames = quality
                            ? quality.totalVideoFrames
                            : (
                                typeof video.webkitDecodedFrameCount === 'number'
                                ? video.webkitDecodedFrameCount
                                : null
                            );

                        var droppedFrames = quality
                            ? quality.droppedVideoFrames
                            : (
                                typeof video.webkitDroppedFrameCount === 'number'
                                ? video.webkitDroppedFrameCount
                                : null
                            );

                        var previous = lastVideoFrames.get(video);
                        var fps = "--";

                        if (
                            previous !== undefined &&
                            totalFrames !== null &&
                            elapsed > 0
                        ) {
                            fps = (
                                (totalFrames - previous) / elapsed
                            ).toFixed(1);
                        }

                        if (totalFrames !== null) {
                            lastVideoFrames.set(video, totalFrames);
                        }

                        reports.push({
                            width: video.videoWidth,
                            height: video.videoHeight,
                            paused: video.paused,
                            fps: fps,
                            frames: totalFrames,
                            dropped: droppedFrames
                        });
                    });

                    lastVideoTime = now;

                    var lines = [];

                    lines.push('TARGET FPS: 40');
                    lines.push('VIDEO: ' + videos.length);

                    reports.forEach(function(v, i) {
                        lines.push(
                            'V' + i + ': ' +
                            v.width + 'x' + v.height +
                            ' | FPS: ' + v.fps
                        );

                        lines.push(
                            'Frames: ' + v.frames +
                            ' | Dropped: ' + v.dropped
                        );
                    });

                    if (videos.length === 0) {
                        lines.push('VIDEO: No HTML video detected');
                    }

                    lines.push('CANVAS: ' + canvases.length);

                    canvases.slice(0, 3).forEach(function(c, i) {
                        lines.push(
                            'C' + i + ': ' +
                            c.width + 'x' + c.height
                        );
                    });

                    lines.push(
                        'RAF LIMIT: ' +
                        (window.__ugFPSController
                            ? window.__ugFPSController.target
                            : '--')
                    );

                    lines.push(
                        'TIME: ' + new Date().toLocaleTimeString()
                    );

                    window.webkit.messageHandlers.ugDiag.postMessage({
                        report: lines.join('\\n')
                    });

                } catch(error) {
                    window.webkit.messageHandlers.ugDiag.postMessage({
                        report: 'Diagnostic error: ' + error.message
                    });
                }
            }

            window.__ugCollectDiagnostics = collectDiagnostics;

            window.__ugDiagnosticTimer = setInterval(
                collectDiagnostics,
                3000
            );

            collectDiagnostics();
        })();
        """

        contentController.addUserScript(
            WKUserScript(
                source: diagnosticScript,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
        )

        configuration.userContentController = contentController

        // MARK: Create WebView

        let webView = WKWebView(
            frame: .zero,
            configuration: configuration
        )

        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.alwaysBounceVertical = false
        webView.scrollView.alwaysBounceHorizontal = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.pinchGestureRecognizer?.isEnabled = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        webView.isOpaque = true
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black

        webView.layer.shouldRasterize = false
        webView.scrollView.layer.shouldRasterize = false

        context.coordinator.webView = webView

        context.coordinator.onDiagnostic = { report in
            DispatchQueue.main.async {
                diagnosticText = report
            }
        }

        context.coordinator.lastActive = isActive

        let startURL = UgPhoneSession.savedURL() ?? homeURL

        webView.load(
            URLRequest(url: startURL)
        )

        return webView
    }

    func updateUIView(
        _ webView: WKWebView,
        context: Context
    ) {
        guard context.coordinator.lastActive != isActive else {
            return
        }

        context.coordinator.lastActive = isActive

        let script = isActive
            ? "window.__ugResumeMedia && window.__ugResumeMedia();"
            : "window.__ugPauseMedia && window.__ugPauseMedia();"

        webView.evaluateJavaScript(
            script,
            completionHandler: nil
        )
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject,
                             WKNavigationDelegate,
                             WKUIDelegate,
                             WKScriptMessageHandler {

        weak var webView: WKWebView?

        var lastActive: Bool?

        var onDiagnostic: ((String) -> Void)?

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard
                message.name == "ugDiag",
                let body = message.body as? [String: Any],
                let report = body["report"] as? String
            else {
                return
            }

            onDiagnostic?(report)
        }

        func webView(
            _ webView: WKWebView,
            didFinish navigation: WKNavigation!
        ) {
            guard let url = webView.url else {
                return
            }

            UgPhoneSession.saveURL(url)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            guard
                navigationAction.targetFrame == nil,
                let url = navigationAction.request.url
            else {
                return nil
            }

            webView.load(
                URLRequest(url: url)
            )

            return nil
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            decisionHandler(.allow)
        }
    }
}
