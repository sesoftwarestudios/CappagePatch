import SwiftUI

struct InstallTab: View {
    let profile: DeviceProfile
    @ObservedObject var session: DeviceDashboardSession
    @ObservedObject var operationCoordinator: OperationCoordinator
    let appSettings: AppSettings
    let showDiagnostics: () -> Void
    let diagnosticsText: () -> String
    @StateObject private var timeMachineRecovery = TimeMachineConnectionRecoveryStore()
    @State private var showsTimeMachineRecoveryConfirmation = false

    var body: some View {
        let store = session.deployStore
        let summary = session.summary(for: profile)
        let presentation = InstallWorkflowPresentation(
            state: store.state,
            plan: store.plan,
            result: store.result,
            error: store.error,
            events: store.events,
            currentStage: store.currentStage,
            plannedOptions: store.plannedOptions,
            profile: profile,
            hostWarning: HostCompatibilityPolicy.warning(enabled: appSettings.timeMachineWarningsEnabled),
            isCheckupRunning: summary.displayStatus == .checking
        )
        let progress = InstallProgressPresentation(state: store.state, currentStage: store.currentStage)
        let isDeviceBusy = operationCoordinator.isDeviceBusy(profile)

        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    InstallHeaderView(presentation: presentation)

                    ForEach(presentation.notices, id: \.self) { notice in
                        Label(notice, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }

                    if !presentation.actions.isEmpty {
                        HStack {
                            ForEach(presentation.actions) { action in
                                InstallActionButton(action: action) {
                                    session.performInstallAction(action, profile: profile, showDiagnostics: showDiagnostics)
                                }
                                .disabled(isDisabled(action, store: store, isDeviceBusy: isDeviceBusy))
                            }
                        }
                    }

                    if let timeline = presentation.timeline {
                        InstallTimelineView(presentation: timeline)
                    }

                    if let error = presentation.error {
                        ErrorRecoveryView(
                            error: error,
                            guidance: presentation.failureGuidance,
                            diagnosticsText: diagnosticsText
                        ) { action in
                            handleRecovery(action: action, error: error)
                        }
                    }

                    if let plan = presentation.plan {
                        InstallPlanView(presentation: plan)
                    }

                    if let completion = presentation.completion {
                        InstallCompletionView(
                            presentation: completion,
                            isDisabled: { isDisabled($0, store: store, isDeviceBusy: isDeviceBusy) }
                        ) { action in
                            session.performInstallAction(action, profile: profile, showDiagnostics: showDiagnostics)
                        }

                        TimeMachineConnectionRecoveryView(
                            state: timeMachineRecovery.state,
                            reset: {
                                showsTimeMachineRecoveryConfirmation = true
                            }
                        )
                    }

                    InstallExecutionOptionsView(store: store, isDeviceBusy: isDeviceBusy)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let progress {
                BlockingProgressOverlay(progress: progress, allowsBackgroundInteraction: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .alert(
            L10n.string("time_machine_recovery.confirm.title"),
            isPresented: $showsTimeMachineRecoveryConfirmation
        ) {
            Button(L10n.string("action.cancel"), role: .cancel) {}
            Button(L10n.string("time_machine_recovery.confirm.action")) {
                timeMachineRecovery.reset()
            }
        } message: {
            Text(L10n.string("time_machine_recovery.confirm.message"))
        }
    }

    private func handleRecovery(action: RecoveryAction, error: BackendErrorViewModel) {
        if action.kind == .diagnostics {
            showDiagnostics()
            return
        }
        _ = session.handleRecoveryAction(action, error: error, profile: profile)
    }

    private func isDisabled(_ action: InstallUserAction, store: DeployWorkflowStore, isDeviceBusy: Bool) -> Bool {
        !InstallActionAvailabilityPolicy.isEnabled(action, store: store, isDeviceBusy: isDeviceBusy)
    }
}

private struct TimeMachineConnectionRecoveryView: View {
    let state: TimeMachineConnectionRecoveryState
    let reset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.string("time_machine_recovery.title"))
                .font(.headline)
            Text(L10n.string("time_machine_recovery.description"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let statusPresentation {
                Label(statusPresentation.message, systemImage: statusPresentation.systemImage)
                    .font(.callout)
                    .foregroundStyle(statusPresentation.color)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: reset) {
                if state.isResetting {
                    ProgressView()
                        .controlSize(.small)
                    Text(L10n.string("time_machine_recovery.action.resetting"))
                } else {
                    Label(
                        L10n.string("time_machine_recovery.action.reset"),
                        systemImage: "arrow.clockwise.circle"
                    )
                }
            }
            .buttonStyle(.bordered)
            .disabled(state.isResetting)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var statusPresentation: (message: String, systemImage: String, color: Color)? {
        switch state {
        case .idle:
            return nil
        case .resetting:
            return (
                L10n.string("time_machine_recovery.status.resetting"),
                "clock",
                .secondary
            )
        case .succeeded:
            return (
                L10n.string("time_machine_recovery.status.succeeded"),
                "checkmark.circle.fill",
                .green
            )
        case .failed(let error):
            return (
                message(for: error),
                "exclamationmark.triangle.fill",
                .yellow
            )
        }
    }

    private func message(for error: TimeMachineConnectionRecoveryError) -> String {
        switch error {
        case .backupRunning:
            return L10n.string("time_machine_recovery.error.backup_running")
        case .statusUnavailable:
            return L10n.string("time_machine_recovery.error.status_unavailable")
        case .authorizationCancelled:
            return L10n.string("time_machine_recovery.error.cancelled")
        case .resetFailed(let detail):
            let trimmed = detail.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty
                ? L10n.string("time_machine_recovery.error.failed")
                : L10n.format("time_machine_recovery.error.failed_detail", trimmed)
        }
    }
}

private struct InstallHeaderView: View {
    let presentation: InstallWorkflowPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(presentation.title)
                    .font(.title2.weight(.semibold))
                Spacer()
                Text(presentation.stateTitle)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.quaternary)
                    .clipShape(Capsule())
            }
            Text(presentation.statusMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

private struct InstallActionButton: View {
    let action: InstallUserAction
    let perform: () -> Void

    var body: some View {
        if action == .installUpdate {
            Button(action: perform) {
                Label(action.title, systemImage: action.systemImage)
            }
            .buttonStyle(.borderedProminent)
        } else {
            Button(action: perform) {
                Label(action.title, systemImage: action.systemImage)
            }
            .buttonStyle(.bordered)
        }
    }
}

private struct InstallPlanView: View {
    let presentation: InstallPlanPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(presentation.title)
                .font(.headline)

            ForEach(presentation.sections) { section in
                VStack(alignment: .leading, spacing: 6) {
                    Text(section.title)
                        .font(.subheadline.weight(.medium))
                    SummaryGrid(rows: section.rows.map { ($0.label, $0.value) })
                }
            }

            ForEach(presentation.warnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.yellow)
            }
        }
    }
}

private struct InstallTimelineView: View {
    let presentation: InstallTimelinePresentation

    var body: some View {
        OperationTimelineListView(
            title: L10n.string("install.timeline.title"),
            emptyMessage: L10n.string("install.timeline.waiting"),
            items: presentation.items
        )
    }
}

private struct InstallCompletionView: View {
    let presentation: InstallCompletionPresentation
    let isDisabled: (InstallUserAction) -> Bool
    let performAction: (InstallUserAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(presentation.title)
                .font(.headline)
            SummaryGrid(rows: presentation.rows.map { ($0.label, $0.value) })
            ForEach(presentation.warnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.yellow)
            }
            HStack {
                ForEach(presentation.actions) { action in
                    Button {
                        performAction(action)
                    } label: {
                        Label(action.title, systemImage: action.systemImage)
                    }
                    .disabled(isDisabled(action))
                }
            }
        }
    }
}

private struct InstallExecutionOptionsView: View {
    @ObservedObject var store: DeployWorkflowStore
    let isDeviceBusy: Bool

    var body: some View {
        DashboardDisclosureSection(title: L10n.string("install.advanced_options")) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Toggle(L10n.string("toggle.no_reboot"), isOn: $store.noReboot)
                        .disabled(!allowsNoReboot)
                    Toggle(L10n.string("toggle.no_wait"), isOn: noWaitBinding)
                        .disabled(!allowsNoWait)
                }
                GridRow {
                    Text(L10n.string("install.advanced_options.no_wait_note"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .gridCellColumns(2)
                }
                GridRow {
                    Toggle(L10n.string("toggle.enable_rsync"), isOn: $store.rsyncEnabled)
                        .gridCellColumns(2)
                }
                GridRow {
                    Text(L10n.string("install.advanced_options.rsync_note"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .gridCellColumns(2)
                }
                GridRow {
                    Text(L10n.string("field.mount_wait"))
                        .foregroundStyle(.secondary)
                    TextField(L10n.string("field.mount_wait"), text: $store.mountWait)
                        .frame(width: 150)
                }
            }
        }
        .disabled(store.isBusy || isDeviceBusy)
    }

    private var allowsNoReboot: Bool {
        RebootExecutionOptionPolicy.allowsNoReboot(noWait: store.noWait)
    }

    private var allowsNoWait: Bool {
        RebootExecutionOptionPolicy.allowsNoWait(noReboot: store.noReboot)
    }

    private var noWaitBinding: Binding<Bool> {
        Binding {
            allowsNoWait ? store.noWait : false
        } set: { value in
            if allowsNoWait {
                store.noWait = value
            } else {
                store.noWait = false
            }
        }
    }
}
