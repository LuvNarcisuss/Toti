-- Ordered deployment source; the remote migration version is recorded separately.
-- Extend the existing private projection without changing media-review or relationship gates.
create or replace function toti_private.profile_document(p_account uuid,p_viewer uuid)
returns jsonb language sql stable security definer set search_path='' as $$
  select (o.body-'avatar_pending_media_revision_id') || jsonb_build_object(
    'id',o.id,'avatar_media_revision_id',approved.id,'hasCustomAvatar',approved.id is not null,
    'my_following',exists(select 1 from toti_private.relationships r where r.actor_id=p_viewer and r.target_id=p_account and r.kind='follow'),
    'follows_me',exists(select 1 from toti_private.relationships r where r.actor_id=p_account and r.target_id=p_viewer and r.kind='follow'),
    'follower_count',(select count(*) from toti_private.relationships r where r.target_id=p_account and r.kind='follow'),
    'following_count',(select count(*) from toti_private.relationships r where r.actor_id=p_account and r.kind='follow'),
    'post_count',(select count(*) from toti_private.objects p where p.owner_id=p_account and p.kind='post' and p.state='published' and p.deleted_at is null),
    'like_count',(select count(*) from toti_private.reactions r join toti_private.objects p on p.id=r.post_id where p.owner_id=p_account and p.kind='post' and p.state='published' and p.deleted_at is null and r.kind='like'),
    'save_count',(select count(*) from toti_private.reactions r join toti_private.objects p on p.id=r.post_id where p.owner_id=p_account and p.kind='post' and p.state='published' and p.deleted_at is null and r.kind='save'))
    || case when p_viewer=p_account then jsonb_build_object(
      'avatar_pending_media_revision_id',pending.id,'avatar_media_status',coalesce(pending.state,approved.state),
      'avatar_media_feedback',coalesce(pending.owner_feedback,approved.owner_feedback),
      'media_review_status',coalesce(pending.state,approved.state),'media_review_reason',coalesce(pending.owner_feedback,approved.owner_feedback)) else '{}'::jsonb end
  from toti_private.objects o join toti_private.accounts a on a.id=o.owner_id
  left join toti_private.media_revisions approved on approved.id=(o.body->>'avatar_media_revision_id')::uuid and approved.state='approved' and approved.upload_state='ready' and approved.kind='avatar' and approved.owner_id=o.owner_id and approved.entity_id=o.id
  left join toti_private.media_revisions pending on pending.id=(o.body->>'avatar_pending_media_revision_id')::uuid and pending.upload_state='ready' and pending.kind='avatar' and pending.owner_id=o.owner_id and pending.entity_id=o.id
  where o.id=p_account and o.kind='profile' and o.deleted_at is null and a.status='active' and not toti_private.blocked(p_viewer,p_account);
$$;
revoke all on function toti_private.profile_document(uuid,uuid) from public,anon,authenticated;
