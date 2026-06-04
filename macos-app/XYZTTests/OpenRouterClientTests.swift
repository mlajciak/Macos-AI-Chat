import XCTest
@testable import XYZT

final class OpenRouterClientTests: XCTestCase {
    func testProviderLabel() {
        XCTAssertEqual(
            OpenRouterClient.Model.providerLabel(id: "anthropic/claude-3.5-sonnet"),
            "Anthropic"
        )
    }

    func testChunkFromSseLineParsesReasoningDetails() {
        let payloadData = try! JSONSerialization.data(withJSONObject: [
            "choices": [[
                "delta": [
                    "reasoning_details": [
                        ["type": "reasoning.text", "text": "Step one. "],
                        ["type": "reasoning.text", "text": "Step two."],
                    ],
                ],
            ]],
        ])
        let line = "data: \(String(data: payloadData, encoding: .utf8)!)"
        let chunk = OpenRouterClient.chunkFromSseLine(line)
        XCTAssertEqual(chunk?.reasoning, "Step one. Step two.")
        XCTAssertNil(chunk?.content)
    }

    func testChunkFromSseLineParsesContentAndReasoning() {
        let payloadData = try! JSONSerialization.data(withJSONObject: [
            "choices": [["delta": [
                "content": "Hello",
                "reasoning": "Hmm",
            ]]],
        ])
        let line = "data: \(String(data: payloadData, encoding: .utf8)!)"
        let chunk = OpenRouterClient.chunkFromSseLine(line)
        XCTAssertEqual(chunk?.content, "Hello")
        XCTAssertEqual(chunk?.reasoning, "Hmm")
    }

    func testDeltaFromSseLineDecodesUTF8Content() {
        let content = "I\u{2019}m sorry. Let\u{2019}s try again! \u{1F600}"
        let payloadData = try! JSONSerialization.data(withJSONObject: [
            "choices": [["delta": ["content": content]]],
        ])
        let payload = String(data: payloadData, encoding: .utf8)!
        let line = "data: \(payload)"
        XCTAssertEqual(OpenRouterClient.deltaFromSseLine(line), content)
    }

    func testUTF8LineBytesDecodeAsSingleString() {
        let content = "caf\u{00E9}"
        let line = "data: {\"choices\":[{\"delta\":{\"content\":\"\(content)\"}}]}"
        let lineBytes = (line + "\n").data(using: .utf8)!

        var lineData = Data()
        var decodedLine: String?
        for byte in lineBytes {
            if byte == UInt8(ascii: "\n") {
                decodedLine = String(data: lineData, encoding: .utf8)
                break
            }
            lineData.append(byte)
        }
        XCTAssertEqual(OpenRouterClient.deltaFromSseLine(decodedLine ?? ""), content)
    }
}
