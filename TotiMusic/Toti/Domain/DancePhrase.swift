// Compatibility data only. No practice feature is exposed in this template.
import Foundation

enum PhraseStyle: String, Codable, CaseIterable {
    case hipHop, kPop, jazz, freestyle, ballet, house, contemporary, swing
    var title: String {
        switch self {
        case .hipHop: return "Hip-hop"
        case .kPop: return "K-pop"
        case .jazz: return "Jazz"
        case .freestyle: return "Freestyle"
        case .ballet: return "Ballet"
        case .house: return "House"
        case .contemporary: return "Contemporary"
        case .swing: return "Swing"
        }
    }
}

enum PhraseTempo: String, Codable, CaseIterable {
    case slow, steady, quick
    var title: String {
        switch self {
        case .slow: return "Slow"
        case .steady: return "Steady"
        case .quick: return "Quick"
        }
    }
    /// Seconds from one count to the next.
    var beatDuration: TimeInterval {
        switch self {
        case .slow: return 1
        case .steady: return 0.75
        case .quick: return 0.6
        }
    }
}

enum PhraseText {
    static let validation = "Use an English title of up to 40 characters and an English count of up to 48 characters."
    static let sameAsParent = "Make a change before saving a branch of this phrase."
    static func permitsAuthoredText(_ text: String) -> Bool {
        text.range(of: #"\b((demo|demonstration|showcase|sample|mock|mockup|prototype|exhibition|preview|presentation|display)s?|(test|demo)[\s_-]*modes?)\b"#,
                   options: [.regularExpression, .caseInsensitive]) == nil
    }
}

struct DancePhrase: Codable, Equatable, Identifiable {
    var id: String
    var title: String
    var style: PhraseStyle
    var tempo: PhraseTempo
    var eights: [[String]]
    var authorID: String
    var authorName: String
    var parentID: String?
    var parentTitle: String?
    var changedEights: [Int]?
    var createdAt: Date
    /// Missing in older libraries, whose text-only phrases remain intact.
    var lesson: PhraseLesson? = nil

    static let maximumSections = 256

    static func validate(title: String, eights: [[String]]) -> String? {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let eights = eights.map { eight in
            eight.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        }
        let titleOK = !title.isEmpty && title.count <= 40 && CreationValidation.isEnglish(title)
        let bodyOK = (1...maximumSections).contains(eights.count) && eights.allSatisfy { eight in
            (1...8).contains(eight.count) && eight.allSatisfy { line in
                !line.isEmpty && line.count <= 48 && CreationValidation.isEnglish(line)
            }
        }
        return titleOK && bodyOK ? nil : PhraseText.validation
    }

    /// 1-based eight indexes whose trimmed lines differ. A missing eight counts as changed.
    static func changedEightIndexes(from parent: [[String]], to child: [[String]]) -> [Int] {
        let span = max(parent.count, child.count)
        var indexes: [Int] = []
        for offset in 0..<span {
            let left = offset < parent.count ? parent[offset].map(trim) : []
            let right = offset < child.count ? child[offset].map(trim) : []
            if left != right { indexes.append(offset + 1) }
        }
        return indexes
    }

    static func changedSummary(_ indexes: [Int]) -> String {
        let numbers = indexes.map(String.init)
        if numbers.count == 1 { return "Changed section \(numbers[0])" }
        return "Changed sections " + numbers.joined(separator: ", ")
    }

    var eightCountLabel: String {
        "\(eights.reduce(0) { $0 + $1.count }) counts"
    }

    func trimmed() -> DancePhrase {
        var copy = self
        copy.title = Self.trim(title)
        copy.eights = eights.map { $0.map(Self.trim) }
        copy.parentTitle = parentTitle.map(Self.trim)
        return copy
    }

    private static func trim(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Source-time intervals. An action is a visible movement, not an invented fixed-tempo beat.
struct PhraseTimedCue: Codable, Equatable {
    let start: TimeInterval
    let end: TimeInterval
    let text: String
    let isAction: Bool
}

struct PhraseFilmTimeline {
    let assetName: String
    let duration: TimeInterval
    let cues: [PhraseTimedCue]
    let actionCueIndices: [Int]
    let actionIndexByCue: [Int?]
    let eights: [[String]]
    private let sectionStarts: [Int]
    private let actionSections: [Int]

    init(assetName: String, duration: TimeInterval, cues: [PhraseTimedCue], groupSizes: [Int]? = nil) {
        precondition(duration.isFinite && duration > 0 && !cues.isEmpty)
        var previousEnd: TimeInterval = 0
        for cue in cues {
            precondition(cue.start.isFinite && cue.end.isFinite)
            precondition(cue.start == previousEnd && cue.end > cue.start && cue.end <= duration)
            precondition(!cue.text.isEmpty && cue.text.count <= 48 && CreationValidation.isEnglish(cue.text))
            previousEnd = cue.end
        }
        precondition(previousEnd == duration)
        self.assetName = assetName
        self.duration = duration
        self.cues = cues
        var actionIndices: [Int] = []
        var reverse = [Int?](repeating: nil, count: cues.count)
        for (index, cue) in cues.enumerated() where cue.isAction {
            reverse[index] = actionIndices.count
            actionIndices.append(index)
        }
        actionCueIndices = actionIndices
        precondition(!actionIndices.isEmpty && actionIndices.count <= DancePhrase.maximumSections * 8)
        actionIndexByCue = reverse
        let actions = actionIndices.map { cues[$0].text }
        let sizes = groupSizes ?? stride(from: 0, to: actions.count, by: 8).map { min(8, actions.count - $0) }
        precondition(sizes.reduce(0, +) == actions.count && sizes.allSatisfy { (1...8).contains($0) })
        var pages: [[String]] = [], starts: [Int] = [], sections: [Int] = []
        var first = 0
        for (section, size) in sizes.enumerated() {
            starts.append(first)
            pages.append(Array(actions[first..<(first + size)]))
            sections.append(contentsOf: Array(repeating: section, count: size))
            first += size
        }
        eights = pages
        sectionStarts = starts
        actionSections = sections
    }

    func cueIndex(at time: TimeInterval) -> Int? {
        guard time.isFinite, time >= 0, time < duration, !cues.isEmpty else { return nil }
        var low = 0
        var high = cues.count
        while low < high {
            let middle = (low + high) / 2
            if cues[middle].start <= time { low = middle + 1 } else { high = middle }
        }
        let index = low - 1
        return index >= 0 && time < cues[index].end ? index : nil
    }

    func action(_ index: Int) -> PhraseTimedCue? {
        guard actionCueIndices.indices.contains(index) else { return nil }
        return cues[actionCueIndices[index]]
    }

    func range(for section: Int) -> ClosedRange<TimeInterval>? {
        guard eights.indices.contains(section) else { return nil }
        let first = sectionStarts[section]
        guard let start = action(first)?.start,
              let end = action(first + eights[section].count - 1)?.end
        else { return nil }
        return start...end
    }

    /// Repeat actual actions only; spoken gaps do not become extra practice counts.
    func practiceRanges(for section: Int) -> [ClosedRange<TimeInterval>] {
        guard eights.indices.contains(section) else { return [] }
        var ranges: [ClosedRange<TimeInterval>] = []
        let first = sectionStarts[section]
        for index in first..<(first + eights[section].count) {
            guard let cue = action(index) else { continue }
            if let last = ranges.last, last.upperBound == cue.start {
                ranges[ranges.count - 1] = last.lowerBound...cue.end
            } else {
                ranges.append(cue.start...cue.end)
            }
        }
        return ranges
    }

    func actionIndex(section: Int, offset: Int) -> Int? {
        guard eights.indices.contains(section), eights[section].indices.contains(offset) else { return nil }
        return sectionStarts[section] + offset
    }

    func position(of action: Int) -> (section: Int, offset: Int)? {
        guard actionSections.indices.contains(action) else { return nil }
        let section = actionSections[action]
        return (section, action - sectionStarts[section])
    }

    static func timestamp(_ time: TimeInterval) -> String {
        let seconds = max(0, Int(time.isFinite ? time : 0))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

struct PhraseActionTiming: Codable, Equatable {
    var start: TimeInterval = -1
    var end: TimeInterval = -1
    var instruction = "Watch the instruction"
}

/// A self-contained lesson snapshot. Imported videos are not added to recommendation feeds.
struct PhraseLesson: Codable, Equatable {
    var localVideo: LocalVideo? = nil
    var bundledAsset: String? = nil
    var duration: TimeInterval
    var coverID: UUID? = nil
    var coverTime: TimeInterval = 0
    var actions: [[PhraseActionTiming]]
    var closingInstruction = "Finish the lesson"
    var credits: String
    var defaultRate: Double = 1
    var pickupBPM: Int = 80
    var startsWithLoop: Bool? = nil

    func validationError(eights: [[String]], requireMedia: Bool = true) -> String? {
        guard duration.isFinite, duration > 0, duration <= 1_800,
              coverTime.isFinite, coverTime >= 0, coverTime < duration,
              [0.5, 0.75, 1].contains(defaultRate), (40...180).contains(pickupBPM) else {
            return "Use a video up to 30 minutes, a valid cover time, and a preparation tempo from 40 to 180 BPM."
        }
        if requireMedia {
            if let video = localVideo {
                guard bundledAsset == nil, ["mp4", "mov", "m4v"].contains(video.fileExtension),
                      video.duration.isFinite, abs(video.duration - duration) < 0.05 else {
                    return "Choose a valid dance video."
                }
            } else if let bundledAsset {
                guard let entry = MusicVideoCatalog.entries.first(where: { $0.assetName == bundledAsset }),
                      DancePhraseCatalog.filmAsset.values.contains(bundledAsset),
                      abs(entry.duration - duration) < 1 else { return "Choose a valid dance video." }
            } else { return "Add a dance video before saving." }
        }
        let inheritedCredit = bundledAsset.flatMap { DancePhraseCatalog.filmCredits[$0] }
        if let inheritedCredit, credits != inheritedCredit { return "Keep the original source credits with this video." }
        guard !credits.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              credits.count <= 2_000, (inheritedCredit != nil || CreationValidation.isEnglish(credits)),
              !closingInstruction.isEmpty, closingInstruction.count <= 48,
              CreationValidation.isEnglish(closingInstruction) else {
            return "Write video credits in English and keep instruction lines within 48 characters."
        }
        guard actions.count == eights.count, !eights.isEmpty else { return "Set a video time for every count." }
        var previous: TimeInterval = 0
        for (section, timings) in actions.enumerated() {
            guard timings.count == eights[section].count else { return "Set a video time for every count." }
            for timing in timings {
                guard timing.start.isFinite, timing.end.isFinite, timing.start >= previous,
                      timing.end > timing.start, timing.end <= duration,
                      !timing.instruction.isEmpty, timing.instruction.count <= 48,
                      CreationValidation.isEnglish(timing.instruction) else {
                    return "Set ordered, non-overlapping start and end times within your video. Use short English instruction lines."
                }
                previous = timing.end
            }
        }
        return nil
    }

    func timeline(eights: [[String]]) -> PhraseFilmTimeline? {
        guard DancePhrase.validate(title: "Phrase", eights: eights) == nil,
              validationError(eights: eights) == nil else { return nil }
        var cues: [PhraseTimedCue] = []
        var previous: TimeInterval = 0
        for (section, timings) in actions.enumerated() {
            for (offset, timing) in timings.enumerated() {
                if timing.start > previous {
                    cues.append(PhraseTimedCue(start: previous, end: timing.start, text: timing.instruction, isAction: false))
                }
                cues.append(PhraseTimedCue(start: timing.start, end: timing.end, text: eights[section][offset], isAction: true))
                previous = timing.end
            }
        }
        if previous < duration {
            cues.append(PhraseTimedCue(start: previous, end: duration, text: closingInstruction, isAction: false))
        }
        return PhraseFilmTimeline(assetName: bundledAsset ?? localVideo!.id.uuidString,
                                  duration: duration, cues: cues, groupSizes: eights.map(\.count))
    }
}
