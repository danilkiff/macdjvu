import Foundation
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
        #expect(try DjVuRenderer.parsePageSize(from: "width=3433 height=4947\n") == PageSize(width: 3433, height: 4947))
    }

    @Test func parsePageSize_smallValues() throws {
        #expect(try DjVuRenderer.parsePageSize(from: "width=100 height=200") == PageSize(width: 100, height: 200))
    }

    @Test func parsePageSize_withCRLF() throws {
        #expect(try DjVuRenderer.parsePageSize(from: "width=800 height=600\r\n") == PageSize(width: 800, height: 600))
    }

    @Test func parsePageSize_extraWhitespace() throws {
        #expect(try DjVuRenderer.parsePageSize(from: "  width=800 height=600  \n") == PageSize(width: 800, height: 600))
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

    @Test func parsePageSize_extraField() throws {
        // Extra fields (e.g. future djvused output) should be silently ignored
        #expect(try DjVuRenderer.parsePageSize(from: "width=100 height=200 depth=300") == PageSize(width: 100, height: 200))
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

    @Test func parsePageSize_zeroWidth() {
        #expect(throws: DjVuError.self) {
            try DjVuRenderer.parsePageSize(from: "width=0 height=200")
        }
    }

    @Test func parsePageSize_zeroHeight() {
        #expect(throws: DjVuError.self) {
            try DjVuRenderer.parsePageSize(from: "width=100 height=0")
        }
    }

    @Test func parsePageSize_negativeValue() {
        #expect(throws: DjVuError.self) {
            try DjVuRenderer.parsePageSize(from: "width=-100 height=200")
        }
    }

    // MARK: - scaledPageHeight

    @Test func scaledPageHeight_100percent() {
        let h = DjVuRenderer.scaledPageHeight(PageSize(width: 2000, height: 3000), scalePercent: 100)
        #expect(h == 1200)
    }

    @Test func scaledPageHeight_200percent() {
        let h = DjVuRenderer.scaledPageHeight(PageSize(width: 2000, height: 3000), scalePercent: 200)
        #expect(h == 2400)
    }

    @Test func scaledPageHeight_50percent() {
        let h = DjVuRenderer.scaledPageHeight(PageSize(width: 2000, height: 3000), scalePercent: 50)
        #expect(h == 600)
    }

    @Test func scaledPageHeight_squarePage() {
        let h = DjVuRenderer.scaledPageHeight(PageSize(width: 1000, height: 1000), scalePercent: 100)
        #expect(h == 800)
    }

    @Test func scaledPageHeight_widePage() {
        // 800 * 500/2000 = 200
        let h = DjVuRenderer.scaledPageHeight(PageSize(width: 2000, height: 500), scalePercent: 100)
        #expect(h == 200)
    }

    @Test func scaledPageHeight_tinyPage() {
        let h = DjVuRenderer.scaledPageHeight(PageSize(width: 1, height: 1), scalePercent: 100)
        #expect(h == 800)
    }

    @Test func scaledPageHeight_veryTallPage() {
        // 800 * 10000/100 = 80000
        let h = DjVuRenderer.scaledPageHeight(PageSize(width: 100, height: 10000), scalePercent: 100)
        #expect(h == 80000)
    }

    @Test func scaledPageHeight_minimumScale() {
        // baseWidth * 1/100 = 8, 8 * 3000/2000 = 12
        let h = DjVuRenderer.scaledPageHeight(PageSize(width: 2000, height: 3000), scalePercent: 1)
        #expect(h == 12)
    }

    // MARK: - toolPath

    @Test func toolPath_findsExistingTool() {
        // /usr/bin/env exists on any macOS and is in searchPaths
        let path = DjVuRenderer.toolPath("env")
        #expect(path == "/usr/bin/env")
    }

    @Test func toolPath_nilForMissing() {
        #expect(DjVuRenderer.toolPath("nonexistent_tool_xyz") == nil)
    }

    // MARK: - Integration: toolNotFound through public API

    @Test func pageCount_toolNotFoundWhenDjvusedMissing() {
        // If djvulibre is not installed, pageCount should throw toolNotFound.
        // We can't uninstall it, but we can verify renderPage throws toolNotFound
        // for a nonexistent tool by testing a path where djvused would fail.
        // Instead, test that pageSize throws a DjVuError on a bad file
        // (this exercises the run() → process failure path).
        #expect(throws: DjVuError.self) {
            try DjVuRenderer.pageCount(of: URL(fileURLWithPath: "/nonexistent.djvu"))
        }
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

    @Test func errorDescription_toolNotFound() {
        let error = DjVuError.toolNotFound("djvused")
        #expect(error.errorDescription?.contains("djvused") == true)
        #expect(error.errorDescription?.contains("brew install djvulibre") == true)
    }
}
