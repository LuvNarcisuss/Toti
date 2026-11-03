import Combine
import UIKit

final class SafetyController: StackScreen {
  private let entryGeneration = TotiBackend.shared.generation
  private var entryAccountIsCurrent: Bool { !store.isOnlineMode || entryGeneration == TotiBackend.shared.generation }
  let target: ContentSafetyTarget
  var recordingInformation: String?
  var saveLocalReport: ((ContentReportReason, String) -> Bool)?
  private var submitsOnline: Bool { store.isOnlineMode && saveLocalReport == nil }
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
          guard let self, self.entryAccountIsCurrent else { return }
          self.reporting = true
          self.title = "Report"
          self.installStudioChrome()
          self.reportFormReady = false
          self.refresh()
        })
      content.addArrangedSubview(
        actionButton("Block " + target.creator.name, icon: .block) { [weak self] in
          guard let self, self.entryAccountIsCurrent else { return }
          self.confirm(
            "Block this creator?",
            message:
              "Their posts, comments and voice rooms will be hidden. You can unblock them from Blocked in Settings.",
            destructive: true, button: "Block"
          ) { [weak self] in
            guard let self, self.entryAccountIsCurrent else { return }
            Task {
              guard self.entryAccountIsCurrent else { return }
              let blocked = await self.store.blockCreator(self.target.creator)
              guard self.entryAccountIsCurrent else { return }
              if blocked {
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
        submitsOnline ? "Reports are submitted to Toti. Submission does not mean a review has been completed." : "Reports stay on this device and are not submitted. Remove one from Reported in Settings.",
        14, TotiTheme.muted))
    content.addArrangedSubview(
      actionButton(submitsOnline ? "Submit report" : "Save report", icon: .flag, primary: true) { [weak self] in
        guard let self, self.entryAccountIsCurrent else { return }
        let reason = selected
        let note = details.text ?? ""
        Task {
          guard self.entryAccountIsCurrent else { return }
          let submitted: Bool
          if let saveLocalReport = self.saveLocalReport { submitted = saveLocalReport(reason, note) }
          else { submitted = await self.store.saveContentReport(self.target, reason: reason, details: note) }
          guard self.entryAccountIsCurrent else { return }
          if submitted {
            self.view.endEditing(true)
            self.closeAfterAction(note: self.submitsOnline ? "Report submitted" : "Report saved on this device")
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
    let balance = heading(store.wallet.isServerWalletUnavailable ? "— Diamonds" : "\(store.wallet.snapshot.diamonds.formatted()) Diamonds")
    balance.accessibilityIdentifier = "wallet.balance"
    balance.accessibilityValue = store.wallet.isServerWalletUnavailable ? "Balance unavailable" : String(store.wallet.snapshot.diamonds)
    content.addArrangedSubview(
      label(
        store.wallet.isLocalStoreKitTesting
          ? "Local test balance and purchase history. Your online account remains signed in."
          : store.wallet.isServerWalletUnavailable
          ? "Your online balance is not available yet. Previous on-device diamonds remain separate in your local archive."
          : "Send a little appreciation. Use diamonds for local gifts on posts and in voice rooms. Messages and replies are free.",
        15, TotiTheme.muted))
    if store.wallet.isLocalStoreKitTesting {
      let status = label("Local StoreKit testing · No real charges. Test diamonds stay on this device for this account and cannot be spent online.", 15, TotiTheme.muted)
      status.accessibilityIdentifier = "wallet.localTesting.notice"
      content.addArrangedSubview(status)
    }
    if let error = store.wallet.localTestingError {
      content.addArrangedSubview(label(error, 15, TotiTheme.muted))
    }
    if store.wallet.isServerWalletUnavailable {
      let status = label("Purchases and gifts are temporarily unavailable. You cannot buy or spend diamonds right now.", 15, TotiTheme.muted)
      status.accessibilityIdentifier = "wallet.payments.unavailable"
      content.addArrangedSubview(status)
    } else if let status = store.wallet.catalog.message {
      let statusLabel = label(status, 14, TotiTheme.muted)
      statusLabel.accessibilityIdentifier = "wallet.catalog.status"
      content.addArrangedSubview(statusLabel)
    }
    if !store.wallet.isServerWalletUnavailable && (store.wallet.catalog.canRetry || store.wallet.localTestingError != nil) {
      let retry = actionButton("Retry prices") { [weak self] in self?.store.wallet.retryProducts() }
      retry.accessibilityIdentifier = "wallet.catalog.retry"
      retry.isEnabled = !store.wallet.isBusy
      content.addArrangedSubview(retry)
    }
    heading("Add diamonds")
    if store.wallet.isServerWalletUnavailable {
      content.addArrangedSubview(label("USD reference prices are shown below. Final prices will come from the App Store when purchases are available.", 14, TotiTheme.muted))
    }
    let packages = WalletCatalog.packages(for: .diamonds)
    for start in stride(from: 0, to: packages.count, by: 3) {
      let row = stack(axis: .horizontal, spacing: 8)
      row.distribution = .fillEqually
      let end = min(start + 3, packages.count)
      for package in packages[start..<end] {
        let price = store.wallet.isServerWalletUnavailable ? "\(package.price) USD\nUnavailable" : store.wallet.priceText(for: package)
        let priceNote = "Price: \(price)"
        let b = actionButton(
          package.amountText + "\n" + price, icon: .diamond, axis: .vertical
        ) { [weak self] in
          guard let self, !self.store.wallet.isServerWalletUnavailable, self.store.wallet.canPurchase(package) else { return }
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
        if store.wallet.isServerWalletUnavailable { b.caption.numberOfLines = 0 }
        b.isEnabled = !store.wallet.isServerWalletUnavailable && store.wallet.canPurchase(package)
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
    if store.wallet.isServerWalletUnavailable {
      let status = label("Online transaction history is not available yet. Previous on-device transactions remain in your local archive.", 15, TotiTheme.muted)
      status.accessibilityIdentifier = "wallet.activity.unavailable"
      content.addArrangedSubview(status)
    } else if store.wallet.snapshot.activity.isEmpty {
      content.addArrangedSubview(label("No transactions yet.", 15, TotiTheme.muted))
    }
    if !store.wallet.isServerWalletUnavailable {
      for item in store.wallet.snapshot.activity {
        let activity = label(item.title)
        activity.accessibilityIdentifier = "wallet.activity.\(item.id)"
        content.addArrangedSubview(activity)
      }
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
  static func show(gift: MusicGift, quantity: Int, in host: UIView, coversWindow: Bool = true) {
    let canvas = coversWindow ? (host.window ?? host) : host
    let stage = UIView(frame: canvas.bounds)
    stage.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    stage.isUserInteractionEnabled = false
    stage.backgroundColor = .clear
    stage.isAccessibilityElement = true
    stage.accessibilityIdentifier = "gift.effect"
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

extension TotiScreen {
  func openGifts(_ context: GiftContext, picksRecipient: Bool = false) {
    guard !store.isOnlineMode else { message("Gifts are not available yet."); return }
    if let reason = store.giftUnavailableReason(context) { message(reason); return }
    let gifts = GiftsController(store: store, context: context, picksRecipient: picksRecipient)
    presentScreen(gifts)
    gifts.navigationController?.sheetPresentationController?.detents = [.large()]
  }
}

final class GiftsController: StackScreen {
  private var quantity = 1
  private var audienceIndex = 0
  private var saving = false
  private var outcome: String?
  let context: GiftContext
  let picksRecipient: Bool
  var onGiftSaved: ((MusicGift, Int) -> Void)?

  init(store: AppStore, context: GiftContext, picksRecipient: Bool = false) {
    self.context = context
    self.picksRecipient = picksRecipient
    super.init(store: store, title: "Give a gift")
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

  override func build() {
    super.build()
    scroll.accessibilityIdentifier = "gift.scroll"
    store.wallet.prepareProducts()
    store.wallet.objectWillChange.receive(on: DispatchQueue.main).sink { [weak self] _ in
      self?.refresh()
    }.store(in: &tokens)
  }

  private var selection: GiftContext {
    var selected = context
    if picksRecipient, audienceIndex > 0, context.recipients.indices.contains(audienceIndex - 1) {
      selected.recipients = [context.recipients[audienceIndex - 1]]
    }
    return selected
  }

  override func refresh() {
    guard isViewLoaded, isAccountContextCurrent else { return }
    clear()
    heading(context.sourceTitle)
    if store.isOnlineMode && !store.wallet.isLocalStoreKitTesting {
      content.addArrangedSubview(label("Gifts are not available yet.", 16, TotiTheme.muted))
    } else {
      content.addArrangedSubview(label("Gifts create an effect and a record on this device. They are not delivered to another person or added to their balance.", 14, TotiTheme.muted))
    }
    if picksRecipient {
      content.addArrangedSubview(label("For", 15, TotiTheme.muted))
      let names = ["Everyone"] + context.recipients.map(\.name)
      let choice = StudioChoice(items: names, index: audienceIndex)
      choice.onChange = { [weak self] next in self?.audienceIndex = next; self?.refresh() }
      choice.isUserInteractionEnabled = !saving
      content.addArrangedSubview(choice)
      content.addArrangedSubview(label("Everyone creates one shared gift effect at the displayed total price.", 12, TotiTheme.muted))
    }
    let recipient = label("For: " + selection.recipientText, 15)
    recipient.accessibilityIdentifier = "gift.recipients"
    content.addArrangedSubview(recipient)
    let balance = label(store.wallet.isServerWalletUnavailable ? "Balance unavailable" : "\(store.wallet.snapshot.diamonds.formatted()) diamonds", 20)
    balance.accessibilityIdentifier = "gift.balance"
    balance.accessibilityValue = store.wallet.isServerWalletUnavailable ? "Balance unavailable" : String(store.wallet.snapshot.diamonds)
    content.addArrangedSubview(balance)
    let topUp = actionButton("Add diamonds", icon: .diamond) { [weak self] in
      guard let self else { return }; self.push(WalletController(store: self.store))
    }
    topUp.isEnabled = !saving && !store.wallet.isBusy
    content.addArrangedSubview(topUp)
    if let outcome {
      let status = label(outcome, 14, TotiTheme.muted)
      status.accessibilityIdentifier = "gift.outcome"
      content.addArrangedSubview(status)
    }
    let unavailable = store.giftUnavailableReason(selection)
    if let unavailable { content.addArrangedSubview(label(unavailable, 14, TotiTheme.muted)) }
    let quantities = StudioChoice(items: ["1 gift", "5 gifts", "10 gifts"], index: [1, 5, 10].firstIndex(of: quantity) ?? 0)
    quantities.onChange = { [weak self] next in self?.quantity = [1, 5, 10][next]; self?.refresh() }
    quantities.isUserInteractionEnabled = !saving
    content.addArrangedSubview(quantities)
    for i in stride(from: 0, to: MusicGift.catalog.count, by: 3) {
      let row = stack(axis: .horizontal, spacing: 8)
      row.distribution = .fillEqually
      for gift in MusicGift.catalog[i..<min(i + 3, MusicGift.catalog.count)] {
        let button = actionButton("\(gift.name)\n\(gift.diamonds * quantity) diamonds",
          icon: giftIcon(for: gift), axis: .vertical, iconSize: 44) { [weak self] in self?.confirmGift(gift) }
        button.accessibilityIdentifier = "gift.item." + gift.id
        button.isEnabled = !saving && !store.wallet.isBusy && unavailable == nil
        row.addArrangedSubview(button)
      }
      content.addArrangedSubview(row)
    }
  }

  private func setSaving(_ value: Bool) {
    saving = value
    navigationController?.isModalInPresentation = value
    navigationItem.leftBarButtonItem?.isEnabled = !value
    navigationItem.leftBarButtonItem?.customView?.isUserInteractionEnabled = !value
  }

  private func confirmGiftAction(_ title: String, message: String, button: String, action: @escaping () -> Void) {
    guard presentedViewController == nil else { return }
    // UIKit keeps long recipient lists scrollable and the actions reachable at large text sizes.
    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alert.addAction(UIAlertAction(title: button, style: .default) { _ in action() })
    present(alert, animated: true)
  }

  private func confirmGift(_ gift: MusicGift) {
    guard isAccountContextCurrent, !saving, !store.wallet.isBusy else { return }
    let selected = selection
    let count = quantity
    let cost = gift.diamonds * count
    if let reason = store.giftUnavailableReason(selected) { message(reason); return }
    guard store.wallet.snapshot.diamonds >= cost else {
      confirmGiftAction("Not enough diamonds", message: "This gift costs \(cost) diamonds. No diamonds have been spent.", button: "Add diamonds") { [weak self] in
        guard let self else { return }; self.push(WalletController(store: self.store))
      }
      return
    }
    confirmGiftAction("Confirm gift", message: "\(count) × \(gift.name)\nFor: \(selected.recipientText)\nTotal: \(cost) diamonds\nBalance after: \(store.wallet.snapshot.diamonds - cost) diamonds\n\nThis spends diamonds for a local effect and record only. No gift or funds are delivered to the recipient.", button: "Spend \(cost) diamonds") { [weak self] in
      guard let self, self.isAccountContextCurrent, !self.saving, !self.store.wallet.isBusy else { return }
      self.setSaving(true)
      self.outcome = nil
      self.refresh()
      Task {
        let error = await self.store.giveGift(gift, quantity: count, context: selected)
        self.setSaving(false)
        guard self.isAccountContextCurrent else { return }
        if let error { self.outcome = error }
        else {
          self.outcome = "Gift saved on this device · \(cost) diamonds spent."
          UIAccessibility.post(notification: .announcement, argument: self.outcome)
          if let onGiftSaved = self.onGiftSaved {
            // The originating room owns the effect after the picker is fully dismissed.
            self.setSaving(true)
            (self.navigationController ?? self).dismiss(animated: true) {
              onGiftSaved(gift, count)
            }
            return
          }
          GiftBurst.show(gift: gift, quantity: count, in: self.view)
        }
        self.refresh()
      }
    }
  }
}
