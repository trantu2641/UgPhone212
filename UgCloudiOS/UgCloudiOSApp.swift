
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

struct UgPhoneScreen: View {
    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let availableHeight = geometry.size.height

            // Tỷ lệ màn hình 720 x 1280 = 9:16.
            let screenWidth = min(
                availableWidth,
                availableHeight * 9.0 / 16.0
            )

            let screenHeight = screenWidth * 16.0 / 9.0

            ZStack {
                Color.black
                    .ignoresSafeArea()

                UgPhoneWebView()
                    .frame(
                        width: screenWidth,
                        height: screenHeight
                    )
                    .overlay {
                        Rectangle()
                            .stroke(
                                Color.black,
                                lineWidth: 3
                            )
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
            .background(Color.black)
            .clipped()
        }
        .background(Color.black)
        .ignoresSafeArea()
    }
}

struct UgPhoneWebView: UIViewRepresentable {
    private let url = URL(
        string: "https://www.ugphone.com/"
    )!

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()

        // Lưu phiên đăng nhập và cookie trong ứng dụng.
        configuration.websiteDataStore = .default()

        configuration.allowsInlineMediaPlayback = true
        configuration.preferences.javaScriptEnabled = true

        let webView = WKWebView(
            frame: .zero,
            configuration: configuration
        )

        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        // Không cho cuộn hoặc kéo trang.
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.alwaysBounceVertical = false
        webView.scrollView.alwaysBounceHorizontal = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.pinchGestureRecognizer?.isEnabled = false

        webView.isOpaque = true
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black

        // Tăng nhẹ độ tương phản và độ rực của màn hình.
        webView.layer.filters = [
            CIFilter(name: "CIColorControls")!
        ]

        let appearanceCSS = """
        html {
            color-scheme: dark;
            overflow: hidden !important;
            overscroll-behavior: none !important;
        }

        body {
            overflow: hidden !important;
            overscroll-behavior: none !important;
        }

        ::-webkit-scrollbar {
            display: none !important;
            width: 0 !important;
            height: 0 !important;
        }
        """

        let cssScript = WKUserScript(
            source: """
            (function() {
                var style = document.createElement('style');
                style.textContent = \(Self.jsString(appearanceCSS));
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

                document.documentElement.style.overflow = 'hidden';
                document.body.style.overflow = 'hidden';
            })();
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )

        configuration.userContentController.addUserScript(cssScript)

        webView.load(URLRequest(url: url))

        return webView
    }

    func updateUIView(
        _ webView: WKWebView,
        context: Context
    ) {
        // Không tải lại trang khi giao diện SwiftUI cập nhật.
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private static func jsString(_ value: String) -> String {
        guard let data = try? JSONSerialization.data(
            withJSONObject: [value],
            options: []
        ),
        let json = String(data: data, encoding: .utf8),
        json.count >= 2 else {
            return "\"\""
        }

        return String(json.dropFirst().dropLast())
    }

    final class Coordinator: NSObject,
                            WKNavigationDelegate,
                            WKUIDelegate {
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            // Mở popup trong chính màn hình hiện tại.
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
            // Cho phép trang web điều hướng trong WebView,
            // bao gồm các trang đăng nhập được website sử dụng.
            decisionHandler(.allow)
        }
    }
}
