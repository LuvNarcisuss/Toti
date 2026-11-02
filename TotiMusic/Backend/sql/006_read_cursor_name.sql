-- Keep cursor parsing distinct from the comment row alias in authorized reads.
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
      when o.kind='post' then o.body || jsonb_build_object(
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

