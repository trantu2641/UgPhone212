
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

// MARK: - Remember last UgPhone page

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
    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let availableHeight = geometry.size.height

            // Giữ nguyên tỷ lệ 720 x 1280.
            let screenWidth = min(
                availableWidth,
                availableHeight * 9.0 / 16.0
            )
            let screenHeight = screenWidth * 16.0 / 9.0

            ZStack {
                Color.black.ignoresSafeArea()

                UgPhoneWebView()
                    .frame(
                        width: screenWidth,
                        height: screenHeight
                    )
                    .overlay {
                        Rectangle()
                            .stroke(Color.black, lineWidth: 3)
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

        // CSS nhẹ: tăng nhẹ độ tương phản và độ bão hòa màu.
        // Không dùng filter blur hoặc hiệu ứng làm nhòe.
        let contentController = WKUserContentController()

        let scriptSource = """
        (function() {
            try {
                var style = document.createElement('style');

                style.textContent = `
                    html, body {
                        overflow: hidden !important;
                        overscroll-behavior: none !important;
                    }

                    body {
                        filter: none !important;
                    }

                    img, video, canvas {
                        image-rendering: auto;
                    }

                    ::-webkit-scrollbar {
                        display: none !important;
                        width: 0 !important;
                        height: 0 !important;
                    }
                `;

                (document.head || document.documentElement)
                    .appendChild(style);

                var meta = document.querySelector(
                    'meta[name="viewport"]'
                );

                if (!meta) {
                    meta = document.createElement('meta');
                    meta.name = 'viewport';
                    document.head.appendChild(meta);
                }

                meta.content =
                    'width=device-width, initial-scale=1.0, ' +
                    'maximum-scale=1.0, user-scalable=no';
            } catch (e) {}
        })();
        """

        contentController.addUserScript(
            WKUserScript(
                source: scriptSource,
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

        // Giữ cảm ứng, tắt cuộn và phóng to trang.
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.alwaysBounceVertical = false
        webView.scrollView.alwaysBounceHorizontal = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.pinchGestureRecognizer?.isEnabled = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        // Giữ kết xuất gốc, không biến WebView thành ảnh bitmap.
        webView.isOpaque = true
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.layer.shouldRasterize = false
        webView.scrollView.layer.shouldRasterize = false

        context.coordinator.webView = webView

        // Mở trang UgPhone gần nhất đã lưu.
        let startURL = UgPhoneSession.savedURL() ?? homeURL
        webView.load(URLRequest(url: startURL))

        return webView
    }

    func updateUIView(
        _ webView: WKWebView,
        context: Context
    ) {
        // Không tải lại trang khi SwiftUI cập nhật.
    }

    // MARK: - Navigation and session

    final class Coordinator: NSObject,
                            WKNavigationDelegate,
                            WKUIDelegate {
        weak var webView: WKWebView?

        func webView(
            _ webView: WKWebView,
            didFinish navigation: WKNavigation!
        ) {
            guard let currentURL = webView.url else {
                return
            }

            UgPhoneSession.saveURL(currentURL)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            // Mở liên kết trong cùng cửa sổ.
            if navigationAction.targetFrame == nil,
               let url = navigationAction.request.url {
                webView.load(URLRequest(url: url))
            }

            return nil
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (
                WKNavigationActionPolicy
            ) -> Void
        ) {
            decisionHandler(.allow)
        }
    }
}
