import AVFoundation
import Combine
import Foundation

@MainActor
final class LocalVideoPlayback: ObservableObject {
    @Published private(set) var player: AVPlayer?
    @Published private(set) var error: String?
    @Published private(set) var isLoading = false
    @Published private(set) var isPlaying = false
    @Published private(set) var isMuted = false
    private var wantsPlayback = false
    private var reachedEnd = false
    private var statusObservation: NSKeyValueObservation?
    private var playbackObservation: NSKeyValueObservation?
    private var failureObserver: AnyCancellable?
    private var completionObserver: AnyCancellable?

    func prepare(url: URL, autoplay: Bool = true) {
        stop()
        error = nil
        guard FileManager.default.fileExists(atPath: url.path) else {
            error = LocalLibraryError.missingVideo.localizedDescription
            return
        }
        isLoading = true
        wantsPlayback = autoplay
        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.defaultRate = 1.0
        newPlayer.isMuted = isMuted
        player = newPlayer
        // Start when ready; pause/stop cancels pending autoplay and loop restarts.
        statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            let status = item.status
            Task { @MainActor [weak self] in
                guard let self, self.player?.currentItem === item else { return }
                switch status {
                case .readyToPlay:
                    self.isLoading = false
                    self.playIfRequested()
                case .failed:
                    self.isLoading = false
                    self.error = "This video could not be played. Try again or import a different file."
                    self.pause()
                default: break
                }
            }
        }
        playbackObservation = newPlayer.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] observed, _ in
            let playing = observed.timeControlStatus == .playing
            Task { @MainActor [weak self] in
                guard let self, self.player === observed else { return }
                self.isPlaying = playing
            }
        }
        completionObserver = NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: item)
            .receive(on: DispatchQueue.main).sink { [weak self, weak item] _ in
                guard let self, let item, self.player?.currentItem === item else { return }
                self.reachedEnd = true
                if self.wantsPlayback { self.restartLoop() }
            }
        failureObserver = NotificationCenter.default.publisher(for: .AVPlayerItemFailedToPlayToEndTime, object: item)
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak item] _ in
                guard let self, let item, self.player?.currentItem === item else { return }
                self.error = "Playback stopped unexpectedly. Try again."
                self.isLoading = false
                self.pause()
            }
    }

    func togglePlayback() {
        guard error == nil, !isLoading, player?.currentItem?.status == .readyToPlay else { return }
        if wantsPlayback { pause() }
        else {
            wantsPlayback = true
            if reachedEnd { restartLoop() }
            else { playIfRequested() }
        }
    }

    func toggleMuted() {
        isMuted.toggle()
        player?.isMuted = isMuted
    }

    private func restartLoop() {
        guard error == nil, wantsPlayback, let player else { return }
        player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self, weak player] finished in
            Task { @MainActor [weak self, weak player] in
                guard finished, let self, let player, self.player === player else { return }
                self.reachedEnd = false
                self.playIfRequested()
            }
        }
    }

    private func playIfRequested() {
        guard wantsPlayback, error == nil, player?.currentItem?.status == .readyToPlay else { return }
        player?.defaultRate = 1.0
        player?.playImmediately(atRate: 1.0)
    }

    func pause() {
        wantsPlayback = false
        player?.pause()
        isPlaying = false
    }

    func stop() {
        pause()
        statusObservation = nil
        playbackObservation = nil
        failureObserver = nil
        completionObserver = nil
        player?.replaceCurrentItem(with: nil)
        player = nil
        isLoading = false
        reachedEnd = false
    }
}
