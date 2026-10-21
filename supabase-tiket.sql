-- Jalankan sekali di Supabase > SQL Editor (setelah supabase-setup.sql)
create table tickets(token text primary key,event text not null,pts int not null,owner_uid text,nim text,status text not null default 'aktif',created_at timestamptz default now(),scanned_at timestamptz);
alter table tickets enable row level security;
create policy "admin tickets" on tickets for all to authenticated using(true) with check(true);

create function beli_tiket2(p_token text,p_event text,p_pts int,p_uid text,p_nim text) returns void language sql security definer as $$
 insert into tickets(token,event,pts,owner_uid,nim) values(p_token,p_event,p_pts,p_uid,p_nim) $$;
create function tiket_saya2(p_uid text) returns setof tickets language sql security definer as $$
 select * from tickets where owner_uid=p_uid order by created_at desc $$;

-- Scan: hanya panitia (login). Scan pertama berhasil dan poin langsung masuk, scan berikutnya ditolak.
create function scan_tiket(p_token text) returns jsonb language plpgsql security definer as $$
declare t tickets;
begin
 if auth.uid() is null then return jsonb_build_object('ok',false,'msg','Hanya panitia yang boleh scan.'); end if;
 update tickets set status='masuk',scanned_at=now() where token=p_token and status='aktif' returning * into t;
 if found then
  insert into claims(code,event,pts,uid,nim,status,decided_at) values(t.token,t.event,t.pts,t.owner_uid,t.nim,'Disetujui',now());
  return jsonb_build_object('ok',true,'msg','Tiket valid. Silakan masuk.','nim',t.nim,'event',t.event);
 end if;
 select * into t from tickets where token=p_token;
 if not found then return jsonb_build_object('ok',false,'msg','Tiket tidak dikenal.'); end if;
 return jsonb_build_object('ok',false,'msg','GAGAL: tiket sudah dipakai ('||to_char(t.scanned_at at time zone 'Asia/Makassar','DD Mon HH24:MI')||' WITA)','nim',t.nim,'event',t.event);
end $$;

revoke execute on function scan_tiket(text) from public, anon;
grant execute on function beli_tiket2(text,text,int,text,text),tiket_saya2(text) to anon,authenticated;
grant execute on function scan_tiket(text) to authenticated;
