import Foundation

enum VideoRecommendations {
    /// Newest collections win among unseen clips; watched clips return oldest-first.
    static func orderedIDs(_ videos: [LocalVideo], watched: [UUID: Date], avoiding firstID: UUID? = nil) -> [UUID] {
        let shuffled = videos.shuffled()
        let tieBreak = Dictionary(uniqueKeysWithValues: shuffled.enumerated().map { ($0.element.id, $0.offset) })
        var ranked = shuffled.sorted { lhs, rhs in
            let left = watched[lhs.id], right = watched[rhs.id]
            if (left == nil) != (right == nil) { return left == nil }
            if let left, let right, left != right { return left < right }
            if left == nil {
                let a = lhs.bundledClip?.collectionGeneration ?? Int.max
                let b = rhs.bundledClip?.collectionGeneration ?? Int.max
                if a != b { return a > b }
            }
            return tieBreak[lhs.id, default: 0] < tieBreak[rhs.id, default: 0]
        }
        // Refresh should visibly change the lead item when equally eligible choices exist.
        if let first = ranked.first, first.id == firstID, watched[first.id] == nil,
           let next = ranked.indices.dropFirst().first(where: {
               watched[ranked[$0].id] == nil && ranked[$0].bundledClip?.collectionGeneration == first.bundledClip?.collectionGeneration
           }) {
            ranked.swapAt(0, next)
        }
        return ranked.map(\.id)
    }
}
