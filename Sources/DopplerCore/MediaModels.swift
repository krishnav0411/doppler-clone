import Foundation
import SwiftUI

public struct Track: Identifiable, Hashable, Codable {
    public let id: UUID
    public let url: URL
    public let title: String
    public let artist: String
    public let album: String
    public let duration: TimeInterval
    public let trackNumber: Int?
    public let artworkData: Data?

    public init(
        id: UUID = UUID(),
        url: URL,
        title: String,
        artist: String,
        album: String,
        duration: TimeInterval,
        trackNumber: Int? = nil,
        artworkData: Data? = nil
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.trackNumber = trackNumber
        self.artworkData = artworkData
    }
}

public struct Album: Identifiable, Hashable, Codable {
    public let id: UUID
    public let name: String
    public let artist: String
    public var tracks: [Track]
    public var artworkData: Data? {
        tracks.first(where: { $0.artworkData != nil })?.artworkData
    }

    public init(id: UUID = UUID(), name: String, artist: String, tracks: [Track] = []) {
        self.id = id
        self.name = name
        self.artist = artist
        self.tracks = tracks
    }
}

public struct Playlist: Identifiable, Hashable, Codable {
    public let id: UUID
    public var name: String
    public var trackIDs: [UUID]

    public init(id: UUID = UUID(), name: String, trackIDs: [UUID] = []) {
        self.id = id
        self.name = name
        self.trackIDs = trackIDs
    }
}
