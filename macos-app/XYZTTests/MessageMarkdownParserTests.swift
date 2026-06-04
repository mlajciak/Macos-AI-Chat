import XCTest
@testable import XYZT

final class MessageMarkdownParserTests: XCTestCase {
    func testParsesHeadingParagraphAndList() {
        let blocks = MessageMarkdownParser.parse("""
        # Title

        A **bold** line.

        - one
        - two
        """)
        XCTAssertEqual(blocks.count, 3)
        XCTAssertEqual(blocks[0], .heading(level: 1, text: "Title"))
        XCTAssertEqual(blocks[1], .paragraph("A **bold** line."))
        XCTAssertEqual(blocks[2], .bulletList(["one", "two"]))
    }

    func testParsesCodeFence() {
        let blocks = MessageMarkdownParser.parse("""
        before

        ```swift
        let x = 1
        ```

        after
        """)
        XCTAssertEqual(blocks.count, 3)
        XCTAssertEqual(blocks[0], .paragraph("before"))
        if case let .codeBlock(language, code) = blocks[1] {
            XCTAssertEqual(language, "swift")
            XCTAssertTrue(code.contains("let x = 1"))
        } else {
            XCTFail("expected code block")
        }
        XCTAssertEqual(blocks[2], .paragraph("after"))
    }

    func testParsesOrderedList() {
        let blocks = MessageMarkdownParser.parse("""
        1. first
        2. second
        """)
        XCTAssertEqual(blocks, [.orderedList(["first", "second"])])
    }
}
