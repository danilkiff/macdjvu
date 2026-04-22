import MacDjVuCore
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
        }
        .id(pageNumber)
        .onAppear {
            Task { await state.renderPageIfNeeded(pageNumber) }
        }
        .onChange(of: state.scalePercent) {
            Task { await state.renderPageIfNeeded(pageNumber) }
        }
    }
}
