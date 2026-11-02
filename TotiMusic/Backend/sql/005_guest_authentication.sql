-- Guest identities use real Auth sessions and the same ownership boundaries.
create or replace function toti_private.actor(require_active boolean default true)
returns uuid language plpgsql stable security definer set search_path = '' as $$
declare actor_id uuid := auth.uid(); session_id uuid;
begin
  if actor_id is null then raise exception 'Authentication required' using errcode='42501'; end if;
  session_id := nullif(auth.jwt()->>'session_id','')::uuid;
  if session_id is null or not exists (
    select 1 from auth.sessions s join auth.users u on u.id=s.user_id
    where s.id=session_id and s.user_id=actor_id
      and (s.not_after is null or s.not_after > now())
      and (u.is_anonymous is true or u.email_confirmed_at is not null)
  ) then raise exception 'Your session has expired. Sign in again.' using errcode='42501'; end if;
  if require_active and not exists(select 1 from toti_private.accounts a where a.id=actor_id and a.status='active') then
    raise exception 'This account is unavailable.' using errcode='42501';
  end if;
  return actor_id;
end; $$;
