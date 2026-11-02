import Foundation

enum MusicPhotography {
  static func avatar(_ asset: String) -> String {
    let mapping = [
      "ChatAvatar1": "Portrait1", "ChatAvatar2": "Portrait2",
      "ChatAvatar3": "Portrait3", "ChatAvatar4": "Portrait4",
      "ChatAvatar5": "Portrait5", "ChatAvatar6": "Portrait6",
      "ChatAvatar7": "Portrait7", "ChatAvatar8": "Portrait8",
      "PartyAvatar1": "Portrait1", "PartyAvatar2": "Portrait2",
      "PartyAvatar3": "Portrait3", "PartyAvatar4": "Portrait4",
    ]
    return mapping[asset] ?? asset
  }
  /// Photographic artwork for a creator account, not a claim about the credited filmmaker.
  static func creatorAvatar(for id: String) -> String {
    ArtistPortraits.asset(forCreator: id)
  }

  static func story(for id: String) -> String {
    let stories = [
      "maya": "LifestyleStudioPractice", "leo": "LifestyleDanceRehearsal",
      "zoe": "LifestyleStudioPractice", "noah": "LifestyleDanceRehearsal",
      "aria": "LifestyleStudioPractice", "finn": "LifestyleDanceRehearsal",
    ]
    return stories[id] ?? "LifestyleDanceRehearsal"
  }

  static func cover(for room: PartyRoom) -> String {
    if room.isCommunityArtwork, let asset = room.coverAsset,
      ["RoomCoverHipHop", "RoomCoverKPop", "RoomCoverJazz", "RoomCoverFreestyle", "MusicPianoRoom", "MusicProductionRoom"].contains(asset) {
      return asset
    }
    let covers = [
      "hip-hop-crew": "RoomCoverHipHop", "k-pop-combo": "RoomCoverKPop",
      "jazz-afterhours": "RoomCoverJazz", "freestyle-circle": "RoomCoverFreestyle",
      "dance-camera": "RoomCoverCamera", "ballet-circle": "MusicPianoRoom",
      "house-friends": "MusicProductionRoom", "practice-break": "RoomCoverPractice",
    ]
    if let asset = covers[room.id] { return asset }
    let drafts = ["RoomCoverDraft1", "RoomCoverDraft2", "RoomCoverDraft3", "RoomCoverDraft4"]
    let seed = room.id.utf8.reduce(UInt64(14_695_981_039_346_656_037)) {
      ($0 ^ UInt64($1)) &* 1_099_511_628_211
    }
    return drafts[Int(seed % UInt64(drafts.count))]
  }

}
