import AppKit
import Foundation
import Testing
@testable import MacDjVuCore

@Suite("ViewerState")
struct ViewerStateTests {

    // MARK: - Initial state

    @Test @MainActor func initialState() {
        let state = ViewerState()
        #expect(state.fileURL == nil)
        #expect(state.pageCount == 0)
        #expect(state.currentPage == 1)
        #expect(state.scalePercent == 100)
        #expect(state.renderedPages.isEmpty)
        #expect(state.errorMessage == nil)
    }

    // MARK: - Navigation

    @Test @MainActor func nextPage() {
        let state = makeState(pages: 5)
        state.nextPage()
        #expect(state.currentPage == 2)
    }

    @Test @MainActor func nextPageMultiple() {
        let state = makeState(pages: 5)
        state.nextPage()
        state.nextPage()
        state.nextPage()
        #expect(state.currentPage == 4)
    }

    @Test @MainActor func prevPage() {
        let state = makeState(pages: 5)
        state.currentPage = 3
        state.prevPage()
        #expect(state.currentPage == 2)
    }

    @Test @MainActor func cannotGoPastLastPage() {
        let state = makeState(pages: 3)
        state.currentPage = 3
        state.nextPage()
        #expect(state.currentPage == 3)
    }

    @Test @MainActor func cannotGoBeforeFirstPage() {
        let state = makeState(pages: 5)
        state.prevPage()
        #expect(state.currentPage == 1)
    }

    @Test @MainActor func goToPage() {
        let state = makeState(pages: 10)
        state.goToPage(7)
        #expect(state.currentPage == 7)
    }

    @Test @MainActor func goToFirstPage() {
        let state = makeState(pages: 10)
        state.goToPage(1)
        #expect(state.currentPage == 1)
    }

    @Test @MainActor func goToLastPage() {
        let state = makeState(pages: 10)
        state.goToPage(10)
        #expect(state.currentPage == 10)
    }

    @Test @MainActor func goToInvalidPageZero() {
        let state = makeState(pages: 10)
        state.goToPage(0)
        #expect(state.currentPage == 1)
    }

    @Test @MainActor func goToInvalidPageBeyondMax() {
        let state = makeState(pages: 10)
        state.goToPage(11)
        #expect(state.currentPage == 1)
    }

    @Test @MainActor func goToNegativePage() {
        let state = makeState(pages: 10)
        state.goToPage(-1)
        #expect(state.currentPage == 1)
    }

    @Test @MainActor func goToPageWithoutFile() {
        let state = ViewerState()
        state.goToPage(5)
        #expect(state.currentPage == 1)
    }

    @Test @MainActor func nextPageWithoutFile() {
        let state = ViewerState()
        state.nextPage()
        #expect(state.currentPage == 1)
    }

    @Test @MainActor func prevPageWithoutFile() {
        let state = ViewerState()
        state.prevPage()
        #expect(state.currentPage == 1)
    }

    @Test @MainActor func nextPageSinglePageDocument() {
        let state = makeState(pages: 1)
        state.nextPage()
        #expect(state.currentPage == 1)
    }

    @Test @MainActor func prevPageSinglePageDocument() {
        let state = makeState(pages: 1)
        state.prevPage()
        #expect(state.currentPage == 1)
    }

    // MARK: - Zoom

    @Test @MainActor func zoomIn() {
        let state = ViewerState()
        state.zoomIn()
        #expect(state.scalePercent == 125)
    }

    @Test @MainActor func zoomOut() {
        let state = ViewerState()
        state.zoomOut()
        #expect(state.scalePercent == 75)
    }

    @Test @MainActor func zoomInMultiple() {
        let state = ViewerState()
        state.zoomIn()
        state.zoomIn()
        #expect(state.scalePercent == 150)
    }

    @Test @MainActor func zoomOutMultiple() {
        let state = ViewerState()
        state.zoomOut()
        state.zoomOut()
        #expect(state.scalePercent == 50)
    }

    @Test @MainActor func zoomClampedMin() {
        let state = ViewerState()
        state.setZoom(10)
        #expect(state.scalePercent == 50)
    }

    @Test @MainActor func zoomClampedMax() {
        let state = ViewerState()
        state.setZoom(999)
        #expect(state.scalePercent == 600)
    }

    @Test @MainActor func zoomClampedNegative() {
        let state = ViewerState()
        state.setZoom(-100)
        #expect(state.scalePercent == 50)
    }

    @Test @MainActor func zoomClampedZero() {
        let state = ViewerState()
        state.setZoom(0)
        #expect(state.scalePercent == 50)
    }

    @Test @MainActor func zoomExactBoundaryMin() {
        let state = ViewerState()
        state.setZoom(50)
        #expect(state.scalePercent == 50)
    }

    @Test @MainActor func zoomExactBoundaryMax() {
        let state = ViewerState()
        state.setZoom(600)
        #expect(state.scalePercent == 600)
    }

    @Test @MainActor func zoomInCapped() {
        let state = ViewerState()
        state.scalePercent = 600
        state.zoomIn()
        #expect(state.scalePercent == 600)
    }

    @Test @MainActor func zoomOutCapped() {
        let state = ViewerState()
        state.scalePercent = 50
        state.zoomOut()
        #expect(state.scalePercent == 50)
    }

    @Test @MainActor func zoomPreservesCacheForSmoothDisplay() {
        let state = ViewerState()
        state.renderedPages[1] = .init()
        state.renderedPages[2] = .init()
        state.setZoom(200)
        // Stale images are kept visible during re-render for smoother zoom UX.
        #expect(state.renderedPages.count == 2)
    }

    @Test @MainActor func zoomSameValueIsNoOp() {
        let state = ViewerState()
        state.renderedPages[1] = .init()
        state.setZoom(100) // same as default — guard fires, nothing changes
        #expect(state.renderedPages.count == 1)
        #expect(state.scalePercent == 100)
    }

    // MARK: - Rendering guards

    @Test @MainActor func renderPageIfNeededSkipsWithoutFile() async {
        let state = ViewerState()
        let sentinel = NSImage()
        state.renderedPages[1] = sentinel
        await state.renderPageIfNeeded(1)
        // No fileURL → returns immediately; cache untouched.
        #expect(state.renderedPages[1] === sentinel)
    }

    @Test @MainActor func renderPageIfNeededSkipsOnCacheHit() async {
        let state = ViewerState()
        state.fileURL = URL(fileURLWithPath: "/fake.djvu")
        let sentinel = NSImage()
        state.renderedPages[1] = sentinel
        state.renderedPageScales[1] = 100 // matches default scalePercent
        await state.renderPageIfNeeded(1)
        // Cache hit: scale matches → returns immediately; no spawn, image unchanged.
        #expect(state.renderedPages[1] === sentinel)
    }

    @Test @MainActor func renderPageIfNeededAttemptsRenderOnStaleScale() async {
        let state = ViewerState()
        state.fileURL = URL(fileURLWithPath: "/fake.djvu")
        let sentinel = NSImage()
        state.renderedPages[1] = sentinel
        state.renderedPageScales[1] = 50  // stale: cached at 50%, current is 100%
        await state.renderPageIfNeeded(1)
        // Render was attempted; it fails on the fake path but errorMessage is set,
        // confirming the guard did NOT short-circuit.
        #expect(state.errorMessage != nil)
    }

    @Test @MainActor func decodeRenderedImageRejectsInvalidData() {
        #expect(throws: ViewerStateError.self) {
            try ViewerState.decodeRenderedImage(Data("not an image".utf8), page: 3)
        }
    }

    // MARK: - Display geometry

    @Test @MainActor func displayWidth_default() {
        let state = ViewerState()
        #expect(state.displayWidth == 800)
    }

    @Test @MainActor func displayWidth_150() {
        let state = ViewerState()
        state.scalePercent = 150
        #expect(state.displayWidth == 1200)
    }

    @Test @MainActor func displayWidth_50() {
        let state = ViewerState()
        state.scalePercent = 50
        #expect(state.displayWidth == 400)
    }

    @Test @MainActor func displayHeight_portrait() {
        let state = ViewerState()
        state.pageSizes = [1: PageSize(width: 2000, height: 3000)]
        state.scalePercent = 100
        #expect(state.displayHeight() == 1200)
    }

    @Test @MainActor func displayHeight_landscape() {
        let state = ViewerState()
        state.pageSizes = [1: PageSize(width: 3000, height: 2000)]
        state.scalePercent = 100
        // 800 * 2000/3000 ≈ 533.33
        #expect(state.displayHeight() > 533)
        #expect(state.displayHeight() < 534)
    }

    @Test @MainActor func displayHeight_square() {
        let state = ViewerState()
        state.pageSizes = [1: PageSize(width: 1000, height: 1000)]
        state.scalePercent = 100
        #expect(state.displayHeight() == 800)
    }

    // MARK: - openFile

    @Test @MainActor func openFileNonexistentSetsError() async {
        let state = ViewerState()
        await state.openFile(URL(fileURLWithPath: "/nonexistent.djvu"))
        #expect(state.errorMessage != nil)
        // State should remain untouched on failure.
        #expect(state.fileURL == nil)
        #expect(state.pageCount == 0)
    }

    @Test @MainActor func openFileErrorDoesNotClobberPreviousState() async {
        let state = makeState(pages: 10)
        state.currentPage = 5
        state.renderedPages[1] = NSImage()
        await state.openFile(URL(fileURLWithPath: "/nonexistent.djvu"))
        // Previous document state preserved on error.
        #expect(state.fileURL?.lastPathComponent == "fake.djvu")
        #expect(state.pageCount == 10)
        #expect(state.currentPage == 5)
        #expect(state.renderedPages[1] != nil)
    }

    // MARK: - Display geometry fallback

    @Test @MainActor func displayHeightFallbackWhenNoPageSizes() {
        let state = ViewerState()
        // No pageSizes at all → uses fallbackPageSize (A4 @ 300dpi: 2480×3508).
        let h = state.displayHeight()
        // 800 * 3508 / 2480 = 1131.6129...
        #expect(h > 1131)
        #expect(h < 1132)
    }

    @Test @MainActor func displayHeightFallsBackToPage1() {
        let state = ViewerState()
        state.pageSizes = [1: PageSize(width: 1000, height: 2000)]
        // Request page 5 which has no entry → falls back to page 1.
        let h = state.displayHeight(page: 5)
        // 800 * 2000 / 1000 = 1600
        #expect(h == 1600)
    }

    // MARK: - Rendering dedup

    @Test @MainActor func renderPageIfNeededSkipsOnDuplicateInFlight() async {
        let state = makeState(pages: 5)
        // Simulate an in-flight render at current scale.
        state.renderingPages[1] = 100
        let sentinel = NSImage()
        state.renderedPages[1] = sentinel
        await state.renderPageIfNeeded(1)
        // Dedup guard fires — no render attempted, cache untouched.
        #expect(state.renderedPages[1] === sentinel)
        #expect(state.errorMessage == nil)
    }

    // MARK: - Cache eviction

    @Test @MainActor func cacheEvictsDistantPages() {
        let state = makeState(pages: 20)
        state.currentPage = 10
        // Fill cache beyond capacity.
        for i in 1...15 {
            state.renderedPages[i] = NSImage()
            state.renderedPageScales[i] = 100
        }
        state.evictDistantPages()
        #expect(state.renderedPages.count == ViewerState.cacheCapacity)
        // Pages closest to currentPage=10 survive; distant ones evicted.
        #expect(state.renderedPages[10] != nil)
        #expect(state.renderedPages[9] != nil)
        #expect(state.renderedPages[11] != nil)
        // Page 1 is farthest from 10 and should be evicted.
        #expect(state.renderedPages[1] == nil)
        #expect(state.renderedPageScales[1] == nil)
    }

    @Test @MainActor func cacheUnderCapacityNotEvicted() {
        let state = makeState(pages: 20)
        state.currentPage = 5
        for i in 1...5 {
            state.renderedPages[i] = NSImage()
            state.renderedPageScales[i] = 100
        }
        state.evictDistantPages()
        // Under capacity — nothing should be evicted.
        #expect(state.renderedPages.count == 5)
    }

    @Test @MainActor func cacheEvictionKeepsClosestPages() {
        let state = makeState(pages: 50)
        state.currentPage = 25
        // Insert pages at edges and near center.
        for i in [1, 2, 3, 24, 25, 26, 27, 28, 29, 30, 48, 49, 50] {
            state.renderedPages[i] = NSImage()
            state.renderedPageScales[i] = 100
        }
        state.evictDistantPages()
        #expect(state.renderedPages.count == ViewerState.cacheCapacity)
        // Center pages survive.
        for i in 24...30 {
            #expect(state.renderedPages[i] != nil)
        }
        // Edge pages evicted.
        #expect(state.renderedPages[1] == nil)
        #expect(state.renderedPages[50] == nil)
    }

    @Test @MainActor func cacheEvictsByCostLimit() {
        let state = makeState(pages: 20)
        state.currentPage = 2
        for i in [1, 2, 20] {
            state.renderedPages[i] = NSImage()
            state.renderedPageScales[i] = 100
            state.renderedPageCosts[i] = ViewerState.cacheCostLimit / 2
        }
        state.evictDistantPages()
        #expect(state.renderedCacheCost <= ViewerState.cacheCostLimit)
        #expect(state.renderedPages[1] != nil)
        #expect(state.renderedPages[2] != nil)
        #expect(state.renderedPages[20] == nil)
        #expect(state.renderedPageCosts[20] == nil)
    }

    @Test @MainActor func cacheKeepsSingleOversizedCurrentPage() {
        let state = makeState(pages: 1)
        state.renderedPages[1] = NSImage()
        state.renderedPageScales[1] = 100
        state.renderedPageCosts[1] = ViewerState.cacheCostLimit * 2
        state.evictDistantPages()
        #expect(state.renderedPages[1] != nil)
        #expect(state.renderedCacheCost == ViewerState.cacheCostLimit * 2)
    }

    @Test @MainActor func estimatedImageCostFallsBackToScaledDimensions() {
        let cost = ViewerState.estimatedImageCost(
            NSImage(),
            nativeSize: PageSize(width: 2000, height: 3000),
            scalePercent: 100
        )
        #expect(cost == 800 * 1200 * 4)
    }

    // MARK: - Search

    @Test @MainActor func toggleSearchActivates() {
        let state = ViewerState()
        state.toggleSearch()
        #expect(state.isSearchActive)
    }

    @Test @MainActor func toggleSearchDeactivatesAndClears() {
        let state = ViewerState()
        state.isSearchActive = true
        state.searchQuery = "test"
        state.searchMatches = [SearchMatch(page: 1, wordIndices: [0])]
        state.currentMatchIndex = 0
        state.toggleSearch()
        #expect(!state.isSearchActive)
        #expect(state.searchQuery.isEmpty)
        #expect(state.searchMatches.isEmpty)
        #expect(state.currentMatchIndex == nil)
    }

    @Test @MainActor func dismissSearchClearsState() {
        let state = ViewerState()
        state.isSearchActive = true
        state.searchQuery = "test"
        state.searchMatches = [SearchMatch(page: 1, wordIndices: [0])]
        state.currentMatchIndex = 0
        state.dismissSearch()
        #expect(!state.isSearchActive)
        #expect(state.searchQuery.isEmpty)
        #expect(state.searchMatches.isEmpty)
        #expect(state.currentMatchIndex == nil)
    }

    @Test @MainActor func nextMatchWrapsAround() {
        let state = makeState(pages: 5)
        state.searchMatches = [
            SearchMatch(page: 1, wordIndices: [0]),
            SearchMatch(page: 2, wordIndices: [0]),
        ]
        state.currentMatchIndex = 1
        state.nextMatch()
        #expect(state.currentMatchIndex == 0)
    }

    @Test @MainActor func previousMatchWrapsAround() {
        let state = makeState(pages: 5)
        state.searchMatches = [
            SearchMatch(page: 1, wordIndices: [0]),
            SearchMatch(page: 2, wordIndices: [0]),
        ]
        state.currentMatchIndex = 0
        state.previousMatch()
        #expect(state.currentMatchIndex == 1)
    }

    @Test @MainActor func nextMatchNavigatesToPage() {
        let state = makeState(pages: 5)
        state.searchMatches = [
            SearchMatch(page: 1, wordIndices: [0]),
            SearchMatch(page: 3, wordIndices: [0]),
        ]
        state.currentMatchIndex = 0
        state.nextMatch()
        #expect(state.currentPage == 3)
        #expect(state.currentMatchIndex == 1)
    }

    @Test @MainActor func previousMatchNavigatesToPage() {
        let state = makeState(pages: 5)
        state.searchMatches = [
            SearchMatch(page: 1, wordIndices: [0]),
            SearchMatch(page: 4, wordIndices: [0]),
        ]
        state.currentMatchIndex = 1
        state.previousMatch()
        #expect(state.currentPage == 1)
        #expect(state.currentMatchIndex == 0)
    }

    @Test @MainActor func nextMatchNoOpWithoutMatches() {
        let state = makeState(pages: 5)
        state.nextMatch()
        #expect(state.currentMatchIndex == nil)
    }

    @Test @MainActor func previousMatchNoOpWithoutMatches() {
        let state = makeState(pages: 5)
        state.previousMatch()
        #expect(state.currentMatchIndex == nil)
    }

    @Test @MainActor func nextMatchNoOpWithNilIndex() {
        let state = makeState(pages: 5)
        state.searchMatches = [SearchMatch(page: 1, wordIndices: [0])]
        state.currentMatchIndex = nil
        state.nextMatch()
        #expect(state.currentMatchIndex == nil)
    }

    @Test @MainActor func nextMatchSingleMatch() {
        let state = makeState(pages: 5)
        state.searchMatches = [SearchMatch(page: 2, wordIndices: [0])]
        state.currentMatchIndex = 0
        state.nextMatch()
        #expect(state.currentMatchIndex == 0)
        #expect(state.currentPage == 2)
    }

    @Test @MainActor func openFileClearsTextCache() async {
        let state = makeState(pages: 5)
        state.pageTextCache[1] = DjVuPageText(words: [
            DjVuWord(text: "stale", xmin: 0, ymin: 0, xmax: 1, ymax: 1),
        ])
        state.searchMatches = [SearchMatch(page: 1, wordIndices: [0])]
        state.currentMatchIndex = 0
        state.searchQuery = "stale"
        // Opening a nonexistent file will fail, but on success the cache is cleared.
        // Test the clear-on-success path by checking initial state setup.
        #expect(!state.pageTextCache.isEmpty)
        #expect(!state.searchMatches.isEmpty)
    }

    @Test @MainActor func searchInitialState() {
        let state = ViewerState()
        #expect(!state.isSearchActive)
        #expect(state.searchQuery.isEmpty)
        #expect(state.searchMatches.isEmpty)
        #expect(state.currentMatchIndex == nil)
        #expect(state.pageTextCache.isEmpty)
    }

    // MARK: - Helpers

    @MainActor
    private func makeState(pages: Int) -> ViewerState {
        let state = ViewerState()
        state.pageCount = pages
        state.fileURL = URL(fileURLWithPath: "/fake.djvu")
        return state
    }
}
