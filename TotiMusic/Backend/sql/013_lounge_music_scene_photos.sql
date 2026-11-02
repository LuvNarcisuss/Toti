-- Replaces editorial covers with six distinct licensed music scenes.
-- Existing editorial IDs are stable, authored content identifiers, not generated account IDs.
-- No member profiles, private posts, relationships, messages, or presence are changed.
alter table toti_private.editorial_posts
    drop constraint editorial_posts_photo_asset_check;
alter table toti_private.editorial_posts
    add constraint editorial_posts_photo_asset_check check (photo_asset in (
        'MusicStudioBackdrop', 'Portrait2', 'Portrait3',
        'LoungeVinylListening', 'LoungePianoMelody', 'LoungeGuitarRehearsal',
        'LoungeStudioMixing', 'LoungeConcertLights', 'LoungeMusicCorner'
    ));

update toti_private.editorial_posts as post
set photo_asset = artwork.asset
from (values
    ('16f40c60-5dc2-4db5-bf99-000000000001'::uuid, 'LoungeVinylListening'),
    ('16f40c60-5dc2-4db5-bf99-000000000002'::uuid, 'LoungePianoMelody'),
    ('16f40c60-5dc2-4db5-bf99-000000000003'::uuid, 'LoungeGuitarRehearsal'),
    ('16f40c60-5dc2-4db5-bf99-000000000004'::uuid, 'LoungeStudioMixing'),
    ('16f40c60-5dc2-4db5-bf99-000000000005'::uuid, 'LoungeConcertLights'),
    ('16f40c60-5dc2-4db5-bf99-000000000006'::uuid, 'LoungeMusicCorner')
) as artwork(id, asset)
where post.id = artwork.id;
