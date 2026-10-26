import Combine
import UIKit

final class SafetyController: StackScreen {
  let target: ContentSafetyTarget
  var recordingInformation: String?
  private var reporting: Bool
  /// Keeps the reason and details while a report form is open. Store updates must not rebuild it.
  private var reportFormReady = false
  /// Runs after a saved block or report, once this screen has closed.
  var onResolved: (() -> Void)?
  init(store: AppStore, target: ContentSafetyTarget, reporting: Bool = false) {
    self.target = target
    self.reporting = reporting
    super.init(store: store, title: reporting ? "Report" : "More")
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if reporting { expandReportSheet() }
  }
  override func refresh() {
    guard isViewLoaded, !reportFormReady else { return }
    clear()
    heading(target.title)
    if !reporting, let recordingInformation {
      content.addArrangedSubview(label(recordingInformation, 14, TotiTheme.muted))
    }
    if !reporting {
      content.addArrangedSubview(
        actionButton("Report " + target.kind.rawValue.lowercased(), icon: .flag) { [weak self] in
          guard let self else { return }
          self.reporting = true
          self.title = "Report"
          self.installStudioChrome()
          self.reportFormReady = false
          self.refresh()
        })
      content.addArrangedSubview(
        actionButton("Block " + target.creator.name, icon: .block) { [weak self] in
          guard let self else { return }
          self.confirm(
            "Block this creator?",
            message:
              "Their posts, comments and voice rooms will be hidden. You can unblock them from Blocked in Settings.",
            destructive: true, button: "Block"
          ) { [weak self] in
            guard let self else { return }
            Task {
              if await self.store.blockCreator(self.target.creator) {
                self.closeAfterAction()
              } else {
                self.message(self.store.lastSaveError ?? "Please try again.")
              }
            }
          }
        })
      return
    }
    let reasons = StudioOptions(items: ContentReportReason.allCases.map(\.rawValue))
    var selected = ContentReportReason.allCases[reasons.index]
    reasons.onChange = { selected = ContentReportReason.allCases[$0] }
    content.addArrangedSubview(reasons)
    let details = field("Additional details (optional)")
    content.addArrangedSubview(details)
    content.addArrangedSubview(
      label(
        "Reports stay on this device and are not submitted. Remove one from Reported in Settings.",
        14, TotiTheme.muted))
    content.addArrangedSubview(
      actionButton("Save report", icon: .flag, primary: true) { [weak self] in
        guard let self else { return }
        let reason = selected
        let note = details.text ?? ""
        Task {
          if await self.store.saveContentReport(self.target, reason: reason, details: note) {
            self.view.endEditing(true)
            self.closeAfterAction(note: "Report saved")
          } else {
            self.message(self.store.lastSaveError ?? "Your report could not be saved. Please try again.")
          }
        }
      })
    reportFormReady = true
    expandReportSheet()
  }
  /// The reason list is taller than the half sheet, so Save report has to be on screen.
  private func expandReportSheet() {
    guard let sheet = navigationController?.sheetPresentationController else { return }
    sheet.animateChanges { sheet.selectedDetentIdentifier = .large }
  }
  private func closeAfterAction(note: String? = nil) {
    let next = onResolved
    let host = navigationController ?? self
    let window = view.window
    host.dismiss(animated: true) {
      if let note { StudioNotice.show(note, in: window) }
      next?()
    }
  }
}
final class WalletController: StackScreen {
  override func build() {
    super.build()
    title = "Wallet"
    store.wallet.prepareProducts()
    store.wallet.objectWillChange.receive(on: DispatchQueue.main).sink { [weak self] _ in
      self?.refresh()
    }.store(in: &tokens)
  }
  override func refresh() {
    guard isViewLoaded else { return }
    clear()
    let image = UIImageView(image: TotiIcon.diamond.image(size: 76))
    image.contentMode = .scaleAspectFit
    image.height(76)
    content.addArrangedSubview(image)
    let balance = heading("\(store.wallet.snapshot.diamonds.formatted()) Diamonds")
    balance.accessibilityIdentifier = "wallet.balance"
    balance.accessibilityValue = String(store.wallet.snapshot.diamonds)
    content.addArrangedSubview(
      label(
        "Send a little appreciation. Diamonds are used for gifts in voice rooms. Messages and replies are free.",
        15, TotiTheme.muted))
    if let status = store.wallet.catalog.message {
      let statusLabel = label(status, 14, TotiTheme.muted)
      statusLabel.accessibilityIdentifier = "wallet.catalog.status"
      content.addArrangedSubview(statusLabel)
    }
    if store.wallet.catalog.canRetry {
      let retry = actionButton("Retry prices") { [weak self] in self?.store.wallet.retryProducts() }
      retry.accessibilityIdentifier = "wallet.catalog.retry"
      retry.isEnabled = !store.wallet.isBusy
      content.addArrangedSubview(retry)
    }
    let packages = WalletCatalog.packages(for: .diamonds)
    for start in stride(from: 0, to: packages.count, by: 3) {
      let row = stack(axis: .horizontal, spacing: 8)
      row.distribution = .fillEqually
      let end = min(start + 3, packages.count)
      for package in packages[start..<end] {
        let price = store.wallet.priceText(for: package)
        let priceNote = "Price: \(price)"
        let b = actionButton(
          package.amountText + "\n" + price, icon: .diamond, axis: .vertical
        ) { [weak self] in
          guard let self, self.store.wallet.canPurchase(package) else { return }
          self.confirm(
            "Add \(package.amountText) diamonds", message: priceNote,
            button: "Continue"
          ) { [weak self] in
            guard let self else { return }
            Task {
              if let error = await self.store.wallet.purchase(package) { self.message(error) }
            }
          }
        }
        b.accessibilityIdentifier = "wallet.package.\(package.amount)"
        b.isEnabled = store.wallet.canPurchase(package)
        row.addArrangedSubview(b)
      }
      for _ in 0..<(3 - (end - start)) {
        let spacer = UIView()
        spacer.isAccessibilityElement = false
        row.addArrangedSubview(spacer)
      }
      content.addArrangedSubview(row)
    }
    heading("Activity")
    if store.wallet.snapshot.activity.isEmpty {
      content.addArrangedSubview(label("No transactions yet.", 15, TotiTheme.muted))
    }
    for item in store.wallet.snapshot.activity {
      let activity = label(item.title)
      activity.accessibilityIdentifier = "wallet.activity.\(item.id)"
      content.addArrangedSubview(activity)
    }
    #if DEBUG
    content.addArrangedSubview(actionButton("Copy store diagnostics") { [weak self] in
      guard let self else { return }
      UIPasteboard.general.string = self.store.wallet.diagnostics
      self.message("Store diagnostics copied.")
    })
    #endif
  }
}
struct GiftAudienceMember {
  let id: String
  let name: String
}

func giftIcon(for gift: MusicGift) -> TotiIcon {
  switch gift.id {
  case "rose": return .flower
  case "balloons": return .balloon
  case "heart": return .heart
  case "beat": return .music
  case "spotlight": return .sparkle
  case "bouquet": return .flower
  case "crown": return .crown
  case "encore": return .gift
  default: return .sparkle
  }
}

/// Gift artwork on the full-screen film. It does not take taps.
enum GiftBurst {
  static func show(gift: MusicGift, quantity: Int, in host: UIView) {
    let canvas = host.window ?? host
    let stage = UIView(frame: canvas.bounds)
    stage.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    stage.isUserInteractionEnabled = false
    stage.backgroundColor = .clear
    stage.isAccessibilityElement = true
    stage.accessibilityLabel = quantity > 1 ? "\(gift.name), \(quantity)" : gift.name
    canvas.addSubview(stage)
    let icon = giftIcon(for: gift)
    let main = UIImageView(image: icon.image(size: 148))
    main.contentMode = .scaleAspectFit
    let caption = UILabel()
    caption.text = quantity > 1 ? "\(gift.name) × \(quantity)" : gift.name
    caption.font = TotiTheme.font(28, title: true)
    caption.textColor = .white
    caption.textAlignment = .center
    caption.layer.shadowColor = UIColor.black.cgColor
    caption.layer.shadowOpacity = 0.45
    caption.layer.shadowRadius = 6
    caption.layer.shadowOffset = CGSize(width: 0, height: 2)
    stage.addSubview(main)
    stage.addSubview(caption)
    let center = CGPoint(x: stage.bounds.midX, y: stage.bounds.height * 0.30)
    main.bounds = CGRect(x: 0, y: 0, width: 148, height: 148)
    main.center = CGPoint(x: center.x, y: center.y + 70)
    caption.sizeToFit()
    caption.center = CGPoint(x: center.x, y: main.center.y + 96)
    var satellites: [UIImageView] = []
    let offsets: [(CGFloat, CGFloat)] = [(-78, -36), (84, -28), (-46, 54), (58, 62), (0, -78)]
    for offset in offsets {
      let small = UIImageView(image: icon.image(size: 54))
      small.bounds = CGRect(x: 0, y: 0, width: 54, height: 54)
      small.center = main.center
      small.alpha = 0
      stage.addSubview(small)
      satellites.append(small)
      small.tag = Int(offset.0 * 10 + offset.1)
    }
    let reduce = UIAccessibility.isReduceMotionEnabled
    main.transform = CGAffineTransform(scaleX: 0.2, y: 0.2)
    main.alpha = 0
    caption.alpha = 0
    UIView.animate(
      withDuration: reduce ? 0.2 : 0.55, delay: 0, usingSpringWithDamping: 0.62,
      initialSpringVelocity: 0.6
    ) {
      main.transform = .identity
      main.alpha = 1
      caption.alpha = 1
      if !reduce {
        main.center = center
        caption.center = CGPoint(x: center.x, y: center.y + 96)
      }
    }
    if !reduce {
      for (index, small) in satellites.enumerated() {
        let offset = offsets[index]
        UIView.animate(
          withDuration: 0.7, delay: 0.08, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.4
        ) {
          small.alpha = 1
          small.center = CGPoint(x: center.x + offset.0, y: center.y + offset.1)
        }
      }
    }
    UIView.animate(withDuration: 0.45, delay: reduce ? 0.8 : 1.35, options: [.curveEaseIn]) {
      main.alpha = 0
      caption.alpha = 0
      if !reduce { main.center.y -= 28 }
      for small in satellites { small.alpha = 0 }
    } completion: { _ in
      stage.removeFromSuperview()
    }
  }
}

final class GiftsController: StackScreen {
  private var quantity = 1
  private var audienceIndex = 0
  let roomID: String
  let recipients: [GiftAudienceMember]
  let picksRecipient: Bool
  var onSent: ((MusicGift, Int) -> Void)?
  init(
    store: AppStore, roomID: String, recipients: [GiftAudienceMember] = [],
    picksRecipient: Bool = false
  ) {
    self.roomID = roomID
    self.recipients = recipients
    self.picksRecipient = picksRecipient
    super.init(store: store, title: "Send a gift")
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  override func refresh() {
    guard isViewLoaded else { return }
    clear()
    if picksRecipient {
      content.addArrangedSubview(label("Send to", 15, TotiTheme.muted))
      let names = ["Everyone"] + recipients.map(\.name)
      let choice = StudioChoice(items: names, index: min(audienceIndex, names.count - 1))
      choice.onChange = { [weak self] next in self?.audienceIndex = next }
      content.addArrangedSubview(choice)
    }
    content.addArrangedSubview(
      actionButton("\(store.wallet.snapshot.diamonds) diamonds · Add more", icon: .diamond) {
        [weak self] in
        guard let self else { return }
        self.push(WalletController(store: self.store))
      })
    let quantities = StudioChoice(
      items: ["1 gift", "5 gifts", "10 gifts"], index: [1, 5, 10].firstIndex(of: quantity) ?? 0)
    quantities.onChange = { [weak self] next in
      self?.quantity = [1, 5, 10][next]
      self?.refresh()
    }
    content.addArrangedSubview(quantities)
    for i in stride(from: 0, to: MusicGift.catalog.count, by: 3) {
      let row = stack(axis: .horizontal, spacing: 8)
      row.distribution = .fillEqually
      for j in i..<min(i + 3, MusicGift.catalog.count) {
        let gift = MusicGift.catalog[j]
        let b = actionButton(
          "\(gift.name)\n\(gift.diamonds * quantity) diamonds", icon: giftIcon(for: gift),
          axis: .vertical, iconSize: 44
        ) { [weak self] in
          guard let self else { return }
          let count = self.quantity
          Task {
            if let error = await self.store.wallet.send(
              gift, quantity: count, roomID: self.roomID)
            {
              self.message(error)
            } else {
              self.onSent?(gift, count)
              let spent = gift.diamonds * count
              let spentText = spent.formatted(.number.locale(Locale(identifier: "en_US")))
              UIAccessibility.post(
                notification: .announcement,
                argument: "Sent \(gift.name). \(spentText) diamonds spent.")
              self.refresh()
            }
          }
        }
        row.addArrangedSubview(b)
      }
      content.addArrangedSubview(row)
    }
  }
}
