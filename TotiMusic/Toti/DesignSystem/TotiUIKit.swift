import Combine
import CoreText
import ImageIO
import UIKit

enum TotiTheme {
  static let background = UIColor(red: 255 / 255, green: 248 / 255, blue: 241 / 255, alpha: 1)
  static let ink = UIColor(red: 42 / 255, green: 28 / 255, blue: 53 / 255, alpha: 1)
  static let plum = UIColor(red: 57 / 255, green: 35 / 255, blue: 79 / 255, alpha: 1)
  static let coral = UIColor(red: 255 / 255, green: 147 / 255, blue: 111 / 255, alpha: 1)
  static let muted = UIColor(red: 108 / 255, green: 87 / 255, blue: 116 / 255, alpha: 1)
  static let pink = UIColor(red: 1, green: 0.24, blue: 0.43, alpha: 1)
  static let soft = UIColor(red: 247 / 255, green: 237 / 255, blue: 243 / 255, alpha: 1)
  static let line = UIColor(red: 227 / 255, green: 210 / 255, blue: 225 / 255, alpha: 1)
  static let dangerInk = UIColor(red: 0.55, green: 0.16, blue: 0.22, alpha: 1)
  static let dangerFill = UIColor(red: 1, green: 0.90, blue: 0.91, alpha: 1)
  static let textFace = "TetoRhythm-Text"
  static let displayFace = "TetoRhythm-Display"
  private static let registerFaces: Void = {
    for name in [textFace, displayFace] {
      guard UIFont(name: name, size: 16) == nil else { continue }
      let url = Bundle.main.url(forResource: name, withExtension: "ttf")
      if let url {
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
      }
    }
  }()
  static func font(_ size: CGFloat = 16, title: Bool = false) -> UIFont {
    _ = registerFaces
    let name = title ? displayFace : textFace
    let face = UIFont(name: name, size: size) ?? UIFont(name: textFace, size: size)
    let base = face ?? UIFont(name: displayFace, size: size)!
    return UIFontMetrics(forTextStyle: title ? .title2 : .body).scaledFont(for: base)
  }
}

final class StudioCanvas: UIView {
  private let wash = CAGradientLayer()
  private let ribbon = CAShapeLayer()
  override init(frame: CGRect) {
    super.init(frame: frame)
    isUserInteractionEnabled = false
    isAccessibilityElement = false
    backgroundColor = TotiTheme.background
    clipsToBounds = true
    wash.colors = [
      UIColor(red: 0.94, green: 0.88, blue: 0.98, alpha: 1).cgColor,
      UIColor(red: 1, green: 0.96, blue: 0.92, alpha: 1).cgColor,
      TotiTheme.background.cgColor,
      UIColor(red: 1, green: 0.91, blue: 0.86, alpha: 1).cgColor,
    ]
    wash.locations = [0, 0.14, 0.62, 1]
    wash.startPoint = CGPoint(x: 0.5, y: 0)
    wash.endPoint = CGPoint(x: 0.5, y: 1)
    layer.addSublayer(wash)
    ribbon.fillColor = TotiTheme.coral.withAlphaComponent(0.10).cgColor
    layer.addSublayer(ribbon)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  override func layoutSubviews() {
    super.layoutSubviews()
    // Resize the background with the page, without implicit layer animations.
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    wash.frame = bounds
    ribbon.frame = bounds
    let w = bounds.width
    let h = bounds.height
    let p = UIBezierPath()
    p.move(to: CGPoint(x: w, y: h * 0.1))
    p.addCurve(
      to: CGPoint(x: 0, y: h * 0.65), controlPoint1: CGPoint(x: -w * 0.7, y: h * 0.1),
      controlPoint2: CGPoint(x: w * 1.5, y: h * 0.6))
    p.addCurve(
      to: CGPoint(x: w, y: h * 0.2), controlPoint1: CGPoint(x: w * 1.7, y: h * 0.8),
      controlPoint2: CGPoint(x: -w * 0.5, y: h * 0.15))
    p.close()
    ribbon.path = p.cgPath
    CATransaction.commit()
  }
}

extension UIView {
  func pin(to other: UIView, insets: UIEdgeInsets = .zero) {
    translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      leadingAnchor.constraint(equalTo: other.leadingAnchor, constant: insets.left),
      trailingAnchor.constraint(equalTo: other.trailingAnchor, constant: -insets.right),
      topAnchor.constraint(equalTo: other.topAnchor, constant: insets.top),
      bottomAnchor.constraint(equalTo: other.bottomAnchor, constant: -insets.bottom),
    ])
  }
  func rounded(_ radius: CGFloat = 18) {
    layer.cornerRadius = radius
    clipsToBounds = true
  }
  func height(_ value: CGFloat) { heightAnchor.constraint(equalToConstant: value).isActive = true }
}
@MainActor func label(
  _ text: String, _ size: CGFloat = 16, _ color: UIColor = TotiTheme.ink, title: Bool = false
) -> UILabel {
  let l = UILabel()
  l.text = text
  l.font = TotiTheme.font(size, title: title)
  l.textColor = color
  l.numberOfLines = 0
  l.adjustsFontForContentSizeCategory = true
  return l
}
@MainActor func stack(
  _ views: [UIView] = [], axis: NSLayoutConstraint.Axis = .vertical, spacing: CGFloat = 12
) -> UIStackView {
  let s = UIStackView(arrangedSubviews: views)
  s.axis = axis
  s.spacing = spacing
  return s
}
@MainActor func iconButton(
  _ icon: TotiIcon, _ name: String, color: UIColor = TotiTheme.plum, size: CGFloat = 26,
  action: @escaping () -> Void
) -> UIButton {
  let b = UIButton(type: .custom)
  b.setImage(icon.image(color, size: size), for: .normal)
  b.accessibilityLabel = name
  b.translatesAutoresizingMaskIntoConstraints = false
  b.widthAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
  b.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
  b.addAction(UIAction { _ in action() }, for: .touchUpInside)
  soften(b)
  return b
}
/// The 34-point Toti mark used at the top left of each root tab.
@MainActor func totiMark() -> UIView {
  let holder = UIView()
  holder.translatesAutoresizingMaskIntoConstraints = false
  holder.isAccessibilityElement = true
  holder.accessibilityLabel = "Toti"
  let logo = UIImageView(image: TotiIcon.appMark)
  logo.contentMode = .scaleAspectFill
  logo.clipsToBounds = true
  logo.layer.cornerRadius = 8
  logo.layer.cornerCurve = .continuous
  logo.isAccessibilityElement = false
  holder.addSubview(logo)
  logo.pin(to: holder)
  NSLayoutConstraint.activate([
    holder.widthAnchor.constraint(equalToConstant: 34),
    holder.heightAnchor.constraint(equalToConstant: 34),
  ])
  return holder
}
/// Custom icons stay bare. iOS 26 otherwise draws a shared glass plate behind a bar button.
@MainActor func barButton(_ view: UIView) -> UIBarButtonItem {
  let item = UIBarButtonItem(customView: view)
  if #available(iOS 26.0, *) {
    item.hidesSharedBackground = true
    item.sharesBackground = false
  }
  return item
}
/// Adjacent navigation actions share one item to avoid UIKit's extra inter-item gap.
@MainActor func compactBarButtons(_ buttons: [UIButton]) -> UIBarButtonItem {
  let row = stack(buttons, axis: .horizontal, spacing: 0)
  row.alignment = .center
  for button in buttons {
    button.widthAnchor.constraint(equalToConstant: 44).isActive = true
    button.heightAnchor.constraint(equalToConstant: 44).isActive = true
  }
  return barButton(row)
}
@MainActor func soften(_ button: UIButton) {
  button.addAction(
    UIAction { [weak button] _ in
      guard !UIAccessibility.isReduceMotionEnabled else { return }
      UIView.animate(withDuration: 0.12, delay: 0, options: [.allowUserInteraction, .curveEaseOut]) {
        button?.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
      }
    }, for: .touchDown)
  button.addAction(
    UIAction { [weak button] _ in
      UIView.animate(
        withDuration: 0.32, delay: 0, usingSpringWithDamping: 0.62, initialSpringVelocity: 0.7,
        options: [.allowUserInteraction]
      ) {
        button?.transform = .identity
      }
    }, for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
}
enum StudioTone { case primary, quiet, coral, pink, danger }

/// Painted control. UIButton configuration adopts the system button chrome, so actions draw their own fill, type, and icon.
final class StudioButton: UIControl {
  var isGroupedRow = false { didSet { paint() } }
  let caption = UILabel()
  let iconView = UIImageView()
  private let tone: StudioTone
  private let compact: Bool
  private let vertical: Bool
  private let iconSize: CGFloat
  private let sidePad: CGFloat
  private let verticalPad: CGFloat
  init(
    title: String, icon: UIImage?, tone: StudioTone, axis: NSLayoutConstraint.Axis = .horizontal,
    compact: Bool = false, iconSize: CGFloat = 23
  ) {
    self.tone = tone
    self.compact = compact
    self.vertical = axis == .vertical
    self.iconSize = iconSize
    self.sidePad = compact ? 14 : 16
    self.verticalPad = compact ? 8 : 13
    super.init(frame: .zero)
    caption.text = title
    caption.font = TotiTheme.font(compact ? 14 : 16)
    caption.numberOfLines = 0
    caption.textAlignment = axis == .vertical || icon == nil ? .center : .natural
    caption.adjustsFontForContentSizeCategory = true
    iconView.image = icon
    iconView.contentMode = .scaleAspectFit
    iconView.isHidden = icon == nil
    let row = UIStackView(arrangedSubviews: [iconView, caption])
    row.axis = axis
    row.spacing = axis == .vertical ? 8 : 10
    row.alignment = .center
    row.isUserInteractionEnabled = false
    addSubview(row)
    row.translatesAutoresizingMaskIntoConstraints = false
    let pad = verticalPad
    let side = sidePad
    let pins = [
      row.topAnchor.constraint(equalTo: topAnchor, constant: pad),
      row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -pad),
      row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: side),
      row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -side),
    ]
    if axis == .vertical {
      caption.numberOfLines = 2
      caption.adjustsFontSizeToFitWidth = true
      caption.minimumScaleFactor = 0.7
    }
    NSLayoutConstraint.activate(pins)
    if icon != nil {
      iconView.widthAnchor.constraint(equalToConstant: iconSize).isActive = true
      iconView.heightAnchor.constraint(equalToConstant: iconSize).isActive = true
    }
    layer.cornerRadius = compact ? 16 : 22
    layer.cornerCurve = .continuous
    clipsToBounds = true
    if !compact {
      heightAnchor.constraint(greaterThanOrEqualToConstant: axis == .vertical ? 108 : 48).isActive = true
    }
    if compact {
      setContentHuggingPriority(.required, for: .horizontal)
      setContentCompressionResistancePriority(.required, for: .horizontal)
    } else if axis == .vertical {
      setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
      caption.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }
    paint()
    addTarget(self, action: #selector(pressDown), for: .touchDown)
    addTarget(self, action: #selector(pressUp), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
    isAccessibilityElement = true
    accessibilityTraits = .button
    accessibilityLabel = title.replacingOccurrences(of: "\n", with: ", ")
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  override var intrinsicContentSize: CGSize {
    let text = caption.intrinsicContentSize
    let icon = iconView.isHidden ? 0 : iconSize + 10
    let width = ceil(text.width + icon + sidePad * 2)
    let minimum: CGFloat = compact ? 36 : (vertical ? 108 : 48)
    let extra: CGFloat = vertical && !iconView.isHidden ? iconSize + 8 : 0
    let height = max(minimum, ceil(text.height + verticalPad * 2 + extra))
    return CGSize(width: max(width, 72), height: height)
  }
  override var isEnabled: Bool {
    didSet {
      alpha = isEnabled ? 1 : 0.45
      if isEnabled {
        accessibilityTraits.remove(.notEnabled)
      } else {
        accessibilityTraits.insert(.notEnabled)
      }
    }
  }
  private func paint() {
    let fill: UIColor
    let ink: UIColor
    switch tone {
    case .primary:
      fill = TotiTheme.plum
      ink = .white
    case .quiet:
      fill = UIColor.white.withAlphaComponent(0.86)
      ink = TotiTheme.ink
    case .coral:
      fill = TotiTheme.coral
      ink = TotiTheme.ink
    case .pink:
      fill = TotiTheme.pink
      ink = .white
    case .danger:
      fill = TotiTheme.dangerFill
      ink = TotiTheme.dangerInk
    }
    backgroundColor = isGroupedRow ? .clear : fill
    caption.textColor = ink
    layer.cornerRadius = isGroupedRow ? 0 : (compact ? 16 : 22)
    layer.borderWidth = !isGroupedRow && tone == .quiet ? 1 : 0
    layer.borderColor = TotiTheme.line.cgColor
  }
  @objc private func pressDown() {
    guard isEnabled, !UIAccessibility.isReduceMotionEnabled else { return }
    UIView.animate(withDuration: 0.12, delay: 0, options: [.allowUserInteraction, .curveEaseOut]) {
      self.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
    }
  }
  @objc private func pressUp() {
    UIView.animate(
      withDuration: 0.32, delay: 0, usingSpringWithDamping: 0.62, initialSpringVelocity: 0.7,
      options: [.allowUserInteraction]
    ) { self.transform = .identity }
  }
}

@MainActor func actionButton(
  _ text: String, icon: TotiIcon? = nil, primary: Bool = false, tone: StudioTone? = nil,
  axis: NSLayoutConstraint.Axis = .horizontal, compact: Bool = false, iconSize: CGFloat = 23,
  action: @escaping () -> Void
) -> StudioButton {
  let resolved = tone ?? (primary ? .primary : .quiet)
  let iconColor: UIColor
  switch resolved {
  case .primary, .pink: iconColor = .white
  case .danger: iconColor = TotiTheme.dangerInk
  case .quiet, .coral: iconColor = TotiTheme.plum
  }
  let button = StudioButton(
    title: text, icon: icon?.image(iconColor, size: iconSize), tone: resolved, axis: axis,
    compact: compact, iconSize: iconSize)
  button.addAction(UIAction { _ in action() }, for: .touchUpInside)
  return button
}

/// Italic word with a lime stroke. Replaces the system navigation title.
final class StudioTitle: UIView {
  private let caption = UILabel()
  private let mark = UIView()
  init(_ text: String) {
    super.init(frame: CGRect(x: 0, y: 0, width: 88, height: 34))
    isAccessibilityElement = true
    accessibilityTraits = .header
    caption.font = TotiTheme.font(18, title: true)
    caption.textColor = TotiTheme.ink
    caption.textAlignment = .center
    caption.adjustsFontSizeToFitWidth = true
    caption.minimumScaleFactor = 0.65
    caption.lineBreakMode = .byTruncatingTail
    mark.backgroundColor = TotiTheme.coral
    mark.layer.cornerRadius = 1.5
    addSubview(caption)
    addSubview(mark)
    setText(text)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  func setText(_ text: String) {
    caption.text = text
    accessibilityLabel = text
    let width = min(220, max(72, caption.intrinsicContentSize.width + 8))
    frame.size = CGSize(width: width, height: 34)
    bounds.size = frame.size
    invalidateIntrinsicContentSize()
    setNeedsLayout()
  }
  override var intrinsicContentSize: CGSize { CGSize(width: bounds.width > 1 ? bounds.width : 88, height: 34) }
  override func layoutSubviews() {
    super.layoutSubviews()
    caption.frame = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height - 7)
    mark.frame = CGRect(x: (bounds.width - 22) / 2, y: bounds.height - 4, width: 22, height: 3)
  }
}

/// Horizontal pills for short choices. Replaces the system segmented control.
final class StudioChoice: UIView {
  private(set) var index: Int
  var onChange: ((Int) -> Void)?
  private var chips: [StudioChip] = []
  init(items: [String], index: Int = 0) {
    self.index = min(max(0, index), max(0, items.count - 1))
    super.init(frame: .zero)
    let scroller = UIScrollView()
    scroller.showsHorizontalScrollIndicator = false
    scroller.alwaysBounceHorizontal = true
    let row = UIStackView()
    row.axis = .horizontal
    row.spacing = 8
    row.alignment = .center
    addSubview(scroller)
    scroller.addSubview(row)
    scroller.translatesAutoresizingMaskIntoConstraints = false
    row.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      scroller.leadingAnchor.constraint(equalTo: leadingAnchor),
      scroller.trailingAnchor.constraint(equalTo: trailingAnchor),
      scroller.topAnchor.constraint(equalTo: topAnchor),
      scroller.bottomAnchor.constraint(equalTo: bottomAnchor),
      heightAnchor.constraint(equalToConstant: 44),
      row.leadingAnchor.constraint(equalTo: scroller.contentLayoutGuide.leadingAnchor),
      row.trailingAnchor.constraint(equalTo: scroller.contentLayoutGuide.trailingAnchor),
      row.topAnchor.constraint(equalTo: scroller.contentLayoutGuide.topAnchor),
      row.bottomAnchor.constraint(equalTo: scroller.contentLayoutGuide.bottomAnchor),
      row.heightAnchor.constraint(equalTo: scroller.frameLayoutGuide.heightAnchor),
    ])
    for (offset, title) in items.enumerated() {
      let chip = StudioChip(title, multiline: false)
      chip.addAction(UIAction { [weak self] _ in self?.select(offset) }, for: .touchUpInside)
      row.addArrangedSubview(chip)
      chips.append(chip)
    }
    restyle()
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  func updateTitles(_ titles: [String]) {
    guard titles.count == chips.count else { return }
    for (chip, title) in zip(chips, titles) { chip.updateTitle(title) }
  }
  private func select(_ next: Int) {
    guard chips.indices.contains(next) else { return }
    index = next
    restyle()
    onChange?(next)
  }
  private func restyle() {
    for (offset, chip) in chips.enumerated() {
      chip.apply(selected: offset == index)
    }
  }
}

/// Full-width choice rows for longer labels.
final class StudioOptions: UIStackView {
  private(set) var index: Int
  var onChange: ((Int) -> Void)?
  private var chips: [StudioChip] = []
  init(items: [String], index: Int = 0) {
    self.index = min(max(0, index), max(0, items.count - 1))
    super.init(frame: .zero)
    axis = .vertical
    spacing = 8
    for (offset, title) in items.enumerated() {
      let chip = StudioChip(title, multiline: true)
      chip.addAction(UIAction { [weak self] _ in self?.select(offset) }, for: .touchUpInside)
      addArrangedSubview(chip)
      chips.append(chip)
    }
    restyle()
  }
  // UIStackView's coder initializer is non-failable, unlike UIView.
  required init(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  private func select(_ next: Int) {
    guard chips.indices.contains(next) else { return }
    index = next
    restyle()
    onChange?(next)
  }
  private func restyle() {
    for (offset, chip) in chips.enumerated() {
      chip.apply(selected: offset == index)
    }
  }
}

final class StudioChip: UIControl {
  private let caption = UILabel()
  init(_ text: String, multiline: Bool) {
    super.init(frame: .zero)
    caption.text = text
    caption.font = TotiTheme.font(14)
    caption.numberOfLines = multiline ? 0 : 1
    caption.textAlignment = multiline ? .natural : .center
    caption.adjustsFontForContentSizeCategory = true
    caption.isUserInteractionEnabled = false
    addSubview(caption)
    caption.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      caption.topAnchor.constraint(equalTo: topAnchor, constant: 10),
      caption.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
      caption.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
      caption.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
      heightAnchor.constraint(greaterThanOrEqualToConstant: 40),
    ])
    layer.cornerRadius = 20
    layer.cornerCurve = .continuous
    clipsToBounds = true
    isAccessibilityElement = true
    accessibilityLabel = text
    accessibilityTraits = .button
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  func updateTitle(_ title: String) {
    if accessibilityIdentifier == nil { accessibilityIdentifier = caption.text }
    caption.text = title
    accessibilityLabel = title
    invalidateIntrinsicContentSize()
  }
  func apply(selected: Bool) {
    backgroundColor = selected ? TotiTheme.coral : UIColor.white.withAlphaComponent(0.86)
    caption.textColor = selected ? TotiTheme.ink : TotiTheme.muted
    layer.borderWidth = selected ? 0 : 1
    layer.borderColor = TotiTheme.line.cgColor
    accessibilityTraits = selected ? [.button, .selected] : .button
  }
}

/// Painted toggle. Replaces the system switch.
final class StudioSwitch: UIControl {
  var isOn = false {
    didSet {
      accessibilityValue = isOn ? "On" : "Off"
      setNeedsLayout()
    }
  }
  private let track = UIView()
  private let knob = UIView()
  override init(frame: CGRect) {
    super.init(frame: frame)
    track.isUserInteractionEnabled = false
    knob.isUserInteractionEnabled = false
    knob.backgroundColor = .white
    knob.layer.cornerRadius = 12
    addSubview(track)
    addSubview(knob)
    addTarget(self, action: #selector(toggle), for: .touchUpInside)
    isAccessibilityElement = true
    accessibilityLabel = "Switch"
    accessibilityTraits = .button
    accessibilityValue = "Off"
    translatesAutoresizingMaskIntoConstraints = false
    widthAnchor.constraint(equalToConstant: 52).isActive = true
    heightAnchor.constraint(equalToConstant: 32).isActive = true
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  override func layoutSubviews() {
    super.layoutSubviews()
    track.frame = bounds
    track.layer.cornerRadius = bounds.height / 2
    let x: CGFloat = isOn ? bounds.width - 28 : 4
    knob.frame = CGRect(x: x, y: 4, width: 24, height: 24)
    track.backgroundColor = isOn ? TotiTheme.plum : TotiTheme.soft
    track.layer.borderWidth = 1
    track.layer.borderColor = (isOn ? TotiTheme.plum : TotiTheme.line).cgColor
  }
  @objc private func toggle() {
    isOn.toggle()
    sendActions(for: .valueChanged)
    guard !UIAccessibility.isReduceMotionEnabled else { return }
    UIView.animate(withDuration: 0.22, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.4) {
      self.layoutIfNeeded()
    }
  }
}

/// Icon stacked over a count. Used on the video rail, without a system button label.
final class StudioCounter: UIControl {
  let iconView = UIImageView()
  private let caption = UILabel()
  init(name: String) {
    super.init(frame: .zero)
    iconView.contentMode = .scaleAspectFit
    caption.font = TotiTheme.font(12)
    caption.textColor = .white
    caption.textAlignment = .center
    caption.isUserInteractionEnabled = false
    iconView.isUserInteractionEnabled = false
    let column = UIStackView(arrangedSubviews: [iconView, caption])
    column.axis = .vertical
    column.alignment = .center
    column.spacing = 2
    column.isUserInteractionEnabled = false
    addSubview(column)
    column.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      column.topAnchor.constraint(equalTo: topAnchor),
      column.bottomAnchor.constraint(equalTo: bottomAnchor),
      column.leadingAnchor.constraint(equalTo: leadingAnchor),
      column.trailingAnchor.constraint(equalTo: trailingAnchor),
      iconView.widthAnchor.constraint(equalToConstant: 32),
      iconView.heightAnchor.constraint(equalToConstant: 32),
      widthAnchor.constraint(greaterThanOrEqualToConstant: 48),
      heightAnchor.constraint(greaterThanOrEqualToConstant: 52),
    ])
    accessibilityLabel = name
    accessibilityTraits = .button
    addTarget(self, action: #selector(pressDown), for: .touchDown)
    addTarget(self, action: #selector(pressUp), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  func setIcon(_ image: UIImage?) { iconView.image = image }
  /// Lets a long count stay inside a narrow live-room control.
  func compressCount() {
    caption.adjustsFontSizeToFitWidth = true
    caption.minimumScaleFactor = 0.6
  }
  /// Hides the number under the icon. The control keeps its name for accessibility.
  func hideCount() {
    caption.isHidden = true
    caption.text = nil
    for constraint in constraints where constraint.firstAttribute == .height
      && constraint.relation == .greaterThanOrEqual && constraint.secondItem == nil
    {
      constraint.constant = 36
    }
  }
  func setCount(_ text: String, selected: Bool) {
    caption.textColor = selected ? TotiTheme.coral : .white
    if caption.isHidden {
      accessibilityValue = selected ? "Selected" : nil
      return
    }
    caption.text = text
    accessibilityValue = text + (selected ? ", selected" : "")
  }
  @objc private func pressDown() {
    guard !UIAccessibility.isReduceMotionEnabled else { return }
    UIView.animate(withDuration: 0.12, delay: 0, options: [.allowUserInteraction]) {
      self.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
    }
  }
  @objc private func pressUp() {
    UIView.animate(
      withDuration: 0.32, delay: 0, usingSpringWithDamping: 0.62, initialSpringVelocity: 0.7,
      options: [.allowUserInteraction]
    ) { self.transform = .identity }
  }
}
@MainActor func field(_ placeholder: String, text: String = "") -> UITextField {
  let f = UITextField()
  f.placeholder = placeholder
  f.text = text
  f.font = TotiTheme.font()
  f.textColor = TotiTheme.ink
  f.backgroundColor = .white
  f.layer.cornerRadius = 14
  f.height(52)
  let pad = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 10))
  f.leftView = pad
  f.leftViewMode = .always
  f.autocorrectionType = .no
  f.accessibilityLabel = placeholder
  return f
}
/// Review feedback is visible only on an owner's existing editing surfaces.
@MainActor func mediaReviewNotice(status: String?, feedback: String?) -> UIView? {
  guard let status, status != "approved" else { return nil }
  let text = status == "rejected"
    ? "Photo not approved. Only you can see this preview. Choose another photo to request review."
    : "Photo awaiting review. Only you can see this preview until it is approved."
  var views: [UIView] = [label(text, 13, status == "rejected" ? TotiTheme.dangerInk : TotiTheme.muted)]
  if let feedback, !feedback.isEmpty { views.append(label(feedback, 13, TotiTheme.muted)) }
  return stack(views, spacing: 6)
}

/// A portrait that is present in the asset catalog. Missing names fall back to a stable photograph.
@MainActor func portraitAsset(_ asset: String?, personID: String) -> String {
  if let asset {
    if TotiPhoto.mediaRevision(in: asset) != nil { return asset }
    let mapped = MusicPhotography.avatar(asset)
    if UIImage(named: mapped) != nil { return mapped }
  }
  let fallback = MusicPhotography.creatorAvatar(for: personID)
  if UIImage(named: fallback) != nil { return fallback }
  return "Portrait1"
}

/// Group artwork is composed from actual members, never the first member alone.
@MainActor func conversationPortrait(_ conversation: MusicConversation, size: CGFloat) -> UIView {
  guard conversation.kind == .group else {
    return roundPortrait(
      asset: conversation.avatars.first ?? conversation.creator?.avatarAsset,
      size: size, personID: conversation.creator?.id ?? conversation.id)
  }
  var seen = Set<String>()
  let assets = Array(conversation.avatars.map { MusicPhotography.avatar($0) }
    .filter { (TotiPhoto.mediaRevision(in: $0) != nil || UIImage(named: $0) != nil) && seen.insert($0).inserted }.prefix(9))
  let frame = UIView()
  frame.translatesAutoresizingMaskIntoConstraints = false
  frame.backgroundColor = TotiTheme.soft
  frame.layer.cornerRadius = size * 0.22
  frame.layer.cornerCurve = .continuous
  frame.layer.borderWidth = 2
  frame.layer.borderColor = TotiTheme.plum.cgColor
  frame.clipsToBounds = true
  frame.isAccessibilityElement = true
  frame.accessibilityLabel = conversation.name + ", group members"
  NSLayoutConstraint.activate([
    frame.widthAnchor.constraint(equalToConstant: size),
    frame.heightAnchor.constraint(equalToConstant: size),
  ])
  if assets.isEmpty {
    let mark = UIImageView(image: TotiIcon.chats.image(size: size * 0.55))
    mark.contentMode = .scaleAspectFit
    mark.translatesAutoresizingMaskIntoConstraints = false
    mark.isAccessibilityElement = false
    frame.addSubview(mark)
    NSLayoutConstraint.activate([
      mark.centerXAnchor.constraint(equalTo: frame.centerXAnchor),
      mark.centerYAnchor.constraint(equalTo: frame.centerYAnchor),
      mark.widthAnchor.constraint(equalToConstant: size * 0.55),
      mark.heightAnchor.constraint(equalTo: mark.widthAnchor),
    ])
    return frame
  }
  let columns = assets.count <= 4 ? 2 : 3
  let rows = max(1, (assets.count + columns - 1) / columns)
  let gap: CGFloat = 2
  let inset: CGFloat = 4
  let tile = (size - 2 * inset - CGFloat(columns - 1) * gap) / CGFloat(columns)
  let top = (size - CGFloat(rows) * tile - CGFloat(rows - 1) * gap) / 2
  for (index, asset) in assets.enumerated() {
    let row = index / columns
    let countInRow = min(columns, assets.count - row * columns)
    let left = (size - CGFloat(countInRow) * tile - CGFloat(countInRow - 1) * gap) / 2
    let photo = TotiPhoto(asset: asset)
    photo.translatesAutoresizingMaskIntoConstraints = false
    photo.layer.cornerRadius = 2
    photo.clipsToBounds = true
    photo.isAccessibilityElement = false
    frame.addSubview(photo)
    NSLayoutConstraint.activate([
      photo.leadingAnchor.constraint(equalTo: frame.leadingAnchor,
        constant: left + CGFloat(index % columns) * (tile + gap)),
      photo.topAnchor.constraint(equalTo: frame.topAnchor, constant: top + CGFloat(row) * (tile + gap)),
      photo.widthAnchor.constraint(equalToConstant: tile),
      photo.heightAnchor.constraint(equalToConstant: tile),
    ])
  }
  return frame
}

/// Circular portrait with an evergreen frame for an individual account.
@MainActor func roundPortrait(
  asset: String?, size: CGFloat, personID: String = "dancer", image: UIImage? = nil
) -> UIView {
  let ring = UIView()
  ring.translatesAutoresizingMaskIntoConstraints = false
  ring.backgroundColor = TotiTheme.coral.withAlphaComponent(0.45)
  ring.layer.cornerRadius = size / 2
  ring.layer.borderWidth = 2
  ring.layer.borderColor = TotiTheme.plum.cgColor
  ring.clipsToBounds = true
  let photo = TotiPhoto(
    asset: image == nil ? portraitAsset(asset, personID: personID) : nil, size: size - 6, round: true)
  if let image { photo.image = image }
  ring.addSubview(photo)
  NSLayoutConstraint.activate([
    ring.widthAnchor.constraint(equalToConstant: size),
    ring.heightAnchor.constraint(equalToConstant: size),
    photo.centerXAnchor.constraint(equalTo: ring.centerXAnchor),
    photo.centerYAnchor.constraint(equalTo: ring.centerYAnchor),
  ])
  return ring
}

final class TotiPhoto: UIImageView {
  private static let coverCache: NSCache<NSURL, UIImage> = {
    let cache = NSCache<NSURL, UIImage>()
    cache.countLimit = 48
    return cache
  }()
  private var request: UUID?
  private var mediaTask: Task<Void, Never>?
  private var mediaRevision: UUID?
  private var mediaGeneration: Int?
  private var accountObservation: AnyCancellable?

  static func mediaRevision(in asset: String?) -> UUID? {
    guard let asset, asset.hasPrefix("remote-media:") else { return nil }
    return UUID(uuidString: String(asset.dropFirst("remote-media:".count)))
  }

  init(asset: String? = nil, size: CGFloat? = nil, round: Bool = false) {
    super.init(frame: .zero)
    contentMode = .scaleAspectFill
    clipsToBounds = true
    backgroundColor = TotiTheme.soft
    if let asset { configure(asset: asset) }
    if let size {
      translatesAutoresizingMaskIntoConstraints = false
      widthAnchor.constraint(equalToConstant: size).isActive = true
      height(size)
      layer.cornerRadius = round ? size / 2 : 14
    }
    isAccessibilityElement = false
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  deinit { mediaTask?.cancel() }

  /// References contain only a revision ID; the backend authorizes every read.
  func configure(asset: String?) {
    cancelImageLoad()
    accountObservation = nil
    mediaRevision = Self.mediaRevision(in: asset)
    guard let mediaRevision else {
      image = asset.flatMap { UIImage(named: MusicPhotography.avatar($0)) }
      return
    }
    mediaGeneration = TotiBackend.shared.generation
    image = TotiIcon.photo.image(size: 40)
    accountObservation = TotiBackend.shared.$generation.dropFirst().sink { [weak self] _ in
      self?.cancelImageLoad()
      self?.mediaRevision = nil
      self?.image = TotiIcon.photo.image(size: 40)
    }
    if window != nil { loadMedia(mediaRevision) }
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    if window == nil, mediaRevision != nil { cancelImageLoad() }
    else if let mediaRevision { loadMedia(mediaRevision) }
  }

  private func cancelImageLoad() {
    request = nil
    mediaTask?.cancel()
    mediaTask = nil
  }

  private func loadMedia(_ revision: UUID) {
    cancelImageLoad()
    let backend = TotiBackend.shared
    let generation = backend.generation
    guard generation == mediaGeneration else { return }
    let id = UUID()
    request = id
    mediaTask = Task { [weak self] in
      do {
        let bytes = try await backend.mediaImage(revisionID: revision)
        guard !Task.isCancelled, generation == backend.generation,
              let self, self.request == id, self.window != nil,
              let image = UIImage(data: bytes) else { return }
        self.image = image
      } catch {
        guard !Task.isCancelled, generation == backend.generation,
              let self, self.request == id else { return }
        self.image = TotiIcon.photo.image(size: 40)
      }
    }
  }

  func load(_ url: URL?) {
    cancelImageLoad()
    mediaRevision = nil
    accountObservation = nil
    let id = UUID()
    request = id
    guard let url else {
      image = TotiIcon.photo.image(size: 64)
      return
    }
    let key = url as NSURL
    if let cached = Self.coverCache.object(forKey: key) {
      image = cached
      return
    }
    image = TotiIcon.photo.image(size: 64)
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      let loaded = CoverDecoding.image(at: url)
      DispatchQueue.main.async {
        guard let self, self.request == id else { return }
        if let loaded {
          Self.coverCache.setObject(loaded, forKey: key)
          self.image = loaded
        }
      }
    }
  }
}

/// Downsamples a cover off the main thread so the first screen can paint without waiting for a tap.
private enum CoverDecoding {
  static func image(at url: URL) -> UIImage? {
    let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
    guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else { return nil }
    let options = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceThumbnailMaxPixelSize: 720,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceShouldCacheImmediately: true,
    ] as CFDictionary
    guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
    return UIImage(cgImage: cgImage)
  }
}

/// A short note on the window. It leaves by itself and does not ask for a tap.
@MainActor enum StudioNotice {
  private static var hide: DispatchWorkItem?
  private static var token = 0
  private static let tag = 814_022

  static func show(_ text: String, seconds: TimeInterval = 3, in window: UIWindow? = nil) {
    let host = window
      ?? UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first { $0.activationState == .foregroundActive }?
        .windows.first { $0.isKeyWindow }
    guard let host else { return }
    token += 1
    let current = token
    hide?.cancel()
    host.viewWithTag(tag)?.removeFromSuperview()
    let box = UIView()
    box.tag = tag
    box.isUserInteractionEnabled = false
    box.backgroundColor = TotiTheme.background
    box.layer.cornerRadius = 18
    box.layer.cornerCurve = .continuous
    box.layer.shadowColor = TotiTheme.ink.cgColor
    box.layer.shadowOpacity = 0.16
    box.layer.shadowRadius = 16
    box.layer.shadowOffset = CGSize(width: 0, height: 8)
    box.accessibilityViewIsModal = false
    box.isAccessibilityElement = true
    box.accessibilityLabel = text
    let title = label(text, 17, TotiTheme.ink, title: true)
    title.textAlignment = .center
    title.isAccessibilityElement = false
    title.translatesAutoresizingMaskIntoConstraints = false
    box.addSubview(title)
    box.translatesAutoresizingMaskIntoConstraints = false
    host.addSubview(box)
    NSLayoutConstraint.activate([
      title.topAnchor.constraint(equalTo: box.topAnchor, constant: 14),
      title.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -14),
      title.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 22),
      title.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -22),
      box.centerXAnchor.constraint(equalTo: host.centerXAnchor),
      box.centerYAnchor.constraint(equalTo: host.centerYAnchor, constant: -24),
      box.leadingAnchor.constraint(greaterThanOrEqualTo: host.leadingAnchor, constant: 32),
      box.trailingAnchor.constraint(lessThanOrEqualTo: host.trailingAnchor, constant: -32),
    ])
    host.bringSubviewToFront(box)
    box.alpha = 0
    box.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
    UIAccessibility.post(notification: .announcement, argument: text)
    UIView.animate(withDuration: 0.2, delay: 0, options: [.allowUserInteraction]) {
      box.alpha = 1
      box.transform = .identity
    }
    let work = DispatchWorkItem {
      guard current == token else { return }
      hide = nil
      UIView.animate(withDuration: 0.25, delay: 0, options: [.allowUserInteraction]) {
        box.alpha = 0
      } completion: { _ in
        box.removeFromSuperview()
      }
    }
    hide = work
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
  }
}

/// Keeps the actual destination page in the transition container for both directions.
@MainActor private final class StudioExpansionTransition: NSObject, UIViewControllerTransitioningDelegate {
  weak var source: UIView?

  init(source: UIView) { self.source = source }

  func animationController(forPresented presented: UIViewController, presenting: UIViewController,
    source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
    StudioExpansionAnimator(source: self.source, opening: true)
  }

  func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
    StudioExpansionAnimator(source: source, opening: false)
  }
}

@MainActor private final class StudioExpansionAnimator: NSObject, UIViewControllerAnimatedTransitioning {
  private weak var source: UIView?
  private let opening: Bool

  init(source: UIView?, opening: Bool) {
    self.source = source
    self.opening = opening
  }

  func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
    UIAccessibility.isReduceMotionEnabled ? 0 : 0.48
  }

  func animateTransition(using context: UIViewControllerContextTransitioning) {
    let container = context.containerView
    let key: UITransitionContextViewControllerKey = opening ? .to : .from
    guard let controller = context.viewController(forKey: key),
      let page = context.view(forKey: opening ? .to : .from) else {
      context.completeTransition(false)
      return
    }
    let frame = opening ? context.finalFrame(for: controller) : context.initialFrame(for: controller)
    guard frame.width > 0, frame.height > 0 else {
      context.completeTransition(false)
      return
    }
    if !opening, let behind = context.view(forKey: .to), behind.superview == nil {
      if let destination = context.viewController(forKey: .to) {
        behind.frame = context.finalFrame(for: destination)
      }
      container.insertSubview(behind, at: 0)
      behind.layoutIfNeeded()
    }

    let originalParent = page.superview
    let originalIndex = originalParent?.subviews.firstIndex(of: page)
    let wrapper = UIView(frame: frame)
    wrapper.backgroundColor = TotiTheme.background
    container.addSubview(wrapper)
    page.transform = .identity
    page.frame = wrapper.bounds
    wrapper.addSubview(page)
    page.setNeedsLayout()
    page.layoutIfNeeded()

    let target: CGRect
    if let source, source.window != nil {
      let rect = source.convert(source.bounds, to: container)
      target = rect.width > 2 && rect.height > 2 ? rect
        : CGRect(x: frame.midX - 26, y: frame.maxY - 90, width: 52, height: 52)
    } else {
      target = CGRect(x: frame.midX - 26, y: frame.maxY - 90, width: 52, height: 52)
    }
    let small = CGAffineTransform(translationX: target.midX - frame.midX, y: target.midY - frame.midY)
      .scaledBy(x: target.width / frame.width, y: target.height / frame.height)
    // A layer mask remains effective even when a screen allows its artwork to overflow.
    let mask = CAShapeLayer()
    let round = UIBezierPath(roundedRect: wrapper.bounds, cornerRadius: min(frame.width, frame.height) / 2).cgPath
    let square = UIBezierPath(roundedRect: wrapper.bounds, cornerRadius: 0).cgPath
    mask.frame = wrapper.bounds
    mask.path = opening ? round : square
    wrapper.layer.mask = mask
    wrapper.transform = opening ? small : .identity

    let duration = transitionDuration(using: context)
    if duration > 0 {
      let shape = CABasicAnimation(keyPath: "path")
      shape.fromValue = opening ? round : square
      shape.toValue = opening ? square : round
      shape.duration = duration
      shape.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
      mask.path = opening ? square : round
      mask.add(shape, forKey: "studio.expansion.shape")
    }
    UIView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: 0.96,
      initialSpringVelocity: 0.15, options: [.curveEaseInOut]) {
      wrapper.transform = self.opening ? .identity : small
    } completion: { _ in
      let cancelled = context.transitionWasCancelled
      if self.opening && !cancelled {
        page.frame = frame
        container.addSubview(page)
      } else if cancelled, let originalParent, let originalIndex {
        page.frame = frame
        originalParent.insertSubview(page, at: min(originalIndex, originalParent.subviews.count))
      } else {
        page.removeFromSuperview()
      }
      wrapper.removeFromSuperview()
      context.completeTransition(!cancelled)
    }
  }
}

@MainActor class TotiScreen: UIViewController, UIAdaptivePresentationControllerDelegate {
  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    onDismiss?()
  }
  let store: AppStore
  let accountGeneration = TotiBackend.shared.generation
  var isAccountContextCurrent: Bool { !store.isOnlineMode || accountGeneration == TotiBackend.shared.generation }
  var tokens = Set<AnyCancellable>()
  var onDismiss: (() -> Void)?
  /// The control this screen grew from. Closing shrinks back to it.
  weak var collapseTarget: UIView?
  // UIViewController keeps transitioningDelegate weak; the destination owns its delegate.
  private var expansionTransition: StudioExpansionTransition?
  private let canvas = StudioCanvas()
  private var shownNotice: UUID?
  private var cardLayer: UIView?
  private var cardDismiss: (() -> Void)?
  var activeSearch: ExpandingSearchBar?
  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    if isBeingDismissed || navigationController?.isBeingDismissed == true { onDismiss?() }
  }
  init(store: AppStore, title: String = "") {
    self.store = store
    super.init(nibName: nil, bundle: nil)
    self.title = title
    // The background extends beneath system bars; content keeps its safe-area constraints.
    edgesForExtendedLayout = .all
    extendedLayoutIncludesOpaqueBars = true
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = TotiTheme.background
    view.clipsToBounds = false
    canvas.frame = view.bounds
    canvas.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    canvas.isUserInteractionEnabled = false
    view.addSubview(canvas)
    overrideUserInterfaceStyle = .light
    build()
    refresh()
    store.objectWillChange.receive(on: DispatchQueue.main).sink { [weak self] _ in
      guard let self else { return }
      self.refresh()
      self.installStudioChrome()
      if let notice = self.store.notice, notice.id != self.shownNotice, self.view.window != nil,
        self.presentedViewController == nil
      {
        self.shownNotice = notice.id
        self.message(notice.message, title: notice.title)
        self.store.notice = nil
      }
    }
    .store(in: &tokens)
  }
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    installStudioChrome()
  }
  /// Custom title and back control. The system title and back button stay out of the bar.
  func installStudioChrome() {
    guard let nav = navigationController, !nav.isNavigationBarHidden else { return }
    nav.navigationBar.prefersLargeTitles = false
    navigationItem.largeTitleDisplayMode = .never
    if !(navigationItem.titleView is BubbleTrack) {
      let text = title ?? ""
      if text.isEmpty {
        if navigationItem.titleView is StudioTitle { navigationItem.titleView = nil }
      } else if let studio = navigationItem.titleView as? StudioTitle {
        studio.setText(text)
      } else if navigationItem.titleView == nil {
        navigationItem.titleView = StudioTitle(text)
      }
    }
    let rooted = nav.viewControllers.first === self
    if !rooted, navigationItem.leftBarButtonItem == nil {
      navigationItem.hidesBackButton = true
      navigationItem.leftBarButtonItem = barButton(
        iconButton(.back, "Back") { [weak self] in
          self?.navigationController?.popViewController(animated: true)
        })
    }
  }
  func build() {}
  func refresh() {}
  /// Artwork frame covering the physical screen, including the status bar and home indicator.
  /// Sheets stay inside their own bounds so the artwork does not spill over the page behind them.
  func coverFrame() -> CGRect {
    let style = navigationController?.modalPresentationStyle ?? modalPresentationStyle
    if style == .pageSheet || style == .formSheet || style == .popover || style == .custom { return view.bounds }
    guard let window = view.window else { return view.bounds }
    return view.convert(window.bounds, from: window)
  }
  func insertAtmosphere(_ extra: UIView) {
    extra.isUserInteractionEnabled = false
    view.insertSubview(extra, aboveSubview: canvas)
  }
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    var node: UIView? = view
    while let current = node, !(current is UIWindow) {
      current.clipsToBounds = false
      node = current.superview
    }
    canvas.frame = coverFrame()
  }
  func presentScreen(
    _ screen: UIViewController, full: Bool = false, animated: Bool = true, collapseTo: UIView? = nil
  ) {
    let nav = TotiNavigationController(rootViewController: screen)
    TotiNavigation.style(nav)
    if full {
      nav.modalPresentationStyle = .fullScreen
    } else {
      nav.modalPresentationStyle = .pageSheet
      nav.sheetPresentationController?.detents = [.medium(), .large()]
      nav.sheetPresentationController?.prefersGrabberVisible = true
      nav.presentationController?.delegate = screen as? UIAdaptivePresentationControllerDelegate
    }
    if let collapseTo, let toti = screen as? TotiScreen {
      toti.collapseTarget = collapseTo
      if full, collapseTo.window != nil {
        let transition = StudioExpansionTransition(source: collapseTo)
        toti.expansionTransition = transition
        nav.modalPresentationStyle = .custom
        nav.transitioningDelegate = transition
      }
    }
    screen.navigationItem.leftBarButtonItem = barButton(
      iconButton(.close, "Close") { [weak screen] in
        if let toti = screen as? TotiScreen {
          toti.dismissCollapsed()
        } else {
          screen?.dismiss(animated: true)
        }
      })
    TotiNavigation.prepare(nav, in: view.window?.bounds ?? view.bounds)
    present(nav, animated: animated)
  }
  /// Shrinks the whole presented page into the control that opened it.
  func dismissCollapsed() {
    let presented = navigationController ?? self
    if expansionTransition != nil {
      view.endEditing(true)
      presented.dismiss(animated: !UIAccessibility.isReduceMotionEnabled)
      return
    }
    let notify = onDismiss
    let target = collapseTarget
    guard target != nil else {
      presented.dismiss(animated: true) { notify?() }
      return
    }
    guard !UIAccessibility.isReduceMotionEnabled, let host = presented.view.window else {
      presented.dismiss(animated: false) { notify?() }
      return
    }
    let start = presented.view.convert(presented.view.bounds, to: host)
    guard let snapshot = presented.view.snapshotView(afterScreenUpdates: false) else {
      // Keep the real page visible when a snapshot cannot be captured.
      presented.dismiss(animated: true) { notify?() }
      return
    }
    snapshot.frame = start
    snapshot.clipsToBounds = true
    snapshot.layer.cornerCurve = .continuous
    snapshot.isUserInteractionEnabled = false
    host.addSubview(snapshot)
    presented.view.isHidden = true
    presented.dismiss(animated: false) {
      let end: CGRect
      if let target, let window = target.window {
        end = target.convert(target.bounds, to: window)
      } else {
        end = CGRect(x: start.midX - 26, y: start.maxY - 90, width: 52, height: 52)
      }
      UIView.animate(
        withDuration: 0.48, delay: 0, usingSpringWithDamping: 0.96, initialSpringVelocity: 0.15,
        options: [.curveEaseInOut]
      ) {
        snapshot.frame = end
        snapshot.layer.cornerRadius = min(end.width, end.height) / 2
      } completion: { _ in
        snapshot.removeFromSuperview()
        notify?()
      }
    }
  }
  /// Expands the actual creation page from the control, reversing the same transition on close.
  func presentExpanded(from source: UIView, _ screen: UIViewController) {
    guard presentedViewController == nil else { return }
    presentScreen(screen, full: true, animated: !UIAccessibility.isReduceMotionEnabled, collapseTo: source)
  }
  func expandSearch(
    from source: UIView, placeholder: String, dark: Bool = false,
    onChange: @escaping (String) -> Void, onClose: @escaping () -> Void
  ) {
    if activeSearch != nil {
      activeSearch?.dismiss()
      return
    }
    let bar = ExpandingSearchBar()
    activeSearch = bar
    bar.onChange = { [weak bar] text in
      onChange(text)
      bar?.setFiltering(!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
    bar.onClose = { [weak self] in
      self?.activeSearch = nil
      onClose()
    }
    let host: UIView
    if let navigationView = navigationController?.view {
      host = navigationView
    } else {
      host = view
    }
    bar.present(from: source, in: host, placeholder: placeholder, dark: dark)
  }
  func push(_ screen: UIViewController) {
    navigationController?.pushViewController(screen, animated: true)
  }
  func message(_ text: String, title: String = "Toti") {
    guard presentedViewController == nil else { return }
    let ok = actionButton("OK", primary: true) { [weak self] in self?.dismissCard() }
    showCard([label(title, 22, title: true), label(text, 15, TotiTheme.muted), ok])
  }
  func confirm(
    _ title: String, message: String, destructive: Bool = false, button: String = "Continue",
    action: @escaping () -> Void
  ) {
    guard presentedViewController == nil else { return }
    let yes = actionButton(button, primary: !destructive, tone: destructive ? .danger : nil) {
      [weak self] in self?.dismissCard { action() }
    }
    let no = actionButton("Cancel") { [weak self] in self?.dismissCard() }
    showCard([label(title, 22, title: true), label(message, 15, TotiTheme.muted), yes, no])
  }
  /// Shared by Voice, Live and Shorts. Saving a message only writes the local outbox.
  func showContentShare(
    text: String, address: String, onShared: @escaping () -> Void = {},
    onClose: @escaping () -> Void = {}
  ) {
    view.endEditing(true)
    var selected = false
    let finish: (@escaping () -> Void) -> Void = { [weak self] action in
      guard !selected, let self else { return }
      selected = true
      self.dismissCard {
        onClose()
        action()
      }
    }
    let title = label("Share with", 22, title: true)
    let close = iconButton(.close, "Close") { [weak self] in self?.dismissCard() }
    let header = stack([title, UIView(), close], axis: .horizontal, spacing: 8)
    header.alignment = .center
    let people = store.chatConversations.filter {
      $0.kind == .person && $0.creator?.isLocalOwner != true && store.followsChatPartner($0)
    }
    let row = UIStackView()
    row.axis = .horizontal
    row.alignment = .top
    row.spacing = 14
    let scroller = UIScrollView()
    scroller.showsHorizontalScrollIndicator = false
    scroller.translatesAutoresizingMaskIntoConstraints = false
    scroller.heightAnchor.constraint(equalToConstant: 96).isActive = true
    if people.isEmpty {
      let empty = label("Add a friend in Chats before sharing with someone.", 14, TotiTheme.muted)
      scroller.addSubview(empty)
      empty.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        empty.leadingAnchor.constraint(equalTo: scroller.contentLayoutGuide.leadingAnchor),
        empty.trailingAnchor.constraint(equalTo: scroller.contentLayoutGuide.trailingAnchor),
        empty.centerYAnchor.constraint(equalTo: scroller.frameLayoutGuide.centerYAnchor),
        empty.widthAnchor.constraint(equalTo: scroller.frameLayoutGuide.widthAnchor),
      ])
    } else {
      scroller.addSubview(row)
      row.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        row.leadingAnchor.constraint(equalTo: scroller.contentLayoutGuide.leadingAnchor),
        row.trailingAnchor.constraint(equalTo: scroller.contentLayoutGuide.trailingAnchor),
        row.topAnchor.constraint(equalTo: scroller.contentLayoutGuide.topAnchor),
        row.bottomAnchor.constraint(equalTo: scroller.contentLayoutGuide.bottomAnchor),
        row.heightAnchor.constraint(equalTo: scroller.frameLayoutGuide.heightAnchor),
      ])
      for person in people {
        row.addArrangedSubview(contentSharePerson(person) { [weak self] in
          finish { [weak self] in
            guard let self else { return }
            Task { [weak self] in
              guard let self else { return }
              if await self.store.sendChatMessage(text, to: person) {
                onShared()
                self.message("Saved in your chat with \(person.name). It stays on this device.")
              } else {
                self.message(self.store.lastSaveError ?? "That message could not be saved.")
              }
            }
          }
        })
      }
    }
    let link = contentShareLink {
      finish { [weak self] in
        UIPasteboard.general.string = address
        onShared()
        self?.message("Link copied. This is a Toti address, not a public web page.")
      }
    }
    let linkRow = stack([link, UIView()], axis: .horizontal, spacing: 8)
    linkRow.alignment = .top
    showBottomPanel(stack([header, scroller, linkRow], spacing: 16))
    cardDismiss = onClose
  }
  private func contentSharePerson(_ person: MusicConversation, action: @escaping () -> Void) -> UIView {
    let item = UIButton(type: .custom)
    let photo = conversationPortrait(person, size: 56)
    let nickname = person.name.components(separatedBy: " ").first ?? person.name
    let name = label(nickname, 12)
    name.textAlignment = .center
    name.numberOfLines = 1
    name.adjustsFontSizeToFitWidth = true
    name.minimumScaleFactor = 0.8
    name.isAccessibilityElement = false
    let column = stack([photo, name], spacing: 6)
    column.alignment = .center
    column.isUserInteractionEnabled = false
    item.addSubview(column)
    column.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      item.widthAnchor.constraint(equalToConstant: 68),
      column.topAnchor.constraint(equalTo: item.topAnchor),
      column.bottomAnchor.constraint(equalTo: item.bottomAnchor),
      column.centerXAnchor.constraint(equalTo: item.centerXAnchor),
      column.widthAnchor.constraint(equalTo: item.widthAnchor),
      column.leadingAnchor.constraint(greaterThanOrEqualTo: item.leadingAnchor),
      column.trailingAnchor.constraint(lessThanOrEqualTo: item.trailingAnchor),
    ])
    item.accessibilityLabel = person.name
    item.addAction(UIAction { _ in action() }, for: .touchUpInside)
    return item
  }
  private func contentShareLink(action: @escaping () -> Void) -> UIView {
    let item = UIButton(type: .custom)
    let circle = UIView()
    circle.isUserInteractionEnabled = false
    circle.backgroundColor = UIColor.white.withAlphaComponent(0.92)
    circle.layer.cornerRadius = 28
    circle.layer.borderWidth = 1.5
    circle.layer.borderColor = TotiTheme.coral.cgColor
    let icon = UIImageView(image: TotiIcon.share.image(size: 26))
    icon.contentMode = .scaleAspectFit
    icon.translatesAutoresizingMaskIntoConstraints = false
    circle.addSubview(icon)
    circle.translatesAutoresizingMaskIntoConstraints = false
    let caption = label("Share link", 12)
    caption.textAlignment = .center
    caption.isAccessibilityElement = false
    let column = stack([circle, caption], spacing: 6)
    column.alignment = .center
    column.isUserInteractionEnabled = false
    item.addSubview(column)
    column.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      item.widthAnchor.constraint(equalToConstant: 76),
      circle.widthAnchor.constraint(equalToConstant: 56),
      circle.heightAnchor.constraint(equalToConstant: 56),
      icon.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
      icon.centerYAnchor.constraint(equalTo: circle.centerYAnchor),
      icon.widthAnchor.constraint(equalToConstant: 26),
      icon.heightAnchor.constraint(equalToConstant: 26),
      column.topAnchor.constraint(equalTo: item.topAnchor),
      column.bottomAnchor.constraint(equalTo: item.bottomAnchor),
      column.centerXAnchor.constraint(equalTo: item.centerXAnchor),
      column.widthAnchor.constraint(equalTo: item.widthAnchor),
    ])
    item.accessibilityLabel = "Share link"
    item.addAction(UIAction { _ in action() }, for: .touchUpInside)
    return item
  }
  func share(_ text: String, completion: ((Bool) -> Void)? = nil) {
    let copy = actionButton("Copy", icon: .share, primary: true) { [weak self] in
      UIPasteboard.general.string = text
      self?.dismissCard {
        completion?(true)
        self?.message("Copied.")
      }
    }
    let close = actionButton("Close") { [weak self] in self?.dismissCard() }
    showCard([
      label("Share", 22, title: true), label(text, 16, TotiTheme.muted), copy, close,
    ])
    cardDismiss = { completion?(false) }
  }
  func choice(
    _ title: String, message: String, accept: String, decline: String,
    onAccept: @escaping () -> Void
  ) {
    let yes = actionButton(accept, primary: true) { [weak self] in
      self?.dismissCard { onAccept() }
    }
    let no = actionButton(decline, tone: .danger) { [weak self] in self?.dismissCard() }
    showCard([label(title, 22, title: true), label(message, 15, TotiTheme.muted), yes, no])
  }
  /// Bottom sheet on the window so it sits above the tab dock. The fill is the studio background.
  func showBottomPanel(_ body: UIView) {
    dismissCard()
    let host: UIView = view.window ?? view
    let dim = UIControl(frame: host.bounds)
    dim.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    dim.backgroundColor = UIColor.black.withAlphaComponent(0.4)
    dim.alpha = 0
    dim.addAction(UIAction { [weak self] _ in self?.dismissCard() }, for: .touchUpInside)
    let panel = UIView()
    panel.backgroundColor = TotiTheme.background
    panel.layer.cornerRadius = 28
    panel.layer.cornerCurve = .continuous
    panel.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    panel.clipsToBounds = true
    panel.translatesAutoresizingMaskIntoConstraints = false
    let canvas = StudioCanvas()
    canvas.translatesAutoresizingMaskIntoConstraints = false
    panel.addSubview(canvas)
    body.translatesAutoresizingMaskIntoConstraints = false
    panel.addSubview(body)
    dim.addSubview(panel)
    host.addSubview(dim)
    NSLayoutConstraint.activate([
      canvas.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
      canvas.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
      canvas.topAnchor.constraint(equalTo: panel.topAnchor),
      canvas.bottomAnchor.constraint(equalTo: panel.bottomAnchor),
      panel.leadingAnchor.constraint(equalTo: dim.leadingAnchor),
      panel.trailingAnchor.constraint(equalTo: dim.trailingAnchor),
      panel.bottomAnchor.constraint(equalTo: dim.bottomAnchor),
      body.topAnchor.constraint(equalTo: panel.topAnchor, constant: 18),
      body.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 16),
      body.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -16),
      body.bottomAnchor.constraint(equalTo: panel.safeAreaLayoutGuide.bottomAnchor, constant: -12),
    ])
    cardLayer = dim
    panel.transform = CGAffineTransform(translationX: 0, y: 48)
    UIView.animate(
      withDuration: 0.34, delay: 0, usingSpringWithDamping: 0.86, initialSpringVelocity: 0.4
    ) {
      dim.alpha = 1
      panel.transform = .identity
    }
  }
  func showCard(_ lines: [UIView]) {
    dismissCard()
    let dim = UIControl(frame: view.bounds)
    dim.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    dim.backgroundColor = UIColor.black.withAlphaComponent(0.4)
    dim.alpha = 0
    dim.addAction(UIAction { [weak self] _ in self?.dismissCard() }, for: .touchUpInside)
    let card = UIView()
    card.backgroundColor = TotiTheme.background
    card.layer.cornerRadius = 24
    card.clipsToBounds = true
    card.translatesAutoresizingMaskIntoConstraints = false
    let column = stack(lines, spacing: 14)
    column.translatesAutoresizingMaskIntoConstraints = false
    card.addSubview(column)
    dim.addSubview(card)
    view.addSubview(dim)
    NSLayoutConstraint.activate([
      card.centerXAnchor.constraint(equalTo: dim.centerXAnchor),
      card.centerYAnchor.constraint(equalTo: dim.centerYAnchor),
      card.widthAnchor.constraint(equalToConstant: 320),
      column.topAnchor.constraint(equalTo: card.topAnchor, constant: 22),
      column.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
      column.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
      column.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
    ])
    cardLayer = dim
    card.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
    UIView.animate(
      withDuration: 0.34, delay: 0, usingSpringWithDamping: 0.82, initialSpringVelocity: 0.4
    ) {
      dim.alpha = 1
      card.transform = .identity
    }
  }
  func dismissCard(then: (() -> Void)? = nil) {
    let fallback = cardDismiss
    cardDismiss = nil
    guard let dim = cardLayer else {
      (then ?? fallback)?()
      return
    }
    cardLayer = nil
    let finish = {
      dim.removeFromSuperview()
      (then ?? fallback)?()
    }
    if UIAccessibility.isReduceMotionEnabled {
      finish()
      return
    }
    UIView.animate(withDuration: 0.18, animations: { dim.alpha = 0 }) { _ in finish() }
  }
  func save(_ operation: @escaping () async -> Bool) {
    guard isAccountContextCurrent else { return }
    Task {
      guard isAccountContextCurrent else { return }
      let saved = await operation()
      guard isAccountContextCurrent else { return }
      if !saved {
        message(store.lastSaveError ?? "Your changes could not be saved. Please try again.")
      }
    }
  }
}

@MainActor class StackScreen: TotiScreen {
  let scroll = UIScrollView()
  let content = UIStackView()
  private var scrollBottomConstraint: NSLayoutConstraint?
  private var listFollowsScreenBottom = false
  override func build() {
    content.axis = .vertical
    content.spacing = 18
    scroll.keyboardDismissMode = .interactive
    // This scroll view is already constrained to safe-area / keyboard guides.
    // Do not apply the navigation and dock insets a second time.
    scroll.contentInsetAdjustmentBehavior = .never
    scroll.automaticallyAdjustsScrollIndicatorInsets = false
    scroll.backgroundColor = .clear
    content.backgroundColor = .clear
    view.addSubview(scroll)
    scroll.translatesAutoresizingMaskIntoConstraints = false
    let bottom = scroll.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor)
    scrollBottomConstraint = bottom
    NSLayoutConstraint.activate([
      scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      bottom,
    ])
    scroll.addSubview(content)
    content.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 20),
      content.bottomAnchor.constraint(
        equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
      content.leadingAnchor.constraint(
        equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 16),
      content.trailingAnchor.constraint(
        equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -16),
      content.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -32),
    ])
    NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification).receive(
      on: DispatchQueue.main
    ).sink { [weak self] _ in
      guard let self, let active = self.view.firstResponderView else { return }
      self.scroll.scrollRectToVisible(
        active.convert(active.bounds, to: self.scroll).insetBy(dx: 0, dy: -18), animated: true)
    }.store(in: &tokens)
  }
  /// Lets this list reach the screen bottom, under the tab dock. The keyboard still lifts it.
  func pinListUnderDock() {
    if #available(iOS 17.0, *) {
      view.keyboardLayoutGuide.usesBottomSafeArea = false
      return
    }
    guard !listFollowsScreenBottom else { return }
    listFollowsScreenBottom = true
    scrollBottomConstraint?.isActive = false
    let bottom = scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    bottom.isActive = true
    scrollBottomConstraint = bottom
    NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] note in self?.liftListForKeyboard(note) }
      .store(in: &tokens)
  }
  private func liftListForKeyboard(_ note: Notification) {
    guard listFollowsScreenBottom, let bottom = scrollBottomConstraint, view.window != nil else {
      return
    }
    let info = note.userInfo
    let raw = (info?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue ?? .zero
    let end = view.convert(raw, from: nil)
    let overlap = min(view.bounds.height, max(0, view.bounds.maxY - end.minY))
    let duration =
      (info?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0.25
    let curve = (info?[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?.uintValue ?? 0
    let options = UIView.AnimationOptions(rawValue: curve << 16).union(.beginFromCurrentState)
    bottom.constant = -overlap
    UIView.animate(withDuration: duration, delay: 0, options: options) {
      self.view.layoutIfNeeded()
    }
  }
  func clear() { content.arrangedSubviews.forEach { $0.removeFromSuperview() } }
  @discardableResult
  func heading(_ text: String) -> UILabel {
    let title = label(text, 26, title: true)
    let mark = UIView()
    mark.backgroundColor = TotiTheme.coral
    mark.layer.cornerRadius = 2
    mark.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      mark.widthAnchor.constraint(equalToConstant: 28),
      mark.heightAnchor.constraint(equalToConstant: 4),
    ])
    let column = stack([title, mark], spacing: 6)
    column.alignment = .leading
    content.addArrangedSubview(column)
    return title
  }
}
extension UIView {
  var firstResponderView: UIView? {
    if isFirstResponder { return self }
    return subviews.lazy.compactMap { $0.firstResponderView }.first
  }
}
private final class StudioPopGesture: NSObject, UIGestureRecognizerDelegate {
  func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    guard let nav = gestureRecognizer.view?.next as? UINavigationController else { return false }
    return nav.viewControllers.count > 1
  }
}

/// Prepares app destinations for pushes, stack replacements and programmatic returns.
/// UIKit still owns navigation animations and interactive-pop cancellation.
@MainActor final class TotiNavigationController: UINavigationController {
  private func prepareDestination(_ controller: UIViewController?) {
    guard isViewLoaded, let controller else { return }
    TotiNavigation.prepare(controller, in: view.bounds)
  }

  override func pushViewController(_ viewController: UIViewController, animated: Bool) {
    prepareDestination(viewController)
    super.pushViewController(viewController, animated: animated)
  }

  override func setViewControllers(_ viewControllers: [UIViewController], animated: Bool) {
    prepareDestination(viewControllers.last)
    super.setViewControllers(viewControllers, animated: animated)
  }

  override func popViewController(animated: Bool) -> UIViewController? {
    if viewControllers.count > 1 { prepareDestination(viewControllers[viewControllers.count - 2]) }
    return super.popViewController(animated: animated)
  }

  override func popToViewController(_ viewController: UIViewController, animated: Bool) -> [UIViewController]? {
    prepareDestination(viewController)
    return super.popToViewController(viewController, animated: animated)
  }

  override func popToRootViewController(animated: Bool) -> [UIViewController]? {
    prepareDestination(viewControllers.first)
    return super.popToRootViewController(animated: animated)
  }
}

@MainActor enum TotiNavigation {
  private static let pop = StudioPopGesture()

  /// Prepare real content synchronously; asynchronous data stays inside that page.
  static func prepare(_ controller: UIViewController, in bounds: CGRect) {
    UIView.performWithoutAnimation {
      controller.loadViewIfNeeded()
      if bounds.width > 0, bounds.height > 0 { controller.view.frame = bounds }
      if let nav = controller as? UINavigationController, let screen = nav.topViewController {
        screen.loadViewIfNeeded()
        (screen as? TotiScreen)?.installStudioChrome()
      } else {
        (controller as? TotiScreen)?.installStudioChrome()
      }
      controller.view.setNeedsLayout()
      controller.view.layoutIfNeeded()
    }
  }

  static func style(_ nav: UINavigationController) {
    let a = UINavigationBarAppearance()
    a.configureWithTransparentBackground()
    a.backgroundColor = .clear
    a.backgroundEffect = nil
    a.shadowColor = .clear
    a.titleTextAttributes = [
      .font: TotiTheme.font(19, title: true), .foregroundColor: TotiTheme.ink,
    ]
    a.setBackIndicatorImage(TotiIcon.back.image(), transitionMaskImage: TotiIcon.back.image())
    nav.navigationBar.standardAppearance = a
    nav.navigationBar.scrollEdgeAppearance = a
    nav.navigationBar.compactAppearance = a
    nav.navigationBar.compactScrollEdgeAppearance = a
    nav.navigationBar.isTranslucent = true
    nav.navigationBar.tintColor = TotiTheme.plum
    nav.navigationBar.prefersLargeTitles = false
    nav.view.backgroundColor = TotiTheme.background
    nav.view.clipsToBounds = false
    nav.interactivePopGestureRecognizer?.delegate = pop
    nav.interactivePopGestureRecognizer?.isEnabled = true
  }
}

/// Title inside a mode track. A label keeps the system button chrome off the word.
private final class TrackTitle: UIControl {
  let caption = UILabel()
  init(_ title: String) {
    super.init(frame: .zero)
    caption.text = title
    caption.font = TotiTheme.font(13)
    caption.textAlignment = .center
    caption.adjustsFontSizeToFitWidth = true
    caption.minimumScaleFactor = 0.6
    caption.lineBreakMode = .byClipping
    caption.isUserInteractionEnabled = false
    addSubview(caption)
    caption.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      caption.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
      caption.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
      caption.topAnchor.constraint(equalTo: topAnchor),
      caption.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
    isAccessibilityElement = true
    accessibilityLabel = title
    accessibilityTraits = .button
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
}

/// Transparent selection bubble. A drag follows the finger, then the bubble springs into place.
final class BubbleTrack: UIView, UIGestureRecognizerDelegate {
  private let bubble = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialLight))
  private let wash = UIView()
  private let row = UIStackView()
  private let barHeight: CGFloat
  private(set) var index: Int
  var onSelect: ((Int) -> Void)?
  private var tracking = false
  private var settling = false
  private var onDark = false
  private let preferredWidth: CGFloat?

  init(titles: [String], index: Int = 0, barHeight: CGFloat = 40, lockedWidth: CGFloat? = nil) {
    self.index = index
    self.barHeight = barHeight
    self.preferredWidth = lockedWidth
    super.init(frame: CGRect(x: 0, y: 0, width: lockedWidth ?? 240, height: barHeight))
    backgroundColor = UIColor.white.withAlphaComponent(0.12)
    layer.borderWidth = 1
    layer.borderColor = UIColor.white.withAlphaComponent(0.45).cgColor
    clipsToBounds = true
    bubble.isUserInteractionEnabled = false
    bubble.clipsToBounds = true
    bubble.layer.borderWidth = 1
    bubble.layer.borderColor = UIColor.white.withAlphaComponent(0.75).cgColor
    wash.backgroundColor = TotiTheme.coral.withAlphaComponent(0.36)
    wash.isUserInteractionEnabled = false
    wash.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    bubble.contentView.addSubview(wash)
    addSubview(bubble)
    row.axis = .horizontal
    row.distribution = .fillEqually
    row.frame = bounds
    row.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    addSubview(row)
    for (i, title) in titles.enumerated() {
      let button = TrackTitle(title)
      button.addAction(
        UIAction { [weak self] _ in self?.select(i, notify: true) }, for: .touchUpInside)
      row.addArrangedSubview(button)
    }
    setContentHuggingPriority(.required, for: .vertical)
    setContentCompressionResistancePriority(.required, for: .vertical)
    if lockedWidth != nil {
      setContentHuggingPriority(.required, for: .horizontal)
      setContentCompressionResistancePriority(.required, for: .horizontal)
    }
    let pan = UIPanGestureRecognizer(target: self, action: #selector(slide(_:)))
    pan.delegate = self
    addGestureRecognizer(pan)
    updateStyles()
  }

  func setOnDark(_ value: Bool) {
    onDark = value
    updateStyles()
  }

  override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
    let velocity = pan.velocity(in: self)
    return abs(velocity.x) > abs(velocity.y)
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

  override var intrinsicContentSize: CGSize {
    CGSize(width: preferredWidth ?? UIView.noIntrinsicMetric, height: barHeight)
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    guard window != nil else { return }
    if bounds.width < 1, let preferredWidth {
      frame.size = CGSize(width: preferredWidth, height: barHeight)
    }
    setNeedsLayout()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    layer.cornerRadius = bounds.height / 2
    guard !tracking, !settling else {
      fitBubble()
      return
    }
    place(index, animated: false)
  }

  func ensureSelectionVisible() {
    guard bounds.width > 1, bounds.height > 1, !tracking else { return }
    place(index, animated: false)
  }

  func select(_ next: Int, notify: Bool) {
    guard row.arrangedSubviews.indices.contains(next) else { return }
    index = next
    tracking = false
    place(next, animated: true)
    updateStyles()
    if notify { onSelect?(index) }
  }

  private func place(_ next: Int, animated: Bool) {
    let count = row.arrangedSubviews.count
    guard count > 0, row.arrangedSubviews.indices.contains(next), bounds.width > 1,
      bounds.height > 1
    else { return }
    let slot = bounds.width / CGFloat(count)
    let rect = CGRect(x: slot * CGFloat(next), y: 0, width: slot, height: bounds.height)
      .insetBy(dx: 3, dy: 4)
    guard rect.width > 1, rect.height > 1 else { return }
    let updates = {
      self.bubble.transform = .identity
      self.bubble.bounds = CGRect(origin: .zero, size: rect.size)
      self.bubble.center = CGPoint(x: rect.midX, y: rect.midY)
      self.fitBubble()
    }
    if animated, bubble.bounds.width > 1, !UIAccessibility.isReduceMotionEnabled {
      settling = true
      bubble.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
      UIView.animate(
        withDuration: 0.42, delay: 0, usingSpringWithDamping: 0.68, initialSpringVelocity: 0.6,
        animations: updates
      ) { _ in
        self.settling = false
      }
    } else {
      updates()
    }
  }

  private func fitBubble() {
    bubble.layer.cornerRadius = bubble.bounds.height / 2
    wash.frame = bubble.bounds
  }

  private func updateStyles() {
    for (i, view) in row.arrangedSubviews.enumerated() {
      guard let button = view as? TrackTitle else { continue }
      let selected = i == index
      button.caption.textColor =
        selected ? TotiTheme.ink : (onDark ? UIColor.white.withAlphaComponent(0.9) : TotiTheme.muted)
      button.accessibilityTraits = selected ? [.button, .selected] : .button
    }
  }

  @objc private func slide(_ gesture: UIPanGestureRecognizer) {
    let count = row.arrangedSubviews.count
    guard count > 0, bounds.width > 0 else { return }
    let width = bounds.width / CGFloat(count)
    let x = min(bounds.width - width, max(0, gesture.location(in: self).x - width / 2))
    switch gesture.state {
    case .began, .changed:
      tracking = true
      bubble.transform = .identity
      let size = CGSize(width: width - 6, height: bounds.height - 8)
      bubble.bounds = CGRect(origin: .zero, size: size)
      bubble.center = CGPoint(x: x + 3 + size.width / 2, y: bounds.midY)
      bubble.transform = CGAffineTransform(scaleX: 1.04, y: 0.96)
      fitBubble()
    case .ended, .cancelled, .failed:
      tracking = false
      bubble.transform = .identity
      let next = min(count - 1, max(0, Int((x / width).rounded())))
      select(next, notify: true)
    default:
      break
    }
  }
}

/// Full-screen recording-studio photograph for the Live list. Controls stay in their existing places.
final class LiveAtmosphere: UIView {
  private let photo = UIImageView(image: UIImage(named: "MusicStudioBackdrop"))
  private let veil = CAGradientLayer()
  override init(frame: CGRect) {
    super.init(frame: frame)
    isUserInteractionEnabled = false
    clipsToBounds = true
    photo.contentMode = .scaleAspectFill
    addSubview(photo)
    veil.colors = [
      UIColor(white: 1, alpha: 0.34).cgColor,
      UIColor(white: 1, alpha: 0.84).cgColor,
      UIColor(white: 1, alpha: 0.84).cgColor,
      UIColor(white: 1, alpha: 0.28).cgColor,
    ]
    veil.locations = [0, 0.08, 0.78, 1]
    layer.addSublayer(veil)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  override func layoutSubviews() {
    super.layoutSubviews()
    photo.frame = bounds
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    veil.frame = bounds
    CATransaction.commit()
  }
}

/// Search field that grows from the tapped control to a bar across the top.
final class ExpandingSearchBar: UIView {
  var onChange: ((String) -> Void)?
  var onClose: (() -> Void)?
  private let blur = UIVisualEffectView(effect: nil)
  private let dim = UIView()
  private let capsule = UIView()
  private let field = UITextField()
  private let closeButton = UIButton(type: .custom)
  private var startFrame: CGRect = .zero
  private var dark = false
  private var placed = false
  private var closing = false
  private var filtering = false

  func present(from source: UIView, in host: UIView, placeholder: String, dark: Bool) {
    self.dark = dark
    frame = host.bounds
    autoresizingMask = [.flexibleWidth, .flexibleHeight]
    backgroundColor = .clear
    blur.isUserInteractionEnabled = false
    dim.isUserInteractionEnabled = false
    dim.backgroundColor = (dark ? UIColor.black : UIColor.white).withAlphaComponent(dark ? 0.28 : 0.22)
    dim.alpha = 0
    addSubview(blur)
    addSubview(dim)
    capsule.backgroundColor = UIColor.white.withAlphaComponent(0.96)
    capsule.clipsToBounds = true
    addSubview(capsule)
    field.placeholder = placeholder
    field.font = TotiTheme.font(16)
    field.textColor = TotiTheme.ink
    field.tintColor = TotiTheme.plum
    field.autocorrectionType = .no
    field.autocapitalizationType = .none
    field.returnKeyType = .search
    field.accessibilityLabel = placeholder
    field.alpha = 0
    field.addAction(
      UIAction { [weak self] _ in self?.onChange?(self?.field.text ?? "") }, for: .editingChanged)
    closeButton.setImage(TotiIcon.close.image(size: 18), for: .normal)
    closeButton.accessibilityLabel = "Close search"
    closeButton.alpha = 0
    closeButton.addAction(UIAction { [weak self] _ in self?.dismiss() }, for: .touchUpInside)
    soften(closeButton)
    capsule.addSubview(field)
    capsule.addSubview(closeButton)
    host.addSubview(self)
    startFrame = source.convert(source.bounds, to: host)
    if startFrame.width < 8 {
      startFrame = CGRect(x: host.bounds.width - 56, y: host.safeAreaInsets.top + 8, width: 44, height: 44)
    }
    capsule.frame = startFrame
    capsule.layer.cornerRadius = min(startFrame.width, startFrame.height) / 2
    blur.frame = bounds
    dim.frame = bounds
    let changes = {
      self.placeBar()
      self.blur.effect = UIBlurEffect(
        style: dark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight)
      self.dim.alpha = 1
      self.field.alpha = 1
      self.closeButton.alpha = 1
    }
    if UIAccessibility.isReduceMotionEnabled {
      changes()
      placed = true
    } else {
      UIView.animate(
        withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.86, initialSpringVelocity: 0.35,
        options: [.allowUserInteraction]
      ) {
        changes()
      } completion: { _ in
        self.placed = true
      }
    }
    field.becomeFirstResponder()
  }

  func setFiltering(_ active: Bool) {
    filtering = active
    let style: UIBlurEffect.Style = dark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight
    UIView.animate(withDuration: 0.25) {
      self.blur.effect = active ? nil : UIBlurEffect(style: style)
      self.dim.alpha = active ? 0.08 : 1
    }
  }

  func dismiss() {
    guard !closing else { return }
    closing = true
    field.resignFirstResponder()
    placed = false
    let finish = { [weak self] in
      guard let self else { return }
      self.removeFromSuperview()
      self.onClose?()
    }
    if UIAccessibility.isReduceMotionEnabled {
      finish()
      return
    }
    UIView.animate(withDuration: 0.32, delay: 0, options: [.curveEaseInOut]) {
      self.capsule.frame = self.startFrame
      self.capsule.layer.cornerRadius = min(self.startFrame.width, self.startFrame.height) / 2
      self.field.alpha = 0
      self.closeButton.alpha = 0
      self.blur.effect = nil
      self.dim.alpha = 0
    } completion: { _ in
      finish()
    }
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    blur.frame = bounds
    dim.frame = bounds
    if placed { placeBar() }
  }

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    let hit = super.hitTest(point, with: event)
    if hit === self || hit === blur || hit === dim { return filtering ? nil : self }
    return hit
  }

  private func placeBar() {
    let top = (superview?.safeAreaInsets.top ?? safeAreaInsets.top) + 8
    capsule.frame = CGRect(x: 12, y: top, width: max(0, bounds.width - 24), height: 52)
    capsule.layer.cornerRadius = 26
    let height = capsule.bounds.height
    closeButton.frame = CGRect(x: capsule.bounds.width - height, y: 0, width: height, height: height)
    field.frame = CGRect(x: 18, y: 0, width: max(0, capsule.bounds.width - height - 12), height: height)
  }
}
