import Testing
@testable import StandupBuddy

@Suite("UpdateService version comparison")
struct UpdateServiceTests {
    @Test("Strips leading v from tags")
    func normalizesTags() {
        #expect(UpdateService.normalizedVersion("v1.2.1") == "1.2.1")
        #expect(UpdateService.normalizedVersion("V1.2.1") == "1.2.1")
        #expect(UpdateService.normalizedVersion(" 1.2.1 ") == "1.2.1")
        #expect(UpdateService.normalizedVersion("1.2.1") == "1.2.1")
    }

    @Test("Detects newer versions")
    func detectsNewer() {
        #expect(UpdateService.isNewer("1.3.0", than: "1.2.1"))
        #expect(UpdateService.isNewer("v1.3.0", than: "1.2.1"))
        #expect(UpdateService.isNewer("1.10.0", than: "1.9.9"))
        #expect(UpdateService.isNewer("2.0.0", than: "1.99.99"))
        #expect(UpdateService.isNewer("1.2", than: "1.1.9"))
    }

    @Test("Treats equal and older versions as not newer")
    func rejectsEqualOrOlder() {
        #expect(!UpdateService.isNewer("1.2.1", than: "1.2.1"))
        #expect(!UpdateService.isNewer("v1.2.1", than: "1.2.1"))
        #expect(!UpdateService.isNewer("1.2.0", than: "1.2.1"))
        #expect(!UpdateService.isNewer("1.9.9", than: "1.10.0"))
        #expect(!UpdateService.isNewer("1.2", than: "1.2.0"))
    }
}
