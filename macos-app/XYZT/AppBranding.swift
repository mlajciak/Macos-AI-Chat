import Foundation

enum AppBranding {
    /// Product name sent to OpenRouter as the app identifier.
    static let name = "XYZT"
    static let openRouterReferrer = "https://xyzt.app"

    /// Headers OpenRouter uses to attribute traffic to this app.
    static func applyOpenRouterHeaders(to request: inout URLRequest) {
        request.setValue(openRouterReferrer, forHTTPHeaderField: "HTTP-Referer")
        request.setValue(name, forHTTPHeaderField: "X-Title")
        request.setValue(name, forHTTPHeaderField: "X-OpenRouter-Title")
    }
}
