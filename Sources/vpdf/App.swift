import SwiftUI

@main
public struct VpdfApp: App {
    public init() {}

    public var body: some Scene {
        WindowGroup {
            ContentView(viewModel: AppViewModel())
                .frame(minWidth: 800, minHeight: 520)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            SidebarCommands() // Habilita o atalho nativo ⌃⌘S para alternar a barra lateral
        }
    }
}
