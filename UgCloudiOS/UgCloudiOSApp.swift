import SwiftUI
import WebKit

@main
struct UgCloudiOSApp: App {
    var body: some Scene {
        WindowGroup {
            UgPhoneScreen()
                .preferredColorScheme(.dark)
                .statusBarHidden(false)
        }
    }
}

// MARK: - Session

enum UgPhoneSession {
    private static let savedURLKey = "ChaGPT.LastURL"

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

        UserDefaults.standard.set(
            url.absoluteString,
            forKey: savedURLKey
        )
    }

    private static func isUgPhoneHost(_ host: String) -> Bool {
        host == "chatgpt.com" ||
        host.hasSuffix(".chatgpt.com")
    }
}

// MARK: - Main Screen

struct UgPhoneScreen: View {
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let availableHeight = geometry.size.height

            // Khung hiển thị dọc.
            let screenWidth = min(
                availableWidth,
                availableHeight * 9.0 / 17.5
            )

            let screenHeight = screenWidth * 17.5 / 9.0

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
                        cornerRadius: 8,
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
        string: "https://chatgpt.com/"
    )!

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()

        // Sử dụng kho dữ liệu mặc định để duy trì cookie.
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
            }

            installStyle();

            // Tạm dừng video khi ứng dụng xuống nền.
            window.__ugPauseMedia = function() {
                document.querySelectorAll('video').forEach(function(video) {
                    video.dataset.ugWasPlaying =
                        (!video.paused && !video.ended) ? '1' : '0';

                    if (!video.paused) {
                        video.pause();
                    }
                });
            };

            // Khôi phục video khi ứng dụng hoạt động trở lại.
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

        // Đảm bảo WebView nhận thao tác chạm.
        webView.isUserInteractionEnabled = true
        webView.scrollView.isUserInteractionEnabled = true
        webView.isMultipleTouchEnabled = true

        // Giữ nguyên khả năng cuộn và thao tác của website.
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.bounces = false
        webView.scrollView.alwaysBounceVertical = false
        webView.scrollView.alwaysBounceHorizontal = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        webView.isOpaque = true
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black

        // Không rasterize trang web động.
        webView.layer.shouldRasterize = false
        webView.scrollView.layer.shouldRasterize = false

        context.coordinator.webView = webView
        context.coordinator.lastActive = isActive

        // Mở URL đã lưu hoặc trang chủ.
        let startURL = UgPhoneSession.savedURL() ?? homeURL

        webView.load(
            URLRequest(
                url: startURL,
                cachePolicy: .useProtocolCachePolicy,
                timeoutInterval: 60
            )
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

    // MARK: - Navigation Coordinator

    final class Coordinator: NSObject,
                             WKNavigationDelegate,
                             WKUIDelegate {

        weak var webView: WKWebView?
        var lastActive: Bool?

        // Lưu URL sau khi tải trang thành công.
        func webView(
            _ webView: WKWebView,
            didFinish navigation: WKNavigation!
        ) {
            guard let url = webView.url else {
                return
            }

            UgPhoneSession.saveURL(url)
        }

        // Mở liên kết target="_blank" trong cùng WebView.
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {

            guard navigationAction.targetFrame == nil else {
                return nil
            }

            guard let url = navigationAction.request.url else {
                return nil
            }

            webView.load(URLRequest(url: url))

            return nil
        }

        // Cho phép điều hướng thông thường.
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            decisionHandler(.allow)
        }

        // Theo dõi lỗi tải trang để thuận tiện kiểm tra.
        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            print(
                "UgCloud WebView navigation error: \(error.localizedDescription)"
            )
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            print(
                "UgCloud WebView loading error: \(error.localizedDescription)"
            )
        }
    }
}
