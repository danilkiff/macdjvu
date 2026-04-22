import AppKit
import Foundation
import Observation

@Observable
@MainActor
public final class ViewerState {
    public var fileURL: URL?
    public var pageCount: Int = 0
    public var currentPage: Int = 1
    public var scalePercent: Int = 100
    public var nativeSize: (width: Int, height: Int) = (2000, 3000)
    public var errorMessage: String?

    // Image cache keyed by 1-based page number
    public var renderedPages: [Int: NSImage] = [:]

    public init() {}

    // MARK: - File

    public func openFile(_ url: URL) {
        do {
            let count = try DjVuRenderer.pageCount(of: url)
            let size = try DjVuRenderer.pageSize(of: url, page: 1)

            fileURL = url
            pageCount = count
            currentPage = 1
            nativeSize = size
            renderedPages.removeAll()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Navigation

    public func goToPage(_ page: Int) {
        guard fileURL != nil, page >= 1, page <= pageCount else { return }
        currentPage = page
    }

    public func nextPage() {
        if currentPage < pageCount { goToPage(currentPage + 1) }
    }

    public func prevPage() {
        if currentPage > 1 { goToPage(currentPage - 1) }
    }

    // MARK: - Zoom

    public func zoomIn() {
        setZoom(scalePercent + 25)
    }

    public func zoomOut() {
        setZoom(scalePercent - 25)
    }

    public func setZoom(_ percent: Int) {
        let clamped = max(50, min(600, percent))
        guard clamped != scalePercent else { return }
        scalePercent = clamped
        renderedPages.removeAll()
    }

    // MARK: - Display geometry

    public var displayWidth: CGFloat {
        max(1, baseWidth * CGFloat(scalePercent) / 100)
    }

    public func displayHeight(page: Int = 1) -> CGFloat {
        DjVuRenderer.scaledPageHeight(
            nativeWidth: nativeSize.width,
            nativeHeight: nativeSize.height,
            scalePercent: scalePercent
        )
    }

    // MARK: - Rendering

    public func renderPageIfNeeded(_ page: Int) async {
        guard let url = fileURL, renderedPages[page] == nil else { return }

        let scale = scalePercent
        do {
            let data = try await Task.detached {
                try DjVuRenderer.renderPage(file: url, page: page, scalePercent: scale)
            }.value
            // Only store if zoom hasn't changed while we were rendering
            if scalePercent == scale {
                renderedPages[page] = NSImage(data: data)
            }
        } catch {
            // Silently skip failed pages
        }
    }
}
