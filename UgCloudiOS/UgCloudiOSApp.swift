
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

            // Khung dọc 9:16.
            let screenWidth = min(
                availableWidth,
                availableHeight * 9.0 / 16.0
            )

            let screenHeight = screenWidth * 16.0 / 9.0

            ZStack {
                Color.black.ignoresSafeArea()

                UgPhoneWebView(
                    isActive: scenePhase == .active
                )
                .frame(
                    width: screenWidth,
                    height: screenHeight
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

// MARK: - WebView

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

        // Duy trì cookie và dữ liệu đăng nhập.
        configuration.websiteDataStore = .default()
        configuration.allowsInlineMediaPlayback = true

        let contentController = WKUserContentController()

        let optimizationScript = """
        (function() {
            if (window.__ugCloudInstalled) return;
            window.__ugCloudInstalled = true;

            var style = document.createElement('style');

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

            window.__ugPauseMedia = function() {
                document.querySelectorAll('video').forEach(function(v) {
                    v.dataset.ugWasPlaying =
                        (!v.paused && !v.ended) ? '1' : '0';

                    if (!v.paused) {
                        v.pause();
                    }
                });
            };

            window.__ugResumeMedia = function() {
                document.querySelectorAll('video').forEach(function(v) {
                    if (v.dataset.ugWasPlaying === '1') {
                        delete v.dataset.ugWasPlaying;

                        var result = v.play();

                        if (result && result.catch) {
                            result.catch(function() {});
                        }
                    } else {
                        delete v.dataset.ugWasPlaying;
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

        let startURL = UgPhoneSession.savedURL() ?? homeURL
        webView.load(URLRequest(url: startURL))

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

            webView.load(URLRequest(url: url))
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
