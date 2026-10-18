
import SwiftUI
import WebKit
import UIKit

@main
struct UgCloudiOSApp: App {
    var body: some Scene {
        WindowGroup {
            UgPhoneWebApp()
                .preferredColorScheme(.dark)
        }
    }
}

@MainActor
final class UgPhoneWebModel: ObservableObject {
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isLoading = false
    @Published var pageTitle = "UgPhone"
    @Published var errorMessage: String?

    let homeURL = URL(string: "https://www.ugphone.com/")!

    weak var webView: WKWebView?

    func attach(_ view: WKWebView) {
        webView = view
    }

    func updateState(_ view: WKWebView) {
        canGoBack = view.canGoBack
        canGoForward = view.canGoForward
        isLoading = view.isLoading
        pageTitle = view.title ?? "UgPhone"
    }

    func back() {
        webView?.goBack()
    }

    func forward() {
        webView?.goForward()
    }

    func reload() {
        errorMessage = nil
        webView?.reload()
    }

    func openHome() {
        errorMessage = nil
        webView?.load(URLRequest(url: homeURL))
    }

    func openInSafari() {
        UIApplication.shared.open(homeURL)
    }
}

struct UgPhoneWebApp: View {
    @StateObject private var model = UgPhoneWebModel()

    var body: some View {
        VStack(spacing: 0) {
            header

            if model.isLoading {
                ProgressView()
                    .tint(.cyan)
                    .frame(maxWidth: .infinity)
            }

            UgPhoneWebView(model: model)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let message = model.errorMessage {
                VStack(spacing: 8) {
                    Text(message)
                        .font(.footnote)
                        .multilineTextAlignment(.center)

                    Button("Tải lại") {
                        model.reload()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)
                }
                .padding()
            }

            toolbar
        }
        .background(Color(red: 0.035, green: 0.05, blue: 0.08))
        .foregroundStyle(.white)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "cloud.fill")
                .font(.system(size: 25))
                .foregroundStyle(.cyan)

            VStack(alignment: .leading, spacing: 3) {
                Text("UGPHONE")
                    .font(.headline.bold())
                    .tracking(1.5)

                Text(model.pageTitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer()

            Button {
                model.openInSafari()
            } label: {
                Image(systemName: "safari")
                    .font(.title3)
            }
            .accessibilityLabel("Mở UgPhone bằng Safari")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.3))
    }

    private var toolbar: some View {
        HStack {
            toolbarButton(
                "chevron.left",
                enabled: model.canGoBack
            ) {
                model.back()
            }

            Spacer()

            toolbarButton(
                "chevron.right",
                enabled: model.canGoForward
            ) {
                model.forward()
            }

            Spacer()

            toolbarButton("house.fill") {
                model.openHome()
            }

            Spacer()

            toolbarButton(
                model.isLoading ? "xmark" : "arrow.clockwise"
            ) {
                if model.isLoading {
                    model.webView?.stopLoading()
                } else {
                    model.reload()
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 13)
        .background(Color.black.opacity(0.4))
    }

    private func toolbarButton(
        _ symbol: String,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 38, height: 32)
                .contentShape(Rectangle())
        }
        .disabled(!enabled)
        .foregroundStyle(
            enabled ? Color.cyan : Color.gray.opacity(0.4)
        )
    }
}

struct UgPhoneWebView: UIViewRepresentable {
    @ObservedObject var model: UgPhoneWebModel

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()

        // Dùng kho cookie của ứng dụng để lưu phiên đăng nhập web.
        configuration.websiteDataStore = .default()

        configuration.allowsInlineMediaPlayback = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false

        let webView = WKWebView(
            frame: .zero,
            configuration: configuration
        )

        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = UIColor(
            red: 0.035,
            green: 0.05,
            blue: 0.08,
            alpha: 1
        )
        webView.scrollView.backgroundColor = webView.backgroundColor

        model.attach(webView)

        webView.load(URLRequest(url: model.homeURL))

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Không tải lại trang khi SwiftUI cập nhật giao diện.
    }

    final class Coordinator: NSObject,
                            WKNavigationDelegate,
                            WKUIDelegate {
        let model: UgPhoneWebModel

        init(model: UgPhoneWebModel) {
            self.model = model
        }

        func webView(
            _ webView: WKWebView,
            didStartProvisionalNavigation navigation: WKNavigation!
        ) {
            model.errorMessage = nil
            model.updateState(webView)
        }

        func webView(
            _ webView: WKWebView,
            didFinish navigation: WKNavigation!
        ) {
            model.updateState(webView)
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            showError(error, webView: webView)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            showError(error, webView: webView)
        }

        private func showError(
            _ error: Error,
            webView: WKWebView
        ) {
            let nsError = error as NSError

            // Bỏ qua lỗi hủy tải trang do người dùng chuyển trang.
            if nsError.code == NSURLErrorCancelled {
                return
            }

            model.errorMessage =
                "Không tải được UgPhone. Hãy kiểm tra mạng hoặc thử mở bằng Safari."

            model.updateState(webView)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            // Xử lý liên kết target=_blank trong cùng cửa sổ.
            if navigationAction.targetFrame == nil,
               let url = navigationAction.request.url {
                webView.load(URLRequest(url: url))
            }

            return nil
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptAlertPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping () -> Void
        ) {
            let alert = UIAlertController(
                title: "UgPhone",
                message: message,
                preferredStyle: .alert
            )

            alert.addAction(
                UIAlertAction(title: "OK", style: .default) { _ in
                    completionHandler()
                }
            )

            present(alert)
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptConfirmPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (Bool) -> Void
        ) {
            let alert = UIAlertController(
                title: "UgPhone",
                message: message,
                preferredStyle: .alert
            )

            alert.addAction(
                UIAlertAction(title: "Hủy", style: .cancel) { _ in
                    completionHandler(false)
                }
            )

            alert.addAction(
                UIAlertAction(title: "Đồng ý", style: .default) { _ in
                    completionHandler(true)
                }
            )

            present(alert)
        }

        private func present(_ alert: UIAlertController) {
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
                  let root = scene.windows.first(where: \.isKeyWindow)?
                    .rootViewController else {
                return
            }

            var top = root
            while let presented = top.presentedViewController {
                top = presented
            }

            top.present(alert, animated: true)
        }
    }
}
