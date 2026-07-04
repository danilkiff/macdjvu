import MacDjVuCore
import Foundation
import SwiftUI

struct PageView: View {
    let pageNumber: Int
    @Environment(ViewerState.self) private var state

    var body: some View {
        let w = state.displayWidth
        let h = state.displayHeight(page: pageNumber)

        ZStack {
            Rectangle()
                .fill(.white)
                .frame(width: w, height: h)

            if let image = state.renderedPages[pageNumber] {
                Image(nsImage: image)
                    .resizable()
                    .frame(width: w, height: h)
            } else {
                ProgressView()
            }

            if state.isSearchActive && !state.searchMatches.isEmpty {
                SearchHighlightOverlay(pageNumber: pageNumber)
            }
        }
        .id(pageNumber)
        .task(id: RenderTaskID(fileURL: state.fileURL, page: pageNumber, scalePercent: state.scalePercent)) {
            await state.renderPageIfNeeded(pageNumber)
        }
        .onAppear { state.pageBecameVisible(pageNumber) }
        .onDisappear { state.pageBecameHidden(pageNumber) }
    }
}

private struct RenderTaskID: Equatable {
    let fileURL: URL?
    let page: Int
    let scalePercent: Int
}
