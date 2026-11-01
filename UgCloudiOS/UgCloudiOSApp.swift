
import SwiftUI
import WebKit
import UIKit

@main
struct UgCloudiOSApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            UgPhoneScreen()
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
                .onChange(of: scenePhase) { phase in
                    if phase == .active {
                        print("UgCloudiOS: App active")
                    }
                }
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

    @State private var diagnosticText = "Đang kiểm tra..."

    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let availableHeight = geometry.size.height

            let screenWidth = min(
                availableWidth,
                availableHeight * 9.0 / 17.5
            )

            let screenHeight = screenWidth * 17.5 / 9.0

            ZStack {
                Color.black
                    .ignoresSafeArea()

                UgPhoneWebView(
                    isActive: scenePhase == .active,
                    diagnosticText: $diagnosticText
                )
                .frame(
                    width: screenWidth,
                    height: screenHeight
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 10,
                        style: .continuous
                    )
                )
                .overlay(alignment: .topLeading) {
                    DiagnosticHUD(text: diagnosticText)
                        .padding(7)
                        .allowsHitTesting(false)
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

// MARK: - Diagnostic HUD

struct DiagnosticHUD: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(
                size: 9,
                weight: .medium,
                design: .monospaced
            ))
            .foregroundColor(.white)
            .padding(7)
            .background(
                Color.black.opacity(0.78)
            )
            .clipShape(
                RoundedRectangle(cornerRadius: 6)
            )
            .lineLimit(10)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - UgPhone WebView

struct UgPhoneWebView: UIViewRepresentable {
    let isActive: Bool

    @Binding var diagnosticText: String

    private let homeURL = URL(
        string: "https://www.ugphone.com/"
    )!

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()

        configuration.websiteDataStore = .default()
        configuration.allowsInlineMediaPlayback = true

        let contentController = WKUserContentController()

        // Nhận thông số chẩn đoán từ JavaScript.
        contentController.add(
            context.coordinator,
            name: "ugDiag"
        )

        let diagnosticScript = """
        (function() {
            if (window.__ugDiagnosticInstalled) return;

            window.__ugDiagnosticInstalled = true;

            var lastVideoFrames = new WeakMap();
            var lastVideoTime = performance.now();

            async function collectDiagnostics() {
                try {
                    var videos = Array.from(
                        document.querySelectorAll('video')
                    );

                    var canvases = Array.from(
                        document.querySelectorAll('canvas')
                    );

                    var now = performance.now();
                    var elapsed = (now - lastVideoTime) / 1000;

                    var videoReports = [];

                    videos.forEach(function(video, index) {
                        var quality = null;

                        try {
                            if (video.getVideoPlaybackQuality) {
                                quality = video.getVideoPlaybackQuality();
                            }
                        } catch(e) {}

                        var totalFrames = quality
                            ? quality.totalVideoFrames
                            : (
                                typeof video.webkitDecodedFrameCount === 'number'
                                ? video.webkitDecodedFrameCount
                                : null
                            );

                        var droppedFrames = quality
                            ? quality.droppedVideoFrames
                            : (
                                typeof video.webkitDroppedFrameCount === 'number'
                                ? video.webkitDroppedFrameCount
                                : null
                            );

                        var previous = lastVideoFrames.get(video);

                        var fps = "--";

                        if (
                            previous &&
                            totalFrames !== null &&
                            elapsed > 0
                        ) {
                            fps = (
                                (totalFrames - previous) / elapsed
                            ).toFixed(1);
                        }

                        if (totalFrames !== null) {
                            lastVideoFrames.set(video, totalFrames);
                        }

                        videoReports.push({
                            index: index,
                            width: video.videoWidth,
                            height: video.videoHeight,
                            paused: video.paused,
                            readyState: video.readyState,
                            fps: fps,
                            totalFrames: totalFrames,
                            droppedFrames: droppedFrames
                        });
                    });

                    lastVideoTime = now;

                    var canvasReports = canvases.map(function(canvas) {
                        return {
                            width: canvas.width,
                            height: canvas.height
                        };
                    });

                    var rtcReports = [];

                    if (window.RTCPeerConnection) {
                        var connections =
                            window.__ugPeerConnections || [];

                        connections.forEach(function(pc) {
                            if (!pc || !pc.getStats) return;
                        });
                    }

                    // Kiểm tra các kết nối WebRTC có thể truy cập
                    // từ JavaScript của trang.
                    var peers = window.__ugPeerConnections || [];

                    for (var i = 0; i < peers.length; i++) {
                        try {
                            var stats = await peers[i].getStats();

                            stats.forEach(function(item) {
                                if (
                                    item.type === 'inbound-rtp' &&
                                    (item.kind === 'video' ||
                                     item.mediaType === 'video')
                                ) {
                                    rtcReports.push({
                                        fps: item.framesPerSecond || null,
                                        decoded: item.framesDecoded || 0,
                                        received: item.framesReceived || 0,
                                        lost: item.packetsLost || 0,
                                        jitter: item.jitter || 0
                                    });
                                }
                            });
                        } catch(e) {}
                    }

                    var report = [];

                    report.push(
                        'VIDEO: ' + videos.length
                    );

                    if (videoReports.length > 0) {
                        videoReports.forEach(function(v, index) {
                            report.push(
                                'V' + index + ': ' +
                                v.width + 'x' + v.height +
                                ' | FPS ' + v.fps +
                                ' | ' + (v.paused ? 'PAUSED' : 'PLAYING')
                            );

                            report.push(
                                'Frames: ' + v.totalFrames +
                                ' | Dropped: ' + v.droppedFrames
                            );
                        });
                    } else {
                        report.push('VIDEO: No HTML video detected');
                    }

                    report.push(
                        'CANVAS: ' + canvases.length
                    );

                    canvasReports.slice(0, 3).forEach(function(c, i) {
                        report.push(
                            'C' + i + ': ' +
                            c.width + 'x' + c.height
                        );
                    });

                    if (rtcReports.length > 0) {
                        rtcReports.forEach(function(r, i) {
                            report.push(
                                'RTC' + i +
                                ': FPS ' + (r.fps || '--') +
                                ' | Decoded ' + r.decoded +
                                ' | Lost ' + r.lost
                            );
                        });
                    } else {
                        report.push('WEBRTC: No accessible stats');
                    }

                    report.push(
                        'TIME: ' + new Date().toLocaleTimeString()
                    );

                    window.webkit.messageHandlers.ugDiag.postMessage({
                        report: report.join('\\n')
                    });

                } catch(error) {
                    window.webkit.messageHandlers.ugDiag.postMessage({
                        report: 'Diagnostic error: ' + error.message
                    });
                }
            }

            window.__ugCollectDiagnostics = collectDiagnostics;

            // Kiểm tra mỗi 3 giây, không can thiệp video.
            window.__ugDiagnosticTimer = setInterval(
                collectDiagnostics,
                3000
            );

            collectDiagnostics();
        })();
        """

        contentController.addUserScript(
            WKUserScript(
                source: diagnosticScript,
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

        context.coordinator.onDiagnostic = { report in
            DispatchQueue.main.async {
                diagnosticText = report
            }
        }

        context.coordinator.lastActive = isActive

        let startURL = UgPhoneSession.savedURL() ?? homeURL

        webView.load(
            URLRequest(url: startURL)
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

    // MARK: - Coordinator

    final class Coordinator: NSObject,
                             WKNavigationDelegate,
                             WKUIDelegate,
                             WKScriptMessageHandler {

        weak var webView: WKWebView?

        var lastActive: Bool?

        var onDiagnostic: ((String) -> Void)?

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard
                message.name == "ugDiag",
                let body = message.body as? [String: Any],
                let report = body["report"] as? String
            else {
                return
            }

            onDiagnostic?(report)
        }

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

            webView.load(
                URLRequest(url: url)
            )

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
