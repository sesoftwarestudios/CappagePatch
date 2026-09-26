import Foundation

struct LocalCommandResult: Equatable, Sendable {
    let exitCode: Int32
    let standardOutput: String
    let standardError: String
}

protocol LocalCommandRunning: Sendable {
    func run(executableURL: URL, arguments: [String]) async throws -> LocalCommandResult
}

struct FoundationLocalCommandRunner: LocalCommandRunning {
    func run(executableURL: URL, arguments: [String]) async throws -> LocalCommandResult {
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            let standardOutput = Pipe()
            let standardError = Pipe()
            process.executableURL = executableURL
            process.arguments = arguments
            process.standardOutput = standardOutput
            process.standardError = standardError

            try process.run()
            process.waitUntilExit()

            return LocalCommandResult(
                exitCode: process.terminationStatus,
                standardOutput: String(
                    data: standardOutput.fileHandleForReading.readDataToEndOfFile(),
                    encoding: .utf8
                ) ?? "",
                standardError: String(
                    data: standardError.fileHandleForReading.readDataToEndOfFile(),
                    encoding: .utf8
                ) ?? ""
            )
        }.value
    }
}

enum TimeMachineConnectionRecoveryError: Error, Equatable {
    case backupRunning
    case statusUnavailable
    case authorizationCancelled
    case resetFailed(String)
}

protocol TimeMachineConnectionResetting: Sendable {
    func resetConnection() async throws
}

struct TimeMachineConnectionResetter: TimeMachineConnectionResetting {
    typealias Command = @Sendable (URL, [String]) async throws -> LocalCommandResult

    private static let tmutilURL = URL(fileURLWithPath: "/usr/bin/tmutil")
    private static let osascriptURL = URL(fileURLWithPath: "/usr/bin/osascript")
    private static let privilegedResetScript = #"do shell script "if /usr/bin/tmutil status | /usr/bin/grep -Eq 'Running[[:space:]]*=[[:space:]]*1[[:space:]]*;'; then exit 75; fi; /usr/bin/tmutil status | /usr/bin/grep -Eq 'Running[[:space:]]*=[[:space:]]*0[[:space:]]*;' || exit 76; /usr/bin/killall -TERM backupd-helper >/dev/null 2>&1 || true; /usr/bin/killall -KILL backupd >/dev/null 2>&1 || true" with administrator privileges"#

    private let command: Command

    init(runner: any LocalCommandRunning = FoundationLocalCommandRunner()) {
        self.command = { executableURL, arguments in
            try await runner.run(executableURL: executableURL, arguments: arguments)
        }
    }

    init(command: @escaping Command) {
        self.command = command
    }

    func resetConnection() async throws {
        let status: LocalCommandResult
        do {
            status = try await command(Self.tmutilURL, ["status"])
        } catch {
            throw TimeMachineConnectionRecoveryError.statusUnavailable
        }

        guard status.exitCode == 0,
              let backupRunning = Self.backupRunning(from: status.standardOutput) else {
            throw TimeMachineConnectionRecoveryError.statusUnavailable
        }
        guard !backupRunning else {
            throw TimeMachineConnectionRecoveryError.backupRunning
        }

        let reset: LocalCommandResult
        do {
            reset = try await command(Self.osascriptURL, ["-e", Self.privilegedResetScript])
        } catch {
            throw TimeMachineConnectionRecoveryError.resetFailed(error.localizedDescription)
        }

        guard reset.exitCode == 0 else {
            let detail = [reset.standardError, reset.standardOutput]
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if Self.backupStartedDuringAuthorization(detail) {
                throw TimeMachineConnectionRecoveryError.backupRunning
            }
            if Self.statusBecameUnavailableDuringAuthorization(detail) {
                throw TimeMachineConnectionRecoveryError.statusUnavailable
            }
            if Self.authorizationWasCancelled(detail) {
                throw TimeMachineConnectionRecoveryError.authorizationCancelled
            }
            throw TimeMachineConnectionRecoveryError.resetFailed(detail)
        }
    }

    static func backupRunning(from status: String) -> Bool? {
        let pattern = #"\bRunning\s*=\s*([01])\s*;"#
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                in: status,
                range: NSRange(status.startIndex..., in: status)
              ),
              let valueRange = Range(match.range(at: 1), in: status) else {
            return nil
        }
        return status[valueRange] == "1"
    }

    private static func authorizationWasCancelled(_ detail: String) -> Bool {
        let normalized = detail.lowercased()
        return normalized.contains("user canceled")
            || normalized.contains("user cancelled")
            || normalized.contains("(-128)")
    }

    private static func backupStartedDuringAuthorization(_ detail: String) -> Bool {
        detail.contains("(75)") || detail.localizedCaseInsensitiveContains("status 75")
    }

    private static func statusBecameUnavailableDuringAuthorization(_ detail: String) -> Bool {
        detail.contains("(76)") || detail.localizedCaseInsensitiveContains("status 76")
    }
}

enum TimeMachineConnectionRecoveryState: Equatable {
    case idle
    case resetting
    case succeeded
    case failed(TimeMachineConnectionRecoveryError)

    var isResetting: Bool {
        self == .resetting
    }
}

@MainActor
final class TimeMachineConnectionRecoveryStore: ObservableObject {
    @Published private(set) var state: TimeMachineConnectionRecoveryState = .idle

    private let resetter: any TimeMachineConnectionResetting

    init(resetter: any TimeMachineConnectionResetting = TimeMachineConnectionResetter()) {
        self.resetter = resetter
    }

    func reset() {
        guard !state.isResetting else {
            return
        }
        state = .resetting
        Task {
            do {
                try await resetter.resetConnection()
                state = .succeeded
            } catch let error as TimeMachineConnectionRecoveryError {
                state = .failed(error)
            } catch {
                state = .failed(.resetFailed(error.localizedDescription))
            }
        }
    }
}
