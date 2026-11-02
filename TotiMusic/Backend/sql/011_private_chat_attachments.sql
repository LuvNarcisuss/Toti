-- Immutable private chat attachments. Existing message mutations remain authoritative.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('toti-chat-attachments','toti-chat-attachments',false,10485760,array['image/jpeg','application/octet-stream']);

create function toti_private.chat_storage_access(p_name text,p_write boolean)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare a uuid; c uuid; parts text[];
begin
  a:=toti_private.actor(); parts:=string_to_array(p_name,'/');
  if array_length(parts,1)<>3 or parts[1]!~'^[0-9a-f-]{36}$' or parts[2]!~'^[0-9a-f-]{36}$'
    or parts[3]!~'^[0-9a-f-]{36}\.(jpg|bin)$' then return false; end if;
  c:=parts[2]::uuid;
  if not exists(select 1 from toti_private.objects o where o.id=c and o.kind='conversation'
      and toti_private.visible(o,a)) then return false; end if;
  if p_write then return parts[1]=a::text; end if;
  if exists(select 1 from toti_private.objects m where m.kind='message' and m.parent_id=c
      and m.body->'attachment'->>'path'=p_name and toti_private.visible(m,a)) then return true; end if;
  return parts[1]=a::text and not exists(select 1 from toti_private.objects m
    where m.kind='message' and m.body->'attachment'->>'path'=p_name);
exception when invalid_text_representation then return false;
end; $$;
revoke all on function toti_private.chat_storage_access(text,boolean) from public,anon,authenticated;
grant execute on function toti_private.chat_storage_access(text,boolean) to authenticated;
create policy toti_chat_attachment_insert on storage.objects for insert to authenticated
  with check(bucket_id='toti-chat-attachments' and toti_private.chat_storage_access(name,true));
create policy toti_chat_attachment_read on storage.objects for select to authenticated
  using(bucket_id='toti-chat-attachments' and toti_private.chat_storage_access(name,false));
-- No UPDATE/DELETE client policy: published bytes cannot be replaced or removed.

create function toti_private.send_attachment(p_operation_id uuid,p_message_id uuid,p_conversation_id uuid,
  p_path text,p_filename text,p_kind text,p_text text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare a uuid; meta jsonb; attachment jsonb; receipt jsonb; old_message toti_private.objects; summary text;
begin
  perform pg_advisory_xact_lock(731209444211::bigint);
  a:=toti_private.actor();
  if p_kind not in ('image','file') or p_kind is null or length(btrim(p_filename)) not between 1 and 160
    or p_filename ~ '[[:cntrl:]]' or strpos(p_filename,'/')>0 or strpos(p_filename,chr(92))>0 or length(coalesce(p_text,''))>2000 then
    raise exception 'Invalid attachment' using errcode='22023'; end if;
  if p_path is distinct from a::text||'/'||p_conversation_id::text||'/'||p_message_id::text||
    (case when p_kind='image' then '.jpg' else '.bin' end)
    or not toti_private.chat_storage_access(p_path,true) then
    raise exception 'This conversation is unavailable' using errcode='42501'; end if;
  select metadata into meta from storage.objects where bucket_id='toti-chat-attachments' and name=p_path;
  if not found or coalesce((meta->>'size')::bigint,0) not between 1 and 10485760
    or meta->>'mimetype' is distinct from (case when p_kind='image' then 'image/jpeg' else 'application/octet-stream' end) then
    raise exception 'Upload a valid attachment before sending' using errcode='22023'; end if;
  attachment:=jsonb_build_object('path',p_path,'filename',p_filename,'kind',p_kind,
    'byteCount',(meta->>'size')::bigint,'contentType',meta->>'mimetype');
  select * into old_message from toti_private.objects where id=p_message_id;
  if found and (old_message.owner_id<>a or old_message.parent_id<>p_conversation_id
    or old_message.kind<>'message' or old_message.body->'attachment' is distinct from attachment) then
    raise exception 'This message already has different content' using errcode='22023'; end if;
  summary:=coalesce(nullif(btrim(p_text),''),case when p_kind='image' then 'Photo' else p_filename end);
  receipt:=toti_private.mutate(p_operation_id,'message.send',p_message_id,
    jsonb_build_object('conversation_id',p_conversation_id,'text',summary,'chat_attachment',attachment));
  update toti_private.objects set body=body||jsonb_build_object('attachment',attachment) where id=p_message_id and owner_id=a;
  return receipt;
end; $$;
create function public.toti_send_attachment(p_operation_id uuid,p_message_id uuid,p_conversation_id uuid,
  p_path text,p_filename text,p_kind text,p_text text)
returns jsonb language sql security invoker set search_path='' as $$
  select toti_private.send_attachment(p_operation_id,p_message_id,p_conversation_id,p_path,p_filename,p_kind,p_text);
$$;
revoke all on function toti_private.send_attachment(uuid,uuid,uuid,text,text,text,text),
  public.toti_send_attachment(uuid,uuid,uuid,text,text,text,text) from public,anon,authenticated;
grant execute on function toti_private.send_attachment(uuid,uuid,uuid,text,text,text,text),
  public.toti_send_attachment(uuid,uuid,uuid,text,text,text,text) to authenticated;
create index toti_chat_attachment_path on toti_private.objects((body->'attachment'->>'path')) where kind='message';

-- Extend the existing owner-only account cleanup without deleting any account here.
create or replace function toti_private.deletion_plan(p_account_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare job toti_private.deletion_jobs; paths jsonb; attachments jsonb;
begin
  if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'Trusted service required' using errcode='42501'; end if;
  select * into job from toti_private.deletion_jobs where account_id=p_account_id;
  if not found then return null; end if;
  select coalesce(jsonb_agg(name),'[]'::jsonb) into paths from
    (select name from storage.objects where bucket_id='toti-media' and split_part(name,'/',1)=p_account_id::text order by name limit 500) q;
  select coalesce(jsonb_agg(name),'[]'::jsonb) into attachments from
    (select name from storage.objects where bucket_id='toti-chat-attachments' and split_part(name,'/',1)=p_account_id::text order by name limit 500) q;
  return jsonb_build_object('account_id',p_account_id,'status',job.status,'paths',paths,'attachment_paths',attachments);
end; $$;
create or replace function toti_private.deletion_complete(p_account_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
begin
  if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'Trusted service required' using errcode='42501'; end if;
  perform pg_advisory_xact_lock(731209444211::bigint);
  if not exists(select 1 from toti_private.deletion_jobs where account_id=p_account_id) then raise exception 'Deletion was not requested' using errcode='42501'; end if;
  if exists(select 1 from auth.users where id=p_account_id) or exists(select 1 from storage.objects
      where bucket_id in ('toti-media','toti-chat-attachments') and split_part(name,'/',1)=p_account_id::text) then
    raise exception 'Cleanup is incomplete' using errcode='22023'; end if;
  update toti_private.deletion_jobs set status='complete',completed_at=now(),last_error=null where account_id=p_account_id;
  return jsonb_build_object('status','complete');
end; $$;
