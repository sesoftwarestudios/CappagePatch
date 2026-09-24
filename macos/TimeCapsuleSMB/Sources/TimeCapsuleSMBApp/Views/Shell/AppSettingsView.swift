import SwiftUI

struct AppSettingsView: View {
    let appStore: AppStore
    @ObservedObject var appSettingsStore: AppSettingsStore
    @ObservedObject var appUpdateStore: AppUpdateStore
    @ObservedObject var editor: AppSettingsEditorStore
    @State private var legalNoticesPresented = false
    @State private var advancedDefaultsExpanded = false

    private let contentWidth: CGFloat = 760

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                    .frame(maxWidth: contentWidth, alignment: .leading)

                SettingsFormSection(title: L10n.string("app_settings.section.general"), contentWidth: contentWidth) {
                    SettingsFormRow(title: L10n.string("app_settings.language")) {
                        Picker("", selection: $editor.draft.language) {
                            ForEach(AppLanguage.allCases) { language in
                                Text(language.title)
                                    .tag(language)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 220, alignment: .leading)
                        .id("language-\(savedLanguageIdentity)")
                    }
                    SettingsFormRow(title: L10n.string("app_settings.appearance")) {
                        Picker("", selection: $editor.draft.appearance) {
                            ForEach(AppAppearance.allCases) { appearance in
                                Text(appearance.title)
                                    .tag(appearance)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 220, alignment: .leading)
                        .id("appearance-\(savedLanguageIdentity)")
                    }
                }

                SettingsFormSection(title: L10n.string("app_settings.section.defaults"), contentWidth: contentWidth) {
                    RecommendedSettingsCard(
                        isRecommended: editor.draft.usesRecommendedDeviceSettings,
                        actionTitle: "Use Recommended"
                    ) {
                        editor.draft.applyRecommendedDeviceSettings()
                    }

                    LegacyMacCompatibilityCard(
                        isEnabled: editor.draft.mdnsAdvertiseAFP,
                        followUpText: "Save to use this as the default for devices added later."
                    ) { enabled in
                        editor.draft.setLegacyMacCompatibility(enabled)
                    }

                    DisclosureGroup("Advanced device defaults", isExpanded: $advancedDefaultsExpanded) {
                        VStack(alignment: .leading, spacing: 10) {
                            AdvancedSettingsGuidance()

                            SettingsFormRow(title: L10n.string("app_settings.default_bonjour_timeout")) {
                                TextField("", text: $editor.draft.defaultBonjourTimeoutSeconds)
                                    .frame(width: 120)
                            }
                            Toggle(L10n.string("toggle.enable_nbns"), isOn: $editor.draft.nbnsEnabled)
                                .help("Recommended on: helps older network browsers find the device.")
                            Toggle(L10n.string("toggle.enable_rsync"), isOn: $editor.draft.rsyncEnabled)
                                .help("Leave off unless you use rsync; it opens an unauthenticated service on TCP 873.")
                            Toggle(L10n.string("toggle.internal_share_use_disk_root"), isOn: $editor.draft.internalShareUseDiskRoot)
                                .help("Leave off to share only the managed backup folder instead of the entire disk root.")
                            Toggle(L10n.string("toggle.smb_bind_lan_only"), isOn: $editor.draft.smbBindLanOnly)
                                .help("Optional network hardening for layouts where LAN interfaces are detected reliably.")
                            Toggle(L10n.string("toggle.smb_browse_compatibility"), isOn: $editor.draft.smbBrowseCompatibility)
                                .help("Leave off unless a client cannot list available SMB shares.")
                            Toggle(L10n.string("toggle.mdns_advertise_afp"), isOn: $editor.draft.mdnsAdvertiseAFP)
                                .help("Legacy only. Modern macOS users should leave AFP advertisement off.")
                            Toggle(L10n.string("toggle.any_protocol"), isOn: anyProtocolBinding)
                                .disabled(!SMBProtocolOptionPolicy.allowsAnyProtocol(requireSMBEncryption: editor.draft.requireSMBEncryption))
                                .help("Leave off to keep the server on SMB2 and SMB3.")
                            Toggle(L10n.string("toggle.require_smb_encryption"), isOn: requireSMBEncryptionBinding)
                                .disabled(!SMBProtocolOptionPolicy.allowsRequireSMBEncryption(
                                    anyProtocol: editor.draft.anyProtocol,
                                    forceDisableSMBSigningAndEncryption: editor.draft.forceDisableSMBSigningAndEncryption
                                ))
                                .help("Optional. Encryption improves confidentiality but costs performance on this hardware.")
                            Toggle(
                                L10n.string("toggle.force_disable_smb_signing_and_encryption"),
                                isOn: forceDisableSMBSigningAndEncryptionBinding
                            )
                            .disabled(!SMBProtocolOptionPolicy.allowsForceDisableSMBSigningAndEncryption(
                                requireSMBEncryption: editor.draft.requireSMBEncryption
                            ))
                            Text(L10n.string("toggle.force_disable_smb_signing_and_encryption.note"))
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Toggle(L10n.string("toggle.use_netatalk_metadata"), isOn: $editor.draft.fruitMetadataNetatalk)
                                .help("Recommended on for compatibility with existing Time Machine metadata.")
                            Toggle(L10n.string("toggle.enable_vfs_aio_fork"), isOn: $editor.draft.vfsAIOForkEnabled)
                                .help("Experimental troubleshooting option. Leave off for normal backups.")
                            Toggle(L10n.string("toggle.force_debug_logging"), isOn: $editor.draft.debugLogging)
                                .help("Troubleshooting only; verbose logging creates additional device writes.")
                            SettingsFormRow(title: L10n.string("field.mount_wait")) {
                                TextField("", text: $editor.draft.mountWaitSeconds)
                                    .frame(width: 120)
                            }
                            SettingsFormRow(title: L10n.string("field.ata_idle_seconds")) {
                                TextField("", text: $editor.draft.ataIdleSeconds)
                                    .frame(width: 120)
                            }
                            SettingsFormRow(title: L10n.string("field.ata_standby")) {
                                TextField(L10n.string("app_settings.blank_uses_device_default"), text: $editor.draft.ataStandby)
                                    .frame(width: 180)
                            }
                        }
                        .padding(.top, 8)
                    }
                }

                SettingsFormSection(title: L10n.string("app_settings.section.diagnostics"), contentWidth: contentWidth) {
                    SettingsFormRow(title: L10n.string("app_settings.helper_path")) {
                        TextField(L10n.string("value.auto"), text: $editor.draft.helperPathOverride)
                            .frame(maxWidth: 420)
                    }
                    Toggle(L10n.string("app_settings.show_raw_events"), isOn: $editor.draft.showRawBackendEventsByDefault)
                }

                SettingsFormSection(title: L10n.string("app_settings.section.updates"), contentWidth: contentWidth) {
                    Toggle(L10n.string("app_settings.check_updates_on_launch"), isOn: $editor.draft.checkForUpdatesOnLaunch)
                    SettingsFormRow(title: L10n.string("app_settings.version_url")) {
                        TextField(L10n.string("value.auto"), text: $editor.draft.versionCheckURL)
                            .frame(maxWidth: 420)
                    }
                    HStack(spacing: 10) {
                        Button {
                            appUpdateStore.checkNow(settings: appSettingsStore.settings)
                        } label: {
                            Label(L10n.string("app_settings.check_now"), systemImage: "arrow.clockwise")
                        }
                        .disabled(
                            appUpdateStore.isChecking
                                || editor.draft.versionCheckURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )

                        if appUpdateStore.isChecking {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(updateStatusText)
                            .font(.caption)
                            .foregroundStyle(updateStatusColor)
                    }
                }

                SettingsFormSection(title: L10n.string("app_settings.section.privacy"), contentWidth: contentWidth) {
                    Label("Telemetry is disabled in this independent build.", systemImage: "hand.raised.fill")
                        .foregroundStyle(.secondary)
                }

                SettingsFormSection(title: L10n.string("app_settings.section.time_machine"), contentWidth: contentWidth) {
                    Toggle(L10n.string("app_settings.time_machine_warnings"), isOn: $editor.draft.timeMachineWarningsEnabled)
                }

                SettingsFormSection(title: "About", contentWidth: contentWidth) {
                    HStack(spacing: 14) {
                        BrandMark(size: 42)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(AppBrand.displayName)
                                .font(.headline)
                            Text(AppBrand.tagline)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Credits & License") {
                            legalNoticesPresented = true
                        }
                    }
                }

                if let message = editor.validationError ?? editor.errorMessage ?? appSettingsStore.error?.localizedDescription {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: contentWidth, alignment: .leading)
                }

                actionBar
                    .frame(maxWidth: contentWidth, alignment: .leading)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $legalNoticesPresented) {
            LegalNoticesView()
        }
    }

    private var anyProtocolBinding: Binding<Bool> {
        Binding(
            get: { editor.draft.anyProtocol },
            set: { value in
                editor.draft.anyProtocol = value
                if value {
                    editor.draft.requireSMBEncryption = false
                }
            }
        )
    }

    private var requireSMBEncryptionBinding: Binding<Bool> {
        Binding(
            get: { editor.draft.requireSMBEncryption },
            set: { value in
                editor.draft.requireSMBEncryption = value
                if value {
                    editor.draft.anyProtocol = false
                    editor.draft.forceDisableSMBSigningAndEncryption = false
                }
            }
        )
    }

    private var forceDisableSMBSigningAndEncryptionBinding: Binding<Bool> {
        Binding(
            get: { editor.draft.forceDisableSMBSigningAndEncryption },
            set: { value in
                editor.draft.forceDisableSMBSigningAndEncryption = value
                if value {
                    editor.draft.requireSMBEncryption = false
                }
            }
        )
    }

    private var header: some View {
        BrandHero(
            eyebrow: AppBrand.displayName,
            title: L10n.string("app_settings.title"),
            message: L10n.string("app_settings.subtitle")
        ) {
            BrandMark(size: 58)
        }
    }

    private var savedLanguageIdentity: String {
        appSettingsStore.settings.language.id
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button {
                Task { await editor.save(appStore: appStore) }
            } label: {
                Label(L10n.string("app_settings.save"), systemImage: "checkmark.circle")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!editor.canSave)

            Button(L10n.string("app_settings.reset_saved")) {
                editor.resetDraft()
            }
            .disabled(editor.isSaving || !editor.hasChanges)

            Button("Restore Recommended") {
                editor.restoreDefaultsDraft()
            }
            .disabled(editor.isSaving)

            if editor.isSaving {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private var updateStatusText: String {
        if let payload = appUpdateStore.payload {
            return payload.localizedSummary
        }
        if let error = appUpdateStore.error {
            return error.message
        }
        return appUpdateStore.state.title
    }

    private var updateStatusColor: Color {
        switch appUpdateStore.state {
        case .updateAvailable, .unavailable, .failed:
            return .yellow
        case .current:
            return .green
        default:
            return .secondary
        }
    }
}

private struct SettingsFormSection<Content: View>: View {
    let title: String
    let contentWidth: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.headline)
                VStack(alignment: .leading, spacing: 8) {
                    content()
                }
            }
            .frame(maxWidth: contentWidth, alignment: .leading)
            Divider()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SettingsFormRow<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(title)
                .frame(width: 220, alignment: .leading)
                .foregroundStyle(.secondary)
            content()
            Spacer(minLength: 0)
        }
    }
}
