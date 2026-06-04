import Foundation

struct DemoFixtures: Decodable {
    let helpText: String
    let faqAnswers: [String]
    let echoTemplate: String
}

enum DemoAgent {
    private static var faqRotation = 0
    private static var cachedFixtures: DemoFixtures?

    static func loadFixtures() -> DemoFixtures {
        if let cached = cachedFixtures { return cached }

        guard let url = Bundle.main.url(forResource: "demo-responses", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(DemoFixtures.self, from: data)
        else {
            return DemoFixtures(
                helpText: "XYZT (demo). Use /help for more.",
                faqAnswers: ["Demo FAQ answer."],
                echoTemplate: "Demo: you said «{text}». Real agent wiring comes later."
            )
        }
        cachedFixtures = decoded
        return decoded
    }

    static func resetFaqRotation() {
        faqRotation = 0
    }

    static func pickFaqAnswer(from answers: [String]) -> String {
        guard !answers.isEmpty else { return "" }
        let answer = answers[faqRotation % answers.count]
        faqRotation += 1
        return answer
    }

    static func replyText(for messages: [ChatMessage], fixtures: DemoFixtures? = nil) -> String {
        let fx = fixtures ?? loadFixtures()
        guard let last = messages.last(where: { $0.role == .user }) else {
            return fx.helpText
        }

        let trimmed = last.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "/help" { return fx.helpText }
        if trimmed.hasSuffix("?") { return pickFaqAnswer(from: fx.faqAnswers) }
        return fx.echoTemplate.replacingOccurrences(of: "{text}", with: trimmed)
    }

    static func reply(for messages: [ChatMessage]) async -> String {
        let delayMs = UInt64.random(in: 600 ... 1200)
        try? await Task.sleep(nanoseconds: delayMs * 1_000_000)
        return replyText(for: messages)
    }
}
