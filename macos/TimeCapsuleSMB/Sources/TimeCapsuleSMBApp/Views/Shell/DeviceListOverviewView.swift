import SwiftUI

struct DeviceListOverviewView: View {
    let appStore: AppStore
    @ObservedObject var deviceRegistry: DeviceRegistryStore
    @ObservedObject var deviceDiscovery: DeviceDiscoveryStore
    @ObservedObject var backend: BackendClient
    let addDiscoveredDevice: (DiscoveredDevice) -> Void

    private let deviceColumns = [
        GridItem(.adaptive(minimum: 280, maximum: 420), spacing: 14, alignment: .top)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                hero
                savedDevicesSection
                discoverySection
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(
            LinearGradient(
                colors: [BrandPalette.deepNavy.opacity(0.06), .clear],
                startPoint: .topLeading,
                endPoint: .center
            )
        )
    }

    private var hero: some View {
        BrandHero(
            eyebrow: "Control center",
            title: "Your backup network",
            message: AppBrand.shortDescription
        ) {
            HStack(spacing: 22) {
                BrandMetric(
                    value: "\(deviceRegistry.profiles.count)",
                    label: "Managed",
                    systemImage: "externaldrive.fill"
                )
                BrandMetric(
                    value: "\(deviceDiscovery.unsavedDevices.count)",
                    label: "Nearby",
                    systemImage: "antenna.radiowaves.left.and.right"
                )
            }
        }
    }

    @ViewBuilder
    private var savedDevicesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(deviceRegistry.profiles.isEmpty
                    ? L10n.string("overview.empty.title")
                    : L10n.string("overview.saved_devices.title"))
                    .font(.title2.weight(.semibold))
                Spacer()
                Button {
                    appStore.showAddDevice()
                } label: {
                    Label(L10n.string("sidebar.add_airport_device"), systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(BrandPalette.violet)
            }

            if deviceRegistry.profiles.isEmpty {
                BrandPanel {
                    HStack(spacing: 16) {
                        Image(systemName: "externaldrive.badge.plus")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundStyle(BrandPalette.accentGradient)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Connect your first backup appliance")
                                .font(.headline)
                            Text(L10n.string("overview.empty.message"))
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                }
            } else {
                LazyVGrid(columns: deviceColumns, alignment: .leading, spacing: 14) {
                    ForEach(deviceRegistry.profiles) { profile in
                        OverviewDeviceCard(
                            profile: profile,
                            summary: appStore.dashboardSummary(for: profile),
                            lastSeenText: deviceDiscovery.lastSeenText(for: profile)
                        ) {
                            appStore.select(profile)
                        }
                    }
                }
            }
        }
    }

    private var discoverySection: some View {
        BrandPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(L10n.string("overview.discovery.title"), systemImage: "dot.radiowaves.left.and.right")
                        .font(.headline)
                    Spacer()
                    Text(deviceDiscovery.state.title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Button {
                        deviceDiscovery.refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .disabled(backend.isRunning)
                    .help(L10n.string("overview.discovery.refresh"))
                }

                discoveryContent
            }
        }
    }

    @ViewBuilder
    private var discoveryContent: some View {
        switch deviceDiscovery.state {
        case .idle, .waitingForReadiness:
            Text(L10n.string("overview.discovery.waiting"))
                .foregroundStyle(.secondary)
        case .discovering:
            ProgressView(L10n.string("overview.discovery.discovering"))
        case .paused:
            Text(L10n.string("overview.discovery.paused"))
                .foregroundStyle(.secondary)
        case .readinessBlocked:
            Text(L10n.string("overview.discovery.readiness_blocked"))
                .foregroundStyle(.secondary)
        case .failed:
            VStack(alignment: .leading, spacing: 6) {
                Text(deviceDiscovery.error?.message ?? L10n.string("overview.discovery.failed"))
                    .foregroundStyle(.red)
                Button(L10n.string("overview.discovery.refresh")) {
                    deviceDiscovery.refresh()
                }
            }
        case .empty:
            Text(L10n.string("overview.discovery.empty"))
                .foregroundStyle(.secondary)
        case .ready:
            let unsaved = deviceDiscovery.unsavedDevices
            let saved = deviceDiscovery.savedDevices
            if unsaved.isEmpty && saved.isEmpty {
                Text(L10n.string("overview.discovery.empty"))
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(unsaved) { device in
                        OverviewDiscoveredDeviceRow(
                            device: device,
                            statusText: L10n.string("overview.discovery.unsaved"),
                            actionTitle: L10n.string("overview.discovery.add")
                        ) {
                            addDiscoveredDevice(device)
                        }
                        Divider()
                    }
                    ForEach(saved) { device in
                        OverviewDiscoveredDeviceRow(
                            device: device,
                            statusText: L10n.string("overview.discovery.saved"),
                            actionTitle: nil,
                            action: nil
                        )
                        Divider()
                    }
                }
            }
        }
    }
}

private struct OverviewDeviceCard: View {
    let profile: DeviceProfile
    let summary: DeviceDashboardSummary
    let lastSeenText: String?
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            BrandPanel {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(statusColor.opacity(0.12))
                            Image(systemName: "externaldrive.fill")
                                .font(.title2)
                                .foregroundStyle(statusColor)
                        }
                        .frame(width: 46, height: 46)

                        Spacer()

                        Label(summary.displayStatus.title, systemImage: summary.displayStatus.systemImage)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(statusColor)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(statusColor.opacity(0.10), in: Capsule())
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(profile.model ?? profile.displayTarget)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Divider()

                    HStack {
                        Label(
                            profile.addressSummary.isEmpty ? profile.displayTarget : profile.addressSummary,
                            systemImage: "network"
                        )
                        .lineLimit(1)
                        Spacer()
                        if let lastSeenText {
                            Text(lastSeenText)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var statusColor: Color {
        switch summary.displayStatus {
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

private struct OverviewDiscoveredDeviceRow: View {
    let device: DiscoveredDevice
    let statusText: String
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(device.name)
                    .font(.body.weight(.medium))
                HStack(spacing: 6) {
                    Text(device.addressSummary.isEmpty ? device.connectionTarget : device.addressSummary)
                    if !device.discoveryModelText.isEmpty {
                        Text(device.discoveryModelText)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
            }
        }
        .padding(.vertical, 8)
    }
}
