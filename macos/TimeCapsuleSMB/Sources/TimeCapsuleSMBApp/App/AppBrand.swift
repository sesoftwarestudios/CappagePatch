import Foundation

public enum AppBrand {
    public static let displayName = "CappagePatch"
    static let tagline = "Modern backups. Classic hardware."
    static let shortDescription = "A focused control center for keeping legacy AirPort storage useful."
    static let bundleIdentifier = "org.cappagepatch.CappagePatch"
    static let diagnosticsFilename = "CappagePatch-Diagnostics.txt"
    static let organizationName = "SE Software Studios"
    static let creatorName = "Benjamin Uitzetter"
    static let creatorTitle = "CEO and Senior Developer"
    static let projectURL = URL(string: "https://github.com/sesoftwarestudios/CappagePatch")!

    // Keep these compatibility identifiers stable so installing the fork does
    // not orphan existing device profiles, Keychain passwords, or helper state.
    static let compatibilityApplicationSupportDirectory = "TimeCapsuleSMB"
    static let compatibilityKeychainService = "TimeCapsuleSMB.DevicePassword"

    static let upstreamProjectName = "TimeCapsuleSMB"
    static let upstreamProjectURL = URL(string: "https://github.com/jamesyc/TimeCapsuleSMB")!
    static let licenseURL = URL(string: "https://www.gnu.org/licenses/gpl-3.0.html")!

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
    }
}
