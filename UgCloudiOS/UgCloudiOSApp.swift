import SwiftUI
import WebKit

// MARK: - App

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

// MARK: - Main Screen

struct UgPhoneScreen: View {
    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let availableHeight = geometry.size.height

            // Khung dọc tỷ lệ 9:17.5.
            let screenWidth = min(
                availableWidth,
                availableHeight * 9.0 / 17.5
            )

            let screenHeight = screenWidth * 17.5 / 9.0

            ZStack {
                Color.black
                    .ignoresSafeArea()

                UgPhoneWebView()
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

// MARK: - ChatGPT WebView

struct UgPhoneWebView: UIViewRepresentable {

    private let homeURL = URL(
        string: "https://chatgpt.com/"
    )!

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()

        // Duy trì cookie đăng nhập.
        configuration.websiteDataStore = .default()

        // Hỗ trợ nội dung đa phương tiện.
        configuration.allowsInlineMediaPlayback = true

        // CSS giữ thanh điều hướng ở trên cùng.
        let navigationStyle = """
        (function() {
            if (window.__ugNavigationStyleInstalled) return;
            window.__ugNavigationStyleInstalled = true;

            var style = document.createElement('style');

            style.id = 'ug-chatgpt-navigation-style';

            style.textContent = `
                html {
                    background: #000 !important;
                }

                body {
                    background: #000 !important;
                }

                /*
                 Giữ thanh điều hướng chính ở trên cùng.
                 Không áp dụng position: fixed cho mọi phần tử
                 để tránh làm hỏng bố cục trang.
                */
                header,
                [data-testid="conversation-header"],
                [data-testid="mobile-header"] {
                    position: sticky !important;
                    top: 0 !important;
                    z-index: 9999 !important;
                    background-color: #000 !important;
                }

                /*
                 Giữ thanh điều hướng nằm phía trên nội dung
                 trong trường hợp trang sử dụng header sticky.
                */
                header a,
                header button {
                    -webkit-tap-highlight-color: transparent;
                }

                ::-webkit-scrollbar {
                    width: 0 !important;
                    height: 0 !important;
                }
            `;

            (document.head || document.documentElement)
                .appendChild(style);
        })();
        """

        let userScript = WKUserScript(
            source: navigationStyle,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )

        configuration.userContentController.addUserScript(
            userScript
        )

        let webView = WKWebView(
            frame: .zero,
            configuration: configuration
        )

        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        // Cảm ứng.
        webView.isUserInteractionEnabled = true
        webView.isMultipleTouchEnabled = true

        // Cuộn trang.
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.bounces = true
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic

        // Nền tối.
        webView.isOpaque = true
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black

        // Tải ChatGPT.
        webView.load(
            URLRequest(
                url: homeURL,
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
        // Không tải lại trang khi SwiftUI cập nhật.
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject,
                             WKNavigationDelegate,
                             WKUIDelegate {

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

            webView.load(
                URLRequest(url: url)
            )

            return nil
        }

        // Cho phép điều hướng.
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            decisionHandler(.allow)
        }

        // Lỗi điều hướng.
        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            print(
                "ChatGPT navigation error: \(error.localizedDescription)"
            )
        }

        // Lỗi tải trang.
        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            print(
                "ChatGPT loading error: \(error.localizedDescription)"
            )
        }
    }
}
