import AVFoundation
import Combine
import UIKit

/// One player for the entire feed, including during partially visible pages.
@MainActor
final class ShortsPlayback: ObservableObject {
  @Published private(set) var player: AVPlayer?
  @Published private(set) var isPlaying = false
  @Published private(set) var isLoading = false
  @Published private(set) var isMuted = false
  @Published private(set) var progress = 0.0
  @Published private(set) var error: String?
  private var selectedID: UUID?
  private var active = false
  private var wantsPlayback = true
  private var statusObservation: NSKeyValueObservation?
  private var playbackObservation: NSKeyValueObservation?
  private var completionObserver: AnyCancellable?
  private var failureObserver: AnyCancellable?
  private var timeObserver: Any?
  private var duration = 1.0

  func select(_ video: LocalVideo, url: URL) {
    guard selectedID != video.id || player == nil else { return }
    stop()
    selectedID = video.id
    duration = video.duration
    wantsPlayback = true
    error = nil
    guard FileManager.default.fileExists(atPath: url.path) else {
      error = LocalLibraryError.missingVideo.localizedDescription
      return
    }
    let item = AVPlayerItem(url: url)
    let newPlayer = AVPlayer(playerItem: item)
    newPlayer.defaultRate = 1.0
    newPlayer.isMuted = isMuted
    newPlayer.actionAtItemEnd = .none
    player = newPlayer
    isLoading = true
    statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
      let status = item.status
      Task { @MainActor [weak self] in
        guard let self, self.player?.currentItem === item else { return }
        switch status {
        case .readyToPlay:
          self.isLoading = false
          self.applyPlaybackIntent()
        case .failed:
          self.isLoading = false
          self.error = "This video could not be played. Try again or choose another clip."
          self.player?.pause()
        default: break
        }
      }
    }
    playbackObservation = newPlayer.observe(\.timeControlStatus, options: [.initial, .new]) {
      [weak self] observed, _ in
      let status = observed.timeControlStatus
      Task { @MainActor [weak self] in
        guard let self, self.player === observed else { return }
        self.isPlaying = status == .playing
        if self.error == nil, observed.currentItem?.status == .readyToPlay {
          self.isLoading = status == .waitingToPlayAtSpecifiedRate
        }
      }
    }
    timeObserver = newPlayer.addPeriodicTimeObserver(
      forInterval: CMTime(seconds: 0.2, preferredTimescale: 600), queue: .main
    ) { [weak self, weak newPlayer] time in
      Task { @MainActor [weak self, weak newPlayer] in
        guard let self, let newPlayer, self.player === newPlayer, time.seconds.isFinite else {
          return
        }
        self.progress = min(max(time.seconds / self.duration, 0), 1)
      }
    }
    completionObserver = NotificationCenter.default.publisher(
      for: .AVPlayerItemDidPlayToEndTime, object: item
    )
    .receive(on: DispatchQueue.main).sink { [weak self, weak item] _ in
      guard let self, let item, self.player?.currentItem === item else { return }
      self.seek(to: 0)
    }
    failureObserver = NotificationCenter.default.publisher(
      for: .AVPlayerItemFailedToPlayToEndTime, object: item
    )
    .receive(on: DispatchQueue.main).sink { [weak self, weak item] _ in
      guard let self, let item, self.player?.currentItem === item else { return }
      self.error = "Playback stopped unexpectedly. Tap Retry to load the clip again."
      self.isLoading = false
      self.player?.pause()
    }
  }

  func setActive(_ value: Bool) {
    active = value
    applyPlaybackIntent()
  }

  func togglePlayback() {
    wantsPlayback.toggle()
    applyPlaybackIntent()
  }

  func toggleMuted() {
    isMuted.toggle()
    player?.isMuted = isMuted
  }

  func seek(to fraction: Double) {
    guard let player, error == nil else { return }
    player.seek(
      to: CMTime(seconds: min(max(fraction, 0), 1) * duration, preferredTimescale: 600),
      toleranceBefore: .zero, toleranceAfter: .zero
    ) { [weak self, weak player] finished in
      Task { @MainActor [weak self, weak player] in
        guard finished, let self, let player, self.player === player else { return }
        self.applyPlaybackIntent()
      }
    }
  }

  func stop() {
    active = false
    player?.pause()
    if let timeObserver { player?.removeTimeObserver(timeObserver) }
    timeObserver = nil
    statusObservation = nil
    playbackObservation = nil
    completionObserver = nil
    failureObserver = nil
    player?.replaceCurrentItem(with: nil)
    player = nil
    selectedID = nil
    isPlaying = false
    isLoading = false
    progress = 0
  }

  private func applyPlaybackIntent() {
    if active, wantsPlayback, error == nil, player?.currentItem?.status == .readyToPlay {
      player?.defaultRate = 1.0
      player?.play()
    } else {
      player?.pause()
    }
  }
}

final class VideoLayerView: UIView {
  override class var layerClass: AnyClass { AVPlayerLayer.self }
  var videoLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
