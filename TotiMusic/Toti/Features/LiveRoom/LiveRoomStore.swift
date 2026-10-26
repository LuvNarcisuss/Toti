import Combine
import Foundation

@MainActor
protocol LiveRoomServicing {
    func setFollowing(_ following: Bool, roomID: String) async throws
    func submitComment(_ text: String, roomID: String) async throws -> LiveComment
    func perform(_ action: LiveRoomAction, roomID: String) async throws -> String
}

enum LiveRoomAction { case like }

@MainActor
struct LocalLiveRoomService: LiveRoomServicing {
    func setFollowing(_ following: Bool, roomID: String) async throws {}
    func submitComment(_ text: String, roomID: String) async throws -> LiveComment {
        LiveComment(nickname: "You", text: text, isLocal: true)
    }
    func perform(_ action: LiveRoomAction, roomID: String) async throws -> String {
        switch action {
        case .like: return "Liked"
        }
    }
}

@MainActor
final class LiveRoomStore: ObservableObject {
    let configuration: LiveRoomConfiguration
    @Published private(set) var following = false
    @Published private(set) var comments: [LiveComment]
    @Published private(set) var likes: Int
    @Published private(set) var notice: String?
    @Published private(set) var isSending = false
    @Published private(set) var isFollowingBusy = false
    @Published private(set) var isActing = false
    @Published var commentFlowEnabled = true
    private let service: any LiveRoomServicing
    private var active = true
    private var noticeTask: Task<Void, Never>?
    private var operations: [UUID: Task<Void, Never>] = [:]
    private var commentTask: Task<Void, Never>?
    private var commentCursor: Int

    init(configuration: LiveRoomConfiguration, service: (any LiveRoomServicing)? = nil) {
        self.configuration = configuration
        self.service = service ?? LocalLiveRoomService()
        comments = configuration.initialComments
        commentCursor = configuration.initialComments.count
        likes = configuration.streamer.likeCount
    }

    func start() { active = true }
    func stop() {
        active = false
        setCommentLoopActive(false)
        noticeTask?.cancel(); noticeTask = nil; notice = nil
        operations.values.forEach { $0.cancel() }; operations.removeAll()
    }

    /// Authored atmosphere is inserted with fresh IDs, independently of the video loop.
    /// No online audience, account identity or delivery status is inferred from these lines.
    func setCommentLoopActive(_ value: Bool) {
        guard value, active, commentFlowEnabled, !configuration.commentLoop.isEmpty else {
            commentTask?.cancel(); commentTask = nil; return
        }
        guard commentTask == nil else { return }
        commentTask = Task { [weak self] in
            while !Task.isCancelled {
                let count = Int.random(in: 1...5)
                let interval = Duration.seconds(1.0 / Double(count))
                for _ in 0..<count {
                    do { try await Task.sleep(for: interval) } catch { return }
                    guard let self, self.active, self.commentFlowEnabled, !Task.isCancelled else { return }
                    let lines = self.configuration.commentLoop
                    var comment = lines[self.commentCursor % lines.count]
                    comment.id = UUID()
                    self.commentCursor += 1
                    self.append(comment)
                }
            }
        }
    }

    func run(_ operation: @escaping @MainActor () async -> Void) {
        guard active else { return }
        let id = UUID()
        operations[id] = Task { [weak self] in
            guard !Task.isCancelled else { return }
            await operation()
            self?.operations[id] = nil
        }
    }

    func toggleFollow() async {
        guard active, !isFollowingBusy else { return }
        isFollowingBusy = true
        defer { isFollowingBusy = false }
        do {
            let value = !following
            try await service.setFollowing(value, roomID: configuration.id)
            guard active, !Task.isCancelled else { return }
            following = value
            showNotice(value ? "Added to following" : "Removed from following")
        } catch { showNotice("Could not update following. Try again.") }
    }

    func send(_ text: String) async -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard active, !isSending, !trimmed.isEmpty else { return false }
        guard trimmed.count <= 200 else { showNotice("Keep your comment within 200 characters."); return false }
        isSending = true
        defer { isSending = false }
        do {
            let comment = try await service.submitComment(trimmed, roomID: configuration.id)
            guard active, !Task.isCancelled else { return false }
            append(comment)
            return true
        } catch { showNotice("Could not add your comment. Try again."); return false }
    }

    func append(_ comment: LiveComment) {
        guard active else { return }
        comments.append(comment)
        if comments.count > 200 { comments.removeFirst(comments.count - 200) }
    }

    func perform(_ action: LiveRoomAction) async {
        guard active, !isActing else { return }
        isActing = true
        defer { isActing = false }
        do {
            let message = try await service.perform(action, roomID: configuration.id)
            guard active, !Task.isCancelled else { return }
            switch action { case .like: likes += 1 }
            showNotice(message)
        } catch { showNotice("Could not complete that action. Try again.") }
    }

    func showNotice(_ text: String) {
        guard active else { return }
        noticeTask?.cancel(); notice = text
        noticeTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(3)) } catch { return }
            self?.notice = nil
        }
    }
}
