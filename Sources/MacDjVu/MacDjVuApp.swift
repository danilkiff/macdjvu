import MacDjVuCore
import SwiftUI

@main
struct MacDjVuApp: App {
    @State private var state = ViewerState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(state)
                .onAppear { openFromArguments() }
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }

    private func openFromArguments() {
        guard CommandLine.arguments.count > 1 else { return }
        let path = CommandLine.arguments[1]
        let url = URL(fileURLWithPath: path)
        if url.pathExtension.lowercased() == "djvu" {
            state.openFile(url)
        }
    }
}
