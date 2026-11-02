-- Operator-only cleanup APIs. No auth identity is trusted from a client payload.
create function toti_private.deletion_plan(p_account_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_job toti_private.deletion_jobs; v_paths jsonb;
begin
  if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'Trusted service required' using errcode='42501'; end if;
  select * into v_job from toti_private.deletion_jobs where account_id=p_account_id;
  if not found then return null; end if;
  select coalesce(jsonb_agg(name),'[]'::jsonb) into v_paths from (
    select name from storage.objects where bucket_id='toti-media' and split_part(name,'/',1)=p_account_id::text order by name limit 500
  ) paths;
  return jsonb_build_object('account_id',p_account_id,'status',v_job.status,'paths',v_paths);
end; $$;
create function toti_private.deletion_complete(p_account_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
begin
  if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'Trusted service required' using errcode='42501'; end if;
  perform pg_advisory_xact_lock(731209444211::bigint);
  if not exists(select 1 from toti_private.deletion_jobs where account_id=p_account_id) then raise exception 'Deletion was not requested' using errcode='42501'; end if;
  if exists(select 1 from auth.users where id=p_account_id) or exists(select 1 from storage.objects where bucket_id='toti-media' and split_part(name,'/',1)=p_account_id::text) then
    raise exception 'Cleanup is incomplete' using errcode='22023';
  end if;
  update toti_private.deletion_jobs set status='complete',completed_at=now(),last_error=null where account_id=p_account_id;
  return jsonb_build_object('status','complete');
end; $$;
create function public.toti_deletion_plan(p_account_id uuid)
returns jsonb language sql security invoker set search_path='' as $$ select toti_private.deletion_plan(p_account_id); $$;
create function public.toti_deletion_complete(p_account_id uuid)
returns jsonb language sql security invoker set search_path='' as $$ select toti_private.deletion_complete(p_account_id); $$;
revoke all on function toti_private.deletion_plan(uuid),toti_private.deletion_complete(uuid),public.toti_deletion_plan(uuid),public.toti_deletion_complete(uuid) from public,anon,authenticated;
grant execute on function toti_private.deletion_plan(uuid),toti_private.deletion_complete(uuid),public.toti_deletion_plan(uuid),public.toti_deletion_complete(uuid) to service_role;
