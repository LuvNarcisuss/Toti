-- Real Guest interactions on authored posts; no editorial Auth identities or seeded activity.
create table toti_private.editorial_reactions (
 actor_id uuid not null references toti_private.accounts(id) on delete cascade,
 post_id uuid not null references toti_private.editorial_posts(id) on delete cascade,
 kind text not null check(kind in ('like','save')),
 created_at timestamptz not null default now(),
 primary key(actor_id,post_id,kind)
);
create index editorial_reactions_post on toti_private.editorial_reactions(post_id,kind);
create table toti_private.editorial_comments (
 id uuid primary key,
 actor_id uuid not null references toti_private.accounts(id) on delete cascade,
 post_id uuid not null references toti_private.editorial_posts(id) on delete cascade,
 body text not null check(length(btrim(body)) between 1 and 500),
 created_at timestamptz not null default now(),
 deleted_at timestamptz
);
create index editorial_comments_page on toti_private.editorial_comments(post_id,created_at desc,id desc) where deleted_at is null;
create table toti_private.editorial_reports (
 actor_id uuid not null references toti_private.accounts(id) on delete cascade,
 post_id uuid not null references toti_private.editorial_posts(id) on delete cascade,
 target_id uuid not null,
 reason text not null check(length(reason) between 1 and 100),
 details text not null default '' check(length(details)<=2000),
 created_at timestamptz not null default now(),
 primary key(actor_id,post_id,target_id)
);
create table toti_private.editorial_requests (
 actor_id uuid not null references toti_private.accounts(id) on delete cascade,
 request_id uuid not null,
 post_id uuid not null references toti_private.editorial_posts(id) on delete cascade,
 action text not null,
 payload jsonb not null,
 created_at timestamptz not null default now(),
 primary key(actor_id,request_id)
);
alter table toti_private.editorial_reactions enable row level security;
alter table toti_private.editorial_comments enable row level security;
alter table toti_private.editorial_reports enable row level security;
alter table toti_private.editorial_requests enable row level security;
revoke all on toti_private.editorial_reactions,toti_private.editorial_comments,toti_private.editorial_reports,toti_private.editorial_requests from public,anon,authenticated;

create function toti_private.editorial_post_document(p_post uuid,p_actor uuid)
returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',p.id,'title',p.title,'body',p.body,'topic',p.topic,
 'photo_asset',p.photo_asset,'created_at',p.created_at,
 'like_count',(select count(*) from toti_private.editorial_reactions r where r.post_id=p.id and r.kind='like'),
 'save_count',(select count(*) from toti_private.editorial_reactions r where r.post_id=p.id and r.kind='save'),
 'comment_count',(select count(*) from toti_private.editorial_comments c join toti_private.accounts a on a.id=c.actor_id and a.status='active'
   where c.post_id=p.id and c.deleted_at is null and not toti_private.blocked(p_actor,c.actor_id)),
 'liked',exists(select 1 from toti_private.editorial_reactions r where r.post_id=p.id and r.kind='like' and r.actor_id=p_actor),
 'saved',exists(select 1 from toti_private.editorial_reactions r where r.post_id=p.id and r.kind='save' and r.actor_id=p_actor))
 from toti_private.editorial_posts p where p.id=p_post and p.published;
$$;
revoke all on function toti_private.editorial_post_document(uuid,uuid) from public,anon,authenticated;

create or replace function toti_private.read_editorial_posts()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_actor uuid:=toti_private.actor();
begin
 return coalesce((select jsonb_agg(toti_private.editorial_post_document(p.id,v_actor) order by p.created_at desc,p.id desc)
 from toti_private.editorial_posts p where p.published),'[]'::jsonb);
end; $$;

create function toti_private.editorial_activity(p_post_id uuid,p_action text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare v_actor uuid; v_id uuid; v_text text; v_kind text; v_enabled boolean;
 old_request toti_private.editorial_requests; old_comment toti_private.editorial_comments;
 v_before timestamptz; v_before_id uuid; v_comments jsonb; v_more boolean; v_cursor jsonb;
 v_post jsonb; v_row record; v_count integer:=0;
begin
 -- Match the business-operation lock so block/account deletion cannot race this mutation.
 perform pg_advisory_xact_lock(731209444211::bigint);
 v_actor:=toti_private.actor();
 if p_post_id is null or p_action not in ('read','like','save','comment','delete_comment','report') or p_action is null
    or p_payload is null or jsonb_typeof(p_payload)<>'object' or octet_length(p_payload::text)>16000 then
   raise exception 'Invalid post action' using errcode='22023';
 end if;
 if not exists(select 1 from toti_private.editorial_posts p where p.id=p_post_id and p.published) then
   raise exception 'This post is unavailable' using errcode='42501';
 end if;
 if p_action<>'read' then
   if p_request_id is null then raise exception 'A request ID is required' using errcode='22023'; end if;
   select * into old_request from toti_private.editorial_requests where actor_id=v_actor and request_id=p_request_id;
   if found and (old_request.post_id<>p_post_id or old_request.action<>p_action or old_request.payload<>p_payload) then
     raise exception 'Request ID already used' using errcode='22023';
   end if;
   if old_request.request_id is null then
     if p_action in ('like','save') then
       if jsonb_typeof(p_payload->'enabled') is distinct from 'boolean' then raise exception 'Choose a reaction state' using errcode='22023'; end if;
       v_enabled:=(p_payload->>'enabled')::boolean;
       if v_enabled then
         insert into toti_private.editorial_reactions(actor_id,post_id,kind) values(v_actor,p_post_id,p_action) on conflict do nothing;
       else delete from toti_private.editorial_reactions where actor_id=v_actor and post_id=p_post_id and kind=p_action;
       end if;
     elsif p_action='comment' then
       v_id:=(p_payload->>'id')::uuid; v_text:=btrim(coalesce(p_payload->>'body',''));
       if v_id is null or length(v_text) not between 1 and 500 then raise exception 'Write a reply of 1 to 500 characters' using errcode='22023'; end if;
       select * into old_comment from toti_private.editorial_comments where id=v_id;
       if found then
         if old_comment.actor_id<>v_actor or old_comment.post_id<>p_post_id or old_comment.body<>v_text or old_comment.deleted_at is not null then
           raise exception 'This reply ID cannot be reused' using errcode='22023';
         end if;
       else insert into toti_private.editorial_comments(id,actor_id,post_id,body) values(v_id,v_actor,p_post_id,v_text);
       end if;
     elsif p_action='delete_comment' then
       v_id:=(p_payload->>'id')::uuid;
       select * into old_comment from toti_private.editorial_comments where id=v_id;
       if not found or old_comment.actor_id<>v_actor or old_comment.post_id<>p_post_id then
         raise exception 'Only your own reply can be deleted' using errcode='42501';
       end if;
       update toti_private.editorial_comments set deleted_at=coalesce(deleted_at,now()) where id=v_id;
     else
       v_id:=coalesce((p_payload->>'target_id')::uuid,p_post_id);
       if v_id<>p_post_id and not exists(select 1 from toti_private.editorial_comments c join toti_private.accounts a on a.id=c.actor_id and a.status='active'
           where c.id=v_id and c.post_id=p_post_id and c.deleted_at is null and c.actor_id<>v_actor and not toti_private.blocked(v_actor,c.actor_id)) then
         raise exception 'This content cannot be reported' using errcode='42501';
       end if;
       if length(btrim(coalesce(p_payload->>'reason',''))) not between 1 and 100 or length(coalesce(p_payload->>'details',''))>2000 then
         raise exception 'Choose a reason and use up to 2,000 characters' using errcode='22023';
       end if;
       insert into toti_private.editorial_reports(actor_id,post_id,target_id,reason,details)
       values(v_actor,p_post_id,v_id,btrim(p_payload->>'reason'),coalesce(p_payload->>'details',''))
       on conflict(actor_id,post_id,target_id) do update set reason=excluded.reason,details=excluded.details;
     end if;
     insert into toti_private.editorial_requests(actor_id,request_id,post_id,action,payload) values(v_actor,p_request_id,p_post_id,p_action,p_payload);
   end if;
 end if;
 v_post:=toti_private.editorial_post_document(p_post_id,v_actor);
 v_before:=(p_payload->>'before_created_at')::timestamptz; v_before_id:=(p_payload->>'before_id')::uuid;
 if (v_before is null)<>(v_before_id is null) then raise exception 'Invalid comment cursor' using errcode='22023'; end if;
 v_comments:='[]'::jsonb; v_more:=false;
 for v_row in
   select c.* from toti_private.editorial_comments c join toti_private.accounts a on a.id=c.actor_id and a.status='active'
   where c.post_id=p_post_id and c.deleted_at is null and not toti_private.blocked(v_actor,c.actor_id)
     and (v_before is null or (c.created_at,c.id)<(v_before,v_before_id))
   order by c.created_at desc,c.id desc limit 41
 loop
   v_count:=v_count+1;
   if v_count>40 then v_more:=true; exit; end if;
   v_comments:=v_comments||jsonb_build_array(jsonb_build_object('id',v_row.id,'author_id',v_row.actor_id,'body',v_row.body,
     'created_at',v_row.created_at,'profile',toti_private.profile_document(v_row.actor_id,v_actor)));
   v_cursor:=jsonb_build_object('created_at',v_row.created_at,'id',v_row.id);
 end loop;
 return jsonb_build_object('post',v_post,'comments',v_comments,'next_cursor',case when v_more then v_cursor else null end);
end; $$;
revoke all on function toti_private.editorial_activity(uuid,text,jsonb,uuid) from public,anon,authenticated;
grant execute on function toti_private.editorial_activity(uuid,text,jsonb,uuid) to authenticated;
create function public.toti_editorial_activity(p_post_id uuid,p_action text default 'read',p_payload jsonb default '{}',p_request_id uuid default null)
returns jsonb language sql volatile security invoker set search_path='' as $$
 select toti_private.editorial_activity(p_post_id,p_action,p_payload,p_request_id);
$$;
revoke all on function public.toti_editorial_activity(uuid,text,jsonb,uuid) from public,anon,authenticated;
grant execute on function public.toti_editorial_activity(uuid,text,jsonb,uuid) to authenticated;

-- Add genuine-post save totals while retaining the deployed photo-review/owner-feedback rules.
create or replace function toti_private.post_media_document(o toti_private.objects,p_viewer uuid)
returns jsonb language sql stable security definer set search_path='' as $$
 select o.body || jsonb_build_object('media_status',r.state,'media_review_status',r.state,
    'save_count',(select count(*) from toti_private.reactions reaction where reaction.post_id=o.id and reaction.kind='save'))
    || case when o.owner_id=p_viewer then jsonb_build_object('media_feedback',r.owner_feedback,'media_review_reason',r.owner_feedback) else '{}'::jsonb end
 from (select 1) seed left join toti_private.media_revisions r
    on r.id=(o.body->>'media_revision_id')::uuid and r.owner_id=o.owner_id and r.kind='post' and r.entity_id=o.id and r.upload_state='ready';
$$;
revoke all on function toti_private.post_media_document(toti_private.objects,uuid) from public,anon,authenticated;
