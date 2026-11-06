import SwiftUI

public struct LibraryView: View {
    @ObservedObject var library: MusicLibraryManager
    @ObservedObject var player: AudioPlayerEngine
    @State private var showFullPlayer: Bool = false

    public init(library: MusicLibraryManager, player: AudioPlayerEngine) {
        self.library = library
        self.player = player
    }

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                List {
                    Section("Albums") {
                        ForEach(library.albums) { album in
                            NavigationLink(destination: AlbumDetailView(album: album, player: player)) {
                                HStack(spacing: 12) {
                                    if let artData = album.artworkData, let uiImage = UIImage(data: artData) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 50, height: 50)
                                            .cornerRadius(8)
                                    } else {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 50, height: 50)
                                            .overlay(Image(systemName: "music.note"))
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(album.name)
                                            .font(.headline)
                                        Text(album.artist)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }

                    Section("All Songs (\(library.tracks.count))") {
                        ForEach(Array(library.tracks.enumerated()), id: \.element.id) { index, track in
                            Button(action: {
                                player.play(tracks: library.tracks, startIndex: index)
                            }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(track.title)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        Text(track.artist)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if player.currentTrack?.id == track.id && player.isPlaying {
                                        Image(systemName: "waveform")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Doppler")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: {
                            Task {
                                await library.scanDocumentsDirectory()
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }

                MiniPlayerView(player: player, showFullPlayer: $showFullPlayer)
                    .padding(.bottom, 8)
            }
            .sheet(isPresented: $showFullPlayer) {
                NowPlayingModalView(player: player)
            }
            .task {
                await library.scanDocumentsDirectory()
            }
        }
    }
}

public struct AlbumDetailView: View {
    public let album: Album
    @ObservedObject var player: AudioPlayerEngine

    public init(album: Album, player: AudioPlayerEngine) {
        self.album = album
        self.player = player
    }

    public var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    if let artData = album.artworkData, let uiImage = UIImage(data: artData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 180, height: 180)
                            .cornerRadius(12)
                            .shadow(radius: 6)
                    }
                    Text(album.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(album.artist)
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            Section("Tracks") {
                ForEach(Array(album.tracks.enumerated()), id: \.element.id) { index, track in
                    Button(action: {
                        player.play(tracks: album.tracks, startIndex: index)
                    }) {
                        HStack {
                            Text("\(index + 1)")
                                .foregroundColor(.secondary)
                                .frame(width: 24, alignment: .leading)
                            Text(track.title)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
