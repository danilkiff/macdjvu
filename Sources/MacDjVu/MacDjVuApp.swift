import MacDjVuCore
import SwiftUI

extension URL {
    var isDjVu: Bool {
        ["djvu", "djv"].contains(pathExtension.lowercased())
    }
}

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
            .onOpenURL { url in
                if url.isDjVu {
                    Task { await state.openFile(url) }
                }
            }
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
        if url.isDjVu {
            Task { await state.openFile(url) }
        }
    }
}
