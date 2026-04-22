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
    }

    // MARK: - Navigation

    @Test @MainActor func nextPage() {
        let state = ViewerState()
        state.pageCount = 5
        state.fileURL = URL(fileURLWithPath: "/fake.djvu")
        state.nextPage()
        #expect(state.currentPage == 2)
    }

    @Test @MainActor func prevPage() {
        let state = ViewerState()
        state.pageCount = 5
        state.fileURL = URL(fileURLWithPath: "/fake.djvu")
        state.currentPage = 3
        state.prevPage()
        #expect(state.currentPage == 2)
    }

    @Test @MainActor func cannotGoPastLastPage() {
        let state = ViewerState()
        state.pageCount = 3
        state.fileURL = URL(fileURLWithPath: "/fake.djvu")
        state.currentPage = 3
        state.nextPage()
        #expect(state.currentPage == 3)
    }

    @Test @MainActor func cannotGoBeforeFirstPage() {
        let state = ViewerState()
        state.pageCount = 5
        state.fileURL = URL(fileURLWithPath: "/fake.djvu")
        state.prevPage()
        #expect(state.currentPage == 1)
    }

    @Test @MainActor func goToPage() {
        let state = ViewerState()
        state.pageCount = 10
        state.fileURL = URL(fileURLWithPath: "/fake.djvu")
        state.goToPage(7)
        #expect(state.currentPage == 7)
    }

    @Test @MainActor func goToInvalidPageIgnored() {
        let state = ViewerState()
        state.pageCount = 10
        state.fileURL = URL(fileURLWithPath: "/fake.djvu")
        state.goToPage(0)
        #expect(state.currentPage == 1)
        state.goToPage(11)
        #expect(state.currentPage == 1)
    }

    @Test @MainActor func goToPageWithoutFile() {
        let state = ViewerState()
        state.goToPage(5)
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

    @Test @MainActor func zoomClearsCache() {
        let state = ViewerState()
        state.renderedPages[1] = .init()
        state.setZoom(200)
        #expect(state.renderedPages.isEmpty)
    }

    // MARK: - Display geometry

    @Test @MainActor func displayWidth() {
        let state = ViewerState()
        state.scalePercent = 150
        #expect(state.displayWidth == 1200)
    }

    @Test @MainActor func displayHeight() {
        let state = ViewerState()
        state.nativeSize = (width: 2000, height: 3000)
        state.scalePercent = 100
        // 800 * 3000/2000 = 1200
        #expect(state.displayHeight() == 1200)
    }
}
