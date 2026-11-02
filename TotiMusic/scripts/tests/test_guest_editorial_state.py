from pathlib import Path


ROOT = Path(__file__).resolve().parents[2].parent


def read(relative: str) -> str:
    return (ROOT / relative).read_text()


def test_guest_mode_and_unavailable_services_are_current():
    config = read("TotiMusic/Toti/Backend/TotiBackendConfiguration.swift")
    assert "static let usesOnlineBackend = true" in config
    assert "static let rolloutEnabled = true" in config
    assert "static let rtcEnabled = false" in config
    assert "static let purchasesEnabled = false" in config

    calls = read("TotiMusic/Toti/Features/Calls/CallController.swift")
    assert "Calls are unavailable" in calls
    assert "real-time audio and video connection is not available yet" in calls


def test_editorial_content_is_explicit_and_not_member_activity():
    lounge = read("TotiMusic/Toti/Features/Lounge/TotiEditorial.swift")
    assert "TOTI EDITORIAL" in lounge
    assert "not member accounts" in lounge

    voice = read("TotiMusic/Toti/Features/Parties/PartyControllers.swift")
    assert "appendTotiVoiceEditorial" not in voice
    assert "TotiEditorialDetailController" not in voice
    assert "PartyRoomController(store: self.store, room: selected)" in voice
    assert '"voice.room.cover." + room.id' in voice


def test_editorial_sql_has_stable_records_and_no_engagement_fields():
    sql = read("TotiMusic/Backend/sql/008_editorial_content.sql")
    assert "toti_private.editorial_posts" in sql
    assert "published boolean not null default false" in sql
    assert "MusicProductionRoom" in sql
    expansion = read("TotiMusic/Backend/sql/009_editorial_content_expansion.sql")
    assert sql.count("16f40c60-5dc2-4db5-bf99-00000000000") == 3
    assert expansion.count("16f40c60-5dc2-4db5-bf99-00000000000") == 3
    assert "like_count" not in sql
    assert "online_count" not in sql


def test_current_docs_state_guest_chat_and_rtc_boundaries():
    readme = read("README.md")
    checklist = read("docs/backend/release-checklist.md")
    for document in (readme, checklist):
        assert "Guest" in document
        assert "RTC" in document or "real-time" in document
        assert "server-verified" in document or "server verification" in document
    assert "Online text chat" in readme
    assert "RTC remains unavailable" in checklist


def test_editorial_media_has_provenance():
    credits = read("Assets/MediaCredits.json")
    assert "MusicStudioBackdrop" in credits
    assert "license" in credits.lower()
    manifest = read("TotiMusic/Configuration/RemoteAssets.json")
    assert "sha256" in manifest
