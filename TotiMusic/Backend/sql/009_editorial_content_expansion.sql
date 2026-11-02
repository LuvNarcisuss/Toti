-- Adds read-only editorial prompts to the already deployed editorial table.
-- This migration contains no Auth identities, member activity, presence, or engagement.
insert into toti_private.editorial_posts(id,title,body,topic,photo_asset,published,created_at) values
('16f40c60-5dc2-4db5-bf99-000000000004','A room for the chorus',
 'A chorus can feel bigger when every part leaves room for the next one. What would you keep quiet in your arrangement?',
 'Making music','MusicStudioBackdrop',true,'2026-10-24T21:00:00Z'),
('16f40c60-5dc2-4db5-bf99-000000000005','The concert afterglow',
 'Write down one small detail you remember after the lights come up: a harmony, a handclap, or the sound of people finding the exit.',
 'Concerts','MusicStudioBackdrop',true,'2026-10-24T20:00:00Z'),
('16f40c60-5dc2-4db5-bf99-000000000006','Start with listening',
 'Finding a collaborator starts with curiosity. Ask what they are hearing before you decide what the song needs.',
 'Find a bandmate','Portrait2',true,'2026-10-24T19:00:00Z');
