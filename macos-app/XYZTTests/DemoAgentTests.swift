import XCTest
@testable import XYZT

final class DemoAgentTests: XCTestCase {
    override func setUp() {
        super.setUp()
        DemoAgent.resetFaqRotation()
    }

    func testHelpCommand() {
        let messages = [
            ChatMessage(id: "1", role: .user, content: "/help", createdAt: 0),
        ]
        let fx = DemoFixtures(
            helpText: "Help text",
            faqAnswers: ["FAQ"],
            echoTemplate: "Echo: {text}"
        )
        XCTAssertEqual(DemoAgent.replyText(for: messages, fixtures: fx), "Help text")
    }

    func testFaqRotation() {
        let fx = DemoFixtures(
            helpText: "Help",
            faqAnswers: ["FAQ one", "FAQ two"],
            echoTemplate: "Echo: {text}"
        )
        let q1 = [ChatMessage(id: "1", role: .user, content: "What?", createdAt: 0)]
        let q2 = [ChatMessage(id: "2", role: .user, content: "Why?", createdAt: 0)]
        XCTAssertEqual(DemoAgent.replyText(for: q1, fixtures: fx), "FAQ one")
        XCTAssertEqual(DemoAgent.replyText(for: q2, fixtures: fx), "FAQ two")
    }

    func testEchoTemplate() {
        let fx = DemoFixtures(
            helpText: "Help",
            faqAnswers: [],
            echoTemplate: "Echo: {text}"
        )
        let messages = [
            ChatMessage(id: "1", role: .user, content: "hello", createdAt: 0),
        ]
        XCTAssertEqual(DemoAgent.replyText(for: messages, fixtures: fx), "Echo: hello")
    }
}
