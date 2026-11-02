-- Private outgoing Like/Save collections, independent of the first discovery page.
create function toti_private.profile_reactions(p_kind text,p_cursor text)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_actor uuid:=toti_private.actor(); v_cut timestamptz; v_cut_id uuid;
 v_cursor jsonb; v_rows jsonb:='[]'::jsonb; v_next text; v_count integer:=0; item record; document jsonb;
begin
 if p_kind is null or p_kind not in ('like','save') then raise exception 'Choose liked or saved posts' using errcode='22023'; end if;
 if p_cursor is not null then
   if length(p_cursor)>1024 then raise exception 'Invalid collection cursor' using errcode='22023'; end if;
   v_cursor:=convert_from(decode(p_cursor,'base64'),'UTF8')::jsonb;
   if v_cursor->>'kind' is distinct from p_kind or v_cursor->>'actor' is distinct from v_actor::text then
     raise exception 'Cursor belongs to another collection' using errcode='22023';
   end if;
   v_cut:=(v_cursor->>'at')::timestamptz; v_cut_id:=(v_cursor->>'id')::uuid;
   if v_cut is null or v_cut_id is null then raise exception 'Invalid collection cursor' using errcode='22023'; end if;
 end if;
 for item in
   select r.post_id,r.created_at from toti_private.reactions r join toti_private.objects o on o.id=r.post_id
   where r.actor_id=v_actor and r.kind=p_kind and o.kind='post' and o.state='published' and toti_private.visible(o,v_actor)
     and (v_cut is null or (r.created_at,r.post_id)<(v_cut,v_cut_id))
   order by r.created_at desc,r.post_id desc limit 31
 loop
   v_count:=v_count+1;
   if v_count>30 then v_next:=encode(convert_to(v_cursor::text,'UTF8'),'base64'); exit; end if;
   -- Reuse the exact authorized post/media/profile projection, rather than inventing another document format.
   document:=toti_private.read_records('post',null,item.post_id)->'records'->0;
   if document is not null then v_rows:=v_rows||jsonb_build_array(document); end if;
   v_cursor:=jsonb_build_object('kind',p_kind,'actor',v_actor,'at',item.created_at,'id',item.post_id);
 end loop;
 return jsonb_build_object('records',v_rows,'next_cursor',v_next);
end; $$;
revoke all on function toti_private.profile_reactions(text,text) from public,anon,authenticated;
grant execute on function toti_private.profile_reactions(text,text) to authenticated;
create function public.toti_profile_reactions(p_kind text,p_cursor text default null)
returns jsonb language sql stable security invoker set search_path='' as $$
 select toti_private.profile_reactions(p_kind,p_cursor);
$$;
revoke all on function public.toti_profile_reactions(text,text) from public,anon,authenticated;
grant execute on function public.toti_profile_reactions(text,text) to authenticated;
