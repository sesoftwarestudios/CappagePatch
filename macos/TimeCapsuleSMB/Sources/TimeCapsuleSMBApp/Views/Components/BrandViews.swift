import SwiftUI

enum BrandPalette {
    static let teal = Color(red: 0.10, green: 0.78, blue: 0.82)
    static let violet = Color(red: 0.45, green: 0.38, blue: 0.96)
    static let amber = Color(red: 1.00, green: 0.67, blue: 0.24)
    static let deepNavy = Color(red: 0.035, green: 0.075, blue: 0.15)

    static let accentGradient = LinearGradient(
        colors: [teal, violet],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct BrandMark: View {
    var size: CGFloat = 36

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(BrandPalette.accentGradient)
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: size * 0.49, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: BrandPalette.teal.opacity(0.24), radius: size * 0.18, y: size * 0.08)
        .accessibilityHidden(true)
    }
}

struct BrandSidebarHeader: View {
    var body: some View {
        HStack(spacing: 11) {
            BrandMark(size: 38)
            VStack(alignment: .leading, spacing: 1) {
                Text(AppBrand.displayName)
                    .font(.headline.weight(.semibold))
                Text("BACKUP BRIDGE")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }
}

struct BrandHero<Accessory: View>: View {
    let eyebrow: String
    let title: String
    let message: String
    @ViewBuilder let accessory: () -> Accessory

    init(
        eyebrow: String,
        title: String,
        message: String,
        @ViewBuilder accessory: @escaping () -> Accessory
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.message = message
        self.accessory = accessory
    }

    var body: some View {
        HStack(alignment: .center, spacing: 28) {
            VStack(alignment: .leading, spacing: 8) {
                Text(eyebrow.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(BrandPalette.teal)
                Text(title)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 560, alignment: .leading)
            }
            Spacer(minLength: 12)
            accessory()
        }
        .padding(24)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.regularMaterial)
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [BrandPalette.teal.opacity(0.12), BrandPalette.violet.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(.white.opacity(0.10))
            }
        }
    }
}

struct BrandMetric: View {
    let value: String
    let label: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(BrandPalette.accentGradient)
            Text(value)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 88, alignment: .leading)
    }
}

struct BrandPanel<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(16)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.primary.opacity(0.07))
            }
    }
}

struct RecommendedSettingsCard: View {
    let isRecommended: Bool
    let actionTitle: String
    let apply: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "checkmark.shield.fill")
                .font(.title2)
                .foregroundStyle(isRecommended ? .green : BrandPalette.amber)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text("Recommended for modern macOS")
                        .font(.headline)
                    Text(isRecommended ? "ACTIVE" : "CUSTOM")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(isRecommended ? .green : BrandPalette.amber)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background((isRecommended ? Color.green : BrandPalette.amber).opacity(0.12), in: Capsule())
                }

                Text("Uses SMB2/SMB3, keeps AFP and unauthenticated rsync off, preserves Time Machine metadata, and leaves experimental or reduced-security options disabled.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Button(actionTitle, action: apply)
                .buttonStyle(.bordered)
                .disabled(isRecommended)
        }
        .padding(14)
        .background((isRecommended ? Color.green : BrandPalette.amber).opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder((isRecommended ? Color.green : BrandPalette.amber).opacity(0.22))
        }
    }
}

struct LegacyMacCompatibilityCard: View {
    let isEnabled: Bool
    let followUpText: String
    let apply: (Bool) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "desktopcomputer")
                .font(.title2)
                .foregroundStyle(isEnabled ? BrandPalette.teal : .secondary)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text("Older Mac Time Machine")
                        .font(.headline)
                    Text(isEnabled ? "AFP DISCOVERY ON" : "MODERN ONLY")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(isEnabled ? BrandPalette.teal : .secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background((isEnabled ? BrandPalette.teal : Color.secondary).opacity(0.12), in: Capsule())
                }

                Text("Enable this when Snow Leopard through El Capitan Macs must use this Time Capsule for Time Machine. It adds the original AFP service alongside SMB2/SMB3; newer Macs continue using the modern SMB destination. SMB1 stays disabled.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(followUpText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Button(isEnabled ? "Use Modern Only" : "Enable Older Mac Support") {
                apply(!isEnabled)
            }
            .buttonStyle(.bordered)
        }
        .padding(14)
        .background(BrandPalette.teal.opacity(isEnabled ? 0.09 : 0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(BrandPalette.teal.opacity(isEnabled ? 0.28 : 0.12))
        }
    }
}

struct AdvancedSettingsGuidance: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label("Safe defaults", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Keep AFP discovery off unless an older Mac needs Time Machine. Keep rsync, Any SMB Protocol, forced signing/encryption disablement, vfs_aio_fork, and debug logging off unless you are solving a specific problem.")
            Text("Keep Netatalk metadata and NBNS on for backup metadata and network discovery compatibility. The recommended button restores all timing values too.")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.vertical, 4)
    }
}

struct LegalNoticesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                BrandMark(size: 54)
                VStack(alignment: .leading, spacing: 2) {
                    Text(AppBrand.displayName)
                        .font(.title2.weight(.semibold))
                    Text("Version \(AppBrand.version)")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }

            Text(AppBrand.tagline)
                .font(.headline)

            VStack(alignment: .leading, spacing: 3) {
                Text("Created and maintained by \(AppBrand.organizationName).")
                Text("\(AppBrand.creatorName) — \(AppBrand.creatorTitle)")
            }
            .font(.callout.weight(.medium))

            Group {
                Text("Independent GPLv3 fork")
                    .font(.headline)
                Text("CappagePatch is an independent modified distribution of \(AppBrand.upstreamProjectName). It is not endorsed by or affiliated with the upstream project or Apple Inc.")
                Text("The upstream project and history remain credited to James Chang and the TimeCapsuleSMB contributors. CappagePatch interface, diagnostics, and compatibility changes are copyright 2026 SE Software Studios.")
                Text("This program is free software under GPL-3.0-only and comes without warranty. Recipients may share and modify it under that license, and the corresponding source must remain available with distributed builds.")
            }
            .font(.callout)

            HStack {
                Link("CappagePatch on GitHub", destination: AppBrand.projectURL)
                Link("View upstream project", destination: AppBrand.upstreamProjectURL)
                Link("Read GPLv3", destination: AppBrand.licenseURL)
            }

            Text("Apple, AirPort, Time Capsule, Time Machine, and macOS are trademarks of Apple Inc. Product names are used only to describe compatibility.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(width: 640, alignment: .topLeading)
    }
}
