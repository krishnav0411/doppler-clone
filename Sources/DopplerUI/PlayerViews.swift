import SwiftUI
import DopplerCore

public struct MiniPlayerView: View {
    @ObservedObject var player: AudioPlayerEngine
    @Binding var showFullPlayer: Bool

    public init(player: AudioPlayerEngine, showFullPlayer: Binding<Bool>) {
        self.player = player
        self._showFullPlayer = showFullPlayer
    }

    public var body: some View {
        if let track = player.currentTrack {
            HStack(spacing: 12) {
                if let artData = track.artworkData, let uiImage = UIImage(data: artData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 44)
                        .cornerRadius(6)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 44, height: 44)
                        .overlay(Image(systemName: "music.note").foregroundColor(.secondary))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button(action: {
                    player.playPauseToggle()
                }) {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .foregroundColor(.primary)
                }
                .padding(.trailing, 8)

                Button(action: {
                    player.next()
                }) {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .cornerRadius(14)
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            .padding(.horizontal, 12)
            .onTapGesture {
                showFullPlayer = true
            }
        }
    }
}

public struct NowPlayingModalView: View {
    @ObservedObject var player: AudioPlayerEngine
    @Environment(\.dismiss) private var dismiss

    public init(player: AudioPlayerEngine) {
        self.player = player
    }

    public var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 12)

            Spacer()

            if let track = player.currentTrack {
                if let artData = track.artworkData, let uiImage = UIImage(data: artData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 280, height: 280)
                        .cornerRadius(16)
                        .shadow(radius: 12)
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 280, height: 280)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 80))
                                .foregroundColor(.secondary)
                        )
                }

                VStack(spacing: 6) {
                    Text(track.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    Text(track.artist)
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)

                VStack(spacing: 8) {
                    Slider(
                        value: Binding(
                            get: { player.currentTime },
                            set: { player.seek(to: $0) }
                        ),
                        in: 0...max(player.duration, 1)
                    )
                    .accentColor(.primary)

                    HStack {
                        Text(formatTime(player.currentTime))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("-" + formatTime(max(0, player.duration - player.currentTime)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 32)

                HStack(spacing: 48) {
                    Button(action: { player.previous() }) {
                        Image(systemName: "backward.fill")
                            .font(.title)
                    }

                    Button(action: { player.playPauseToggle() }) {
                        Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 64))
                    }

                    Button(action: { player.next() }) {
                        Image(systemName: "forward.fill")
                            .font(.title)
                    }
                }
                .foregroundColor(.primary)
            }

            Spacer()
        }
        .padding()
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
