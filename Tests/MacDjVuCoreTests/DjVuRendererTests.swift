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

    // MARK: - scaledPageHeight

    @Test func scaledPageHeight_100percent() {
        // 800 * 3000/2000 = 1200
        let h = DjVuRenderer.scaledPageHeight(nativeWidth: 2000, nativeHeight: 3000, scalePercent: 100)
        #expect(h == 1200)
    }

    @Test func scaledPageHeight_200percent() {
        // 1600 * 3000/2000 = 2400
        let h = DjVuRenderer.scaledPageHeight(nativeWidth: 2000, nativeHeight: 3000, scalePercent: 200)
        #expect(h == 2400)
    }

    @Test func scaledPageHeight_50percent() {
        // 400 * 3000/2000 = 600
        let h = DjVuRenderer.scaledPageHeight(nativeWidth: 2000, nativeHeight: 3000, scalePercent: 50)
        #expect(h == 600)
    }

    @Test func scaledPageHeight_squarePage() {
        let h = DjVuRenderer.scaledPageHeight(nativeWidth: 1000, nativeHeight: 1000, scalePercent: 100)
        #expect(h == 800)
    }
}
