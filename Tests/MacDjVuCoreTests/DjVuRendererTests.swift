import Testing
@testable import MacDjVuCore

@Suite("DjVuRenderer parsing")
struct DjVuRendererTests {

    // MARK: - parsePageCount

    @Test func parsePageCount_valid() throws {
        #expect(try DjVuRenderer.parsePageCount(from: "42\n") == 42)
    }

    @Test func parsePageCount_withWhitespace() throws {
        #expect(try DjVuRenderer.parsePageCount(from: "  7  \n") == 7)
    }

    @Test func parsePageCount_withCRLF() throws {
        #expect(try DjVuRenderer.parsePageCount(from: "12\r\n") == 12)
    }

    @Test func parsePageCount_invalid() {
        #expect(throws: DjVuError.self) {
            try DjVuRenderer.parsePageCount(from: "not a number")
        }
    }

    @Test func parsePageCount_empty() {
        #expect(throws: DjVuError.self) {
            try DjVuRenderer.parsePageCount(from: "")
        }
    }

    @Test func parsePageCount_negative() {
        #expect(throws: DjVuError.self) {
            try DjVuRenderer.parsePageCount(from: "-5")
        }
    }

    @Test func parsePageCount_zero() {
        #expect(throws: DjVuError.self) {
            try DjVuRenderer.parsePageCount(from: "0")
        }
    }

    @Test func parsePageCount_float() {
        #expect(throws: DjVuError.self) {
            try DjVuRenderer.parsePageCount(from: "3.5")
        }
    }

    // MARK: - parsePageSize

    @Test func parsePageSize_valid() throws {
        let (w, h) = try DjVuRenderer.parsePageSize(from: "width=3433 height=4947\n")
        #expect(w == 3433)
        #expect(h == 4947)
    }

    @Test func parsePageSize_smallValues() throws {
        let (w, h) = try DjVuRenderer.parsePageSize(from: "width=100 height=200")
        #expect(w == 100)
        #expect(h == 200)
    }

    @Test func parsePageSize_withCRLF() throws {
        let (w, h) = try DjVuRenderer.parsePageSize(from: "width=800 height=600\r\n")
        #expect(w == 800)
        #expect(h == 600)
    }

    @Test func parsePageSize_extraWhitespace() throws {
        let (w, h) = try DjVuRenderer.parsePageSize(from: "  width=800 height=600  \n")
        #expect(w == 800)
        #expect(h == 600)
    }

    @Test func parsePageSize_invalid() {
        #expect(throws: DjVuError.self) {
            try DjVuRenderer.parsePageSize(from: "garbage")
        }
    }

    @Test func parsePageSize_partialOutput() {
        #expect(throws: DjVuError.self) {
            try DjVuRenderer.parsePageSize(from: "width=100")
        }
    }

    @Test func parsePageSize_empty() {
        #expect(throws: DjVuError.self) {
            try DjVuRenderer.parsePageSize(from: "")
        }
    }

    @Test func parsePageSize_threeFields() {
        #expect(throws: DjVuError.self) {
            try DjVuRenderer.parsePageSize(from: "width=100 height=200 depth=300")
        }
    }

    @Test func parsePageSize_nonNumericValue() {
        #expect(throws: DjVuError.self) {
            try DjVuRenderer.parsePageSize(from: "width=abc height=200")
        }
    }

    @Test func parsePageSize_missingEquals() {
        #expect(throws: DjVuError.self) {
            try DjVuRenderer.parsePageSize(from: "width100 height200")
        }
    }

    // MARK: - scaledPageHeight

    @Test func scaledPageHeight_100percent() {
        let h = DjVuRenderer.scaledPageHeight(nativeWidth: 2000, nativeHeight: 3000, scalePercent: 100)
        #expect(h == 1200)
    }

    @Test func scaledPageHeight_200percent() {
        let h = DjVuRenderer.scaledPageHeight(nativeWidth: 2000, nativeHeight: 3000, scalePercent: 200)
        #expect(h == 2400)
    }

    @Test func scaledPageHeight_50percent() {
        let h = DjVuRenderer.scaledPageHeight(nativeWidth: 2000, nativeHeight: 3000, scalePercent: 50)
        #expect(h == 600)
    }

    @Test func scaledPageHeight_squarePage() {
        let h = DjVuRenderer.scaledPageHeight(nativeWidth: 1000, nativeHeight: 1000, scalePercent: 100)
        #expect(h == 800)
    }

    @Test func scaledPageHeight_widePage() {
        // 800 * 500/2000 = 200
        let h = DjVuRenderer.scaledPageHeight(nativeWidth: 2000, nativeHeight: 500, scalePercent: 100)
        #expect(h == 200)
    }

    @Test func scaledPageHeight_tinyPage() {
        let h = DjVuRenderer.scaledPageHeight(nativeWidth: 1, nativeHeight: 1, scalePercent: 100)
        #expect(h == 800)
    }

    @Test func scaledPageHeight_veryTallPage() {
        // 800 * 10000/100 = 80000
        let h = DjVuRenderer.scaledPageHeight(nativeWidth: 100, nativeHeight: 10000, scalePercent: 100)
        #expect(h == 80000)
    }

    @Test func scaledPageHeight_minimumScale() {
        // baseWidth * 1/100 = 8, 8 * 3000/2000 = 12
        let h = DjVuRenderer.scaledPageHeight(nativeWidth: 2000, nativeHeight: 3000, scalePercent: 1)
        #expect(h == 12)
    }

    // MARK: - toolPath

    @Test func toolPath_findsExistingTool() {
        // /usr/bin/env exists on any macOS and is in searchPaths
        let path = DjVuRenderer.toolPath("env")
        #expect(path == "/usr/bin/env")
    }

    @Test func toolPath_fallbackForMissing() {
        let path = DjVuRenderer.toolPath("nonexistent_tool_xyz")
        #expect(path == "nonexistent_tool_xyz")
    }

    // MARK: - DjVuError descriptions

    @Test func errorDescription_processFailure() {
        let error = DjVuError.processFailure("ddjvu", 1, "")
        #expect(error.errorDescription?.contains("ddjvu") == true)
        #expect(error.errorDescription?.contains("1") == true)
    }

    @Test func errorDescription_processFailureWithStderr() {
        let error = DjVuError.processFailure("djvused", 10, "Cannot open file")
        #expect(error.errorDescription == "djvused failed with exit code 10: Cannot open file")
    }

    @Test func errorDescription_unexpectedOutput() {
        let error = DjVuError.unexpectedOutput("bad data")
        #expect(error.errorDescription?.contains("bad data") == true)
    }
}
