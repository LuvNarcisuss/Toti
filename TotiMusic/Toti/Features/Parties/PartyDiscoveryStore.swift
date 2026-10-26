import Combine
import Foundation

@MainActor
protocol PartyDiscoveryServing {
    func rooms() async throws -> [PartyRoom]
}
struct LocalPartyDiscoveryService: PartyDiscoveryServing {
    func rooms() async throws -> [PartyRoom] {
        await Task.yield()
        try Task.checkCancellation()
        return MusicRoomCatalog.rooms
    }
}

@MainActor
final class PartyDiscoveryStore: ObservableObject {
    @Published private(set) var rooms: [PartyRoom] = []
    @Published private(set) var loading = false
    @Published private(set) var loaded = false
    @Published private(set) var failure: String?
    @Published var category: PartyCategory?
    @Published var filter = PartyFilter()
    private let service: any PartyDiscoveryServing
    init(service: (any PartyDiscoveryServing)? = nil) { self.service = service ?? LocalPartyDiscoveryService() }

    func refresh(reorder: Bool = true) async {
        guard !loading else { return }
        loading = true; failure = nil
        defer { loading = false }
        do {
            let fetched = try await service.rooms()
            try Task.checkCancellation()
            rooms = reorder ? fetched.shuffled() : fetched
            loaded = true
        } catch is CancellationError {
        } catch {
            failure = "Unable to load parties. Please try again."
        }
    }
    func visibleRooms(in rooms: [PartyRoom]) -> [PartyRoom] {
        let filtered = rooms.filter { (category == nil || $0.category == category) && filter.includes($0) }
        return filter.popularFirst ? filtered.sorted { ($0.popularity?.value ?? -1) > ($1.popularity?.value ?? -1) } : filtered
    }
}
