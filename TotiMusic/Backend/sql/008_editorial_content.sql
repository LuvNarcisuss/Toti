-- Official content reuses licensed artwork without fabricating member identities or activity.
create table toti_private.editorial_posts (
  id uuid primary key,
  title text not null check(length(title) between 1 and 100),
  body text not null check(length(body) between 1 and 1000),
  topic text not null check(topic in ('Listening','Concerts','Making music','Find a bandmate')),
  photo_asset text check(photo_asset in ('MusicStudioBackdrop','MusicProductionRoom','Portrait2','Portrait3')),
  published boolean not null default false,
  created_at timestamptz not null default now()
);
alter table toti_private.editorial_posts enable row level security;
revoke all on toti_private.editorial_posts from public, anon, authenticated;

insert into toti_private.editorial_posts(id,title,body,topic,photo_asset,published,created_at) values
('16f40c60-5dc2-4db5-bf99-000000000001','Listening together',
 'That moment when a song makes the whole room feel quieter. What have you been listening to on repeat lately?',
 'Listening','MusicStudioBackdrop',true,'2026-10-26T00:00:00Z'),
('16f40c60-5dc2-4db5-bf99-000000000002','A first line',
 'Songwriting prompt: begin with a sound you heard on your way home. A train, rain on a window, a friend''s laugh. Where does the melody go?',
 'Making music','Portrait2',true,'2026-10-25T23:00:00Z'),
('16f40c60-5dc2-4db5-bf99-000000000003','Finding a bandmate',
 'Your first rehearsal together: one familiar song, plenty of listening, and room to get it wrong. What would you want a new bandmate to know about your sound?',
 'Find a bandmate','Portrait3',true,'2026-10-25T22:00:00Z');

create function toti_private.read_editorial_posts()
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  perform toti_private.actor();
  return coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'title',p.title,'body',p.body,
    'topic',p.topic,'photo_asset',p.photo_asset,'created_at',p.created_at) order by p.created_at desc,p.id desc)
    from toti_private.editorial_posts p where p.published),'[]'::jsonb);
end; $$;
revoke all on function toti_private.read_editorial_posts() from public,anon,authenticated;
grant execute on function toti_private.read_editorial_posts() to authenticated;
create function public.toti_editorial_posts()
returns jsonb language sql stable security invoker set search_path='' as $$
  select toti_private.read_editorial_posts();
$$;
revoke all on function public.toti_editorial_posts() from public,anon,authenticated;
grant execute on function public.toti_editorial_posts() to authenticated;
