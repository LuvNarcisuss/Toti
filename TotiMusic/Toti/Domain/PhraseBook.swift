// Compatibility data only. No practice feature is exposed in this template.
import Foundation

struct PhraseBookState: Codable, Equatable {
    var phrases: [DancePhrase] = []
    var keptOrder: [String] = []
    var learned: [String: [Bool]] = [:]

    private enum CodingKeys: String, CodingKey {
        case phrases, keptOrder, learned
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        phrases = try container.decodeIfPresent([DancePhrase].self, forKey: .phrases) ?? []
        keptOrder = try container.decodeIfPresent([String].self, forKey: .keptOrder) ?? []
        learned = try container.decodeIfPresent([String: [Bool]].self, forKey: .learned) ?? [:]
    }

    /// Drops keep ids and learned marks that do not match a phrase still on this device.
    /// Legacy learned arrays are retained; timed catalog sections use a separate versioned key.
    func normalized(catalogIDs: Set<String>) -> PhraseBookState {
        let catalogCounts = Dictionary(
            uniqueKeysWithValues: DancePhraseCatalog.phrases
                .filter { catalogIDs.contains($0.id) }
                .map { ($0.id, $0.eights.count) })
        let eightCounts = catalogCounts.merging(phrases.map { ($0.id, $0.eights.count) }) { _, local in local }
        let known = Set(eightCounts.keys)
        var copy = self
        copy.keptOrder = keptOrder.filter { known.contains($0) }
        let timedKeys = Set(catalogIDs.map { DancePhraseCatalog.learnedKey(for: $0) })
        copy.learned = learned.filter { id, _ in known.contains(id) || timedKeys.contains(id) }
        return copy
    }

    /// Why this book cannot be trusted, or nil when an older library can keep it.
    /// Unknown keep ids are ignored by `normalized` and are not an error.
    func validationError(catalogIDs: Set<String>) -> String? {
        let ids = phrases.map(\.id)
        if Set(ids).count != ids.count { return "duplicate phrase" }
        for phrase in phrases {
            if catalogIDs.contains(phrase.id) { return "catalog id stored" }
            if phrase.authorID != "local-owner" { return "author" }
            if DancePhrase.validate(title: phrase.title, eights: phrase.eights) != nil {
                return "text"
            }
            if phrase.lesson?.validationError(eights: phrase.eights) != nil { return "lesson" }
            if let parentID = phrase.parentID {
                if parentID.isEmpty || (phrase.parentTitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return "parent"
                }
            }
            if let changed = phrase.changedEights {
                // A shorter branch can mark sections removed from its longer parent.
                let allowed = Set(1...DancePhrase.maximumSections)
                if Set(changed).count != changed.count || changed.contains(where: { !allowed.contains($0) }) {
                    return "changed"
                }
            }
        }
        return nil
    }
}
