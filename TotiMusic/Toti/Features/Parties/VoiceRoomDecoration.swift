import UIKit

final class PulseRing: UIView {
  override init(frame: CGRect) {
    super.init(frame: frame)
    isUserInteractionEnabled = false
    backgroundColor = .clear
    layer.borderWidth = 1.5
    layer.borderColor = TotiTheme.coral.cgColor
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

  override func layoutSubviews() {
    super.layoutSubviews()
    layer.cornerRadius = 21
    layer.cornerCurve = .continuous
  }

  func start() {
    guard layer.animation(forKey: "glow") == nil, !UIAccessibility.isReduceMotionEnabled else {
      return
    }
    let anim = CABasicAnimation(keyPath: "opacity")
    anim.fromValue = 0.35
    anim.toValue = 0.95
    anim.duration = 1.15
    anim.autoreverses = true
    anim.repeatCount = .infinity
    layer.add(anim, forKey: "glow")
  }

  func stop() { layer.removeAnimation(forKey: "glow") }
}

final class FrameMarks: UIView {
  private let shape = CAShapeLayer()

  override init(frame: CGRect) {
    super.init(frame: frame)
    isUserInteractionEnabled = false
    backgroundColor = .clear
    shape.fillColor = nil
    shape.strokeColor = TotiTheme.plum.cgColor
    shape.lineWidth = 2
    shape.lineCap = .round
    layer.addSublayer(shape)
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

  override func layoutSubviews() {
    super.layoutSubviews()
    let rect = bounds.insetBy(dx: 1, dy: 1)
    let arm = min(14, rect.width * 0.16)
    let path = UIBezierPath()
    func corner(_ x: CGFloat, _ y: CGFloat, _ dx: CGFloat, _ dy: CGFloat) {
      path.move(to: CGPoint(x: x + dx * arm, y: y))
      path.addLine(to: CGPoint(x: x, y: y))
      path.addLine(to: CGPoint(x: x, y: y + dy * arm))
    }
    corner(rect.minX, rect.minY, 1, 1)
    corner(rect.maxX, rect.minY, -1, 1)
    corner(rect.minX, rect.maxY, 1, -1)
    corner(rect.maxX, rect.maxY, -1, -1)
    shape.frame = bounds
    shape.path = path.cgPath
  }
}

