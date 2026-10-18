
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

        UserDefaults.standard.set(
            url.absoluteString,
            forKey: savedURLKey
        )
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

            // Portrait ratio: 720 x 1280
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

// MARK: - UgPhone website

struct UgPhoneWebView: UIViewRepresentable {
    private let homeURL = URL(
        string: "https://www.ugphone.com/"
    )!

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()

        // Keep website cookies and login session between launches.
        configuration.websiteDataStore = .default()
        configuration.allowsInlineMediaPlayback = true

        // Configure JavaScript before creating the web view.
        let contentController = WKUserContentController()

        let css = """
        html {
            overflow: hidden !important;
            overscroll-behavior: none !important;
        }

        body {
            overflow: hidden !important;
            overscroll-behavior: none !important;
            contrast: 1;
            filter: contrast(1.05) saturate(1.04);
        }

        ::-webkit-scrollbar {
            display: none !important;
            width: 0 !important;
            height: 0 !important;
        }
        """

        let cssData = try? JSONSerialization.data(
            withJSONObject: [css],
            options: []
        )

        let cssJSON = cssData.flatMap {
            String(data: $0, encoding: .utf8)
        } ?? "[\"\"]"

        let scriptSource = """
        (function() {
            try {
                var css = \(cssJSON);
                var style = document.createElement('style');
                style.textContent = css[0];
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

        let script = WKUserScript(
            source: scriptSource,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )

        contentController.addUserScript(script)
        configuration.userContentController = contentController

        let webView = WKWebView(
            frame: .zero,
            configuration: configuration
        )

        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        // Disable page scrolling, bouncing and zoom gestures.
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

        context.coordinator.webView = webView

        // Open the last saved UgPhone page, if available.
        let startURL = UgPhoneSession.savedURL() ?? homeURL
        webView.load(URLRequest(url: startURL))

        return webView
    }

    func updateUIView(
        _ webView: WKWebView,
        context: Context
    ) {
        // Do not reload the page during SwiftUI updates.
    }

    // MARK: - Navigation and session handling

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

            // Save the current UgPhone page for next launch.
            UgPhoneSession.saveURL(currentURL)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            // Keep links that request a new window inside this web view.
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
