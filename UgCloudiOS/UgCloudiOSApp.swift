
import SwiftUI
import WebKit

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
                    isActive: scenePhase == .active
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

// MARK: - UgPhone WebView

struct UgPhoneWebView: UIViewRepresentable {
    let isActive: Bool

    private let homeURL = URL(
        string: "https://www.ugphone.com/"
    )!

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()

        // Giữ cookie và phiên đăng nhập.
        configuration.websiteDataStore = .default()
        configuration.allowsInlineMediaPlayback = true

        let contentController = WKUserContentController()

        // MARK: JavaScript FPS and image optimization

        let optimizationScript = """
        (function() {
            if (window.__ugCloudInstalled) return;
            window.__ugCloudInstalled = true;

            // =========================================
            // FPS LIMITER: 30 FPS
            // =========================================

            (function() {
                var nativeRAF =
                    window.requestAnimationFrame.bind(window);

                var nativeCancelRAF =
                    window.cancelAnimationFrame.bind(window);

                var targetFPS = 30;
                var frameDuration = 1000 / targetFPS;

                var nextID = 1;
                var callbacks = new Map();

                var scheduled = false;
                var lastFrameTime = 0;

                function scheduleFrame() {
                    if (scheduled || callbacks.size === 0) {
                        return;
                    }

                    scheduled = true;

                    nativeRAF(function(timestamp) {
                        scheduled = false;

                        var shouldRender =
                            lastFrameTime === 0 ||
                            timestamp - lastFrameTime >= frameDuration;

                        if (shouldRender) {
                            lastFrameTime = timestamp;

                            var currentCallbacks =
                                Array.from(callbacks.entries());

                            callbacks.clear();

                            currentCallbacks.forEach(function(entry) {
                                var callback = entry[1];

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
                    nativeCancelRAF(id);
                };

                window.__ugFPSController = {
                    targetFPS: 30,
                    frameDuration: frameDuration
                };
            })();

            // =========================================
            // COLOR OPTIMIZATION
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

                    canvas {
                        filter:
                            saturate(1.13)
                            contrast(1.17);
                    }
                `;

                (document.head || document.documentElement)
                    .appendChild(style);

                var viewport = document.querySelector(
                    'meta[name="viewport"]'
                );

                if (!viewport && document.head) {
                    viewport = document.createElement('meta');
                    viewport.name = 'viewport';
                    document.head.appendChild(viewport);
                }

                if (viewport) {
                    viewport.content =
                        'width=device-width, initial-scale=1.0, ' +
                        'maximum-scale=1.0, user-scalable=no';
                }
            }

            installStyle();

            // =========================================
            // BACKGROUND VIDEO MANAGEMENT
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
        })();
        """

        contentController.addUserScript(
            WKUserScript(
                source: optimizationScript,
                injectionTime: .atDocumentStart,
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

        // Giữ khả năng điều khiển cảm ứng.
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
        context.coordinator.lastActive = isActive

        // Khôi phục trang gần nhất.
        let startURL = UgPhoneSession.savedURL() ?? homeURL

        webView.load(
            URLRequest(url: startURL)
        )

        return webView
    }

    // MARK: - App lifecycle

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

    // MARK: - Navigation

    final class Coordinator: NSObject,
                             WKNavigationDelegate,
                             WKUIDelegate {

        weak var webView: WKWebView?
        var lastActive: Bool?

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
