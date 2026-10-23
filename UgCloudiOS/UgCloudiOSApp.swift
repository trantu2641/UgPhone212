
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

// MARK: - Save last UgPhone page

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

// MARK: - Main screen

struct UgPhoneScreen: View {
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let availableHeight = geometry.size.height

            let screenWidth = min(
                availableWidth,
                availableHeight * 9.0 / 16.0
            )

            let screenHeight = screenWidth * 16.0 / 9.0

            ZStack {
                Color.black
                    .ignoresSafeArea()

                UgPhoneWebView(isActive: scenePhase == .active)
                    .frame(
                        width: screenWidth,
                        height: screenHeight
                    )
                    .overlay {
                        Rectangle()
                            .stroke(Color.black, lineWidth: 1)
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

        // Preserve cookies and website login data.
        configuration.websiteDataStore = .default()

        // Allow inline playback when supported by UgPhone.
        configuration.allowsInlineMediaPlayback = true

        let contentController = WKUserContentController()

        let optimizationScript = """
        (function() {
            if (window.__ugCloudInstalled) return;
            window.__ugCloudInstalled = true;

            function addOptimizationStyle() {
                if (!document.documentElement) return;

                if (!document.getElementById('ug-cloud-style')) {
                    var style = document.createElement('style');
                    style.id = 'ug-cloud-style';

                    style.textContent = `
                        html, body {
                            overscroll-behavior: none !important;
                        }

                        ::-webkit-scrollbar {
                            width: 0 !important;
                            height: 0 !important;
                        }

                        html {
                            scroll-behavior: auto !important;
                        }
                    `;

                    (document.head || document.documentElement)
                        .appendChild(style);
                }

                var meta = document.querySelector(
                    'meta[name="viewport"]'
                );

                if (!meta && document.head) {
                    meta = document.createElement('meta');
                    meta.name = 'viewport';
                    document.head.appendChild(meta);
                }

                if (meta) {
                    meta.content =
                        'width=device-width, initial-scale=1.0, ' +
                        'maximum-scale=1.0, user-scalable=no';
                }
            }

            addOptimizationStyle();

            // Pause HTML videos when the app enters the background.
            window.__ugPauseVideos = function() {
                document.querySelectorAll('video').forEach(function(video) {
                    video.dataset.ugWasPlaying =
                        (!video.paused && !video.ended) ? '1' : '0';

                    if (!video.paused) {
                        video.pause();
                    }
                });
            };

            // Resume only videos that were playing before backgrounding.
            window.__ugResumeVideos = function() {
                document.querySelectorAll('video').forEach(function(video) {
                    if (video.dataset.ugWasPlaying === '1') {
                        delete video.dataset.ugWasPlaying;

                        var promise = video.play();

                        if (promise && promise.catch) {
                            promise.catch(function() {});
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
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
        )

        configuration.userContentController = contentController

        let webView = WKWebView(
            frame: .zero,
            configuration: configuration
        )

        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        // Keep the original touch events available to the webpage.
        // Disable outer-page scrolling without adding touch interceptors.
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

        // Do not rasterize dynamic content such as video.
        webView.layer.shouldRasterize = false
        webView.scrollView.layer.shouldRasterize = false

        context.coordinator.webView = webView
        context.coordinator.lastActive = isActive

        // Restore the previous UgPhone page without clearing its cookies.
        let startURL = UgPhoneSession.savedURL() ?? homeURL
        var request = URLRequest(url: startURL)
        request.cachePolicy = .useProtocolCachePolicy
        request.timeoutInterval = 60

        webView.load(request)

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

        let script: String

        if isActive {
            script = """
            if (window.__ugResumeVideos) {
                window.__ugResumeVideos();
            }
            """
        } else {
            script = """
            if (window.__ugPauseVideos) {
                window.__ugPauseVideos();
            }
            """
        }

        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    // MARK: Navigation delegate

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

        // Handle links that request a new window in the same WebView.
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil,
               let url = navigationAction.request.url {
                webView.load(URLRequest(url: url))
            }

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
