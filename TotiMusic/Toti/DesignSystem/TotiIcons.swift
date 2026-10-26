import UIKit

/// Interface icons are image-model drawings; brand artwork is supplied by the user.
/// The app never substitutes a system symbol.
enum TotiIcon: String, CaseIterable {
  static var wordmark: UIImage {
    (UIImage(named: "TotiWordmark") ?? UIImage()).withRenderingMode(.alwaysOriginal)
  }
  static var appMark: UIImage {
    (UIImage(named: "TotiMark") ?? UIImage()).withRenderingMode(.alwaysOriginal)
  }

  case lounge, notebook
  case search, live, shorts, voice, phrases, chats, me, settings, plus, close, back, forward
  case heart, heartOutline, heartFill, star, starFill, bookmark, comment, share, send, play, pause
  case flag, block, trash, logout
  case check, checkbox, checkboxOn, clock, filter, refresh, microphone, microphoneOff, microphoneIvory, microphoneOffIvory, speaker, muted, speakerIvory, mutedIvory, flip, phone, handset
  case video, gift, bellOff, unreadBadge
  case diamond, flower, balloon, music, crown, sparkle, photo, info, more, grid, eye

  func image(_ color: UIColor = TotiTheme.plum, size: CGFloat = 26, filled: Bool = false)
    -> UIImage
  {
    let name = self == .forward ? "back" : rawValue
    guard let source = UIImage(named: "TotiIcon-" + name) else { return UIImage() }
    let image: UIImage
    if self == .forward, let cg = source.cgImage {
      image = UIImage(cgImage: cg, scale: source.scale, orientation: .upMirrored)
    } else {
      image = source
    }
    let format = UIGraphicsImageRendererFormat()
    format.opaque = false
    return UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format)
      .image { _ in image.draw(in: CGRect(x: 0, y: 0, width: size, height: size)) }
      .withRenderingMode(.alwaysOriginal)
  }
}
