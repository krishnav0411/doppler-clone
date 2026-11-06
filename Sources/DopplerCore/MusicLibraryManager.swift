import Foundation
import AVFoundation

@MainActor
public final class MusicLibraryManager: ObservableObject {
    public static let shared = MusicLibraryManager()

    @Published public private(set) var tracks: [Track] = []
    @Published public private(set) var albums: [Album] = []
    @Published public private(set) var isScanning: Bool = false

    private let supportedExtensions = ["mp3", "m4a", "flac", "wav", "aac", "alac"]

    public init() {}

    public func scanDocumentsDirectory() async {
        isScanning = true
        defer { isScanning = false }

        guard let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }

        let fileURLs = enumerateAudioFiles(in: docsURL)
        var parsedTracks: [Track] = []

        for url in fileURLs {
            if let track = await parseTrack(at: url) {
                parsedTracks.append(track)
            }
        }

        self.tracks = parsedTracks
        self.albums = groupIntoAlbums(tracks: parsedTracks)
    }

    private func enumerateAudioFiles(in directory: URL) -> [URL] {
        var results: [URL] = []
        let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        while let fileURL = enumerator?.nextObject() as? URL {
            if supportedExtensions.contains(fileURL.pathExtension.lowercased()) {
                results.append(fileURL)
            }
        }
        return results
    }

    private func parseTrack(at url: URL) async -> Track? {
        let asset = AVURLAsset(url: url)
        do {
            let durationTime = try await asset.load(.duration)
            let duration = CMTimeGetSeconds(durationTime)
            guard duration > 0 else { return nil }

            let commonMetadata = try await asset.load(.commonMetadata)

            var title: String = url.deletingPathExtension().lastPathComponent
            var artist: String = "Unknown Artist"
            var album: String = "Unknown Album"
            var artworkData: Data? = nil

            for item in commonMetadata {
                guard let key = item.commonKey?.rawValue else { continue }
                switch key {
                case AVMetadataKey.commonKeyTitle.rawValue:
                    title = try await item.load(.stringValue) ?? title
                case AVMetadataKey.commonKeyArtist.rawValue:
                    artist = try await item.load(.stringValue) ?? artist
                case AVMetadataKey.commonKeyAlbumName.rawValue:
                    album = try await item.load(.stringValue) ?? album
                case AVMetadataKey.commonKeyArtwork.rawValue:
                    artworkData = try await item.load(.dataValue)
                default:
                    break
                }
            }

            return Track(
                url: url,
                title: title,
                artist: artist,
                album: album,
                duration: duration,
                artworkData: artworkData
            )
        } catch {
            print("Error parsing track at \(url): \(error)")
            return nil
        }
    }

    private func groupIntoAlbums(tracks: [Track]) -> [Album] {
        let grouped = Dictionary(grouping: tracks, by: { "\($0.album)__\($0.artist)" })
        return grouped.map { _, albumTracks in
            let sample = albumTracks.first!
            return Album(name: sample.album, artist: sample.artist, tracks: albumTracks)
        }.sorted { $0.name < $1.name }
    }
}
