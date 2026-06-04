import Foundation

struct WorkspaceCommandRequest: Equatable {
    let command: String
    let reason: String
}

struct WorkspaceCommandResult: Equatable {
    let stdout: String
    let stderr: String
    let exitCode: Int32
}

enum WorkspaceSandbox {
    private static let destructivePatterns: [String] = [
        #"rm\s+-rf\s+/"#,
        #"rm\s+-rf\s+~"#,
        #"mkfs\."#,
        #"dd\s+if="#,
        #">\s*/dev/"#,
        #"sudo\s+"#,
        #"chmod\s+-R\s+777\s+/"#,
    ]

    static func isDestructive(_ command: String) -> Bool {
        let normalized = command.lowercased()
        return destructivePatterns.contains { pattern in
            (try? NSRegularExpression(pattern: pattern, options: .caseInsensitive))
                .flatMap { regex in
                    regex.firstMatch(in: normalized, range: NSRange(normalized.startIndex..., in: normalized)) != nil
                } ?? false
        }
    }

    static func isReadOnly(_ command: String) -> Bool {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let prefixes = [
            "ls ", "ls\n", "pwd", "cat ", "head ", "tail ", "wc ", "file ",
            "git status", "git diff", "git log", "git branch", "find ", "grep ",
            "swift --version", "node --version", "python --version",
        ]
        if trimmed == "ls" || trimmed == "pwd" { return true }
        return prefixes.contains { trimmed.hasPrefix($0) || trimmed == String($0.dropLast()) }
    }

    static func needsApproval(
        command: String,
        mode: CommandApprovalMode,
        sandboxEnabled: Bool
    ) -> Bool {
        if isDestructive(command) { return true }
        switch mode {
        case .alwaysAsk:
            return true
        case .askDestructive:
            return !isReadOnly(command)
        case .autoApprove:
            _ = sandboxEnabled
            return false
        }
    }

    static func run(
        request: WorkspaceCommandRequest,
        workingDirectory: URL,
        sandboxEnabled: Bool
    ) async -> WorkspaceCommandResult {
        await Task.detached(priority: .userInitiated) {
            runSync(request: request, workingDirectory: workingDirectory, sandboxEnabled: sandboxEnabled)
        }.value
    }

    private static func runSync(
        request: WorkspaceCommandRequest,
        workingDirectory: URL,
        sandboxEnabled: Bool
    ) -> WorkspaceCommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", request.command]
        process.currentDirectoryURL = workingDirectory

        var environment = ProcessInfo.processInfo.environment
        environment["XYZT_SANDBOX"] = sandboxEnabled ? "1" : "0"
        if sandboxEnabled {
            environment["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin"
        }
        process.environment = environment

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
            process.waitUntilExit()
            let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            return WorkspaceCommandResult(
                stdout: stdout,
                stderr: stderr,
                exitCode: process.terminationStatus
            )
        } catch {
            return WorkspaceCommandResult(
                stdout: "",
                stderr: error.localizedDescription,
                exitCode: 127
            )
        }
    }
}
