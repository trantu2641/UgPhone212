
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

            // Giữ khung hiển thị dọc 9:16.
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
                // Bo 4 góc, bán kính 6 points.
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 6,
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

        // Giữ cookie và phiên đăng nhập website.
        configuration.websiteDataStore = .default()
        configuration.allowsInlineMediaPlayback = true

        let contentController = WKUserContentController()

        let optimizationScript = """
        (function() {
            if (window.__ugCloudInstalled) return;
            window.__ugCloudInstalled = true;

            function installStyle() {
                if (!document.documentElement) return;

                if (!document.getElementById('ug-cloud-style')) {
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
                    `;

                    (document.head || document.documentElement)
                        .appendChild(style);
                }

                var viewport = document.querySelector(
                    'meta[name="viewport"]'
                );

                if (!viewport && document.head) {
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

            // Tạm dừng video HTML khi app chuyển xuống nền.
            window.__ugPauseMedia = function() {
                document.querySelectorAll('video').forEach(function(video) {
                    video.dataset.ugWasPlaying =
                        (!video.paused && !video.ended) ? '1' : '0';

                    if (!video.paused) {
                        video.pause();
                    }
                });
            };

            // Khôi phục video nếu trước đó đang phát.
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

        // Không cuộn trang ngoài khung cloud phone.
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

        // Không rasterize toàn bộ trang động.
        webView.layer.shouldRasterize = false
        webView.scrollView.layer.shouldRasterize = false

        context.coordinator.webView = webView
        context.coordinator.lastActive = isActive

        // Mở trang đã lưu hoặc trang chủ nếu chưa có.
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

        // Mở liên kết cửa sổ mới trong cùng WebView.
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
