import AppKit
import Foundation
import Testing
@testable import MacDjVuCore

@Suite("DjVuRenderer integration")
struct DjVuRendererIntegrationTests {

    @Test func readsSinglePageFixtureMetadata() throws {
        try requireDjVuLibreTools()
        let url = try fixtureURL("single-page")

        #expect(try DjVuRenderer.pageCount(of: url) == 1)
        #expect(try DjVuRenderer.pageSize(of: url, page: 1) == PageSize(width: 40, height: 30))
    }

    @Test func readsBundledFixtureMetadata() throws {
        try requireDjVuLibreTools()
        let url = try fixtureURL("two-page")

        #expect(try DjVuRenderer.pageCount(of: url) == 2)
        #expect(try DjVuRenderer.pageSize(of: url, page: 1) == PageSize(width: 40, height: 30))
        #expect(try DjVuRenderer.pageSize(of: url, page: 2) == PageSize(width: 24, height: 48))
    }

    @Test func rendersSinglePageFixtureToDecodableImage() throws {
        try requireDjVuLibreTools()
        let url = try fixtureURL("single-page")

        let rendered = try DjVuRenderer.renderPage(file: url, page: 1, scalePercent: 50)
        let image = try #require(NSImage(data: rendered.data))
        let representation = try #require(image.representations.max { lhs, rhs in
            lhs.pixelsWide * lhs.pixelsHigh < rhs.pixelsWide * rhs.pixelsHigh
        })

        #expect(rendered.nativeSize == PageSize(width: 40, height: 30))
        #expect(representation.pixelsWide == 400)
        #expect(representation.pixelsHigh == 300)
    }

    @Test @MainActor func viewerStateOpensAndRendersBundledFixture() async throws {
        try requireDjVuLibreTools()
        let url = try fixtureURL("two-page")
        let state = ViewerState()

        await state.openFile(url)
        #expect(state.errorMessage == nil)
        #expect(state.fileURL == url)
        #expect(state.pageCount == 2)
        #expect(state.currentPage == 1)
        #expect(state.pageSizes[1] == PageSize(width: 40, height: 30))

        await state.renderPageIfNeeded(2)
        #expect(state.errorMessage == nil)
        #expect(state.renderedPages[2] != nil)
        #expect(state.renderedPageScales[2] == state.scalePercent)
        #expect(state.renderedPageCosts[2] != nil)
        #expect(state.pageSizes[2] == PageSize(width: 24, height: 48))
    }
}

private func fixtureURL(_ name: String) throws -> URL {
    try #require(Bundle.module.url(forResource: name, withExtension: "djvu"))
}

private func requireDjVuLibreTools() throws {
    for tool in ["djvused", "ddjvu"] where DjVuRenderer.toolPath(tool) == nil {
        throw DjVuError.toolNotFound(tool)
    }
}
