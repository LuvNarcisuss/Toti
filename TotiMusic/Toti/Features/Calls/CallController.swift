import AVFoundation
import Combine
import UIKit

/// Call presentation and local camera preview only; no remote call transport or audio capture.
final class CallController: TotiScreen {
  private let name: String, asset: String?, video: Bool
  private let camera = CallCameraController(), surface = CallCameraSurface(),
    stateLabel = label("", 17, .white)
  private var active = false, microphoneOn = true, speakerOn = true
  private let mic = UIButton(type: .custom), speaker = UIButton(type: .custom)
  init(store: AppStore, name: String, asset: String?, video: Bool) {
    self.name = name
    self.asset = asset
    self.video = video
    super.init(store: store)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  override func build() {
    view.backgroundColor = TotiTheme.ink
    view.accessibilityIdentifier = video ? "call.video" : "call.voice"
    let portrait = asset ?? (store.isOnlineMode ? "TotiMark" : ArtistPortraits.asset(forName: name))
    let background = TotiPhoto(asset: portrait)
    view.addSubview(background)
    background.pin(to: view)
    let blur = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    view.addSubview(blur)
    blur.pin(to: view)
    if video {
      surface.cameraLayer.session = camera.session
      surface.cameraLayer.videoGravity = .resizeAspectFill
      view.addSubview(surface)
      surface.pin(to: view)
    }
    let identity = stack(spacing: 20)
    identity.alignment = .center
    if !video {
      identity.addArrangedSubview(TotiPhoto(asset: portrait, size: 140, round: true))
    }
    let mode = label(video ? "Video call" : "Voice call", 16, .white)
    mode.accessibilityIdentifier = "call.mode"
    identity.addArrangedSubview(mode)
    identity.addArrangedSubview(label(name, 30, .white, title: true))
    stateLabel.accessibilityIdentifier = "call.status"
    stateLabel.textAlignment = .center
    identity.addArrangedSubview(stateLabel)
    view.addSubview(identity)
    identity.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      identity.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      identity.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 90),
      identity.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -32),
    ])
    let close = iconButton(.close, "Close", color: .white) { [weak self] in
      self?.dismiss(animated: true)
    }
    view.addSubview(close)
    close.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      close.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
      close.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
    ])
    let controls = UIStackView()
    controls.axis = .horizontal
    controls.spacing = 18
    controls.distribution = .fillEqually
    configure(mic, icon: .microphone, name: "Microphone")
    mic.addAction(
      UIAction { [weak self] _ in
        self?.microphoneOn.toggle()
        self?.updateControls()
      }, for: .touchUpInside)
    configure(speaker, icon: .speaker, name: "Speaker")
    speaker.addAction(
      UIAction { [weak self] _ in
        self?.speakerOn.toggle()
        self?.updateControls()
      }, for: .touchUpInside)
    let end = UIButton(type: .custom)
    configure(end, icon: .phone, name: "End call")
    end.backgroundColor = TotiTheme.pink
    end.addAction(UIAction { [weak self] _ in self?.dismiss(animated: true) }, for: .touchUpInside)
    soften(mic)
    soften(speaker)
    soften(end)
    [mic, end, speaker].forEach { controls.addArrangedSubview($0) }
    view.addSubview(controls)
    controls.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      controls.leadingAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 28),
      controls.trailingAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -28),
      controls.bottomAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -18),
      controls.heightAnchor.constraint(equalToConstant: 72),
    ])
    if video {
      let flip = iconButton(.flip, "Flip camera", color: .white) { [weak self] in
        self?.camera.flip()
      }
      view.addSubview(flip)
      flip.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        flip.trailingAnchor.constraint(
          equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
        flip.topAnchor.constraint(equalTo: close.topAnchor),
      ])
      let retry = actionButton("Camera options", icon: .settings) { [weak self] in
        self?.cameraOptions()
      }
      view.addSubview(retry)
      retry.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        retry.leadingAnchor.constraint(
          equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
        retry.trailingAnchor.constraint(
          equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
        retry.bottomAnchor.constraint(equalTo: controls.topAnchor, constant: -20),
      ])
      camera.objectWillChange.receive(on: DispatchQueue.main).sink { [weak self] _ in
        self?.updateCamera()
      }.store(in: &tokens)
      NotificationCenter.default.publisher(
        for: AVCaptureSession.wasInterruptedNotification, object: camera.session
      ).receive(on: DispatchQueue.main).sink { [weak self] _ in self?.camera.interrupted() }.store(
        in: &tokens)
      NotificationCenter.default.publisher(
        for: AVCaptureSession.interruptionEndedNotification, object: camera.session
      ).receive(on: DispatchQueue.main).sink { [weak self] _ in self?.camera.interruptionEnded() }
        .store(in: &tokens)
      NotificationCenter.default.publisher(
        for: AVCaptureSession.runtimeErrorNotification, object: camera.session
      ).receive(on: DispatchQueue.main).sink { [weak self] _ in self?.camera.failed() }.store(
        in: &tokens)
    }
    NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification).sink {
      [weak self] _ in self?.camera.stop()
    }.store(in: &tokens)
    NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification).sink {
      [weak self] _ in if self?.active == true && self?.video == true { self?.camera.start() }
    }.store(in: &tokens)
    stateLabel.text = ""
    updateControls()
  }
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.setNavigationBarHidden(true, animated: false)
  }
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    active = true
    if video { camera.start() }
  }
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    active = false
    camera.stop()
  }
  private func configure(_ b: UIButton, icon: TotiIcon, name: String) {
    b.setImage(icon.image(size: 42), for: .normal)
    b.backgroundColor = UIColor.white.withAlphaComponent(0.85)
    b.rounded(24)
    b.accessibilityLabel = name
  }
  private func updateControls() {
    let lit = TotiTheme.coral
    let dimmed = UIColor.white.withAlphaComponent(0.35)
    mic.setImage((microphoneOn ? TotiIcon.microphone : .microphoneOff).image(size: 42), for: .normal)
    speaker.setImage((speakerOn ? TotiIcon.speaker : .muted).image(size: 42), for: .normal)
    mic.backgroundColor = microphoneOn ? lit : dimmed
    speaker.backgroundColor = speakerOn ? lit : dimmed
    mic.accessibilityValue = microphoneOn ? "On" : "Off"
    speaker.accessibilityValue = speakerOn ? "On" : "Off"
  }
  private func updateCamera() {
    surface.frontFacing = camera.frontFacing
    surface.setNeedsLayout()
    switch camera.state {
    case .idle, .ready: stateLabel.text = ""
    case .loading: stateLabel.text = "Opening camera…"
    case .denied: stateLabel.text = "Allow camera access in Settings."
    case .restricted: stateLabel.text = "Camera access is restricted."
    case .unavailable: stateLabel.text = "Camera is unavailable on this device."
    case .failed: stateLabel.text = "The camera could not be opened."
    case .interrupted: stateLabel.text = "Camera paused."
    }
  }
  private func cameraOptions() {
    let retry = actionButton("Try again", icon: .refresh, primary: true) { [weak self] in
      self?.dismissCard { self?.camera.start() }
    }
    let settings = actionButton("Settings", icon: .settings) { [weak self] in
      self?.dismissCard {
        if let url = URL(string: UIApplication.openSettingsURLString) {
          UIApplication.shared.open(url)
        }
      }
    }
    let cancel = actionButton("Cancel") { [weak self] in self?.dismissCard() }
    showCard([label("Camera", 22, title: true), retry, settings, cancel])
  }
}
