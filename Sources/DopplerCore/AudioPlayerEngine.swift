import Foundation
import AVFoundation
import MediaPlayer
import Combine

@MainActor
public final class AudioPlayerEngine: ObservableObject {
    public static let shared = AudioPlayerEngine()

    @Published public private(set) var currentTrack: Track?
    @Published public private(set) var isPlaying: Bool = false
    @Published public var currentTime: TimeInterval = 0
    @Published public var duration: TimeInterval = 0
    @Published public var queue: [Track] = []
    @Published public var currentIndex: Int = 0

    private var player: AVPlayer?
    private var timeObserverToken: Any?
    private var cancellables = Set<AnyCancellable>()

    public init() {
        configureAudioSession()
        setupRemoteCommands()
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("Failed to configure AVAudioSession: \(error)")
        }
    }

    public func play(tracks: [Track], startIndex: Int = 0) {
        guard !tracks.isEmpty, tracks.indices.contains(startIndex) else { return }
        self.queue = tracks
        self.currentIndex = startIndex
        loadAndPlay(track: tracks[startIndex])
    }

    public func playPauseToggle() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
        updateNowPlayingPlaybackInfo()
    }

    public func next() {
        guard currentIndex + 1 < queue.count else { return }
        currentIndex += 1
        loadAndPlay(track: queue[currentIndex])
    }

    public func previous() {
        if currentTime > 3.0 {
            seek(to: 0)
        } else if currentIndex > 0 {
            currentIndex -= 1
            loadAndPlay(track: queue[currentIndex])
        }
    }

    public func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime) { [weak self] _ in
            self?.updateNowPlayingPlaybackInfo()
        }
    }

    private func loadAndPlay(track: Track) {
        stop()
        self.currentTrack = track
        self.duration = track.duration

        let item = AVPlayerItem(url: track.url)
        self.player = AVPlayer(playerItem: item)

        setupTimeObserver()

        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: item)
            .sink { [weak self] _ in
                self?.next()
            }
            .store(in: &cancellables)

        player?.play()
        self.isPlaying = true
        updateNowPlayingMetadata(for: track)
    }

    private func stop() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        player?.pause()
        player = nil
        cancellables.removeAll()
    }

    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserverToken = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = time.seconds
        }
    }

    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.playPauseToggle()
            return .success
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.playPauseToggle()
            return .success
        }
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.next()
            return .success
        }
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.previous()
            return .success
        }
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let posEvent = event as? MPChangePlaybackPositionCommandEvent {
                self?.seek(to: posEvent.positionTime)
                return .success
            }
            return .commandFailed
        }
    }

    private func updateNowPlayingMetadata(for track: Track) {
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = track.title
        info[MPMediaItemPropertyArtist] = track.artist
        info[MPMediaItemPropertyAlbumTitle] = track.album
        info[MPMediaItemPropertyPlaybackDuration] = track.duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0.0
        info[MPNowPlayingInfoPropertyPlaybackRate] = 1.0

        if let artData = track.artworkData, let image = UIImage(data: artData) {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func updateNowPlayingPlaybackInfo() {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
