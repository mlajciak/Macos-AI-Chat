import XCTest
@testable import XYZT

final class OpenRouterClientTests: XCTestCase {
    func testProviderLabel() {
        XCTAssertEqual(
            OpenRouterClient.Model.providerLabel(id: "anthropic/claude-3.5-sonnet"),
            "Anthropic"
        )
    }
}
