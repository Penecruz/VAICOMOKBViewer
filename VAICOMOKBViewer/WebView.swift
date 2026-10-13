import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let url: URL
    let reloadToken: UUID
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading, errorMessage: $errorMessage)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.bounces = false
        webView.allowsBackForwardNavigationGestures = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if context.coordinator.lastReloadToken != reloadToken {
            context.coordinator.lastReloadToken = reloadToken
            let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
            webView.load(request)
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding private var isLoading: Bool
        @Binding private var errorMessage: String?
        var lastReloadToken = UUID()

        init(isLoading: Binding<Bool>, errorMessage: Binding<String?>) {
            _isLoading = isLoading
            _errorMessage = errorMessage
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
            errorMessage = nil
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading = false
            errorMessage = formatErrorMessage(error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            isLoading = false
            errorMessage = formatErrorMessage(error)
        }

        private func formatErrorMessage(_ error: Error) -> String {
            let nsError = error as NSError

            if nsError.domain == NSURLErrorDomain {
                switch nsError.code {
                case NSURLErrorNotConnectedToInternet:
                    return "No network connection. Check Wi-Fi and Local Network permission for this app."
                case NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed:
                    return "Host not found. Check the host value in Connection Settings."
                case NSURLErrorCannotConnectToHost:
                    return "Cannot connect to host. Confirm the VAICOM OKB server is running and reachable from this iPad."
                case NSURLErrorTimedOut:
                    return "Connection timed out. Verify host, port, and firewall settings."
                case NSURLErrorAppTransportSecurityRequiresSecureConnection:
                    return "Connection blocked by iOS security policy (ATS). Use HTTPS or allow this endpoint in app settings."
                default:
                    break
                }
            }

            return nsError.localizedDescription
        }
    }
}
