import MacDjVuCore
import SwiftUI

@main
struct MacDjVuApp: App {
    @State private var state = ViewerState()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentView()
            }
            .environment(state)
            .onAppear { openFromArguments() }
        }
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }

    private func openFromArguments() {
        guard CommandLine.arguments.count > 1 else { return }
        let path = CommandLine.arguments[1]
        let url = URL(fileURLWithPath: path)
        if ["djvu", "djv"].contains(url.pathExtension.lowercased()) {
            Task { await state.openFile(url) }
        }
    }
}
