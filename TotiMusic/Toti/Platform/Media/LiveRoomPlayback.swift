import AVFoundation
import Combine
import Foundation

@MainActor
final class LiveRoomPlayback: ObservableObject {
  @Published private(set) var player: AVPlayer?
  @Published private(set) var loading = false
  @Published private(set) var failure: String?
  @Published private(set) var muted = false
  @Published private(set) var pausedByUser = false
  private var source: LiveMediaSource?
  private var active = false
  private var atEnd = false
  private var readyObservation: NSKeyValueObservation?
  private var waitingObservation: NSKeyValueObservation?
  private var endObserver: AnyCancellable?
  private var failureObserver: AnyCancellable?
  private var startupTask: Task<Void, Never>?

  func prepare(_ media: LiveRoomMedia) {
    guard source != media.source else { return }
    stop()
    source = media.source
    failure = nil
    pausedByUser = false
    guard let url = media.source.url else { return }
    switch media.source {
    case .local:
      guard url.isFileURL, FileManager.default.fileExists(atPath: url.path) else {
        failure = "This video is unavailable."
        return
      }
    case .remote:
      guard url.scheme?.lowercased() == "https" else {
        failure = "Use an HTTPS video address."
        return
      }
    case .coverOnly: return
    }
    loading = true
    let item = AVPlayerItem(url: url)
    let created = AVPlayer(playerItem: item)
    created.defaultRate = 1
    created.isMuted = muted
    player = created
    startupTask = Task { [weak self, weak created] in
      do { try await Task.sleep(for: .seconds(20)) } catch { return }
      guard let self, let created, self.player === created,
        created.currentItem?.status != .readyToPlay
      else { return }
      self.fail("The video took too long to load.")
    }
    readyObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
      Task { @MainActor [weak self] in
        guard let self, self.player?.currentItem === item else { return }
        switch item.status {
        case .readyToPlay:
          self.startupTask?.cancel()
          self.startupTask = nil
          self.loading = false
          self.applyIntent()
        case .failed: self.fail("Unable to load this video.")
        default: break
        }
      }
    }
    waitingObservation = created.observe(\.timeControlStatus, options: [.new]) {
      [weak self] observed, _ in
      Task { @MainActor [weak self] in
        guard let self, self.player === observed, self.failure == nil else { return }
        self.loading = observed.timeControlStatus == .waitingToPlayAtSpecifiedRate
      }
    }
    endObserver = NotificationCenter.default.publisher(
      for: .AVPlayerItemDidPlayToEndTime, object: item
    )
    .receive(on: DispatchQueue.main).sink { [weak self, weak item] _ in
      guard let self, let item, self.player?.currentItem === item else { return }
      self.atEnd = true
      self.applyIntent()
    }
    failureObserver = NotificationCenter.default.publisher(
      for: .AVPlayerItemFailedToPlayToEndTime, object: item
    )
    .receive(on: DispatchQueue.main).sink { [weak self, weak item] _ in
      guard let self, let item, self.player?.currentItem === item else { return }
      self.fail("Playback was interrupted.")
    }
  }

  func setActive(_ value: Bool) {
    active = value
    applyIntent()
  }
  func togglePause() {
    pausedByUser.toggle()
    applyIntent()
  }
  func toggleMute() {
    muted.toggle()
    player?.isMuted = muted
  }
  func retry(_ media: LiveRoomMedia, active: Bool) {
    source = nil
    prepare(media)
    setActive(active)
  }

  private func applyIntent() {
    guard active, !pausedByUser, failure == nil, let player,
      player.currentItem?.status == .readyToPlay
    else {
      player?.pause()
      return
    }
    if atEnd {
      atEnd = false
      player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) {
        [weak self, weak player] finished in
        Task { @MainActor [weak self, weak player] in
          guard finished, let self, let player, self.player === player else { return }
          self.applyIntent()
        }
      }
    } else {
      player.defaultRate = 1
      player.play()
    }
  }

  private func fail(_ text: String) {
    startupTask?.cancel()
    startupTask = nil
    failure = text
    loading = false
    player?.pause()
  }
  func stop() {
    active = false
    player?.pause()
    startupTask?.cancel()
    startupTask = nil
    readyObservation = nil
    waitingObservation = nil
    endObserver = nil
    failureObserver = nil
    player?.replaceCurrentItem(with: nil)
    player = nil
    source = nil
    loading = false
    atEnd = false
  }
}
