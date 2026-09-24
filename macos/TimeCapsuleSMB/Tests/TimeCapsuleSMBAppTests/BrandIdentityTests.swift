import XCTest
@testable import TimeCapsuleSMBApp

final class BrandIdentityTests: XCTestCase {
    func testVisibleBrandIdentityIsCappagePatch() {
        XCTAssertEqual(AppBrand.displayName, "CappagePatch")
        XCTAssertEqual(AppBrand.bundleIdentifier, "org.cappagepatch.CappagePatch")
        XCTAssertEqual(AppBrand.diagnosticsFilename, "CappagePatch-Diagnostics.txt")
        XCTAssertEqual(AppBrand.organizationName, "SE Software Studios")
        XCTAssertEqual(AppBrand.creatorName, "Benjamin Uitzetter")
        XCTAssertEqual(AppBrand.creatorTitle, "CEO and Senior Developer")
    }

    func testCompatibilityIdentifiersRemainStable() {
        XCTAssertEqual(AppBrand.compatibilityApplicationSupportDirectory, "TimeCapsuleSMB")
        XCTAssertEqual(AppBrand.compatibilityKeychainService, "TimeCapsuleSMB.DevicePassword")
    }
}
