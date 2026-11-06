import SwiftUI
import DopplerCore
import DopplerUI

@main
struct DopplerCloneApp: App {
    @StateObject private var library = MusicLibraryManager.shared
    @StateObject private var player = AudioPlayerEngine.shared

    var body: some Scene {
        WindowGroup {
            LibraryView(library: library, player: player)
        }
    }
}
