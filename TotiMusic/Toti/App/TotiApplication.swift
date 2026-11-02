import Combine
import UIKit
import WebKit
import PDFKit
import CryptoKit

@main final class TotiAppDelegate: UIResponder, UIApplicationDelegate {
  func application(
    _ application: UIApplication, configurationForConnecting session: UISceneSession,
    options: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    let configuration = UISceneConfiguration(name: "Toti", sessionRole: session.role)
    configuration.sceneClass = UIWindowScene.self
    configuration.delegateClass = TotiSceneDelegate.self
    return configuration
  }
}
final class TotiSceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?
  private var coordinator: TotiCoordinator?
  func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions
  ) {
    guard let scene = scene as? UIWindowScene else { return }
    let window = UIWindow(windowScene: scene)
    window.frame = scene.coordinateSpace.bounds
    window.backgroundColor = TotiTheme.background
    self.window = window
    coordinator = TotiCoordinator(window: window)
    coordinator?.start()
    window.makeKeyAndVisible()
  }
}
@MainActor final class TotiCoordinator {
  let store: AppStore = {
    #if DEBUG
    // UI tests get an isolated library inside the app sandbox, retained for relaunch checks.
    // UUID validation prevents arbitrary path injection; Release ignores this environment key.
    if let value = ProcessInfo.processInfo.environment["TOTI_UI_TEST_LIBRARY"],
      let identifier = UUID(uuidString: value) {
      let root = URL.applicationSupportDirectory
        .appendingPathComponent("UIAutomation", isDirectory: true)
        .appendingPathComponent(identifier.uuidString, isDirectory: true)
      return AppStore(storageRoot: root)
    }
    #endif
    return AppStore()
  }()
  private let window: UIWindow
  private let backdrop = StudioCanvas()
  private var token: AnyCancellable?
  init(window: UIWindow) {
    self.window = window
    backdrop.isUserInteractionEnabled = false
    window.addSubview(backdrop)
    backdrop.pin(to: window)
  }
  private func install(_ controller: UIViewController) {
    TotiNavigation.prepare(controller, in: window.bounds)
    window.rootViewController = controller
    window.layoutIfNeeded()
    window.sendSubviewToBack(backdrop)
  }
  func start() {
    let loading = UIViewController()
    loading.overrideUserInterfaceStyle = .light
    loading.view.backgroundColor = TotiTheme.background
    let brand = UIImageView(image: TotiIcon.wordmark)
    brand.contentMode = .scaleAspectFit
    brand.layer.cornerRadius = 36
    brand.layer.cornerCurve = .continuous
    brand.clipsToBounds = true
    brand.isAccessibilityElement = true
    brand.accessibilityLabel = "Toti"
    loading.view.addSubview(brand)
    brand.translatesAutoresizingMaskIntoConstraints = false
    let spinner = UIActivityIndicatorView(style: .medium)
    spinner.color = TotiTheme.plum
    spinner.accessibilityLabel = "Loading your music"
    loading.view.addSubview(spinner)
    spinner.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      brand.centerXAnchor.constraint(equalTo: loading.view.centerXAnchor),
      brand.centerYAnchor.constraint(equalTo: loading.view.centerYAnchor, constant: -24),
      brand.widthAnchor.constraint(equalToConstant: 160),
      brand.heightAnchor.constraint(equalToConstant: 160),
      spinner.centerXAnchor.constraint(equalTo: loading.view.centerXAnchor),
      spinner.topAnchor.constraint(equalTo: brand.bottomAnchor, constant: 24),
    ])
    spinner.startAnimating()
    install(loading)
    token = store.$accountExitRevision.dropFirst().receive(on: DispatchQueue.main).sink {
      [weak self] _ in self?.showEntry(welcome: false)
    }
    if store.isOnlineMode {
      // A saved guest session is reused only after the explicit login action.
      showEntry(welcome: true)
    } else {
      Task {
        await store.load()
        showEntry(welcome: true)
      }
    }
  }
  func showEntry(welcome: Bool) {
    let entry = EntryController(store: store, welcome: welcome)
    entry.onContinue = { [weak self] in
      guard let self else { return }
      self.install(TotiTabController(store: self.store))
    }
    let nav = TotiNavigationController(rootViewController: entry)
    TotiNavigation.style(nav)
    install(nav)
  }
}
/// Bottom-tab control drawn as an icon over an italic word, without a system button label.
private final class DockItem: UIControl {
  init(icon: TotiIcon, title: String) {
    super.init(frame: .zero)
    let image = UIImageView(image: icon.image(size: 30))
    image.contentMode = .scaleAspectFit
    image.isUserInteractionEnabled = false
    let caption = UILabel()
    caption.text = title
    caption.font = TotiTheme.font(10, title: true)
    caption.textColor = TotiTheme.ink
    caption.textAlignment = .center
    caption.adjustsFontSizeToFitWidth = true
    caption.minimumScaleFactor = 0.7
    caption.isUserInteractionEnabled = false
    caption.layer.shadowColor = UIColor.white.cgColor
    caption.layer.shadowOpacity = 0.95
    caption.layer.shadowRadius = 2
    caption.layer.shadowOffset = .zero
    caption.layer.masksToBounds = false
    image.layer.shadowColor = UIColor.white.cgColor
    image.layer.shadowOpacity = 0.9
    image.layer.shadowRadius = 2.5
    image.layer.shadowOffset = .zero
    image.layer.masksToBounds = false
    let column = UIStackView(arrangedSubviews: [image, caption])
    column.axis = .vertical
    column.alignment = .center
    column.spacing = 1
    column.isUserInteractionEnabled = false
    addSubview(column)
    column.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      column.centerXAnchor.constraint(equalTo: centerXAnchor),
      column.centerYAnchor.constraint(equalTo: centerYAnchor),
      caption.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -2),
      image.widthAnchor.constraint(equalToConstant: 30),
      image.heightAnchor.constraint(equalToConstant: 30),
    ])
    isAccessibilityElement = true
    accessibilityLabel = title
    accessibilityTraits = .button
    addTarget(self, action: #selector(pressDown), for: .touchDown)
    addTarget(self, action: #selector(pressUp), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  @objc private func pressDown() {
    guard !UIAccessibility.isReduceMotionEnabled else { return }
    UIView.animate(withDuration: 0.12, delay: 0, options: [.allowUserInteraction]) {
      self.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
    }
  }
  @objc private func pressUp() {
    UIView.animate(
      withDuration: 0.28, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.4,
      options: [.allowUserInteraction]
    ) { self.transform = .identity }
  }
}

final class TotiTabController: UIViewController, UINavigationControllerDelegate {
  let store: AppStore
  private var pages: [UINavigationController] = []
  private let dock = UIView(), bubble = UIView(), buttons = UIStackView()
  private var index = 0
  private var draggingDock = false
  private var movingBubble = false
  private var bubbleMove = 0
  private var selectedLeading: NSLayoutConstraint?
  init(store: AppStore) {
    self.store = store
    super.init(nibName: nil, bundle: nil)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  override func viewDidLoad() {
    super.viewDidLoad()
    overrideUserInterfaceStyle = .light
    view.backgroundColor = TotiTheme.background
    view.clipsToBounds = false
    let screens: [UIViewController] = [
      LoungeController(store: store), PartyDiscoveryController(store: store),
      NotebookController(store: store), ChatsController(store: store), MeController(store: store),
    ]
    pages = screens.map {
      let nav = TotiNavigationController(rootViewController: $0)
      TotiNavigation.style(nav)
      nav.delegate = self
      nav.additionalSafeAreaInsets.bottom = 78
      return nav
    }
    dock.backgroundColor = .clear
    dock.layer.cornerRadius = 30
    dock.layer.cornerCurve = .continuous
    dock.layer.borderWidth = 1
    dock.layer.borderColor = UIColor.white.withAlphaComponent(0.55).cgColor
    dock.clipsToBounds = false
    view.addSubview(dock)
    dock.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      dock.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
      dock.trailingAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
      dock.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -6),
      dock.heightAnchor.constraint(equalToConstant: 66),
    ])
    let frost = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialLight))
    frost.isUserInteractionEnabled = false
    frost.layer.cornerRadius = 30
    frost.layer.cornerCurve = .continuous
    frost.clipsToBounds = true
    dock.addSubview(frost)
    frost.pin(to: dock)
    let veil = UIView()
    veil.backgroundColor = UIColor.white.withAlphaComponent(0.2)
    veil.isUserInteractionEnabled = false
    frost.contentView.addSubview(veil)
    veil.pin(to: frost.contentView)
    bubble.backgroundColor = .clear
    bubble.rounded(28)
    bubble.layer.borderWidth = 1
    bubble.layer.borderColor = UIColor.white.withAlphaComponent(0.72).cgColor
    let glass = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialLight))
    glass.isUserInteractionEnabled = false
    bubble.addSubview(glass)
    glass.pin(to: bubble)
    let tint = UIView()
    tint.backgroundColor = TotiTheme.coral.withAlphaComponent(0.16)
    tint.isUserInteractionEnabled = false
    glass.contentView.addSubview(tint)
    tint.pin(to: glass.contentView)
    dock.addSubview(bubble)
    bubble.translatesAutoresizingMaskIntoConstraints = false
    selectedLeading = bubble.leadingAnchor.constraint(equalTo: dock.leadingAnchor, constant: 5)
    NSLayoutConstraint.activate([
      selectedLeading!, bubble.topAnchor.constraint(equalTo: dock.topAnchor, constant: 5),
      bubble.bottomAnchor.constraint(equalTo: dock.bottomAnchor, constant: -5),
      bubble.widthAnchor.constraint(equalTo: dock.widthAnchor, multiplier: 1 / CGFloat(pages.count), constant: -6),
    ])
    buttons.axis = .horizontal
    buttons.distribution = .fillEqually
    dock.addSubview(buttons)
    buttons.pin(to: dock, insets: UIEdgeInsets(top: 3, left: 3, bottom: 3, right: 3))
    for (i, pair) in [
      (TotiIcon.lounge, "Lounge"), (.voice, "Voice"), (.notebook, "Notebook"),
      (.chats, "Chats"), (.me, "Me"),
    ]
      .enumerated()
    {
      let item = DockItem(icon: pair.0, title: pair.1)
      item.addAction(UIAction { [weak self] _ in self?.select(i) }, for: .touchUpInside)
      buttons.addArrangedSubview(item)
    }
    let pan = UIPanGestureRecognizer(target: self, action: #selector(dragDock(_:)))
    dock.addGestureRecognizer(pan)
    select(0)
  }
  @objc private func dragDock(_ gesture: UIPanGestureRecognizer) {
    let width = dock.bounds.width
    guard width > 0 else { return }
    let segment = width / CGFloat(pages.count)
    let leading = min(5 + CGFloat(pages.count - 1) * segment, max(5, gesture.location(in: dock).x - (segment - 6) / 2))
    let nearest = min(pages.count - 1, max(0, Int(((leading - 5) / segment).rounded())))
    switch gesture.state {
    case .began, .changed:
      draggingDock = true
      selectedLeading?.constant = leading
      let slot = 5 + CGFloat(nearest) * segment
      let pull = min(0.06, abs(leading - slot) / segment * 0.1)
      bubble.transform = CGAffineTransform(scaleX: 1 + pull, y: 1 - pull * 0.45)
      showPage(nearest)
    case .ended, .cancelled, .failed:
      draggingDock = false
      select(nearest)
    default:
      break
    }
  }
  private func select(_ next: Int) {
    let previous = index
    showPage(next)
    guard dock.bounds.width > 0 else { return }
    let destination = 5 + CGFloat(index) * dock.bounds.width / CGFloat(pages.count)
    bubbleMove += 1
    let move = bubbleMove
    let finish = {
      self.selectedLeading?.constant = destination
      self.dock.layoutIfNeeded()
      self.bubble.transform = .identity
    }
    if UIAccessibility.isReduceMotionEnabled {
      movingBubble = false
      finish()
      return
    }
    let alreadyThere = previous == index && bubble.transform.isIdentity
    if alreadyThere {
      movingBubble = false
      finish()
      return
    }
    movingBubble = true
    // One spring carries the bubble into place. No second pose, so it does not stop midway.
    if previous != index {
      let stretch = min(1.045, 1 + 0.02 * CGFloat(abs(index - previous)))
      bubble.transform = CGAffineTransform(scaleX: stretch, y: 2 - stretch)
    }
    UIView.animate(
      withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0.15,
      options: [.allowUserInteraction, .beginFromCurrentState]
    ) {
      finish()
    } completion: { _ in
      if self.bubbleMove == move { self.movingBubble = false }
    }
  }
  private func showPage(_ next: Int) {
    guard children.isEmpty || next != index else { return }
    let old = children.isEmpty ? nil : pages[index]
    index = next
    let nav = pages[next]
    addChild(nav)
    view.insertSubview(nav.view, at: 0)
    nav.view.pin(to: view)
    let covered = nav.topViewController !== nav.viewControllers.first
    applyDock(covered: covered, nav: nav)
    TotiNavigation.prepare(nav, in: view.bounds)
    view.layoutIfNeeded()
    nav.didMove(toParent: self)
    // Keep the previous page attached until the destination has real laid-out content.
    if let old {
      old.willMove(toParent: nil)
      old.view.removeFromSuperview()
      old.removeFromParent()
    }
    for (i, button) in buttons.arrangedSubviews.enumerated() {
      button.accessibilityTraits = i == next ? [.button, .selected] : .button
    }
  }
  func navigationController(
    _ navigationController: UINavigationController, willShow viewController: UIViewController,
    animated: Bool
  ) {
    guard pages.indices.contains(index), navigationController === pages[index] else { return }
    let covered = viewController !== navigationController.viewControllers.first
    let apply = { self.applyDock(covered: covered, nav: navigationController) }
    guard animated, let coordinator = navigationController.transitionCoordinator else {
      apply()
      return
    }
    coordinator.animate(alongsideTransition: { _ in apply() }) { context in
      guard context.isCancelled else { return }
      let stillCovered = navigationController.topViewController !== navigationController.viewControllers.first
      self.applyDock(covered: stillCovered, nav: navigationController)
    }
  }
  /// Home pages keep the dock. A pushed page, including a friend chat, covers it.
  private func applyDock(covered: Bool, nav: UINavigationController) {
    nav.additionalSafeAreaInsets.bottom = covered ? 0 : 78
    dock.alpha = covered ? 0 : 1
    dock.isUserInteractionEnabled = !covered
    dock.accessibilityElementsHidden = covered
  }
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    if bubble.bounds.height > 1 {
      bubble.layer.cornerRadius = bubble.bounds.height / 2
    }
    guard !draggingDock, !movingBubble, dock.bounds.width > 0 else { return }
    selectedLeading?.constant = 5 + CGFloat(index) * dock.bounds.width / CGFloat(pages.count)
  }

}
final class EntryController: TotiScreen, UITextViewDelegate {
  var onContinue: (() -> Void)?
  private let scroll = UIScrollView()
  private let content = UIStackView()
  private var welcome: Bool
  private var accepted = false
  private var signingIn = false
  init(store: AppStore, welcome: Bool) {
    self.welcome = welcome
    super.init(store: store)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  override func build() {
    scroll.contentInsetAdjustmentBehavior = .never
    scroll.showsVerticalScrollIndicator = false
    view.addSubview(scroll)
    scroll.translatesAutoresizingMaskIntoConstraints = false
    content.axis = .vertical
    content.spacing = 16
    scroll.addSubview(content)
    content.translatesAutoresizingMaskIntoConstraints = false
    let preferredWidth = content.widthAnchor.constraint(
      equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -40)
    preferredWidth.priority = .defaultHigh
    NSLayoutConstraint.activate([
      scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
      scroll.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
      scroll.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
      scroll.contentLayoutGuide.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
      content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 12),
      content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -20),
      content.centerXAnchor.constraint(equalTo: scroll.contentLayoutGuide.centerXAnchor),
      content.widthAnchor.constraint(lessThanOrEqualToConstant: 440),
      content.widthAnchor.constraint(lessThanOrEqualTo: scroll.frameLayoutGuide.widthAnchor, constant: -40),
      content.heightAnchor.constraint(greaterThanOrEqualTo: scroll.frameLayoutGuide.heightAnchor, constant: -32),
      preferredWidth,
    ])
  }
  override func viewWillAppear(_ animated: Bool) {
    navigationController?.setNavigationBarHidden(true, animated: false)
    super.viewWillAppear(animated)
  }
  override func refresh() {
    guard isViewLoaded else { return }
    content.arrangedSubviews.forEach { $0.removeFromSuperview() }
    let logo = UIImageView(image: TotiIcon.wordmark)
    logo.contentMode = .scaleAspectFit
    logo.layer.cornerRadius = 26
    logo.layer.cornerCurve = .continuous
    logo.clipsToBounds = true
    logo.isAccessibilityElement = true
    logo.accessibilityLabel = "Toti"
    let mark = UIView()
    logo.translatesAutoresizingMaskIntoConstraints = false
    mark.addSubview(logo)
    NSLayoutConstraint.activate([
      logo.topAnchor.constraint(equalTo: mark.topAnchor),
      logo.bottomAnchor.constraint(equalTo: mark.bottomAnchor),
      logo.centerXAnchor.constraint(equalTo: mark.centerXAnchor),
      logo.widthAnchor.constraint(equalToConstant: 112),
      logo.heightAnchor.constraint(equalToConstant: 112),
    ])
    content.addArrangedSubview(mark)
    content.setCustomSpacing(4, after: mark)
    let musicians = UIImageView(image: UIImage(named: "TotiEntryMusic"))
    musicians.contentMode = .scaleAspectFit
    musicians.isAccessibilityElement = false
    content.addArrangedSubview(musicians)
    // Both views must share the stack hierarchy before activating this constraint.
    musicians.heightAnchor.constraint(equalTo: content.widthAnchor, multiplier: 0.78).isActive = true
    let title = label(welcome ? "Every voice.\nA new story." : "Find your\nmusic people.", 36, title: true)
    title.textAlignment = .center
    title.accessibilityTraits = .header
    title.setContentCompressionResistancePriority(.required, for: .vertical)
    content.addArrangedSubview(title)
    content.setCustomSpacing(8, after: title)
    let subtitle = label(
      welcome ? "Your sound. Your people." : "Open the mic. Find your harmony.",
      18, TotiTheme.muted)
    subtitle.textAlignment = .center
    subtitle.setContentCompressionResistancePriority(.required, for: .vertical)
    content.addArrangedSubview(subtitle)
    let space = UIView()
    space.heightAnchor.constraint(greaterThanOrEqualToConstant: 0).isActive = true
    space.setContentHuggingPriority(.init(1), for: .vertical)
    content.addArrangedSubview(space)
    content.setCustomSpacing(0, after: space)
    if let error = store.loadError {
      content.addArrangedSubview(label(error))
      content.addArrangedSubview(
        actionButton("Try again", icon: .refresh) { [weak self] in
          Task {
            await self?.store.load()
            self?.refresh()
          }
        })
      return
    }
    if welcome {
      content.addArrangedSubview(
        actionButton("Get started", icon: .forward, tone: .coral) { [weak self] in
          self?.welcome = false
          self?.refresh()
          self?.scroll.setContentOffset(.zero, animated: false)
        })
      return
    }
    let box = iconButton(
      accepted ? .checkboxOn : .checkbox,
      accepted ? "Agreement checked" : "Agree to the agreements", size: 28
    ) { [weak self] in
      guard let self else { return }
      self.accepted.toggle()
      self.refresh()
    }
    box.accessibilityTraits = accepted ? [.button, .selected] : .button
    box.widthAnchor.constraint(equalToConstant: 44).isActive = true
    let row = stack([box, agreementText()], axis: .horizontal, spacing: 10)
    row.alignment = .top
    content.addArrangedSubview(row)
    content.addArrangedSubview(
      actionButton(signingIn ? "Logging in…" : "Log in", icon: .forward, tone: .coral) { [weak self] in self?.continueEntry() }
    )
  }
  private func agreementText() -> UITextView {
    let text = UITextView()
    text.backgroundColor = .clear
    text.isEditable = false
    text.isSelectable = true
    text.isScrollEnabled = false
    text.delegate = self
    text.textContainerInset = .zero
    text.textContainer.lineFragmentPadding = 0
    text.adjustsFontForContentSizeCategory = true
    text.linkTextAttributes = [
      .foregroundColor: TotiTheme.plum,
      .underlineStyle: NSUnderlineStyle.single.rawValue,
    ]
    let bodyStyle = NSMutableParagraphStyle()
    bodyStyle.lineSpacing = 3
    let base: [NSAttributedString.Key: Any] = [
      .font: TotiTheme.font(16),
      .foregroundColor: TotiTheme.ink,
      .paragraphStyle: bodyStyle,
    ]
    let body = NSMutableAttributedString(
      string: "I have read and agree to the ", attributes: base)
    for (index, document) in AgreementDocument.allCases.enumerated() {
      if index > 0 {
        body.append(NSAttributedString(string: " and ", attributes: base))
      }
      var link = base
      link[.link] = URL(string: "toti-agreement://agreement/\(document.rawValue)")
      link[.foregroundColor] = TotiTheme.plum
      link[.underlineStyle] = NSUnderlineStyle.single.rawValue
      body.append(NSAttributedString(string: document.linkTitle, attributes: link))
    }
    body.append(NSAttributedString(string: ".", attributes: base))
    text.attributedText = body
    text.accessibilityLabel =
      "I have read and agree to the Terms of Service and Privacy Policy."
    return text
  }
  func textView(
    _ textView: UITextView,
    shouldInteractWith url: URL,
    in characterRange: NSRange,
    interaction: UITextItemInteraction
  ) -> Bool {
    if #available(iOS 17.0, *) {
      return true
    }
    presentAgreement(for: url)
    return false
  }
  @available(iOS 17.0, *)
  func textView(
    _ textView: UITextView, primaryActionFor textItem: UITextItem, defaultAction: UIAction
  ) -> UIAction? {
    guard case .link(let url) = textItem.content, let document = agreementDocument(for: url) else {
      return defaultAction
    }
    return UIAction { [weak self] _ in
      guard let self else { return }
      self.presentScreen(AgreementController(store: self.store, document: document))
    }
  }
  private func presentAgreement(for url: URL) {
    guard let document = agreementDocument(for: url) else { return }
    presentScreen(AgreementController(store: store, document: document))
  }
  private func agreementDocument(for url: URL) -> AgreementDocument? {
    guard url.scheme == "toti-agreement",
      let name = url.path.split(separator: "/").last
    else { return nil }
    return AgreementDocument(rawValue: String(name))
  }
  private func continueEntry() {
    guard !signingIn else { return }
    guard accepted else {
      askToAgree()
      return
    }
    enterApp()
  }
  private func askToAgree() {
    let agree = actionButton("Agree and continue", primary: true) { [weak self] in
      guard let self else { return }
      self.accepted = true
      self.dismissCard {
        self.refresh()
        self.enterApp()
      }
    }
    let decline = actionButton("Disagree") { [weak self] in self?.dismissCard() }
    showCard([agreementReminder(), agree, decline])
  }
  private func agreementReminder() -> UITextView {
    let text = UITextView()
    text.backgroundColor = .clear
    text.isEditable = false
    text.isSelectable = true
    text.isScrollEnabled = false
    text.delegate = self
    text.textContainerInset = .zero
    text.textContainer.lineFragmentPadding = 0
    text.adjustsFontForContentSizeCategory = true
    text.linkTextAttributes = [
      .foregroundColor: TotiTheme.plum,
      .underlineStyle: NSUnderlineStyle.single.rawValue,
    ]
    let bodyStyle = NSMutableParagraphStyle()
    bodyStyle.lineSpacing = 3
    let base: [NSAttributedString.Key: Any] = [
      .font: TotiTheme.font(16),
      .foregroundColor: TotiTheme.ink,
      .paragraphStyle: bodyStyle,
    ]
    let body = NSMutableAttributedString(
      string: "Please read and agree to the ", attributes: base)
    for (index, document) in AgreementDocument.allCases.enumerated() {
      if index > 0 {
        body.append(NSAttributedString(string: " and ", attributes: base))
      }
      var link = base
      link[.link] = URL(string: "toti-agreement://agreement/\(document.rawValue)")
      link[.foregroundColor] = TotiTheme.plum
      link[.underlineStyle] = NSUnderlineStyle.single.rawValue
      body.append(NSAttributedString(string: document.linkTitle, attributes: link))
    }
    body.append(NSAttributedString(string: " before you continue.", attributes: base))
    text.attributedText = body
    text.accessibilityLabel =
      "Please read and agree to the Terms of Service and Privacy Policy before you continue."
    text.frame.size.width = 284
    let height = text.sizeThatFits(CGSize(width: 284, height: 240)).height
    text.heightAnchor.constraint(equalToConstant: max(48, height)).isActive = true
    return text
  }
  private func enterApp() {
    guard !signingIn else { return }
    signingIn = true
    refresh()
    view.isUserInteractionEnabled = false
    Task {
      defer {
        signingIn = false
        view.isUserInteractionEnabled = true
        refresh()
      }
      if store.isOnlineMode {
        do {
          try await TotiBackend.shared.signInAsGuest(agreementVersion: TotiUserAgreement.version)
          if await store.refreshOnline() { onContinue?() }
          else { message(store.onlineReadError ?? "Your account could not be loaded. Please try again.") }
        } catch { message(error.localizedDescription) }
      } else if await store.acceptUserAgreement() {
        onContinue?()
      } else {
        message(store.lastSaveError ?? "The agreements could not be saved. Please try again.")
      }
    }
  }
}
final class AgreementController: TotiScreen {
  let document: AgreementDocument
  private let pdf = PDFView()
  private let spinner = UIActivityIndicatorView(style: .medium)
  private var loadingTask: Task<Void, Never>?

  init(store: AppStore, document: AgreementDocument) {
    self.document = document
    super.init(store: store, title: document.title)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  override func build() {
    pdf.autoScales = true
    pdf.backgroundColor = TotiTheme.background
    view.addSubview(pdf)
    pdf.pin(to: view)
    view.addSubview(spinner)
    spinner.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
    ])
    navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Retry", style: .plain, target: self, action: #selector(loadPDF))
    loadPDF()
  }
  @objc private func loadPDF() {
    loadingTask?.cancel()
    guard let url = document.onlineURL, url.scheme == "https" else {
      message("This agreement is unavailable. Please try again later.")
      return
    }
    spinner.startAnimating()
    loadingTask = Task { [weak self] in
      guard let self else { return }
      defer { self.spinner.stopAnimating() }
      do {
        let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url, timeoutInterval: 30))
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode),
          response.url?.scheme == "https", data.count <= 5_000_000,
          data.starts(with: Data("%PDF-".utf8)),
          SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == self.document.expectedPDFHash,
          let document = PDFDocument(data: data) else {
          throw URLError(.cannotDecodeContentData)
        }
        self.pdf.document = document
      } catch is CancellationError { }
      catch { if !Task.isCancelled { self.message("The PDF could not be loaded. Check your connection and tap Retry.") } }
    }
  }
  deinit { loadingTask?.cancel() }
}
