import SwiftUI

private enum OverviewLayout {
    static let actionIconSize: CGFloat = 16
    static let healthRowMinHeight: CGFloat = 64
    static let healthStatusIconSize: CGFloat = 30
    static let healthStatusSymbolSize: CGFloat = 18
    static let healthActionSlotMinWidth: CGFloat = 144
}

struct OverviewTab: View {
    let profile: DeviceProfile
    @ObservedObject var session: DeviceDashboardSession
    @ObservedObject var reachabilityStore: DeviceReachabilityStore

    var body: some View {
        let summary = session.summary(for: profile)
        let presentation = DeviceDashboardOverviewPresentation(
            summary: summary,
            currentCheckupSummary: session.doctorStore.summary,
            reachabilitySnapshot: reachabilityStore.snapshot(for: profile),
            isReachabilityRunning: reachabilityStore.isRunning(profile: profile)
        )

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let warning = presentation.hostWarning {
                    WarningBanner(warning: warning)
                }

                DashboardHeaderView(presentation: presentation.header)

                DashboardPrimaryActionStrip(
                    primaryAction: presentation.primaryAction,
                    isPrimaryActionEnabled: presentation.isPrimaryActionEnabled,
                    secondaryActions: presentation.secondaryActions,
                    isSecondaryActionEnabled: presentation.isEnabled,
                    performPrimary: {
                        session.performPrimaryAction(presentation.primaryAction, profile: profile)
                    },
                    performSecondary: { action in
                        session.performSecondaryAction(action, profile: profile)
                    }
                )

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(presentation.healthSections) { section in
                        DashboardHealthSectionView(section: section, isActionEnabled: presentation.isEnabled) { action in
                            session.performSecondaryAction(action, profile: profile)
                        }
                    }
                }
            }
            .padding(4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct DashboardHeaderView: View {
    let presentation: DeviceDashboardHeaderPresentation

    var body: some View {
        BrandPanel {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(BrandPalette.accentGradient)
                        Image(systemName: "externaldrive.fill")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 64, height: 64)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(presentation.title)
                            .font(.system(size: 26, weight: .semibold, design: .rounded))
                        Label(presentation.connectionTarget, systemImage: "network")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    StatusBadge(status: presentation.status)
                }

                Divider()

                HStack(alignment: .top, spacing: 36) {
                    Label(presentation.lastChecked, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 190, alignment: .leading)
                    SummaryGrid(rows: presentation.rows.map { ($0.label, $0.value) })
                }
            }
        }
    }
}

private struct StatusBadge: View {
    let status: DeviceDisplayStatus

    var body: some View {
        Label {
            Text(status.title)
        } icon: {
            Image(systemName: status.systemImage)
                .frame(width: OverviewLayout.actionIconSize, height: OverviewLayout.actionIconSize)
        }
            .font(.caption.weight(.medium))
            .foregroundStyle(statusColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(statusColor.opacity(0.12))
            .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch status {
        case .healthy:
            return .green
        case .warning, .activationNeeded:
            return BrandPalette.amber
        case .failed, .passwordInvalid, .keychainUnavailable, .offline, .unsupported:
            return .red
        case .installing, .checking, .maintaining, .readyToInstall:
            return BrandPalette.teal
        default:
            return .secondary
        }
    }
}

private struct DashboardPrimaryActionStrip: View {
    let primaryAction: DashboardPrimaryAction
    let isPrimaryActionEnabled: Bool
    let secondaryActions: [DashboardSecondaryAction]
    let isSecondaryActionEnabled: (DashboardSecondaryAction) -> Bool
    let performPrimary: () -> Void
    let performSecondary: (DashboardSecondaryAction) -> Void

    var body: some View {
        BrandPanel {
            HStack(spacing: 8) {
                DashboardPrimaryActionButton(action: primaryAction, perform: performPrimary)
                    .disabled(!isPrimaryActionEnabled)

                ForEach(secondaryActions) { action in
                    Button {
                        performSecondary(action)
                    } label: {
                        DashboardActionLabel(title: action.title, systemImage: action.systemImage)
                    }
                    .disabled(!isSecondaryActionEnabled(action))
                }
            }
        }
    }
}

private struct DashboardPrimaryActionButton: View {
    let action: DashboardPrimaryAction
    let perform: () -> Void

    var body: some View {
        Button(action: perform) {
            DashboardActionLabel(title: action.title, systemImage: action.systemImage)
        }
        .buttonStyle(.borderedProminent)
        .tint(BrandPalette.violet)
    }
}

private struct DashboardActionLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label {
            Text(title)
                .lineLimit(1)
        } icon: {
            Image(systemName: systemImage)
                .frame(width: OverviewLayout.actionIconSize, height: OverviewLayout.actionIconSize)
        }
    }
}

private struct DashboardHealthSectionView: View {
    let section: DashboardHealthSection
    let isActionEnabled: (DashboardSecondaryAction) -> Bool
    let performAction: (DashboardSecondaryAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(section.title)
                .font(.headline)
            ForEach(section.rows) { row in
                HStack(alignment: .top, spacing: 10) {
                    DashboardHealthStatusIcon(status: row.status)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(row.title)
                                .font(.body.weight(.medium))
                            Spacer()
                            DashboardHealthActionSlot(
                                action: row.action,
                                isActionEnabled: isActionEnabled,
                                performAction: performAction
                            )
                        }
                        AnimatedProgressText(message: row.detail, isRunning: row.status == .running)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, minHeight: OverviewLayout.healthRowMinHeight, alignment: .topLeading)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.primary.opacity(0.07))
                }
            }
        }
    }
}

private struct DashboardHealthActionSlot: View {
    let action: DashboardSecondaryAction?
    let isActionEnabled: (DashboardSecondaryAction) -> Bool
    let performAction: (DashboardSecondaryAction) -> Void

    var body: some View {
        Group {
            if let action {
                Button {
                    performAction(action)
                } label: {
                    DashboardActionLabel(title: action.title, systemImage: action.systemImage)
                }
                .controlSize(.small)
                .disabled(!isActionEnabled(action))
            } else {
                // Reserve real button metrics so rows without actions align with rows that have action buttons.
                Button {} label: {
                    DashboardActionLabel(
                        title: DashboardSecondaryAction.runCheckup.title,
                        systemImage: DashboardSecondaryAction.runCheckup.systemImage
                    )
                }
                    .controlSize(.small)
                    .hidden()
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
            }
        }
        .frame(
            minWidth: OverviewLayout.healthActionSlotMinWidth,
            alignment: .trailing
        )
    }
}

private struct DashboardHealthStatusIcon: View {
    let status: DashboardHealthStatus

    var body: some View {
        ZStack {
            Circle()
                .fill(statusColor.opacity(status == .unknown ? 0.10 : 0.14))
            icon
                .foregroundStyle(statusColor)
        }
            .frame(width: OverviewLayout.healthStatusIconSize, height: OverviewLayout.healthStatusIconSize)
            .accessibilityLabel(status.title)
    }

    @ViewBuilder
    private var icon: some View {
        if status == .running {
            OperationTimelineStateIcon(state: .running)
        } else {
            Image(systemName: status.systemImage)
                .font(.system(size: OverviewLayout.healthStatusSymbolSize, weight: .semibold))
        }
    }

    private var statusColor: Color {
        switch status {
        case .unknown:
            return .secondary
        case .good:
            return .green
        case .warning:
            return .orange
        case .failed:
            return .red
        case .running:
            return .accentColor
        }
    }
}
