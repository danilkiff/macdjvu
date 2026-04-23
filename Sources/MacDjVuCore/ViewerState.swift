import AppKit
import Foundation
import Observation

/// Zoom step for zoomIn()/zoomOut(), in percentage points.
public let zoomStep = 25
/// Minimum allowed zoom percentage.
public let zoomMin = 50
/// Maximum allowed zoom percentage.
public let zoomMax = 600

/// Fallback page dimensions (pixels) when djvused query fails.
/// Approximates a typical A4 scan at 300 DPI (≈2480x3508),
/// rounded for simplicity.
private let fallbackPageSize = (width: 2000, height: 3000)

@Observable
@MainActor
public final class ViewerState {
    public var fileURL: URL?
    /// Tracks the security-scoped URL so deinit can release it.
    @ObservationIgnored nonisolated(unsafe) private var scopedURL: URL?
    public var pageCount: Int = 0
    public var currentPage: Int = 1
    public var scalePercent: Int = 100
    public var nativeSize: (width: Int, height: Int) = fallbackPageSize
    public var errorMessage: String?

    // Image cache keyed by 1-based page number
    public var renderedPages: [Int: NSImage] = [:]

    public init() {}

    // MARK: - File

    public func openFile(_ url: URL) {
        // Release previous security scope
        scopedURL?.stopAccessingSecurityScopedResource()
        scopedURL = nil

        // fileImporter returns security-scoped URLs; child processes
        // (djvused/ddjvu) inherit access only while the scope is active.
        let scoped = url.startAccessingSecurityScopedResource()

        do {
            let count = try DjVuRenderer.pageCount(of: url)
            let size = try DjVuRenderer.pageSize(of: url, page: 1)

            fileURL = url
            if scoped { scopedURL = url }
            pageCount = count
            currentPage = 1
            nativeSize = size
            renderedPages.removeAll()
            errorMessage = nil
        } catch {
            if scoped { url.stopAccessingSecurityScopedResource() }
            errorMessage = error.localizedDescription
        }
    }

    deinit {
        scopedURL?.stopAccessingSecurityScopedResource()
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
        setZoom(scalePercent + zoomStep)
    }

    public func zoomOut() {
        setZoom(scalePercent - zoomStep)
    }

    public func setZoom(_ percent: Int) {
        let clamped = max(zoomMin, min(zoomMax, percent))
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
