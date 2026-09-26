import XCTest
@testable import TimeCapsuleSMBApp

final class TimeMachineConnectionRecoveryTests: XCTestCase {
    func testStatusParserRecognizesIdleAndRunningBackups() {
        XCTAssertEqual(
            TimeMachineConnectionResetter.backupRunning(from: "Backup session status:\n{\n    Running = 0;\n}"),
            false
        )
        XCTAssertEqual(
            TimeMachineConnectionResetter.backupRunning(from: "Backup session status:\n{\n    Running = 1;\n}"),
            true
        )
        XCTAssertNil(TimeMachineConnectionResetter.backupRunning(from: "unexpected output"))
    }

    func testResetRefusesToInterruptRunningBackup() async {
        let recorder = CommandRecorder(responses: [
            LocalCommandResult(exitCode: 0, standardOutput: "Running = 1;", standardError: "")
        ])
        let resetter = TimeMachineConnectionResetter { executableURL, arguments in
            try await recorder.run(executableURL: executableURL, arguments: arguments)
        }

        do {
            try await resetter.resetConnection()
            XCTFail("Expected a running-backup error")
        } catch {
            XCTAssertEqual(error as? TimeMachineConnectionRecoveryError, .backupRunning)
        }

        let commands = await recorder.commands
        XCTAssertEqual(commands.count, 1)
        XCTAssertEqual(commands.first?.executableURL.path, "/usr/bin/tmutil")
        XCTAssertEqual(commands.first?.arguments, ["status"])
    }

    func testResetRequestsAdministratorApprovalOnlyAfterIdleCheck() async throws {
        let recorder = CommandRecorder(responses: [
            LocalCommandResult(exitCode: 0, standardOutput: "Running = 0;", standardError: ""),
            LocalCommandResult(exitCode: 0, standardOutput: "", standardError: "")
        ])
        let resetter = TimeMachineConnectionResetter { executableURL, arguments in
            try await recorder.run(executableURL: executableURL, arguments: arguments)
        }

        try await resetter.resetConnection()

        let commands = await recorder.commands
        XCTAssertEqual(commands.count, 2)
        XCTAssertEqual(commands[0].executableURL.path, "/usr/bin/tmutil")
        XCTAssertEqual(commands[1].executableURL.path, "/usr/bin/osascript")
        XCTAssertEqual(commands[1].arguments.first, "-e")
        let script = try XCTUnwrap(commands[1].arguments.last)
        XCTAssertTrue(script.contains("with administrator privileges"))
        XCTAssertTrue(script.contains("tmutil status"))
        XCTAssertTrue(script.contains("exit 75"))
        XCTAssertTrue(script.contains("exit 76"))
        XCTAssertTrue(script.contains("killall -TERM backupd-helper"))
        XCTAssertTrue(script.contains("killall -KILL backupd"))
        XCTAssertFalse(script.localizedCaseInsensitiveContains("sparsebundle"))
        XCTAssertFalse(script.localizedCaseInsensitiveContains("delete"))
    }

    func testResetMapsCancelledAdministratorPrompt() async {
        let recorder = CommandRecorder(responses: [
            LocalCommandResult(exitCode: 0, standardOutput: "Running = 0;", standardError: ""),
            LocalCommandResult(exitCode: 1, standardOutput: "", standardError: "User canceled. (-128)")
        ])
        let resetter = TimeMachineConnectionResetter { executableURL, arguments in
            try await recorder.run(executableURL: executableURL, arguments: arguments)
        }

        do {
            try await resetter.resetConnection()
            XCTFail("Expected cancellation")
        } catch {
            XCTAssertEqual(error as? TimeMachineConnectionRecoveryError, .authorizationCancelled)
        }
    }

    func testResetRefusesWhenBackupStartsDuringAdministratorPrompt() async {
        let recorder = CommandRecorder(responses: [
            LocalCommandResult(exitCode: 0, standardOutput: "Running = 0;", standardError: ""),
            LocalCommandResult(
                exitCode: 1,
                standardOutput: "",
                standardError: "The command exited with a non-zero status. (75)"
            )
        ])
        let resetter = TimeMachineConnectionResetter { executableURL, arguments in
            try await recorder.run(executableURL: executableURL, arguments: arguments)
        }

        do {
            try await resetter.resetConnection()
            XCTFail("Expected a running-backup error")
        } catch {
            XCTAssertEqual(error as? TimeMachineConnectionRecoveryError, .backupRunning)
        }
    }

    func testResetFailsClosedWhenStatusBecomesUnavailableDuringAdministratorPrompt() async {
        let recorder = CommandRecorder(responses: [
            LocalCommandResult(exitCode: 0, standardOutput: "Running = 0;", standardError: ""),
            LocalCommandResult(
                exitCode: 1,
                standardOutput: "",
                standardError: "The command exited with a non-zero status. (76)"
            )
        ])
        let resetter = TimeMachineConnectionResetter { executableURL, arguments in
            try await recorder.run(executableURL: executableURL, arguments: arguments)
        }

        do {
            try await resetter.resetConnection()
            XCTFail("Expected status failure")
        } catch {
            XCTAssertEqual(error as? TimeMachineConnectionRecoveryError, .statusUnavailable)
        }
    }

    func testResetFailsClosedWhenStatusCannotBeParsed() async {
        let recorder = CommandRecorder(responses: [
            LocalCommandResult(exitCode: 0, standardOutput: "not a Time Machine status", standardError: "")
        ])
        let resetter = TimeMachineConnectionResetter { executableURL, arguments in
            try await recorder.run(executableURL: executableURL, arguments: arguments)
        }

        do {
            try await resetter.resetConnection()
            XCTFail("Expected status failure")
        } catch {
            XCTAssertEqual(error as? TimeMachineConnectionRecoveryError, .statusUnavailable)
        }
        let commands = await recorder.commands
        XCTAssertEqual(commands.count, 1)
    }
}

private actor CommandRecorder {
    struct Invocation: Equatable {
        let executableURL: URL
        let arguments: [String]
    }

    private var responses: [LocalCommandResult]
    private(set) var commands: [Invocation] = []

    init(responses: [LocalCommandResult]) {
        self.responses = responses
    }

    func run(executableURL: URL, arguments: [String]) throws -> LocalCommandResult {
        commands.append(Invocation(executableURL: executableURL, arguments: arguments))
        guard !responses.isEmpty else {
            throw CommandRecorderError.missingResponse
        }
        return responses.removeFirst()
    }
}

private enum CommandRecorderError: Error {
    case missingResponse
}
