import Combine
import Foundation
import UIKit

@MainActor
final class AppStore: ObservableObject {
  @Published private(set) var library = LocalLibrary()
  @Published private(set) var isLoaded = false
  @Published private(set) var loadError: String?
  @Published private(set) var busyMessage: String?
  @Published var notice: AppNotice?
  @Published private(set) var accountExitRevision = 0
  private var sessionActive = false
  let isOnlineMode: Bool
  @Published var onlineEditorialPosts: [OnlineEditorialPost] = []
  @Published var onlineEditorialError: String?
  @Published var onlineCommunityRooms: [PartyRoom] = []
  @Published var onlineCommunityRoomsError: String?
  @Published var onlineReadError: String?
  @Published var onlineHasMore = false
  var onlineRecords: [String: [OnlineRecord]] = [:]
  var onlineCursors: [String: String] = [:]
  var onlineThreadPages: [String: Int] = [:]
  var onlineThreadStarts: [String: String] = [:]
  var onlineThreadParentKinds: [String: String] = [:]
  var onlineAcknowledgedVersions: [UUID: Int] = [:]
  var onlineReadInProgress = false
  var onlineMutationInProgress = false
  var onlineRefreshTask: Task<Void, Never>?
  var onlineAccountObservation: AnyCancellable?
  var onlineProjectedAccountID: UUID?
  var onlineProjectedGeneration: Int?

  func adoptOnlineLibrary(_ value: LocalLibrary) {
    library = value
    isLoaded = true
    sessionActive = TotiBackend.shared.isAuthenticated
    loadError = nil
  }

  func clearOnlineState() {
    onlineRefreshTask?.cancel()
    onlineRefreshTask = nil
    onlineRecords = [:]
    onlineEditorialPosts = []
    onlineEditorialError = nil
    onlineCommunityRooms = []
    onlineCommunityRoomsError = nil
    onlineCursors = [:]
    onlineThreadPages = [:]
    onlineThreadStarts = [:]
    onlineThreadParentKinds = [:]
    onlineAcknowledgedVersions = [:]
    onlineHasMore = false
    onlineReadError = nil
    onlineProjectedAccountID = nil
    onlineProjectedGeneration = nil
    library = LocalLibrary()
    sessionActive = false
    isLoaded = false
    ownerAvatarCache = nil
    ownerAvatarStamp = nil
    wallet.clearAccountMemory()
    notice = nil
    lastSaveError = nil
  }

  func finishOnlineExit() {
    clearOnlineState()
    accountExitRevision += 1
  }
  var canEndSession: Bool {
    isLoaded && sessionActive && !isBusy && !onlineMutationInProgress && !shortsSocial.isSaving && !wallet.isBusy
  }
  private(set) var lastSaveError: String?
  private var ownerAvatarCache: UIImage?
  private var ownerAvatarStamp: Date?

  func giftUnavailableReason(_ context: GiftContext) -> String? {
    if isOnlineMode && !wallet.isLocalStoreKitTesting { return "Gifts are unavailable until server payment verification is configured." }
    if isOnlineMode && !wallet.canSendLocalGifts { return "Opening your local test wallet. If this continues, open Wallet and try again." }
    guard isLoaded, sessionActive, busyMessage == nil, !onlineMutationInProgress else { return "Please reopen the wallet before giving a gift." }
    guard context.isValid, !context.recipients.contains(where: { isCreatorBlocked($0.id) }) else {
      return "This recipient is unavailable. No diamonds were spent."
    }
    let ids = Set(context.recipients.map(\.id))
    if let account = TotiBackend.shared.accountID, isOnlineMode,
       context.recipients.contains(where: { UUID(uuidString: $0.id) == account }) {
      return "Choose another recipient. No diamonds were spent."
    }
    switch context.surface {
    case .post:
      guard let id = UUID(uuidString: context.sourceID), let post = loungePost(id),
            !post.author.isLocalOwner, ids == [post.author.id] else {
        return "This post is unavailable for gifts."
      }
    case .voiceRoom:
      guard let room = (loungeVoiceRooms + (isOnlineMode ? onlineCommunityRooms : [])).first(where: { $0.id == context.sourceID }),
            ids.isSubset(of: Set(room.participants.map(\.id))) else {
        return "This room or its selected members are unavailable."
      }
    }
    return nil
  }

  func giveGift(_ gift: MusicGift, quantity: Int, context: GiftContext) async -> String? {
    if let reason = giftUnavailableReason(context) { return reason }
    return await wallet.send(gift, quantity: quantity, context: context)
  }

  let wallet = WalletStore()
  let shortsSocial: ShortsInteractionStore
  private var socialObservation: AnyCancellable?
  let storageRoot: URL
  @Published private var liveVideoOrder: [UUID]
  @Published private var shortsVideoOrder: [UUID]
  private var watchedVideos: [UUID: Date] = [:]
  private let viewingHistory: VideoViewingHistory
  private var refreshingLive = false
  private var refreshingShorts = false
  private let repository: LocalLibraryRepository
  var isBusy: Bool { busyMessage != nil || onlineMutationInProgress || onlineReadInProgress }
  // Retired content is retained only for private-library decoding.
  var musicVideos: [LocalVideo] { [] }
  var discoveryVideos: [LocalVideo] { feed(surface: .live, orderedBy: liveVideoOrder) }
  var shortsDiscoveryVideos: [LocalVideo] { feed(surface: .shorts, orderedBy: shortsVideoOrder) }

  /// Live and Shorts keep separate films. A dance saved on this device stays in Shorts.
  private func feed(surface: MusicSurface, orderedBy order: [UUID]) -> [LocalVideo] {
    let bundled = musicVideos.filter { $0.bundledClip?.surface == surface }
    let imported = surface == .shorts ? library.videos.filter { $0.isDance == true } : []
    let candidates = (imported + bundled).filter {
      !pendingVideoIDs.contains($0.id) && !hidesVideo($0, live: surface == .live)
    }
    let lookup = Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, $0) })
    let known = Set(order)
    return candidates.filter { !known.contains($0.id) } + order.compactMap { lookup[$0] }
  }

  func recordVideoViewed(_ id: UUID) async {
    guard isLoaded, sessionActive, !isBusy else { return }
    let now = Date()
    guard now.timeIntervalSince(watchedVideos[id] ?? .distantPast) > 30 else { return }
    watchedVideos[id] = now
    // A storage failure leaves in-session recommendations working; never reset private data.
    try? await viewingHistory.record(id, at: now)
  }

  func refreshLiveRecommendations() async {
    guard !refreshingLive else { return }
    refreshingLive = true
    defer { refreshingLive = false }
    await Task.yield()
    guard !Task.isCancelled else { return }
    liveVideoOrder = VideoRecommendations.orderedIDs(
      discoveryVideos, watched: watchedVideos, avoiding: discoveryVideos.first?.id)
  }

  func refreshShortsRecommendations() async {
    guard !refreshingShorts else { return }
    refreshingShorts = true
    defer { refreshingShorts = false }
    await Task.yield()
    guard !Task.isCancelled else { return }
    let candidates = shortsDiscoveryVideos.filter { $0.duration <= 180 }
    shortsVideoOrder = VideoRecommendations.orderedIDs(
      candidates, watched: watchedVideos, avoiding: candidates.first?.id)
  }

  var collectionVideos: [LocalVideo] { library.videos + musicVideos }
  var likedVideos: [LocalVideo] {
    var seen: Set<UUID> = []
    return collectionVideos.filter { video in
      guard video.bundledClip?.surface != .live,
        shortsSocial.liked.contains(video.id), !pendingVideoIDs.contains(video.id),
        !hidesListedVideo(video), seen.insert(video.id).inserted
      else { return false }
      return true
    }
  }
  var savedVideos: [LocalVideo] {
    collectionVideos.filter {
      !pendingVideoIDs.contains($0.id) && $0.isSaved && !hidesListedVideo($0)
    }
  }

  init(storageRoot suppliedRoot: URL? = nil) {
    isOnlineMode = suppliedRoot == nil && TotiBackendConfiguration.usesOnlineBackend
    liveVideoOrder = MusicVideoCatalog.shuffledDiscoveryIDs(for: .live)
    shortsVideoOrder = MusicVideoCatalog.shuffledDiscoveryIDs(for: .shorts)
    // Online mode never initializes the legacy repository against its archive path.
    let root = suppliedRoot ?? URL.applicationSupportDirectory.appendingPathComponent(
      isOnlineMode ? "TotiOnline/UnavailableLocalStore" : TotiIdentity.storageDirectory, isDirectory: true)
    storageRoot = root
    viewingHistory = VideoViewingHistory(root: root)
    repository = LocalLibraryRepository(root: root)
    shortsSocial = ShortsInteractionStore(root: root)
    wallet.requiresServerVerification = isOnlineMode
    wallet.allowsLocalStoreKitTesting = isOnlineMode
    if isOnlineMode {
      onlineAccountObservation = TotiBackend.shared.$generation.dropFirst().sink { [weak self] _ in
        guard let self else { return }
        let wasSignedIn = self.onlineProjectedAccountID != nil
        self.clearOnlineState()
        if wasSignedIn && !TotiBackend.shared.isTransitioning { self.accountExitRevision += 1 }
      }
    }
    socialObservation = shortsSocial.objectWillChange.sink { [weak self] _ in
      self?.objectWillChange.send()
    }
  }

  // Legacy local-only agreement path. Online mode uses the real Guest enrollment path in EntryController.
  func acceptUserAgreement() async -> Bool {
    if isOnlineMode { noteSaveError("Use the Guest login action to authenticate online."); return false }
    var updated = library
    updated.agreementAcceptance = AgreementAcceptance(
      version: TotiUserAgreement.version, acceptedAt: Date())
    guard await commit(updated, permitsEntry: true) else { return false }
    await viewingHistory.setRecordingEnabled(true)
    sessionActive = true
    shortsSocial.setSessionActive(true)
    await wallet.startPayments()
    return true
  }

  /// Ends only the local session. No online credentials or remote session exist.
  func logOut() async -> Bool {
    if isOnlineMode { return await signOutOnline() }
    guard canEndSession else { return false }
    busyMessage = "Signing out…"
    defer { busyMessage = nil }
    sessionActive = false
    shortsSocial.setSessionActive(false)
    await viewingHistory.setRecordingEnabled(false)
    await wallet.stopPayments()
    notice = nil
    lastSaveError = nil
    accountExitRevision += 1
    return true
  }

  /// Explicitly confirmed by the settings screen; never called on simple logout.
  func deleteLocalAccount() async -> Bool {
    if isOnlineMode { return await deleteOnlineAccount() }
    guard canEndSession else { return false }
    guard !wallet.hasUnfinishedTransactions else {
      notice = AppNotice(title: "Purchase pending", message: "Please wait until the purchase is resolved before deleting your data.")
      return false
    }
    busyMessage = "Deleting your data…"
    defer { busyMessage = nil }
    sessionActive = false
    shortsSocial.setSessionActive(false)
    await viewingHistory.setRecordingEnabled(false)
    await wallet.stopPayments()
    do {
      try await repository.deleteLocalAccount()
      await clearAccountMemory()
      try await shortsSocial.load()
      loadError = nil
      accountExitRevision += 1
      await wallet.startPayments()
      return true
    } catch {
      // A durable deletion marker makes load() finish cleanup before any reads.
      await clearAccountMemory()
      isLoaded = false
      loadError = message(for: error)
      accountExitRevision += 1
      return false
    }
  }

  private func clearAccountMemory() async {
    library = LocalLibrary()
    shortsSocial.clearAccountMemory()
    wallet.clearAccountMemory()
    watchedVideos = [:]
    await viewingHistory.clearMemory()
    liveVideoOrder = MusicVideoCatalog.shuffledDiscoveryIDs(for: .live)
    shortsVideoOrder = MusicVideoCatalog.shuffledDiscoveryIDs(for: .shorts)
    notice = nil
    lastSaveError = nil
  }

  func load() async {
    if isOnlineMode { return }
    guard !isBusy, !isLoaded else { return }
    busyMessage = "Opening your library…"
    defer { busyMessage = nil }
    loadError = nil
    do {
      library = try await repository.load()
      try await shortsSocial.load()
      let ledger = try await repository.loadWallet()
      wallet.adopt(ledger)
      wallet.setPersist { [repository] ledger in
        do {
          try await repository.saveWallet(ledger)
          return true
        } catch {
          return false
        }
      }
      watchedVideos = (try? await viewingHistory.load()) ?? [:]
      liveVideoOrder = VideoRecommendations.orderedIDs(discoveryVideos, watched: watchedVideos)
      shortsVideoOrder = VideoRecommendations.orderedIDs(
        shortsDiscoveryVideos.filter { $0.duration <= 180 }, watched: watchedVideos)
      await wallet.startPayments()
      isLoaded = true
    } catch {
      loadError = message(for: error)
    }
  }

  func videoURL(_ video: LocalVideo) -> URL {
    if let clip = video.bundledClip { return clip.resourceURL(fileExtension: "mp4") }
    return storageRoot.appendingPathComponent("Media/\(video.id.uuidString).\(video.fileExtension)")
  }

  func coverURL(_ video: LocalVideo) -> URL {
    if let clip = video.bundledClip { return clip.resourceURL(fileExtension: "jpg") }
    return storageRoot.appendingPathComponent("Media/\(video.id.uuidString).jpg")
  }

  var pendingSubmissions: [CreationSubmission] { library.submissions ?? [] }
  var pendingVideoIDs: Set<UUID> { Set(pendingSubmissions.compactMap(\.videoID)) }
  var personalWorks: [LocalVideo] {
    library.videos.filter { !pendingVideoIDs.contains($0.id) && !hidesListedVideo($0) }
  }

  func submissionCoverURL(_ submission: CreationSubmission) -> URL? {
    if submission.hasCover {
      return storageRoot.appendingPathComponent("Media/\(submission.id.uuidString).jpg")
    }
    if let id = submission.videoID, let video = library.videos.first(where: { $0.id == id }) {
      return coverURL(video)
    }
    return nil
  }

  /// Queue content atomically; never start streaming, publish, or manufacture review approval.
  func queueCreation(
    kind: CreationKind, title: String, caption: String, category: PartyCategory,
    videoURL: URL?, coverData: Data?
  ) async -> UUID? {
    guard isLoaded, sessionActive, !isBusy,
      CreationValidation.valid(title: title, caption: caption),
      kind != .shortVideo || videoURL != nil
    else { return nil }
    busyMessage = "Preparing your content…"
    lastSaveError = nil
    defer { busyMessage = nil }
    var submission = CreationSubmission(
      kind: kind, title: title.trimmingCharacters(in: .whitespacesAndNewlines),
      caption: caption.trimmingCharacters(in: .whitespacesAndNewlines), category: category.title)
    var importedVideo: LocalVideo?
    do {
      if kind == .shortVideo, let videoURL {
        var video = try await repository.importVideo(from: videoURL)
        importedVideo = video
        guard video.duration <= 180 else { throw CreationError.shortTooLong }
        video.title = submission.title
        video.isDance = true
        importedVideo = video
        submission.videoID = video.id
      }
      if kind == .live, let data = coverData {
        try await repository.importSubmissionCover(data, id: submission.id)
        submission.hasCover = true
      }
      try Task.checkCancellation()
      var updated = library
      if let importedVideo { updated.videos.insert(importedVideo, at: 0) }
      var submissions = updated.submissions ?? []
      submissions.insert(submission, at: 0)
      updated.submissions = submissions
      try await repository.save(updated)
      library = updated
      return submission.id
    } catch {
      if let importedVideo { await repository.removeMedia(for: importedVideo) }
      await repository.removeSubmissionCover(submission.id)
      lastSaveError =
        (error as? CreationError)?.errorDescription
        ?? (error as? LocalLibraryError)?.errorDescription
        ?? "Your content could not be saved. Please try again."
      return nil
    }
  }

  func removeSubmission(_ id: UUID) async -> Bool {
    guard let submission = pendingSubmissions.first(where: { $0.id == id }) else { return false }
    let video = library.videos.first { $0.id == submission.videoID }
    var updated = library
    updated.submissions?.removeAll { $0.id == id }
    if let video { updated.videos.removeAll { $0.id == video.id } }
    guard await commit(updated) else { return false }
    if let video { await repository.removeMedia(for: video) }
    if submission.hasCover { await repository.removeSubmissionCover(submission.id) }
    return true
  }

  func markAsMusic(_ id: UUID) async {
    var updated = library
    guard let index = updated.videos.firstIndex(where: { $0.id == id }) else { return }
    updated.videos[index].isDance = true
    if !(await commit(updated)) { showSaveFailure() }
  }

  func toggleSaved(_ id: UUID) async {
    var updated = library
    if MusicVideoCatalog.entries.contains(where: { $0.id == id }) {
      var saved = updated.savedDemoVideoIDs ?? []
      if saved.contains(id) { saved.remove(id) } else { saved.insert(id) }
      updated.savedDemoVideoIDs = saved
      if !(await commit(updated)) { showSaveFailure() }
      return
    }
    guard let index = updated.videos.firstIndex(where: { $0.id == id }) else { return }
    updated.videos[index].isSaved.toggle()
    if !(await commit(updated)) { showSaveFailure() }
  }

  func renameVideo(_ id: UUID, title: String) async -> Bool {
    let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty, title.count <= 80 else { return false }
    var updated = library
    guard let index = updated.videos.firstIndex(where: { $0.id == id }) else { return false }
    updated.videos[index].title = title
    return await commit(updated)
  }

  func deleteVideo(_ id: UUID) async -> Bool {
    guard let video = library.videos.first(where: { $0.id == id }) else { return false }
    var updated = library
    updated.videos.removeAll { $0.id == id }
    updated.submissions?.removeAll { $0.videoID == id }
    guard await commit(updated) else {
      showSaveFailure()
      return false
    }
    await repository.removeMedia(for: video)
    return true
  }

  func saveProfile(_ profile: LocalProfile, avatarJPEG: Data? = nil) async -> Bool {
    if isOnlineMode { return await saveOnlineProfile(profile, avatarJPEG: avatarJPEG) }
    lastSaveError = nil
    var profile = profile
    profile.displayName = profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !profile.displayName.isEmpty, profile.displayName.count <= 30,
      profile.biography.count <= 160, CreationValidation.isEnglish(profile.displayName),
      CreationValidation.isEnglish(profile.biography)
    else { return false }
    if let avatarJPEG {
      do { try await repository.storeProfileAvatar(avatarJPEG) }
      catch {
        lastSaveError = message(for: error)
        return false
      }
      profile.hasCustomAvatar = true
    }
    var updated = library
    updated.profile = profile
    let saved = await commit(updated)
    guard avatarJPEG != nil else { return saved }
    if saved {
      do {
        try await repository.promoteProfileAvatar()
        ownerAvatarCache = nil
        ownerAvatarStamp = nil
        objectWillChange.send()
      } catch {
        lastSaveError = message(for: error)
        await repository.discardPendingProfileAvatar()
        return false
      }
    } else {
      await repository.discardPendingProfileAvatar()
    }
    return saved
  }

  /// Shared current-user avatar source for Me, profile editing and room seats.
  var ownerAvatarAsset: String {
    isOnlineMode ? (onlineOwnerProfile?.avatarAsset ?? "TotiMark")
      : MusicPhotography.creatorAvatar(for: "local-owner")
  }

  func configureOwnerAvatar(_ photo: TotiPhoto) {
    photo.configure(asset: ownerAvatarAsset)
    if !isOnlineMode, let image = ownerAvatarImage() { photo.image = image }
  }

  func ownerAvatarImage() -> UIImage? {
    if isOnlineMode { return nil }
    guard library.profile.hasCustomAvatar == true else { return nil }
    let url = storageRoot.appendingPathComponent("Media/profile-avatar.jpg")
    guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
      let modified = attrs[.modificationDate] as? Date
    else { return nil }
    if ownerAvatarStamp == modified, let ownerAvatarCache { return ownerAvatarCache }
    let image = UIImage(contentsOfFile: url.path)
    ownerAvatarCache = image
    ownerAvatarStamp = modified
    return image
  }

  func saveRoom(_ draft: VoiceRoomDraft) async -> Bool {
    if isOnlineMode { return await saveOnlineModel(draft, action: "room.save", id: draft.id) }
    var draft = draft
    draft.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !draft.title.isEmpty, draft.title.count <= 60, draft.description.count <= 240,
      [4, 6, 8].contains(draft.seatCount), CreationValidation.isEnglish(draft.title),
      CreationValidation.isEnglish(draft.description)
    else { return false }
    draft.updatedAt = Date()
    var updated = library
    updated.roomDrafts.removeAll { $0.id == draft.id }
    updated.roomDrafts.insert(draft, at: 0)
    return await commit(updated)
  }

  func deleteRoom(_ id: UUID) async -> Bool {
    if isOnlineMode { return await performOnline(action: "room.delete", id: id) }
    var updated = library
    updated.roomDrafts.removeAll { $0.id == id }
    let saved = await commit(updated)
    if !saved { showSaveFailure() }
    return saved
  }

  func saveMessageDraft(_ text: String) async -> Bool {
    if isOnlineMode { noteSaveError("Open a conversation before saving a draft."); return false }
    guard text.count <= 2_000 else { return false }
    var updated = library
    updated.messageDraft = text
    return await commit(updated)
  }

  var chatConversations: [MusicConversation] {
    if isOnlineMode { return onlineConversations }
    let state = library.creatorState ?? CreatorLocalState()
    var records = state.conversations ?? [:]
    // Surface existing drafts from versions that did not store inbox entries.
    for id in state.messageDrafts.keys where records[id] == nil {
      let creator = resolvedCreator(id: id, stored: nil)
      records[id] = CreatorConversationRecord(creator: creator, updatedAt: nil)
    }
    let creators = records.values.filter { !isCreatorBlocked($0.creator.id) }.sorted {
      let left = $0.updatedAt ?? .distantPast
      let right = $1.updatedAt ?? .distantPast
      return left == right ? $0.creator.id < $1.creator.id : left > right
    }.map { record in
      let creator = resolvedCreator(id: record.creator.id, stored: record.creator)
      let time =
        record.updatedAt.map { date in
          Calendar.current.isDateInToday(date)
            ? date.formatted(.dateTime.hour().minute().locale(Locale(identifier: "en_US")))
            : date.formatted(
              .dateTime.month(.abbreviated).day().locale(Locale(identifier: "en_US")))
        } ?? ""
      return MusicConversation(
        id: "creator-chat:\(creator.id)", name: creator.name,
        avatars: [creator.avatarAsset ?? MusicPhotography.creatorAvatar(for: creator.id)],
        kind: .person, time: time, initialUnread: 0, initiallyPinned: false,
        story: nil, messages: library.chatState?.sentMessages?["creator-chat:\(creator.id)"] ?? [],
        creator: creator)
    }
    let authored = MusicChatCatalog.conversations.map { conversation in
      let additions = library.chatState?.sentMessages?[conversation.id] ?? []
      return MusicConversation(
        id: conversation.id, name: conversation.name, avatars: conversation.avatars,
        kind: conversation.kind, time: additions.last?.time ?? conversation.time,
        initialUnread: conversation.initialUnread, initiallyPinned: conversation.initiallyPinned,
        story: conversation.story, messages: conversation.messages + additions)
    }
    let groups = (library.chatState?.createdGroups ?? []).sorted { $0.createdAt > $1.createdAt }.map {
      group in
      let additions = library.chatState?.sentMessages?[group.id] ?? []
      return MusicConversation(
        id: group.id, name: group.name,
        avatars: group.avatarAssets,
        kind: .group,
        time: additions.last?.time ?? "Now", initialUnread: 0, initiallyPinned: false,
        story: nil, messages: additions)
    }
    let hidden = library.chatState?.hiddenChatIDs ?? []
    let ordered = groups + (creators + authored).sorted { left, right in
      let a = library.chatState?.sentMessages?[left.id]?.last?.createdAt ?? .distantPast
      let b = library.chatState?.sentMessages?[right.id]?.last?.createdAt ?? .distantPast
      if a == b { return false }
      return a > b
    }
    return ordered.filter { conversation in
      if hidden.contains(conversation.id) { return false }
      if isCreatorBlocked(conversation.id) { return false }
      if let creatorID = conversation.creator?.id, isCreatorBlocked(creatorID) { return false }
      return true
    }
  }

  /// Saves a group on this device. The other people are not notified.
  func createChatGroup(with people: [MusicConversation]) async -> MusicConversation? {
    if isOnlineMode { return await createOnlineGroup(people) }
    guard isLoaded, !isBusy, people.count >= 2 else { return nil }
    let names = people.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    guard names.count >= 2, CreationValidation.isEnglish(names.joined(separator: ", ")) else {
      lastSaveError = "Choose at least two friends."
      return nil
    }
    var title = names.joined(separator: ", ")
    if title.count > 48 { title = String(title.prefix(45)) + "..." }
    let group = LocalChatGroup(
      id: "group-" + UUID().uuidString, name: title,
      avatarAssets: people.map { person in
        if let asset = person.avatars.first { return asset }
        if let creator = person.creator { return MusicPhotography.creatorAvatar(for: creator.id) }
        return ArtistPortraits.asset(forName: person.name)
      }, createdAt: Date())
    var updated = library
    var state = updated.chatState ?? ChatLocalState()
    var groups = state.createdGroups ?? []
    groups.insert(group, at: 0)
    state.createdGroups = groups
    updated.chatState = state
    guard await commit(updated) else { return nil }
    return chatConversations.first { $0.id == group.id }
  }

  func messages(for conversation: MusicConversation) -> [ChatMessage] {
    if isOnlineMode { return onlineConversations.first { $0.id == conversation.id }?.messages ?? [] }
    return chatConversations.first { $0.id == conversation.id }?.messages ?? conversation.messages
  }

  func followsChatPartner(_ conversation: MusicConversation) -> Bool {
    if isOnlineMode { return conversation.creator.map { isFollowingCreator($0.id) } ?? false }
    if let creator = conversation.creator { return isFollowingCreator(creator.id) }
    return library.chatState?.followingOverrides?[conversation.id]
      ?? MusicChatCatalog.initialMutualIDs.contains(conversation.id)
  }

  /// Catalog friends follow the chat relationship. Video creators follow the creator list.
  func followsProfile(_ creator: CreatorProfile) -> Bool {
    if isOnlineMode { return isFollowingCreator(creator.id) }
    if let person = MusicChatCatalog.people.first(where: { $0.id == creator.id }) {
      return followsChatPartner(person)
    }
    return isFollowingCreator(creator.id)
  }

  /// Use the same incoming relationship IDs as Chats; following alone is not mutual.
  func isMutualProfile(_ creator: CreatorProfile) -> Bool {
    guard !creator.isLocalOwner, !isCreatorBlocked(creator.id) else { return false }
    if isOnlineMode { return isFollowingCreator(creator.id) && onlineFollowerIDs.contains(creator.id.lowercased()) }
    if let person = MusicChatCatalog.people.first(where: { $0.id == creator.id }) {
      return isMutualChat(person)
    }
    return isFollowingCreator(creator.id)
      && (library.chatState?.followerIDs ?? []).contains("creator-chat:\(creator.id)")
  }

  func toggleProfileFollow(_ creator: CreatorProfile) async {
    if isOnlineMode { await toggleCreatorFollow(creator.id); return }
    guard !isCreatorBlocked(creator.id) else { return }
    if let person = MusicChatCatalog.people.first(where: { $0.id == creator.id }) {
      await toggleChatFollow(person)
      return
    }
    await toggleCreatorFollow(creator.id)
  }

  func chatPartnerFollowsMe(_ conversation: MusicConversation) -> Bool {
    if isOnlineMode { return conversation.creator.map { onlineFollowerIDs.contains($0.id.lowercased()) } ?? false }
    // Unknown creator relationships remain false until an authoritative service updates them.
    let followers = library.chatState?.followerIDs ?? MusicChatCatalog.initialFollowerIDs
    return followers.contains(conversation.id)
  }

  func isMutualChat(_ conversation: MusicConversation) -> Bool {
    followsChatPartner(conversation) && chatPartnerFollowsMe(conversation)
  }

  func canSendChatMessage(_ conversation: MusicConversation) -> Bool {
    if isOnlineMode { return onlineConversations.contains { $0.id == conversation.id } && !isBusy }
    if conversation.kind == .activity { return false }
    if isCreatorBlocked(conversation.id) { return false }
    if let creator = conversation.creator, isCreatorBlocked(creator.id) { return false }
    if conversation.kind == .group || conversation.creator?.isLocalOwner == true
      || isMutualChat(conversation)
    {
      return true
    }
    return (library.chatState?.sentMessages?[conversation.id] ?? []).isEmpty
  }

  func toggleChatFollow(_ conversation: MusicConversation) async {
    if isOnlineMode { if let creator = conversation.creator { await toggleCreatorFollow(creator.id) }; return }
    if let creator = conversation.creator {
      await toggleCreatorFollow(creator.id)
      return
    }
    guard isLoaded, !isBusy, conversation.kind == .person, !isCreatorBlocked(conversation.id) else {
      return
    }
    var updated = library
    var state = updated.chatState ?? ChatLocalState()
    var overrides = state.followingOverrides ?? [:]
    overrides[conversation.id] = !followsChatPartner(conversation)
    state.followingOverrides = overrides
    updated.chatState = state
    if !(await commit(updated)) { showSaveFailure() }
  }

  /// Local outbox only: persistence does not imply remote delivery or a read receipt.
  func sendChatMessage(_ text: String, to conversation: MusicConversation) async -> Bool {
    if isOnlineMode { return await sendOnlineMessage(text, conversation: conversation) }
    guard isLoaded, !isBusy else { return false }
    lastSaveError = nil
    let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty, text.count <= 2_000, CreationValidation.isEnglish(text) else {
      lastSaveError = "Write a message of up to 2,000 characters in English."
      return false
    }
    guard canSendChatMessage(conversation) else {
      let blocked = isCreatorBlocked(conversation.id)
        || conversation.creator.map { isCreatorBlocked($0.id) } == true
      lastSaveError =
        blocked
        ? "Unblock this person to chat."
        : "You can send another message once you follow each other."
      return false
    }
    var updated = library
    var state = updated.chatState ?? ChatLocalState()
    var outbox = state.sentMessages ?? [:]
    let now = Date()
    let message = ChatMessage(
      id: UUID().uuidString, author: "You", text: text,
      time: now.formatted(.dateTime.hour().minute().locale(Locale(identifier: "en_US"))),
      isOwn: true, createdAt: now, isPending: true)
    outbox[conversation.id, default: []].append(message)
    state.sentMessages = outbox
    state.drafts.removeValue(forKey: conversation.id)
    state.readIDs.insert(conversation.id)
    var marks = state.unreadMarks ?? [:]
    marks[conversation.id] = nil
    state.unreadMarks = marks.isEmpty ? nil : marks
    updated.chatState = state
    if let creator = conversation.creator {
      var creators = updated.creatorState ?? CreatorLocalState()
      creators.messageDrafts.removeValue(forKey: creator.id)
      var records = creators.conversations ?? [:]
      records[creator.id] = CreatorConversationRecord(creator: creator, updatedAt: now)
      creators.conversations = records
      updated.creatorState = creators
    }
    return await commit(updated)
  }

  func chatDraft(for conversation: MusicConversation) -> String? {
    if isOnlineMode { return onlinePreference(conversation.id)?.string("draft") }
    if let creator = conversation.creator { return library.creatorState?.messageDrafts[creator.id] }
    return library.chatState?.drafts[conversation.id]
  }

  private func resolvedCreator(id: String, stored: CreatorProfile?) -> CreatorProfile {
    if let video = collectionVideos.first(where: { $0.creatorID == id }) {
      return .from(video: video, profile: library.profile, coverURL: coverURL(video))
    }
    if id == "local-owner" {
      return CreatorProfile(
        id: id, name: library.profile.displayName, biography: library.profile.biography,
        avatarSymbol: library.profile.avatarSymbol, isLocalOwner: true)
    }
    return stored ?? CreatorProfile(id: id, name: "Music creator", biography: "")
  }

  @discardableResult
  func openCreatorConversation(_ creator: CreatorProfile) async -> Bool {
    if isOnlineMode { return await openOnlineConversation(creator) }
    guard !isCreatorBlocked(creator.id) else { return false }
    var updated = library
    var state = updated.creatorState ?? CreatorLocalState()
    var records = state.conversations ?? [:]
    records[creator.id] = CreatorConversationRecord(creator: creator, updatedAt: Date())
    state.conversations = records
    updated.creatorState = state
    return await commit(updated)
  }

  func chatUnreadCount(_ conversation: MusicConversation) -> Int {
    if isOnlineMode { return onlinePreference(conversation.id)?.bool("read") == false ? 1 : 0 }
    if let marked = library.chatState?.unreadMarks?[conversation.id] { return marked }
    if library.chatState?.readIDs.contains(conversation.id) == true { return 0 }
    return conversation.initialUnread
  }

  func isChatPinned(_ conversation: MusicConversation) -> Bool {
    if isOnlineMode { return onlinePreference(conversation.id)?.bool("pinned") == true }
    return library.chatState?.pinOverrides[conversation.id] ?? conversation.initiallyPinned
  }

  func isChatMuted(_ conversation: MusicConversation) -> Bool {
    if isOnlineMode { return onlinePreference(conversation.id)?.bool("muted") == true }
    return library.chatState?.mutedIDs?.contains(conversation.id) == true
  }

  func markChatRead(_ id: String? = nil) async {
    if isOnlineMode {
      for value in id.map({ [$0] }) ?? onlineConversations.map(\.id) {
        _ = await saveOnlinePreference(value, payload: ["read": .bool(true)])
      }
      return
    }
    var updated = library
    var state = updated.chatState ?? ChatLocalState()
    let ids = id.map { Set([$0]) } ?? Set(chatConversations.map(\.id))
    var marks = state.unreadMarks ?? [:]
    let hadMark = ids.contains { marks[$0] != nil }
    guard hadMark || !ids.isSubset(of: state.readIDs) else { return }
    for item in ids { marks[item] = nil }
    state.unreadMarks = marks.isEmpty ? nil : marks
    state.readIDs.formUnion(ids)
    updated.chatState = state
    if !(await commit(updated)) { showSaveFailure() }
  }

  /// Forces a local unread count of 1. This does not deliver a message.
  func markChatUnread(_ conversation: MusicConversation) async {
    if isOnlineMode { _ = await saveOnlinePreference(conversation.id, payload: ["read": .bool(false)]); return }
    var updated = library
    var state = updated.chatState ?? ChatLocalState()
    var marks = state.unreadMarks ?? [:]
    marks[conversation.id] = 1
    state.unreadMarks = marks
    state.readIDs.remove(conversation.id)
    updated.chatState = state
    if !(await commit(updated)) { showSaveFailure() }
  }

  func toggleChatPin(_ conversation: MusicConversation) async {
    if isOnlineMode { _ = await saveOnlinePreference(conversation.id, payload: ["pinned": .bool(!isChatPinned(conversation))]); return }
    var updated = library
    var state = updated.chatState ?? ChatLocalState()
    state.pinOverrides[conversation.id] = !isChatPinned(conversation)
    updated.chatState = state
    if !(await commit(updated)) { showSaveFailure() }
  }

  func toggleChatMute(_ conversation: MusicConversation) async {
    if isOnlineMode { _ = await saveOnlinePreference(conversation.id, payload: ["muted": .bool(!isChatMuted(conversation))]); return }
    var updated = library
    var state = updated.chatState ?? ChatLocalState()
    var muted = state.mutedIDs ?? []
    if muted.contains(conversation.id) {
      muted.remove(conversation.id)
    } else {
      muted.insert(conversation.id)
    }
    state.mutedIDs = muted
    updated.chatState = state
    if !(await commit(updated)) { showSaveFailure() }
  }

  /// Hides the row on this device. The conversation is not removed from another account.
  func hideChat(_ conversation: MusicConversation) async {
    if isOnlineMode { _ = await saveOnlinePreference(conversation.id, payload: ["hidden": .bool(true)]); return }
    var updated = library
    var state = updated.chatState ?? ChatLocalState()
    var hidden = state.hiddenChatIDs ?? []
    guard !hidden.contains(conversation.id) else { return }
    hidden.insert(conversation.id)
    state.hiddenChatIDs = hidden
    updated.chatState = state
    if !(await commit(updated)) { showSaveFailure() }
  }

  func saveChatDraft(_ text: String, conversationID: String) async -> Bool {
    if isOnlineMode { return await saveOnlinePreference(conversationID, payload: ["draft": .string(text)]) }
    let known = MusicChatCatalog.conversations.contains { $0.id == conversationID }
      || (library.chatState?.createdGroups ?? []).contains { $0.id == conversationID }
    guard text.count <= 2_000, known else { return false }
    var updated = library
    var state = updated.chatState ?? ChatLocalState()
    if text.isEmpty {
      state.drafts[conversationID] = nil
    } else {
      state.drafts[conversationID] = text
    }
    updated.chatState = state
    return await commit(updated)
  }

  /// The profile grid and totals share the complete catalog, independent of feed order.
  /// Pending submissions are private queue entries, not published works.
  func creatorWorks(for creatorID: String) -> [LocalVideo] {
    collectionVideos.filter {
      $0.creatorID == creatorID && !pendingVideoIDs.contains($0.id) && !hidesListedVideo($0)
    }
  }

  func statistics(for creator: CreatorProfile) -> CreatorStatistics {
    if isOnlineMode { return onlineStatistics(creator) }
    let posts = loungePosts(for: creator.id)
    let totals = (likes: posts.filter { (library.lounge?.likedPostIDs ?? []).contains($0.id) }.count,
                  saves: posts.filter { (library.lounge?.savedPostIDs ?? []).contains($0.id) }.count)
    if creator.isLocalOwner {
      let creatorFollows = library.creatorState?.followedIDs.count ?? 0
      let chatFollows = MusicChatCatalog.conversations.filter {
        $0.kind == .person && followsChatPartner($0)
      }.count
      return CreatorStatistics(
        likes: totals.likes, saves: totals.saves,
        following: creatorFollows + chatFollows, followers: 0)
    }
    // Only relationships actually stored on this device can contribute a count.
    return CreatorStatistics(
      likes: totals.likes, saves: totals.saves, following: 0,
      followers: followsProfile(creator) ? 1 : 0)
  }

  func isFollowingCreator(_ id: String) -> Bool {
    library.creatorState?.followedIDs.contains(isOnlineMode ? id.lowercased() : id) == true
  }

  func toggleCreatorFollow(_ id: String) async {
    if isOnlineMode {
      guard let target = UUID(uuidString: id) else { return }
      _ = await performOnline(action: "follow.set", id: target, payload: ["enabled": .bool(!isFollowingCreator(id))])
      return
    }
    guard isLoaded, !isBusy, !isCreatorBlocked(id) else { return }
    var updated = library
    var state = updated.creatorState ?? CreatorLocalState()
    if state.followedIDs.contains(id) {
      state.followedIDs.remove(id)
    } else {
      state.followedIDs.insert(id)
    }
    updated.creatorState = state
    if !(await commit(updated)) { showSaveFailure() }
  }

  func saveCreatorMessageDraft(_ text: String, creator: CreatorProfile) async -> Bool {
    if isOnlineMode {
      guard let conversation = onlineConversations.first(where: { $0.creator?.id == creator.id }) else {
        noteSaveError("Open this conversation before saving a draft."); return false
      }
      return await saveOnlinePreference(conversation.id, payload: ["draft": .string(text)])
    }
    guard !isCreatorBlocked(creator.id), text.count <= 2_000 else { return false }
    var updated = library
    var state = updated.creatorState ?? CreatorLocalState()
    state.messageDrafts[creator.id] = text.isEmpty ? nil : text
    var records = state.conversations ?? [:]
    records[creator.id] = CreatorConversationRecord(creator: creator, updatedAt: Date())
    state.conversations = records
    updated.creatorState = state
    return await commit(updated)
  }

  func isCreatorBlocked(_ id: String) -> Bool {
    library.contentSafety?.blockedCreators[isOnlineMode ? id.lowercased() : id] != nil
  }

  func isContentReported(_ id: String, kind: ContentSafetyTarget.Kind) -> Bool {
    library.contentSafety?.reports.contains {
      (isOnlineMode ? $0.contentID.lowercased() == id.lowercased() : $0.contentID == id) && $0.kind == kind
    } == true
  }

  /// A report hides that film on its own surface. A block hides every film from that creator.
  func hidesVideo(_ video: LocalVideo, live: Bool) -> Bool {
    if isCreatorBlocked(video.creatorID) { return true }
    return isContentReported(video.id.uuidString, kind: live ? .live : .shortVideo)
  }

  private func hidesListedVideo(_ video: LocalVideo) -> Bool {
    hidesVideo(video, live: video.bundledClip?.surface == .live)
  }

  func isCommentReported(_ id: String) -> Bool {
    isContentReported(id, kind: .comment)
  }

  func isPartyReported(_ id: String) -> Bool {
    isContentReported(id, kind: .party)
  }

  /// Latest reason for each video, comment, or room, newest first.
  func reportedContent() -> [ReportedContentItem] {
    var latest: [String: LocalContentReport] = [:]
    for report in library.contentSafety?.reports ?? [] {
      let key = report.kind.rawValue + ":" + report.contentID
      if let current = latest[key], current.savedAt >= report.savedAt { continue }
      latest[key] = report
    }
    return latest.values.map {
      ReportedContentItem(
        contentID: $0.contentID, kind: $0.kind, title: $0.title,
        creatorName: $0.creatorName, reason: $0.reason, savedAt: $0.savedAt)
    }
    .sorted { $0.savedAt > $1.savedAt }
  }

  /// Removes every saved reason for one item so it can appear again. Media stays on device.
  func removeReports(contentID: String, kind: ContentSafetyTarget.Kind) async -> Bool {
    if isOnlineMode { noteSaveError("Submitted reports remain available for review."); return false }
    var updated = library
    var safety = updated.contentSafety ?? ContentSafetyState()
    let before = safety.reports.count
    safety.reports.removeAll { $0.contentID == contentID && $0.kind == kind }
    guard safety.reports.count != before else { return true }
    updated.contentSafety = safety
    return await commit(updated)
  }

  func blockCreator(_ creator: CreatorProfile) async -> Bool {
    if isOnlineMode {
      guard let id = UUID(uuidString: creator.id) else { noteSaveError("This account is unavailable."); return false }
      return await performOnline(action: "block.set", id: id, payload: ["enabled": .bool(true)])
    }
    guard !creator.isLocalOwner, !isBusy else { return false }
    var updated = library
    var safety = updated.contentSafety ?? ContentSafetyState()
    safety.blockedCreators[creator.id] = creator
    updated.contentSafety = safety
    updated.creatorState?.followedIDs.remove(creator.id)
    var chat = updated.chatState ?? ChatLocalState()
    var overrides = chat.followingOverrides ?? [:]
    overrides[creator.id] = false
    chat.followingOverrides = overrides
    updated.chatState = chat
    return await commit(updated)
  }

  func unblockCreator(_ id: String) async -> Bool {
    if isOnlineMode {
      guard let target = UUID(uuidString: id) else { return false }
      return await performOnline(action: "block.set", id: target, payload: ["enabled": .bool(false)])
    }
    var updated = library
    var safety = updated.contentSafety ?? ContentSafetyState()
    safety.blockedCreators[id] = nil
    updated.contentSafety = safety
    return await commit(updated)
  }

  func saveContentReport(
    _ target: ContentSafetyTarget, reason: ContentReportReason, details: String
  ) async -> Bool {
    if isOnlineMode { return await reportOnline(target, reason: reason, details: details) }
    let text = details.trimmingCharacters(in: .whitespacesAndNewlines)
    lastSaveError = nil
    guard text.count <= 500,
      !text.unicodeScalars.contains(where: { $0.properties.isAlphabetic && !$0.isASCII })
    else {
      lastSaveError = "Use up to 500 characters in English."
      return false
    }
    var updated = library
    var safety = updated.contentSafety ?? ContentSafetyState()
    let existing = safety.reports.first {
      $0.contentID == target.id && $0.kind == target.kind && $0.reason == reason
    }
    let report = LocalContentReport(
      id: existing?.id ?? UUID(), contentID: target.id, title: target.title,
      kind: target.kind, creatorID: target.creator.id, creatorName: target.creator.name,
      reason: reason, details: text, savedAt: Date())
    if let index = safety.reports.firstIndex(where: { $0.id == report.id }) {
      safety.reports[index] = report
    } else {
      safety.reports.append(report)
    }
    updated.contentSafety = safety
    let saved = await commit(updated)
    if !saved, lastSaveError == nil {
      lastSaveError = "Your report could not be saved. Please try again."
    }
    return saved
  }

  func noteSaveError(_ message: String?) {
    lastSaveError = message
  }

  /// Copy new files first, commit their references atomically, then release unused app-owned copies.
  func commit(_ updated: LocalLibrary, permitsEntry: Bool = false) async -> Bool {
    if isOnlineMode { noteSaveError("This action requires an online service operation."); return false }
    guard isLoaded, !isBusy, sessionActive || permitsEntry else { return false }
    lastSaveError = nil
    busyMessage = "Saving…"
    defer { busyMessage = nil }
    do {
      try await repository.save(updated)
      library = updated
      return true
    } catch {
      lastSaveError = message(for: error)
      return false
    }
  }

  private func showSaveFailure() {
    if let lastSaveError {
      notice = AppNotice(title: "Changes were not saved", message: lastSaveError)
    }
  }

  private func message(for error: Error) -> String {
    (error as? LocalLibraryError)?.errorDescription
      ?? LocalLibraryError.storageUnavailable.localizedDescription
  }
}
