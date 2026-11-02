-- Ordered deployment source; the remote migration version is recorded separately.
-- All writes and their receipts commit together. Client roles cannot write tables.
create schema if not exists toti_private;
revoke all on schema toti_private from public, anon, authenticated;
grant usage on schema toti_private to authenticated, service_role;

create table toti_private.accounts (
  id uuid primary key references auth.users(id) on delete cascade,
  status text not null default 'active' check (status in ('active', 'deleting')),
  agreement_version text not null,
  accepted_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);
create table toti_private.objects (
  id uuid primary key,
  owner_id uuid not null references toti_private.accounts(id) on delete cascade,
  kind text not null check (kind in ('profile','post','comment','note','room','conversation','message','report','preference','invitation')),
  parent_id uuid references toti_private.objects(id) on delete cascade,
  body jsonb not null default '{}' check (jsonb_typeof(body) = 'object'),
  state text not null default 'private' check (state in ('private','published','pending','rejected','closed')),
  version bigint not null default 1 check (version > 0),
  sequence bigint,
  dedup_key text unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index toti_objects_kind_page on toti_private.objects(kind,created_at desc,id desc) where deleted_at is null;
create index toti_objects_owner on toti_private.objects(owner_id,kind);
create index toti_objects_parent_page on toti_private.objects(parent_id,created_at desc,id desc) where deleted_at is null;
create table toti_private.relationships (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid not null references toti_private.accounts(id) on delete cascade,
  target_id uuid not null references toti_private.accounts(id) on delete cascade,
  kind text not null check (kind in ('follow','block')),
  created_at timestamptz not null default now(),
  unique(actor_id,target_id,kind),
  check(actor_id <> target_id)
);
create index toti_relationship_target on toti_private.relationships(target_id,kind,actor_id);
create table toti_private.reactions (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid not null references toti_private.accounts(id) on delete cascade,
  post_id uuid not null references toti_private.objects(id) on delete cascade,
  kind text not null check (kind in ('like','save')),
  created_at timestamptz not null default now(),
  unique(actor_id,post_id,kind)
);
create index toti_reaction_post on toti_private.reactions(post_id,kind);
create table toti_private.members (
  container_id uuid not null references toti_private.objects(id) on delete cascade,
  account_id uuid not null references toti_private.accounts(id) on delete cascade,
  role text not null check (role in ('owner','member')),
  active boolean not null default true,
  joined_sequence bigint not null default 0,
  joined_at timestamptz not null default now(),
  primary key(container_id,account_id)
);
create index toti_members_account on toti_private.members(account_id,active,container_id);
create table toti_private.operations (
  actor_id uuid not null references toti_private.accounts(id) on delete cascade,
  operation_id uuid not null,
  action text not null,
  entity_id uuid not null,
  payload jsonb not null,
  result jsonb not null,
  created_at timestamptz not null default now(),
  primary key(actor_id,operation_id)
);
-- This job deliberately has no Auth foreign key so cleanup evidence survives identity removal.
create table toti_private.deletion_jobs (
  account_id uuid primary key,
  requested_at timestamptz not null default now(),
  status text not null default 'pending' check (status in ('pending','storage_removed','complete')),
  completed_at timestamptz,
  last_error text
);
create table toti_private.media_revisions (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references toti_private.accounts(id) on delete cascade,
  object_path text not null unique,
  state text not null default 'pending' check (state in ('pending','approved','rejected')),
  actual_mime text,
  width integer,
  height integer,
  byte_size bigint,
  owner_feedback text,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz
);
create index toti_media_owner on toti_private.media_revisions(owner_id,state);

alter table toti_private.accounts enable row level security;
alter table toti_private.objects enable row level security;
alter table toti_private.relationships enable row level security;
alter table toti_private.reactions enable row level security;
alter table toti_private.members enable row level security;
alter table toti_private.operations enable row level security;
alter table toti_private.deletion_jobs enable row level security;
alter table toti_private.media_revisions enable row level security;
revoke all on all tables in schema toti_private from public, anon, authenticated;
-- Trusted functions, not broad table grants, are the only business-data access boundary.

create function toti_private.actor(require_active boolean default true)
returns uuid language plpgsql stable security definer set search_path = '' as $$
declare actor_id uuid := auth.uid(); session_id uuid;
begin
  if actor_id is null then raise exception 'Authentication required' using errcode='42501'; end if;
  session_id := nullif(auth.jwt()->>'session_id','')::uuid;
  if session_id is null or not exists (
    select 1 from auth.sessions s join auth.users u on u.id=s.user_id
    where s.id=session_id and s.user_id=actor_id
      and (s.not_after is null or s.not_after > now())
      and u.email_confirmed_at is not null and coalesce(u.is_anonymous,false)=false
  ) then raise exception 'Your session has expired. Sign in again.' using errcode='42501'; end if;
  if require_active and not exists(select 1 from toti_private.accounts a where a.id=actor_id and a.status='active') then
    raise exception 'This account is unavailable.' using errcode='42501';
  end if;
  return actor_id;
end; $$;

create function toti_private.blocked(a uuid,b uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from toti_private.relationships r where r.kind='block'
    and ((r.actor_id=a and r.target_id=b) or (r.actor_id=b and r.target_id=a)));
$$;

create function toti_private.container_access(container uuid, actor_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from toti_private.objects o join toti_private.members m on m.container_id=o.id
    join toti_private.accounts a on a.id=o.owner_id
    where o.id=container and o.kind in ('conversation','room') and o.deleted_at is null
      and o.state<>'closed' and a.status='active' and m.account_id=actor_id and m.active
      and not exists(select 1 from toti_private.members other where other.container_id=o.id and other.active
        and toti_private.blocked(actor_id,other.account_id)));
$$;

create function toti_private.visible(o toti_private.objects, actor_id uuid)
returns boolean language plpgsql stable security definer set search_path = '' as $$
begin
  if o.deleted_at is not null or not exists(select 1 from toti_private.accounts a where a.id=o.owner_id and a.status='active') then return false; end if;
  if o.kind='message' then
    return toti_private.container_access(o.parent_id,actor_id)
      and exists(select 1 from toti_private.members m where m.container_id=o.parent_id and m.account_id=actor_id
        and m.active and o.sequence>m.joined_sequence);
  elsif o.kind='conversation' then return toti_private.container_access(o.id,actor_id);
  elsif o.kind='invitation' then
    return o.owner_id=actor_id and exists(select 1 from toti_private.objects p where p.id=o.parent_id and p.deleted_at is null and p.state<>'closed');
  elsif o.kind in ('note','report','preference') then return o.owner_id=actor_id;
  elsif o.kind='profile' then return not toti_private.blocked(actor_id,o.owner_id);
  elsif o.kind='comment' then
    return not toti_private.blocked(actor_id,o.owner_id) and exists (
      select 1 from toti_private.objects p where p.id=o.parent_id and p.kind='post'
      and p.deleted_at is null and (p.owner_id=actor_id or p.state='published')
      and not toti_private.blocked(actor_id,p.owner_id)
      and exists(select 1 from toti_private.accounts a where a.id=p.owner_id and a.status='active')
    );
  else return o.owner_id=actor_id or (o.state='published' and not toti_private.blocked(actor_id,o.owner_id));
  end if;
end; $$;

create function toti_private.read_records(p_kind text, p_cursor text, p_parent_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_actor uuid := toti_private.actor(); c jsonb; cut_time timestamptz; cut_id uuid;
  rows_json jsonb; next_value text; last_row jsonb;
begin
  if p_kind is null or p_kind not in ('profile','post','comment','note','room','conversation','message','follow','block','reaction','report','preference','invitation') then
    raise exception 'Unsupported collection' using errcode='22023';
  end if;
  if p_cursor is not null then
    if length(p_cursor)>512 then raise exception 'Invalid cursor' using errcode='22023'; end if;
    c := convert_from(decode(p_cursor,'base64'),'UTF8')::jsonb;
    if c->>'kind'<>p_kind or (c->>'parent') is distinct from p_parent_id::text then
      raise exception 'Cursor belongs to another collection' using errcode='22023';
    end if;
    cut_time := (c->>'at')::timestamptz; cut_id := (c->>'id')::uuid;
    if cut_time is null or cut_id is null then raise exception 'Invalid cursor' using errcode='22023'; end if;
  end if;
  if p_kind='message' and p_parent_id is not null and not toti_private.container_access(p_parent_id,v_actor) then
    raise exception 'This conversation is unavailable.' using errcode='42501';
  end if;
  with candidates as (
    select o.id,o.owner_id,o.kind,o.parent_id,
      case when o.kind='conversation' then o.body || jsonb_build_object(
        'member_ids',coalesce((select jsonb_agg(m.account_id order by m.account_id) from toti_private.members m where m.container_id=o.id and m.active),'[]'::jsonb),
        'peer_id',case when o.body->>'kind'='direct' then (select m.account_id from toti_private.members m where m.container_id=o.id and m.account_id<>v_actor limit 1) else null end,
        'is_owner',o.owner_id=v_actor,'is_group',o.body->>'kind'='group')
      when o.kind='room' then o.body || jsonb_build_object('member_ids',coalesce((select jsonb_agg(m.account_id order by m.account_id) from toti_private.members m where m.container_id=o.id and m.active),'[]'::jsonb))
      when o.kind='profile' then o.body || jsonb_build_object(
        'follower_count',(select count(*) from toti_private.relationships r where r.target_id=o.owner_id and r.kind='follow'),
        'following_count',(select count(*) from toti_private.relationships r where r.actor_id=o.owner_id and r.kind='follow'),
        'post_count',(select count(*) from toti_private.objects p where p.owner_id=o.owner_id and p.kind='post' and p.state='published' and p.deleted_at is null))
      when o.kind='post' then o.body || jsonb_build_object(
        'likeCount',(select count(*) from toti_private.reactions r where r.post_id=o.id and r.kind='like'),
        'like_count',(select count(*) from toti_private.reactions r where r.post_id=o.id and r.kind='like'),
        'comment_count',(select count(*) from toti_private.objects c where c.parent_id=o.id and c.kind='comment' and toti_private.visible(c,v_actor)))
      else o.body end as body,o.version,o.created_at,o.updated_at
    from toti_private.objects o where o.kind=p_kind and (p_parent_id is null or o.parent_id=p_parent_id)
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

create function toti_private.mutate(p_operation_id uuid,p_action text,p_entity_id uuid,p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_actor uuid; old_receipt toti_private.operations; old_object toti_private.objects;
  target toti_private.objects; v_id uuid:=p_entity_id; v_kind text; v_body jsonb; v_state text:='private';
  v_parent uuid; v_version bigint:=1; v_status text:='saved'; peer uuid; member_id uuid; invite_id uuid;
  v_enabled boolean; v_seq bigint; v_now timestamptz:=now(); v_date numeric:=extract(epoch from now())-978307200;
  pair_key text; v_name text; v_count integer; v_array jsonb; v_expected bigint;
begin
  if p_operation_id is null or p_entity_id is null or p_action is null or p_payload is null or jsonb_typeof(p_payload)<>'object'
    or octet_length(p_payload::text)>200000 then raise exception 'Invalid operation' using errcode='22023'; end if;
  -- A bounded pilot serializes business mutations, including block/send and deletion races.
  -- Replace only with an audited lock ordering strategy before high-volume rollout.
  perform pg_advisory_xact_lock(731209444211::bigint);
  v_actor := toti_private.actor(p_action not in ('enroll','account.delete'));
  select * into old_receipt from toti_private.operations where operations.actor_id=v_actor and operation_id=p_operation_id;
  if found then
    if old_receipt.action<>p_action or old_receipt.entity_id<>p_entity_id or old_receipt.payload<>p_payload then
      raise exception 'Operation ID was already used with different content' using errcode='22023';
    end if;
    return old_receipt.result;
  end if;
  if p_action='enroll' then
    if v_id<>v_actor or length(coalesce(p_payload->>'agreement_version','')) not between 1 and 100
      or p_payload->>'agreement_version'='unavailable' then raise exception 'A valid agreement is required' using errcode='22023'; end if;
    if exists(select 1 from toti_private.accounts a where a.id=v_actor and a.status<>'active') then
      raise exception 'Account deletion is pending' using errcode='42501';
    end if;
    insert into toti_private.accounts(id,agreement_version) values(v_actor,p_payload->>'agreement_version')
      on conflict(id) do update set agreement_version=excluded.agreement_version,accepted_at=now();
    insert into toti_private.objects(id,owner_id,kind,body,state) values(v_actor,v_actor,'profile',
      jsonb_build_object('displayName','Music lover','biography','','avatarSymbol','person','hasCustomAvatar',false),'published') on conflict(id) do nothing;
  elsif p_action='account.delete' then
    if v_id<>v_actor then raise exception 'Access denied' using errcode='42501'; end if;
    update toti_private.accounts set status='deleting' where id=v_actor;
    if not found then raise exception 'Account is not enrolled' using errcode='42501'; end if;
    insert into toti_private.deletion_jobs(account_id) values(v_actor) on conflict(account_id) do nothing;
    update toti_private.members set active=false where account_id=v_actor;
    v_status:='deletion_pending';
  elsif p_action in ('follow.set','block.set') then
    if v_id=v_actor or not exists(select 1 from toti_private.accounts a where a.id=v_id and a.status='active') then
      raise exception 'This account is unavailable' using errcode='22023'; end if;
    v_kind:=split_part(p_action,'.',1); v_enabled:=(p_payload->>'enabled')::boolean;
    if v_enabled is null then raise exception 'An enabled value is required' using errcode='22023'; end if;
    if v_kind='follow' and toti_private.blocked(v_actor,v_id) then raise exception 'This relationship is unavailable' using errcode='42501'; end if;
    if v_enabled then
      insert into toti_private.relationships(actor_id,target_id,kind) values(v_actor,v_id,v_kind) on conflict(actor_id,target_id,kind) do nothing;
      if v_kind='block' then
        delete from toti_private.relationships r where r.kind='follow' and ((r.actor_id=v_actor and r.target_id=v_id) or (r.actor_id=v_id and r.target_id=v_actor));
      end if;
    else delete from toti_private.relationships r where r.actor_id=v_actor and r.target_id=v_id and r.kind=v_kind; end if;
  elsif p_action='reaction.set' then
    select * into target from toti_private.objects where id=v_id and kind='post';
    if not found or not toti_private.visible(target,v_actor) or target.state<>'published' then raise exception 'This post is unavailable' using errcode='42501'; end if;
    v_kind:=p_payload->>'kind'; v_enabled:=(p_payload->>'enabled')::boolean;
    if v_kind not in ('like','save') or v_kind is null or v_enabled is null then raise exception 'Invalid reaction' using errcode='22023'; end if;
    if v_enabled then insert into toti_private.reactions(actor_id,post_id,kind) values(v_actor,v_id,v_kind) on conflict(actor_id,post_id,kind) do nothing;
    else delete from toti_private.reactions r where r.actor_id=v_actor and r.post_id=v_id and r.kind=v_kind; end if;
  elsif p_action in ('conversation.open','group.create') then
    if p_action='conversation.open' then
      peer:=(p_payload->>'peer_id')::uuid;
      if peer is null or peer=v_actor or not exists(select 1 from toti_private.accounts a where a.id=peer and a.status='active') or toti_private.blocked(v_actor,peer) then
        raise exception 'This account is unavailable' using errcode='42501'; end if;
      pair_key:='direct:'||least(v_actor::text,peer::text)||':'||greatest(v_actor::text,peer::text);
      select * into old_object from toti_private.objects where dedup_key=pair_key;
      if found then
        if old_object.deleted_at is not null or old_object.state='closed' then raise exception 'This conversation is unavailable' using errcode='42501'; end if;
        v_id:=old_object.id; v_version:=old_object.version;
        if not toti_private.container_access(v_id,v_actor) then raise exception 'This conversation is unavailable' using errcode='42501'; end if;
      else
        insert into toti_private.objects(id,owner_id,kind,body,dedup_key) values(v_id,v_actor,'conversation',jsonb_build_object('kind','direct','peer_id',peer),pair_key);
        insert into toti_private.members(container_id,account_id,role) values(v_id,v_actor,'owner'),(v_id,peer,'member');
      end if;
    else
      v_name:=btrim(p_payload->>'name'); v_array:=p_payload->'member_ids';
      if v_name is null or length(v_name) not between 1 and 48 or v_array is null or jsonb_typeof(v_array)<>'array' then raise exception 'Invalid group' using errcode='22023'; end if;
      if jsonb_array_length(v_array) not between 2 and 30 then raise exception 'Choose between 2 and 30 members' using errcode='22023'; end if;
      select count(distinct value::uuid) into v_count from jsonb_array_elements_text(v_array);
      if v_count<>jsonb_array_length(v_array) then raise exception 'Duplicate members' using errcode='22023'; end if;
      insert into toti_private.objects(id,owner_id,kind,body) values(v_id,v_actor,'conversation',jsonb_build_object('kind','group','name',v_name));
      insert into toti_private.members(container_id,account_id,role) values(v_id,v_actor,'owner');
      for member_id in select value::uuid from jsonb_array_elements_text(v_array) loop
        if member_id=v_actor or not exists(select 1 from toti_private.accounts a where a.id=member_id and a.status='active') or toti_private.blocked(v_actor,member_id)
          or not exists(select 1 from toti_private.relationships r where r.actor_id=v_actor and r.target_id=member_id and r.kind='follow')
          or not exists(select 1 from toti_private.relationships r where r.actor_id=member_id and r.target_id=v_actor and r.kind='follow') then
          raise exception 'Only mutual contacts can be invited' using errcode='42501'; end if;
        invite_id:=gen_random_uuid();
        insert into toti_private.objects(id,owner_id,kind,parent_id,body) values(invite_id,member_id,'invitation',v_id,
          jsonb_build_object('conversation_id',v_id,'inviter_id',v_actor,'name',v_name,'status','pending'));
      end loop;
    end if;
  elsif p_action in ('invitation.accept','invitation.decline') then
    select * into old_object from toti_private.objects where id=v_id and kind='invitation' and owner_id=v_actor and deleted_at is null;
    if not found or old_object.body->>'status'<>'pending' then raise exception 'This invitation is unavailable' using errcode='42501'; end if;
    select * into target from toti_private.objects where id=old_object.parent_id and deleted_at is null and state<>'closed';
    if not found or not exists(select 1 from toti_private.accounts a where a.id=target.owner_id and a.status='active') or toti_private.blocked(v_actor,target.owner_id) then raise exception 'This group is unavailable' using errcode='42501'; end if;
    if p_action='invitation.accept' then
      if exists(select 1 from toti_private.members m where m.container_id=target.id and m.active and toti_private.blocked(v_actor,m.account_id)) then raise exception 'This group is unavailable' using errcode='42501'; end if;
      select coalesce(max(sequence),0) into v_seq from toti_private.objects where parent_id=target.id and kind='message';
      insert into toti_private.members(container_id,account_id,role,joined_sequence) values(target.id,v_actor,'member',v_seq)
        on conflict(container_id,account_id) do update set active=true,joined_sequence=excluded.joined_sequence,joined_at=now();
    end if;
    update toti_private.objects set body=body||jsonb_build_object('status',case when p_action='invitation.accept' then 'accepted' else 'declined' end),version=version+1,updated_at=now() where id=v_id returning version into v_version;
  elsif p_action in ('conversation.leave','conversation.remove','room.join','room.leave') then
    select * into target from toti_private.objects where id=v_id and kind=case when p_action like 'room.%' then 'room' else 'conversation' end and deleted_at is null and state<>'closed';
    if not found then raise exception 'This space is unavailable' using errcode='42501'; end if;
    if p_action='room.join' then
      if not toti_private.visible(target,v_actor) or exists(select 1 from toti_private.members m where m.container_id=v_id and m.active and toti_private.blocked(v_actor,m.account_id)) then raise exception 'This room is unavailable' using errcode='42501'; end if;
      select count(*) into v_count from toti_private.members m where m.container_id=v_id and m.active;
      if v_count >= (target.body->>'seatCount')::integer and not exists(select 1 from toti_private.members m where m.container_id=v_id and m.account_id=v_actor and m.active) then raise exception 'This room is full' using errcode='22023'; end if;
      select coalesce(max(sequence),0) into v_seq from toti_private.objects where parent_id=v_id and kind='message';
      insert into toti_private.members(container_id,account_id,role,joined_sequence) values(v_id,v_actor,case when target.owner_id=v_actor then 'owner' else 'member' end,v_seq)
        on conflict(container_id,account_id) do update set active=true,joined_sequence=case when members.active then members.joined_sequence else excluded.joined_sequence end,joined_at=now();
    else
      member_id:=case when p_action='conversation.remove' then (p_payload->>'member_id')::uuid else v_actor end;
      if member_id is null or (p_action='conversation.remove' and (target.owner_id<>v_actor or member_id=v_actor)) then raise exception 'Only the owner can remove a member' using errcode='42501'; end if;
      if p_action='conversation.remove' and target.body->>'kind'<>'group' then raise exception 'Only groups support member removal' using errcode='22023'; end if;
      update toti_private.members set active=false where container_id=v_id and account_id=member_id and active;
      if not found then raise exception 'Membership is unavailable' using errcode='42501'; end if;
      if member_id=target.owner_id then update toti_private.objects set state='closed',version=version+1,updated_at=now() where id=v_id; end if;
    end if;
  elsif p_action in ('message.send','room.message') then
    v_parent:=case when p_action='room.message' then p_entity_id else (p_payload->>'conversation_id')::uuid end;
    select * into target from toti_private.objects where id=v_parent and deleted_at is null and kind=case when p_action='room.message' then 'room' else 'conversation' end;
    if not found or not toti_private.container_access(v_parent,v_actor) then raise exception 'This conversation is unavailable' using errcode='42501'; end if;
    if length(btrim(coalesce(p_payload->>'text',''))) not between 1 and 2000 then raise exception 'Write a message of up to 2,000 characters' using errcode='22023'; end if;
    if target.body->>'kind'='direct' then
      select m.account_id into peer from toti_private.members m where m.container_id=v_parent and m.account_id<>v_actor and m.active limit 1;
      if peer is null or not exists(select 1 from toti_private.accounts a where a.id=peer and a.status='active') then raise exception 'This recipient is unavailable' using errcode='42501'; end if;
      if not (exists(select 1 from toti_private.relationships r where r.actor_id=v_actor and r.target_id=peer and r.kind='follow')
        and exists(select 1 from toti_private.relationships r where r.actor_id=peer and r.target_id=v_actor and r.kind='follow'))
        and exists(select 1 from toti_private.objects o where o.parent_id=v_parent and o.kind='message' and o.owner_id=v_actor) then
        raise exception 'You can send another message once you follow each other.' using errcode='42501'; end if;
    end if;
    select coalesce(max(sequence),0)+1 into v_seq from toti_private.objects where parent_id=v_parent and kind='message';
    if p_action='room.message' then v_id:=p_operation_id; end if;
    v_kind:='message'; v_body:=jsonb_build_object('text',btrim(p_payload->>'text'),'conversation_id',v_parent,'sender_id',v_actor,'author_id',v_actor,'createdAt',v_date,'sequence',v_seq);
    insert into toti_private.objects(id,owner_id,kind,parent_id,body,sequence) values(v_id,v_actor,v_kind,v_parent,v_body,v_seq);
    update toti_private.objects set updated_at=now(),version=version+1 where id=v_parent;
  elsif p_action='preference.save' then
    if not toti_private.container_access(v_id,v_actor) then raise exception 'This conversation is unavailable' using errcode='42501'; end if;
    if length(coalesce(p_payload->>'draft',''))>2000 then raise exception 'Draft is too long' using errcode='22023'; end if;
    v_body:=jsonb_build_object('conversation_id',v_id);
    if p_payload ? 'draft' then v_body:=v_body||jsonb_build_object('draft',coalesce(p_payload->>'draft','')); end if;
    foreach v_name in array array['pinned','muted','hidden','read'] loop
      if p_payload ? v_name then
        if jsonb_typeof(p_payload->v_name)<>'boolean' then raise exception 'Invalid preference' using errcode='22023'; end if;
        v_body:=v_body||jsonb_build_object(v_name,p_payload->v_name);
      end if;
    end loop;
    pair_key:='preference:'||v_actor::text||':'||v_id::text;
    insert into toti_private.objects(id,owner_id,kind,parent_id,body,dedup_key) values(gen_random_uuid(),v_actor,'preference',v_id,v_body,pair_key)
      on conflict(dedup_key) do update set body=objects.body||excluded.body,version=objects.version+1,updated_at=now() returning version into v_version;
  elsif p_action in ('profile.save','post.save','comment.save','note.save','room.save','report.save') then
    v_kind:=split_part(p_action,'.',1);
    select * into old_object from toti_private.objects where id=v_id;
    if found and (old_object.kind<>v_kind or old_object.owner_id<>v_actor or old_object.deleted_at is not null) then raise exception 'Only your own available content can be edited' using errcode='42501'; end if;
    v_expected:=(p_payload->>'expected_version')::bigint;
    if v_expected is not null and coalesce(old_object.version,0)<>v_expected then raise exception 'This item changed. Reload before editing.' using errcode='40001'; end if;
    if v_kind='profile' then
      if v_id<>v_actor or length(btrim(coalesce(p_payload->>'displayName',''))) not between 1 and 30 or length(coalesce(p_payload->>'biography',''))>160 then raise exception 'Invalid profile' using errcode='22023'; end if;
      if coalesce((p_payload->>'hasCustomAvatar')::boolean,false) then raise exception 'Profile photo uploads are not available yet.' using errcode='22023'; end if;
      v_body:=jsonb_build_object('displayName',btrim(p_payload->>'displayName'),'biography',coalesce(p_payload->>'biography',''),'avatarSymbol','person','hasCustomAvatar',false); v_state:='published';
    elsif v_kind='post' then
      if p_payload->>'photoJPEG' is not null or p_payload->>'photoAsset' is not null then raise exception 'Photo publication is unavailable until media review is configured.' using errcode='22023'; end if;
      v_enabled:=coalesce((p_payload->>'isDraft')::boolean,false);
      if length(coalesce(p_payload->>'body',''))>(case when v_enabled then 10100 else 1000 end)
        or (not v_enabled and length(btrim(coalesce(p_payload->>'body','')))=0)
        or coalesce(p_payload->>'topic','') not in ('Listening','Concerts','Making music','Find a bandmate') then raise exception 'Invalid post' using errcode='22023'; end if;
      if p_payload->>'voiceRoomID' is not null then
        v_parent:=(p_payload->>'voiceRoomID')::uuid;
        select * into target from toti_private.objects where id=v_parent and kind='room';
        if not found or not toti_private.visible(target,v_actor) or target.state='closed' then raise exception 'The linked room is unavailable' using errcode='22023'; end if;
      end if;
      v_body:=jsonb_build_object('id',v_id,'body',coalesce(p_payload->>'body',''),'topic',p_payload->>'topic','isDraft',v_enabled,'isEditorial',false,
        'createdAt',coalesce(old_object.body->'createdAt',to_jsonb(v_date)),'updatedAt',v_date,'voiceRoomID',v_parent);
      v_parent:=null; v_state:=case when v_enabled then 'private' else 'published' end;
    elsif v_kind='comment' then
      v_parent:=(p_payload->>'postID')::uuid;
      select * into target from toti_private.objects where id=v_parent and kind='post';
      if not found or not toti_private.visible(target,v_actor) or target.state<>'published' then raise exception 'This post is unavailable' using errcode='42501'; end if;
      if old_object.id is not null and old_object.parent_id<>v_parent then raise exception 'A reply cannot move to another post' using errcode='22023'; end if;
      if length(btrim(coalesce(p_payload->>'body',''))) not between 1 and 500 then raise exception 'Replies can contain up to 500 characters' using errcode='22023'; end if;
      v_body:=jsonb_build_object('id',v_id,'postID',v_parent,'body',btrim(p_payload->>'body'),'createdAt',coalesce(old_object.body->'createdAt',to_jsonb(v_date))); v_state:='published';
    elsif v_kind='note' then
      if length(coalesce(p_payload->>'title',''))>80 or length(coalesce(p_payload->>'body',''))>10000
        or coalesce(p_payload->>'category','') not in ('Lyrics','Chords','Ideas')
        or (p_payload->>'mood' is not null and p_payload->>'mood' not in ('Hopeful','Reflective','Energetic','Wistful','Calm')) then raise exception 'Invalid notebook entry' using errcode='22023'; end if;
      v_body:=jsonb_build_object('id',v_id,'title',coalesce(p_payload->>'title',''),'body',coalesce(p_payload->>'body',''),'category',p_payload->>'category',
        'mood',p_payload->>'mood','isPinned',coalesce((p_payload->>'isPinned')::boolean,false),'createdAt',coalesce(old_object.body->'createdAt',to_jsonb(v_date)),'updatedAt',v_date);
    elsif v_kind='room' then
      if length(btrim(coalesce(p_payload->>'title',''))) not between 1 and 60 or length(coalesce(p_payload->>'description',''))>240
        or coalesce((p_payload->>'seatCount')::integer,0) not in (4,6,8)
        or coalesce(p_payload->>'topic','') not in ('Music','Everyday','Unwind')
        or (p_payload->>'danceCategory' is not null and p_payload->>'danceCategory' not in ('hipHop','kPop','jazz','freestyle','ballet','house'))
        or (p_payload->>'partyType' is not null and p_payload->>'partyType'<>'Voice party') then raise exception 'Invalid voice room' using errcode='22023'; end if;
      if (select count(*) from toti_private.members m where m.container_id=v_id and m.active)>(p_payload->>'seatCount')::integer then raise exception 'Remove members before reducing capacity' using errcode='22023'; end if;
      v_body:=jsonb_build_object('id',v_id,'title',btrim(p_payload->>'title'),'description',coalesce(p_payload->>'description',''),'topic',p_payload->>'topic',
        'seatCount',(p_payload->>'seatCount')::integer,'danceCategory',coalesce(p_payload->>'danceCategory','freestyle'),'partyType','Voice party','updatedAt',v_date,'rtcAvailable',false); v_state:='published';
    else
      v_parent:=(p_payload->>'target_id')::uuid;
      select * into target from toti_private.objects where id=v_parent and kind=p_payload->>'target_kind';
      if not found or not toti_private.visible(target,v_actor) or target.owner_id=v_actor then raise exception 'This content cannot be reported' using errcode='42501'; end if;
      if length(btrim(coalesce(p_payload->>'reason',''))) not between 1 and 100 or length(coalesce(p_payload->>'details',''))>2000 then raise exception 'Invalid report' using errcode='22023'; end if;
      v_body:=jsonb_build_object('target_id',v_parent,'target_kind',target.kind,'reason',p_payload->>'reason','details',coalesce(p_payload->>'details',''),'status','received','moderator_assigned',false);
    end if;
    insert into toti_private.objects(id,owner_id,kind,parent_id,body,state) values(v_id,v_actor,v_kind,v_parent,v_body,v_state)
      on conflict(id) do update set body=excluded.body,state=excluded.state,version=objects.version+1,updated_at=now() returning version into v_version;
    if v_kind='room' and old_object.id is null then insert into toti_private.members(container_id,account_id,role) values(v_id,v_actor,'owner'); end if;
  elsif p_action in ('post.delete','comment.delete','note.delete','room.delete') then
    v_kind:=split_part(p_action,'.',1);
    update toti_private.objects set deleted_at=now(),updated_at=now(),version=version+1 where id=v_id and kind=v_kind and owner_id=v_actor and deleted_at is null returning version into v_version;
    if not found then raise exception 'This item is unavailable' using errcode='42501'; end if;
    if v_kind='room' then update toti_private.members set active=false where container_id=v_id; end if;
    v_status:='deleted';
  else raise exception 'This operation is unavailable' using errcode='22023';
  end if;
  v_body:=jsonb_build_object('entity_id',v_id,'version',v_version,'status',v_status);
  insert into toti_private.operations(actor_id,operation_id,action,entity_id,payload,result) values(v_actor,p_operation_id,p_action,p_entity_id,p_payload,v_body);
  return v_body;
end; $$;

create function public.toti_read(p_kind text,p_cursor text default null,p_parent_id uuid default null)
returns jsonb language sql stable security invoker set search_path = '' as $$
  select toti_private.read_records(p_kind,p_cursor,p_parent_id);
$$;
create function public.toti_mutate(p_operation_id uuid,p_action text,p_entity_id uuid,p_payload jsonb)
returns jsonb language sql security invoker set search_path = '' as $$
  select toti_private.mutate(p_operation_id,p_action,p_entity_id,p_payload);
$$;
revoke all on function toti_private.actor(boolean),toti_private.blocked(uuid,uuid),toti_private.container_access(uuid,uuid),toti_private.visible(toti_private.objects,uuid),toti_private.read_records(text,text,uuid),toti_private.mutate(uuid,text,uuid,jsonb) from public,anon,authenticated;
grant execute on function toti_private.read_records(text,text,uuid),toti_private.mutate(uuid,text,uuid,jsonb) to authenticated;
revoke all on function public.toti_read(text,text,uuid),public.toti_mutate(uuid,text,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.toti_read(text,text,uuid),public.toti_mutate(uuid,text,uuid,jsonb) to authenticated;

-- Private immutable staging only. No client INSERT/UPDATE policy is installed until
-- an authenticated byte-validation and moderation worker is configured.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('toti-media','toti-media',false,1048576,array['image/jpeg'])
on conflict(id) do nothing;
create policy toti_media_owner_read on storage.objects for select to authenticated using (
  bucket_id='toti-media' and (storage.foldername(name))[1]=(select auth.uid())::text
  and (select toti_private.actor()) is not null
);
-- Storage invokes this helper through its RLS policy; it reveals only the caller's identity.
grant execute on function toti_private.actor(boolean) to authenticated;
