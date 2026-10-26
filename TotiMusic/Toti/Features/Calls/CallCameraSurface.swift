import AVFoundation
import UIKit

final class CallCameraSurface: UIView {
  override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
  var cameraLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
  var frontFacing = true

  override func layoutSubviews() {
    super.layoutSubviews()
    guard let connection = cameraLayer.connection else { return }
    let interface = window?.windowScene?.interfaceOrientation
    if #available(iOS 17.0, *) {
      let angle: CGFloat
      switch interface {
      case .landscapeLeft: angle = 0
      case .landscapeRight: angle = 180
      case .portraitUpsideDown: angle = 270
      default: angle = 90
      }
      if connection.isVideoRotationAngleSupported(angle) { connection.videoRotationAngle = angle }
    } else if connection.isVideoOrientationSupported {
      let orientation: AVCaptureVideoOrientation
      switch interface {
      case .landscapeLeft: orientation = .landscapeRight
      case .landscapeRight: orientation = .landscapeLeft
      case .portraitUpsideDown: orientation = .portraitUpsideDown
      default: orientation = .portrait
      }
      connection.videoOrientation = orientation
    }
    if connection.isVideoMirroringSupported {
      connection.automaticallyAdjustsVideoMirroring = false
      connection.isVideoMirrored = frontFacing
    }
  }
}
