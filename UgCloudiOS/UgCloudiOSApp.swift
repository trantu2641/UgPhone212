
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

// MARK: - Screen

struct UgPhoneScreen: View {
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let availableHeight = geometry.size.height

            // Khung 9:16, tương ứng màn hình dọc 720 x 1280.
            let screenWidth = min(
                availableWidth,
                availableHeight * 9.0 / 16.0
            )

            let screenHeight = screenWidth * 16.0 / 9.0

            ZStack {
                Color.black.ignoresSafeArea()

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

        // Giữ cookie, đăng nhập và dữ liệu website giữa các lần mở app.
        configuration.websiteDataStore = .default()

        // Giữ video phát trực tiếp bên trong trang nếu website hỗ trợ.
        configuration.allowsInlineMediaPlayback = true

        let contentController = WKUserContentController()

        let optimizationScript = """
        (function() {
            if (window.__ugCloudOptimizationInstalled) return;
            window.__ugCloudOptimizationInstalled = true;

            function installStyle() {
                if (!document.documentElement) return;

                if (!document.getElementById('ug-cloud-optimization')) {
                    var style = document.createElement('style');
                    style.id = 'ug-cloud-optimization';

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

                        @media (prefers-reduced-motion: reduce) {
                            *,
                            *::before,
                            *::after {
                                scroll-behavior: auto !important;
                            }
                        }
                    `;

                    (document.head || document.documentElement)
                        .appendChild(style);
                }

                var meta = document.querySelector(
                    'meta[name="viewport"]'
                );

                if (!meta) {
                    meta = document.createElement('meta');
                    meta.name = 'viewport';

                    if (document.head) {
                        document.head.appendChild(meta);
                    }
                }

                if (meta) {
                    meta.content =
                        'width=device-width, initial-scale=1.0, ' +
                        'maximum-scale=1.0, user-scalable=no';
                }
            }

            installStyle();

            // Ghi nhớ video nào đang phát trước khi app xuống nền.
            window.__ugPauseMedia = function() {
                document.querySelectorAll('video').forEach(function(v) {
                    v.dataset.ugWasPlaying =
                        (!v.paused && !v.ended) ? '1' : '0';

                    if (!v.paused) {
                        v.pause();
                    }
                });
            };

            // Chỉ thử khôi phục video vốn đang phát trước đó.
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

            // Bổ sung style nếu website dựng lại phần head.
            var observer = new MutationObserver(function() {
                if (!document.getElementById(
                    'ug-cloud-optimization'
                )) {
                    installStyle();
                }
            });

            if (document.documentElement) {
                observer.observe(document.documentElement, {
                    childList: true,
                    subtree: true
                });
            }
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

        // Không rasterize toàn bộ trang động, tránh tạo thêm chi phí
        // bộ nhớ và cập nhật hình ảnh cho nội dung cloud phone.
        webView.layer.shouldRasterize = false
        webView.scrollView.layer.shouldRasterize = false

        context.coordinator.webView = webView

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

        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    // MARK: Navigation and window handling

    final class Coordinator: NSObject,
                             WKNavigationDelegate,
                             WKUIDelegate {
        weak var webView: WKWebView?
        var lastActive: Bool?

        func webView(
            _ webView: WKWebView,
            didFinish navigation: WKNavigation!
        ) {
            guard let currentURL = webView.url else {
                return
            }

            UgPhoneSession.saveURL(currentURL)
        }

        // Xử lý liên kết mở cửa sổ mới ngay trong cùng WebView.
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
