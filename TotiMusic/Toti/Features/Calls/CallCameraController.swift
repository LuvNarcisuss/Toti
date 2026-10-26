import AVFoundation
import Combine
import Foundation

/// Owns only a video input. No audio input, recording output or network transport.
@MainActor
final class CallCameraController: ObservableObject {
    enum State: Equatable { case idle, loading, ready, denied, restricted, unavailable, failed, interrupted }
    @Published private(set) var state: State = .idle
    @Published private(set) var frontFacing = true
    private let capture = CallCameraSession()
    private var generation = 0
    private var active = false
    var session: AVCaptureSession { capture.session }

    func start() {
        active = true
        generation += 1
        let request = generation
        state = .loading
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: startAuthorized(front: frontFacing, request: request)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    guard let self, self.active, self.generation == request else { return }
                    if granted { self.startAuthorized(front: self.frontFacing, request: request) }
                    else { self.state = .denied }
                }
            }
        case .denied: state = .denied
        case .restricted: state = .restricted
        @unknown default: state = .unavailable
        }
    }

    func flip() {
        guard active, state == .ready else { return }
        generation += 1
        state = .loading
        startAuthorized(front: !frontFacing, request: generation)
    }

    func stop() {
        active = false
        generation += 1
        capture.stop()
        state = .idle
    }

    func interrupted() {
        guard active else { return }
        generation += 1
        state = .interrupted
        capture.stop()
    }

    func interruptionEnded() {
        if active { start() }
    }

    func failed() {
        guard active else { return }
        generation += 1
        state = .failed
        capture.stop()
    }

    private func startAuthorized(front: Bool, request: Int) {
        capture.start(front: front) { [weak self] result in
            Task { @MainActor in
                guard let self, self.active, self.generation == request else { return }
                self.state = result
                if result == .ready { self.frontFacing = front }
            }
        }
    }

    deinit { capture.stop() }
}

/// All session configuration and start/stop work runs on this serial queue.
private final class CallCameraSession {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "Toti.call-camera")

    func start(front: Bool, completion: @escaping (CallCameraController.State) -> Void) {
        queue.async { [self] in
            let position: AVCaptureDevice.Position = front ? .front : .back
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
                if session.isRunning { session.stopRunning() }
                completion(.unavailable)
                return
            }
            do {
                let input = try AVCaptureDeviceInput(device: device)
                session.beginConfiguration()
                if session.canSetSessionPreset(.high) { session.sessionPreset = .high }
                let previous = session.inputs
                previous.forEach { session.removeInput($0) }
                guard session.canAddInput(input) else {
                    previous.filter { session.canAddInput($0) }.forEach { session.addInput($0) }
                    session.commitConfiguration()
                    if session.isRunning { session.stopRunning() }
                    completion(.failed)
                    return
                }
                session.addInput(input)
                session.commitConfiguration()
                if !session.isRunning { session.startRunning() }
                completion(session.isInterrupted ? .interrupted : (session.isRunning ? .ready : .failed))
            } catch {
                if session.isRunning { session.stopRunning() }
                completion(.failed)
            }
        }
    }

    func stop() {
        queue.async { [self] in
            if session.isRunning { session.stopRunning() }
            session.beginConfiguration()
            session.inputs.forEach { session.removeInput($0) }
            session.commitConfiguration()
        }
    }
}
