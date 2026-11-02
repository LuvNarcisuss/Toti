-- Ordered deployment source. Apply after 006; do not edit deployed migrations.
-- JPEG validation and immutable Storage writes are performed only by trusted Edge code.
alter table toti_private.media_revisions
  add column kind text check (kind in ('avatar','post')),
  add column entity_id uuid,
  add column source_sha256 text check (source_sha256 ~ '^[0-9a-f]{64}$'),
  add column sha256 text check (sha256 ~ '^[0-9a-f]{64}$'),
  add column upload_state text not null default 'reserved' check (upload_state in ('reserved','ready')),
  add column reviewed_by text;
create index toti_media_entity on toti_private.media_revisions(owner_id,kind,entity_id);
create table toti_private.media_review_events (
  id uuid primary key default gen_random_uuid(),
  revision_id uuid not null references toti_private.media_revisions(id) on delete cascade,
  owner_id uuid not null references toti_private.accounts(id) on delete cascade,
  decision text not null check (decision in ('approved','rejected')),
  operator_identity text not null,
  database_identity text not null,
  reason text not null,
  created_at timestamptz not null default now()
);
create index toti_media_review_revision on toti_private.media_review_events(revision_id,created_at);
create index toti_media_review_owner on toti_private.media_review_events(owner_id);
alter table toti_private.media_review_events enable row level security;
revoke all on toti_private.media_review_events from public,anon,authenticated;

-- No client can list, fetch, sign or replace Storage objects directly.
-- An INSERT is permitted only for a live caller's server-validated reservation.
drop policy if exists toti_media_owner_read on storage.objects;
update storage.buckets set public=false,file_size_limit=1048576,allowed_mime_types=array['image/jpeg'] where id='toti-media';

create function toti_private.media_session(p_actor uuid,p_session uuid)
returns void language plpgsql stable security definer set search_path='' as $$
begin
  if coalesce(auth.jwt()->>'role','')<>'service_role' then
    raise exception 'Trusted service required' using errcode='42501';
  end if;
  if not exists(select 1 from toti_private.accounts a join auth.users u on u.id=a.id
    join auth.sessions s on s.user_id=u.id
    where a.id=p_actor and a.status='active' and s.id=p_session
      and (s.not_after is null or s.not_after>now())
      and (u.is_anonymous is true or u.email_confirmed_at is not null)) then
    raise exception 'Your session has expired. Sign in again.' using errcode='42501';
  end if;
end; $$;

create function toti_private.media_context()
returns jsonb language sql stable security definer set search_path='' as $$
  select jsonb_build_object('actor_id',toti_private.actor(),'session_id',auth.jwt()->>'session_id');
$$;

create function toti_private.media_reserve(p_actor uuid,p_session uuid,p_revision uuid,p_kind text,
  p_entity uuid,p_source_sha256 text,p_sha256 text,p_width integer,p_height integer,p_byte_size bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare r toti_private.media_revisions; o toti_private.objects; v_path text;
begin
  perform pg_advisory_xact_lock(731209444211::bigint);
  perform toti_private.media_session(p_actor,p_session);
  if p_revision is null or p_entity is null or p_kind is null or p_kind not in ('avatar','post')
    or p_source_sha256 is null or p_sha256 is null
    or p_source_sha256 !~ '^[0-9a-f]{64}$' or p_sha256 !~ '^[0-9a-f]{64}$'
    or p_width is null or p_height is null or p_byte_size is null
    or p_width not between 1 and 2048 or p_height not between 1 and 2048
    or p_width::bigint*p_height>4000000 or p_byte_size not between 4 and 1048576
    or (p_kind='avatar' and p_entity<>p_actor) then
    raise exception 'Invalid photo' using errcode='22023';
  end if;
  select * into o from toti_private.objects where id=p_entity;
  if found and (o.owner_id<>p_actor or o.kind<>(case when p_kind='avatar' then 'profile' else 'post' end) or o.deleted_at is not null) then
    raise exception 'This photo target is unavailable' using errcode='42501';
  end if;
  select * into r from toti_private.media_revisions where id=p_revision;
  if found then
    if r.owner_id<>p_actor or r.kind<>p_kind or r.entity_id<>p_entity
      or r.source_sha256<>p_source_sha256 or r.sha256<>p_sha256
      or r.width<>p_width or r.height<>p_height or r.byte_size<>p_byte_size then
      raise exception 'Revision ID was already used with different content' using errcode='22023';
    end if;
  else
    if (select count(*) from toti_private.media_revisions where owner_id=p_actor and created_at>now()-interval '1 hour')>=30
      or (select coalesce(sum(byte_size),0) from toti_private.media_revisions where owner_id=p_actor)>=52428800 then
      raise exception 'Photo upload limit reached. Try again later.' using errcode='22023';
    end if;
    v_path:=p_actor::text||'/'||p_revision::text||'/'||p_sha256||'.jpg';
    insert into toti_private.media_revisions(id,owner_id,object_path,kind,entity_id,source_sha256,sha256,
      actual_mime,width,height,byte_size)
    values(p_revision,p_actor,v_path,p_kind,p_entity,p_source_sha256,p_sha256,'image/jpeg',p_width,p_height,p_byte_size)
    returning * into r;
  end if;
  return jsonb_build_object('id',r.id,'entity_id',r.entity_id,'kind',r.kind,'status',r.state,
    'sha256',r.sha256,'object_path',r.object_path,'upload_state',r.upload_state,'owner_feedback',r.owner_feedback);
end; $$;

create function toti_private.media_finalize(p_actor uuid,p_session uuid,p_revision uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare r toti_private.media_revisions;
begin
  perform pg_advisory_xact_lock(731209444211::bigint);
  perform toti_private.media_session(p_actor,p_session);
  select * into r from toti_private.media_revisions where id=p_revision and owner_id=p_actor for update;
  if not found or not exists(select 1 from storage.objects where bucket_id='toti-media' and name=r.object_path) then
    raise exception 'The photo upload is incomplete. Try again.' using errcode='22023';
  end if;
  update toti_private.media_revisions set upload_state='ready' where id=r.id;
  return jsonb_build_object('id',r.id,'entity_id',r.entity_id,'kind',r.kind,'status',r.state,
    'sha256',r.sha256,'owner_feedback',r.owner_feedback);
end; $$;

-- Storage INSERT RLS participates in the same lock as account deletion.
-- VOLATILE obtains a fresh snapshot after waiting for a concurrent deletion.
create function toti_private.media_insert_allowed(p_path text)
returns boolean language plpgsql volatile security definer set search_path='' as $$
declare v_actor uuid;
begin
  perform pg_advisory_xact_lock(731209444211::bigint);
  v_actor:=toti_private.actor();
  return exists(select 1 from toti_private.media_revisions r
    where r.object_path=p_path and r.owner_id=v_actor and r.upload_state='reserved'
      and r.kind in ('avatar','post') and r.actual_mime='image/jpeg'
      and r.sha256 ~ '^[0-9a-f]{64}$'
      and p_path=v_actor::text||'/'||r.id::text||'/'||r.sha256||'.jpg');
end; $$;
create policy toti_media_reserved_insert on storage.objects for insert to authenticated
  with check(bucket_id='toti-media' and toti_private.media_insert_allowed(name));

create function toti_private.media_access(p_revision uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_actor uuid:=toti_private.actor(); r toti_private.media_revisions; o toti_private.objects;
begin
  select * into r from toti_private.media_revisions where id=p_revision and upload_state='ready';
  if not found or not exists(select 1 from toti_private.accounts where id=r.owner_id and status='active') then
    raise exception 'This photo is unavailable' using errcode='42501';
  end if;
  if exists(select 1 from toti_private.objects where id=r.entity_id and deleted_at is not null) then
    raise exception 'This photo is unavailable' using errcode='42501';
  end if;
  if r.owner_id<>v_actor then
    select * into o from toti_private.objects where id=r.entity_id;
    if not found or r.state<>'approved' or not toti_private.visible(o,v_actor)
      or (r.kind='post' and (o.kind<>'post' or o.body->>'media_revision_id'<>r.id::text))
      or (r.kind='avatar' and (o.kind<>'profile' or o.body->>'avatar_media_revision_id'<>r.id::text)) then
      raise exception 'This photo is unavailable' using errcode='42501';
    end if;
    -- SQL NULL must not authorize an attachment which is no longer referenced.
    if (case when r.kind='post' then o.body->>'media_revision_id' else o.body->>'avatar_media_revision_id' end)
      is distinct from r.id::text then raise exception 'This photo is unavailable' using errcode='42501'; end if;
  end if;
  return jsonb_build_object('object_path',r.object_path,'sha256',r.sha256);
end; $$;

-- Preserve the established business implementation for all unrelated actions.
alter function toti_private.mutate(uuid,text,uuid,jsonb) rename to mutate_without_media;
revoke all on function toti_private.mutate_without_media(uuid,text,uuid,jsonb) from public,anon,authenticated;
create function toti_private.mutate(p_operation_id uuid,p_action text,p_entity_id uuid,p_payload jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid; old_receipt toti_private.operations; old_object toti_private.objects;
  r toti_private.media_revisions; target toti_private.objects; v_kind text; v_body jsonb;
  v_revision uuid; v_parent uuid; v_state text; v_draft boolean; v_version bigint;
  v_date numeric:=extract(epoch from now())-978307200; v_result jsonb;
begin
  if p_action not in ('profile.save','post.save') then
    return toti_private.mutate_without_media(p_operation_id,p_action,p_entity_id,p_payload);
  end if;
  if p_operation_id is null or p_entity_id is null or p_payload is null or jsonb_typeof(p_payload)<>'object'
    or octet_length(p_payload::text)>200000 then raise exception 'Invalid operation' using errcode='22023'; end if;
  perform pg_advisory_xact_lock(731209444211::bigint);
  v_actor:=toti_private.actor(); v_kind:=split_part(p_action,'.',1);
  select * into old_receipt from toti_private.operations where actor_id=v_actor and operation_id=p_operation_id;
  if found then
    if old_receipt.action<>p_action or old_receipt.entity_id<>p_entity_id or old_receipt.payload<>p_payload then
      raise exception 'Operation ID was already used with different content' using errcode='22023';
    end if;
    return old_receipt.result;
  end if;
  select * into old_object from toti_private.objects where id=p_entity_id;
  if found and (old_object.owner_id<>v_actor or old_object.kind<>v_kind or old_object.deleted_at is not null) then
    raise exception 'This item is unavailable' using errcode='42501';
  end if;
  if p_payload->>'expected_version' is not null and coalesce(old_object.version,0)<>(p_payload->>'expected_version')::bigint then
    raise exception 'This item changed. Reload before editing.' using errcode='40001';
  end if;
  if p_payload->>'photoJPEG' is not null or p_payload->>'photoAsset' is not null then
    raise exception 'Upload the selected photo before saving.' using errcode='22023';
  end if;
  if p_payload ? 'media_revision_id' then v_revision:=(p_payload->>'media_revision_id')::uuid;
  elsif v_kind='post' then v_revision:=(old_object.body->>'media_revision_id')::uuid;
  else v_revision:=coalesce((old_object.body->>'avatar_pending_media_revision_id')::uuid,(old_object.body->>'avatar_media_revision_id')::uuid); end if;
  if v_revision is not null then
    select * into r from toti_private.media_revisions where id=v_revision;
    if not found or r.owner_id<>v_actor or r.entity_id<>p_entity_id
      or r.kind<>(case when v_kind='profile' then 'avatar' else 'post' end) or r.upload_state<>'ready' then
      raise exception 'This photo is unavailable. Upload it again.' using errcode='42501';
    end if;
  end if;
  if v_kind='profile' then
    if p_entity_id<>v_actor or length(btrim(coalesce(p_payload->>'displayName',''))) not between 1 and 30
      or length(coalesce(p_payload->>'biography',''))>160 then raise exception 'Invalid profile' using errcode='22023'; end if;
    v_body:=jsonb_build_object('displayName',btrim(p_payload->>'displayName'),'biography',coalesce(p_payload->>'biography',''),'avatarSymbol','person','hasCustomAvatar',false);
    if v_revision is not null then
      v_body:=v_body||jsonb_build_object('avatar_media_revision_id',old_object.body->'avatar_media_revision_id');
      if r.state='approved' then v_body:=v_body||jsonb_build_object('avatar_media_revision_id',r.id);
      else v_body:=v_body||jsonb_build_object('avatar_pending_media_revision_id',r.id); end if;
      v_body:=v_body||jsonb_build_object('hasCustomAvatar',(v_body->>'avatar_media_revision_id') is not null);
    elsif coalesce((p_payload->>'hasCustomAvatar')::boolean,false) and not (p_payload ? 'media_revision_id') then
      raise exception 'Upload the selected photo before saving.' using errcode='22023';
    end if;
    v_state:='published';
  else
    v_draft:=coalesce((p_payload->>'isDraft')::boolean,false);
    if length(coalesce(p_payload->>'body',''))>(case when v_draft then 10100 else 1000 end)
      or (not v_draft and length(btrim(coalesce(p_payload->>'body','')))=0)
      or coalesce(p_payload->>'topic','') not in ('Listening','Concerts','Making music','Find a bandmate') then
      raise exception 'Invalid post' using errcode='22023';
    end if;
    if p_payload->>'voiceRoomID' is not null then
      v_parent:=(p_payload->>'voiceRoomID')::uuid;
      select * into target from toti_private.objects where id=v_parent and kind='room';
      if not found or not toti_private.visible(target,v_actor) or target.state='closed' then
        raise exception 'The linked room is unavailable' using errcode='22023'; end if;
    end if;
    v_body:=jsonb_build_object('id',p_entity_id,'body',coalesce(p_payload->>'body',''),'topic',p_payload->>'topic','isDraft',v_draft,
      'isEditorial',false,'createdAt',coalesce(old_object.body->'createdAt',to_jsonb(v_date)),
      'updatedAt',v_date,'voiceRoomID',v_parent,'media_revision_id',v_revision);
    v_state:=case when v_draft then 'private' when v_revision is null or r.state='approved' then 'published' else r.state end;
  end if;
  insert into toti_private.objects(id,owner_id,kind,body,state) values(p_entity_id,v_actor,v_kind,v_body,v_state)
    on conflict(id) do update set body=excluded.body,state=excluded.state,version=objects.version+1,updated_at=now()
    returning version into v_version;
  v_result:=jsonb_build_object('entity_id',p_entity_id,'version',v_version,'status','saved');
  insert into toti_private.operations(actor_id,operation_id,action,entity_id,payload,result)
    values(v_actor,p_operation_id,p_action,p_entity_id,p_payload,v_result);
  return v_result;
end; $$;

-- Only a trusted SQL operator can record a real approval or rejection.
-- No HTTP review route and no automatic approval worker are installed.
create function toti_private.review_media(p_revision uuid,p_decision text,p_operator text,p_reason text)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare r toti_private.media_revisions; o toti_private.objects; v_body jsonb; v_state text;
begin
  if p_decision is null or p_decision not in ('approved','rejected') or length(btrim(coalesce(p_operator,''))) not between 1 and 160
    or length(btrim(coalesce(p_reason,''))) not between 1 and 500 then raise exception 'A decision, operator and reason are required'; end if;
  perform pg_advisory_xact_lock(731209444211::bigint);
  select * into r from toti_private.media_revisions where id=p_revision and upload_state='ready' for update;
  if not found or not exists(select 1 from toti_private.accounts where id=r.owner_id and status='active') then
    raise exception 'This photo is unavailable'; end if;
  if not exists(select 1 from storage.objects where bucket_id='toti-media' and name=r.object_path) then raise exception 'Photo bytes are missing'; end if;
  insert into toti_private.media_review_events(revision_id,owner_id,decision,operator_identity,database_identity,reason)
    values(r.id,r.owner_id,p_decision,btrim(p_operator),session_user,btrim(p_reason));
  update toti_private.media_revisions set state=p_decision,owner_feedback=btrim(p_reason),reviewed_by=btrim(p_operator),reviewed_at=now() where id=r.id;
  select * into o from toti_private.objects where id=r.entity_id and owner_id=r.owner_id and deleted_at is null for update;
  if found then
    v_body:=o.body; v_state:=o.state;
    if r.kind='post' and o.kind='post' and o.body->>'media_revision_id'=r.id::text then
      v_state:=case when coalesce((o.body->>'isDraft')::boolean,false) then 'private' when p_decision='approved' then 'published' else 'rejected' end;
    elsif r.kind='avatar' and o.kind='profile' then
      if p_decision='approved' and o.body->>'avatar_pending_media_revision_id'=r.id::text then
        v_body:=(v_body-'avatar_pending_media_revision_id')||jsonb_build_object('avatar_media_revision_id',r.id,'hasCustomAvatar',true);
      elsif p_decision='rejected' and o.body->>'avatar_media_revision_id'=r.id::text then
        v_body:=(v_body-'avatar_media_revision_id')||jsonb_build_object('hasCustomAvatar',false);
        if o.body->>'avatar_pending_media_revision_id' is null then
          v_body:=v_body||jsonb_build_object('avatar_pending_media_revision_id',r.id);
        end if;
      end if;
    end if;
    if v_body is distinct from o.body or v_state is distinct from o.state
      or o.body->>'avatar_pending_media_revision_id'=r.id::text then
      update toti_private.objects set body=v_body,state=v_state,version=version+1,updated_at=now() where id=o.id;
    end if;
  end if;
  return jsonb_build_object('revision_id',r.id,'decision',p_decision,'reviewed_at',now());
end; $$;

create function toti_private.post_media_document(o toti_private.objects,p_viewer uuid)
returns jsonb language sql stable security definer set search_path='' as $$
  select o.body || jsonb_build_object('media_status',r.state,'media_review_status',r.state)
    || case when o.owner_id=p_viewer then jsonb_build_object('media_feedback',r.owner_feedback,'media_review_reason',r.owner_feedback) else '{}'::jsonb end
  from (select 1) seed left join toti_private.media_revisions r
    on r.id=(o.body->>'media_revision_id')::uuid and r.owner_id=o.owner_id and r.kind='post' and r.entity_id=o.id and r.upload_state='ready';
$$;

create or replace function toti_private.profile_document(p_account uuid,p_viewer uuid)
returns jsonb language sql stable security definer set search_path='' as $$
  select (o.body-'avatar_pending_media_revision_id') || jsonb_build_object(
    'id',o.id,'avatar_media_revision_id',approved.id,'hasCustomAvatar',approved.id is not null,
    'my_following',exists(select 1 from toti_private.relationships r where r.actor_id=p_viewer and r.target_id=p_account and r.kind='follow'),
    'follows_me',exists(select 1 from toti_private.relationships r where r.actor_id=p_account and r.target_id=p_viewer and r.kind='follow'),
    'follower_count',(select count(*) from toti_private.relationships r where r.target_id=p_account and r.kind='follow'),
    'following_count',(select count(*) from toti_private.relationships r where r.actor_id=p_account and r.kind='follow'),
    'post_count',(select count(*) from toti_private.objects p where p.owner_id=p_account and p.kind='post' and p.state='published' and p.deleted_at is null),
    'like_count',(select count(*) from toti_private.reactions r join toti_private.objects p on p.id=r.post_id where p.owner_id=p_account and p.kind='post' and p.state='published' and p.deleted_at is null and r.kind='like'))
    || case when p_viewer=p_account then jsonb_build_object(
      'avatar_pending_media_revision_id',pending.id,'avatar_media_status',coalesce(pending.state,approved.state),
      'avatar_media_feedback',coalesce(pending.owner_feedback,approved.owner_feedback),
      'media_review_status',coalesce(pending.state,approved.state),'media_review_reason',coalesce(pending.owner_feedback,approved.owner_feedback)) else '{}'::jsonb end
  from toti_private.objects o join toti_private.accounts a on a.id=o.owner_id
  left join toti_private.media_revisions approved on approved.id=(o.body->>'avatar_media_revision_id')::uuid and approved.state='approved' and approved.upload_state='ready' and approved.kind='avatar' and approved.owner_id=o.owner_id and approved.entity_id=o.id
  left join toti_private.media_revisions pending on pending.id=(o.body->>'avatar_pending_media_revision_id')::uuid and pending.upload_state='ready' and pending.kind='avatar' and pending.owner_id=o.owner_id and pending.entity_id=o.id
  where o.id=p_account and o.kind='profile' and o.deleted_at is null and a.status='active' and not toti_private.blocked(p_viewer,p_account);
$$;

create function public.toti_media_context() returns jsonb language sql security invoker set search_path='' as $$ select toti_private.media_context(); $$;
create function public.toti_media_access(p_revision uuid) returns jsonb language sql security invoker set search_path='' as $$ select toti_private.media_access(p_revision); $$;
create function public.toti_media_reserve(p_actor uuid,p_session uuid,p_revision uuid,p_kind text,p_entity uuid,p_source_sha256 text,p_sha256 text,p_width integer,p_height integer,p_byte_size bigint)
returns jsonb language sql security invoker set search_path='' as $$ select toti_private.media_reserve(p_actor,p_session,p_revision,p_kind,p_entity,p_source_sha256,p_sha256,p_width,p_height,p_byte_size); $$;
create function public.toti_media_finalize(p_actor uuid,p_session uuid,p_revision uuid)
returns jsonb language sql security invoker set search_path='' as $$ select toti_private.media_finalize(p_actor,p_session,p_revision); $$;
create or replace function public.toti_mutate(p_operation_id uuid,p_action text,p_entity_id uuid,p_payload jsonb)
returns jsonb language sql security invoker set search_path='' as $$ select toti_private.mutate(p_operation_id,p_action,p_entity_id,p_payload); $$;

revoke all on function toti_private.media_session(uuid,uuid),toti_private.media_context(),toti_private.media_reserve(uuid,uuid,uuid,text,uuid,text,text,integer,integer,bigint),
  toti_private.media_finalize(uuid,uuid,uuid),toti_private.media_insert_allowed(text),toti_private.media_access(uuid),toti_private.mutate(uuid,text,uuid,jsonb),
  toti_private.review_media(uuid,text,text,text),toti_private.post_media_document(toti_private.objects,uuid),
  public.toti_media_context(),public.toti_media_access(uuid),public.toti_media_reserve(uuid,uuid,uuid,text,uuid,text,text,integer,integer,bigint),public.toti_media_finalize(uuid,uuid,uuid)
  from public,anon,authenticated;
grant execute on function toti_private.media_context(),toti_private.media_access(uuid),toti_private.media_insert_allowed(text),toti_private.mutate(uuid,text,uuid,jsonb),public.toti_media_context(),public.toti_media_access(uuid) to authenticated;
grant execute on function toti_private.media_reserve(uuid,uuid,uuid,text,uuid,text,text,integer,integer,bigint),toti_private.media_finalize(uuid,uuid,uuid),
  public.toti_media_reserve(uuid,uuid,uuid,text,uuid,text,text,integer,integer,bigint),public.toti_media_finalize(uuid,uuid,uuid) to service_role;
-- review_media deliberately has no client/service grant. Run through trusted SQL.
revoke all on function toti_private.review_media(uuid,text,text,text) from service_role;

-- Preserve cursor/access behavior and enrich the existing post projection.
create or replace function toti_private.read_records(p_kind text, p_cursor text, p_parent_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_actor uuid := toti_private.actor(); v_cursor jsonb; cut_time timestamptz; cut_id uuid;
  rows_json jsonb; next_value text; last_row jsonb;
begin
  if p_kind is null or p_kind not in ('profile','post','comment','note','room','conversation','message','follow','block','reaction','report','preference','invitation') then
    raise exception 'Unsupported collection' using errcode='22023';
  end if;
  if p_cursor is not null then
    if length(p_cursor)>512 then raise exception 'Invalid cursor' using errcode='22023'; end if;
    v_cursor := convert_from(decode(p_cursor,'base64'),'UTF8')::jsonb;
    if v_cursor->>'kind'<>p_kind or (v_cursor->>'parent') is distinct from p_parent_id::text then
      raise exception 'Cursor belongs to another collection' using errcode='22023';
    end if;
    cut_time := (v_cursor->>'at')::timestamptz; cut_id := (v_cursor->>'id')::uuid;
    if cut_time is null or cut_id is null then raise exception 'Invalid cursor' using errcode='22023'; end if;
  end if;
  if p_kind='message' and p_parent_id is not null and not toti_private.container_access(p_parent_id,v_actor) then
    raise exception 'This conversation is unavailable.' using errcode='42501';
  end if;
  with candidates as (
    select o.id,o.owner_id,o.kind,o.parent_id,
      (case when o.kind='conversation' then o.body || jsonb_build_object(
        'member_ids',coalesce((select jsonb_agg(m.account_id order by m.account_id) from toti_private.members m where m.container_id=o.id and m.active),'[]'::jsonb),
        'member_profiles',coalesce((select jsonb_agg(toti_private.profile_document(m.account_id,v_actor) order by m.account_id) from toti_private.members m where m.container_id=o.id and m.active),'[]'::jsonb),
        'peer_id',case when o.body->>'kind'='direct' then (select m.account_id from toti_private.members m where m.container_id=o.id and m.account_id<>v_actor limit 1) else null end,
        'peer_profile',case when o.body->>'kind'='direct' then (select toti_private.profile_document(m.account_id,v_actor) from toti_private.members m where m.container_id=o.id and m.account_id<>v_actor limit 1) else null end,
        'preference',coalesce((select p.body from toti_private.objects p where p.parent_id=o.id and p.kind='preference' and p.owner_id=v_actor and p.deleted_at is null),'{}'::jsonb),
        'is_owner',o.owner_id=v_actor,'is_group',o.body->>'kind'='group')
      when o.kind='room' then o.body || jsonb_build_object(
        'member_ids',coalesce((select jsonb_agg(m.account_id order by m.account_id) from toti_private.members m where m.container_id=o.id and m.active and not toti_private.blocked(v_actor,m.account_id)),'[]'::jsonb),
        'member_profiles',coalesce((select jsonb_agg(toti_private.profile_document(m.account_id,v_actor) order by m.account_id) from toti_private.members m where m.container_id=o.id and m.active and not toti_private.blocked(v_actor,m.account_id)),'[]'::jsonb))
      when o.kind='profile' then toti_private.profile_document(o.owner_id,v_actor)
      when o.kind='post' then toti_private.post_media_document(o,v_actor) || jsonb_build_object(
        'my_liked',exists(select 1 from toti_private.reactions r where r.post_id=o.id and r.actor_id=v_actor and r.kind='like'),
        'my_saved',exists(select 1 from toti_private.reactions r where r.post_id=o.id and r.actor_id=v_actor and r.kind='save'),
        'likeCount',(select count(*) from toti_private.reactions r where r.post_id=o.id and r.kind='like'),
        'like_count',(select count(*) from toti_private.reactions r where r.post_id=o.id and r.kind='like'),
        'comment_count',(select count(*) from toti_private.objects c where c.parent_id=o.id and c.kind='comment' and toti_private.visible(c,v_actor)))
      else o.body end) || jsonb_build_object('owner_profile',toti_private.profile_document(o.owner_id,v_actor)) as body,
      o.version,o.created_at,o.updated_at
    from toti_private.objects o where o.kind=p_kind and (p_parent_id is null or (p_kind in ('profile','post','room','conversation','note') and o.id=p_parent_id) or (p_kind not in ('profile','post','room','conversation','note') and o.parent_id=p_parent_id))
      and toti_private.visible(o,v_actor)
    union all
    select r.id,r.actor_id,r.kind,null::uuid,
      jsonb_build_object('target_id',r.target_id,'actor_id',r.actor_id,'enabled',true),1::bigint,r.created_at,r.created_at
    from toti_private.relationships r where r.kind=p_kind
      and ((r.kind='block' and r.actor_id=v_actor) or (r.kind='follow' and (r.actor_id=v_actor or r.target_id=v_actor)
        and not toti_private.blocked(v_actor,case when r.actor_id=v_actor then r.target_id else r.actor_id end)))
    union all
    select r.id,r.actor_id,'reaction',r.post_id,
      jsonb_build_object('target_id',r.post_id,'kind',r.kind,'enabled',true),1::bigint,r.created_at,r.created_at
    from toti_private.reactions r join toti_private.objects o on o.id=r.post_id
    where p_kind='reaction' and r.actor_id=v_actor and toti_private.visible(o,v_actor)
  ), page as (
    select * from candidates where cut_time is null or (created_at,id)<(cut_time,cut_id)
    order by created_at desc,id desc limit 51
  ) select coalesce(jsonb_agg(to_jsonb(page) order by created_at desc,id desc),'[]'::jsonb) into rows_json from page;
  if jsonb_array_length(rows_json)>50 then
    rows_json := rows_json - 50;
    last_row := rows_json->49;
    next_value := encode(convert_to(jsonb_build_object('kind',p_kind,'parent',p_parent_id,'at',last_row->>'created_at','id',last_row->>'id')::text,'UTF8'),'base64');
  end if;
  return jsonb_build_object('records',rows_json,'next_cursor',next_value);
end; $$;

