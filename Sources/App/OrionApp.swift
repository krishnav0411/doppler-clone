import SwiftUI

@main
struct OrionApp: App {
    @StateObject private var library = MusicLibraryManager.shared
    @StateObject private var player = AudioPlayerEngine.shared

    var body: some Scene {
        WindowGroup {
            LibraryView(library: library, player: player)
        }
    }
}
