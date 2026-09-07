-- ============================================================
-- 氣墊樂園 預約系統 — Supabase 資料庫設定
-- 在 Supabase Dashboard → SQL Editor 貼上整份執行一次即可
-- （若之前跑過舊版，這份會先清掉舊表重建）
-- ============================================================
drop table if exists public.bookings;
drop table if exists public.event_settings;

-- 1. 活動設定（只有一列，id 固定為 1；後台可直接修改）
create table public.event_settings (
  id          int primary key default 1 check (id = 1),
  event_name  text not null default '氣墊樂園',
  days        text[] not null,      -- 活動日期
  slots       text[] not null,      -- 每天相同的時段
  capacity    int  not null default 65,
  is_open     boolean not null default true,
  notice      text not null default ''
);

insert into public.event_settings (id, days, slots) values (1,
  array['9/21','9/22','9/23'],
  array['12:00-12:25','12:30-12:55','13:00-13:25','13:30-13:55',
        '14:00-14:25','14:30-14:55','15:00-15:25','15:30-15:55',
        '16:00-16:25','16:30-16:55','17:00-17:25','17:30-17:55',
        '18:00-18:25','18:30-18:55','19:00-19:25','19:30-19:55']);

-- 2. 預約資料
create table public.bookings (
  id            uuid primary key default gen_random_uuid(),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  identity      text not null check (identity in ('student','staff','external')),
  name          text not null,
  phone         text not null,            -- 所有人都要填
  student_id    text not null default '', -- 學生填
  staff_id      text not null default '', -- 教職員填
  day           text not null,
  slot          text not null,
  status        text not null default 'booked'
                check (status in ('booked','arrived','late','absent')),
  note          text not null default '',
  checked_in_at timestamptz
);

-- 同一支電話每天最多一筆預約（三天可各約一場）
create unique index bookings_phone_day_key on public.bookings (regexp_replace(phone, '\D', '', 'g'), day);
create index bookings_day_slot_idx on public.bookings (day, slot);

-- 3. 權限：匿名者不能直接讀寫；登入的後台管理員可完全存取
alter table public.event_settings enable row level security;
alter table public.bookings enable row level security;
create policy "admin_settings" on public.event_settings for all to authenticated using (true) with check (true);
create policy "admin_bookings" on public.bookings for all to authenticated using (true) with check (true);

-- 4. 公開函式（前台用）：只回傳設定與各時段人數，不含個資
create or replace function public.get_public_state()
returns json language sql security definer set search_path = public as $$
  select json_build_object(
    'settings', (select row_to_json(s) from (
       select event_name, days, slots, capacity, is_open, notice
       from public.event_settings where id = 1) s),
    'counts', (select coalesce(json_object_agg(k, c), '{}'::json) from (
       select day || '|' || slot as k, count(*) c from public.bookings group by day, slot) t)
  );
$$;

-- 5. 預約（含名額檢查，同時段併發安全）
create or replace function public.book_slot(
  p_identity text, p_name text, p_phone text, p_student_id text, p_staff_id text,
  p_day text, p_slot text)
returns json language plpgsql security definer set search_path = public as $$
declare
  s public.event_settings; n int; b public.bookings; existing public.bookings;
  ph text := regexp_replace(coalesce(p_phone,''), '\D', '', 'g');
begin
  select * into s from public.event_settings where id = 1;
  if not s.is_open then return json_build_object('ok', false, 'error', 'closed'); end if;
  if p_identity not in ('student','staff','external') then return json_build_object('ok', false, 'error', 'bad_identity'); end if;
  if coalesce(length(trim(p_name)),0) = 0 then return json_build_object('ok', false, 'error', 'missing'); end if;
  if ph !~ '^09\d{8}$' then return json_build_object('ok', false, 'error', 'bad_phone'); end if;
  if p_identity = 'student' and coalesce(length(trim(p_student_id)),0) = 0 then return json_build_object('ok', false, 'error', 'missing_student_id'); end if;
  if p_identity = 'staff' and coalesce(length(trim(p_staff_id)),0) = 0 then return json_build_object('ok', false, 'error', 'missing_staff_id'); end if;
  if not (p_day = any(s.days)) or not (p_slot = any(s.slots)) then return json_build_object('ok', false, 'error', 'bad_slot'); end if;

  select * into existing from public.bookings where regexp_replace(phone, '\D', '', 'g') = ph and day = p_day limit 1;
  if found then
    return json_build_object('ok', false, 'error', 'duplicate',
      'booking', json_build_object('name', existing.name, 'day', existing.day, 'slot', existing.slot));
  end if;

  perform pg_advisory_xact_lock(hashtext(p_day || '|' || p_slot));
  select count(*) into n from public.bookings where day = p_day and slot = p_slot;
  if n >= s.capacity then return json_build_object('ok', false, 'error', 'full'); end if;

  insert into public.bookings (identity, name, phone, student_id, staff_id, day, slot)
    values (p_identity, trim(p_name), ph,
            case when p_identity='student' then trim(p_student_id) else '' end,
            case when p_identity='staff'   then trim(p_staff_id)   else '' end,
            p_day, p_slot)
    returning * into b;
  return json_build_object('ok', true, 'booking', json_build_object(
    'id', b.id, 'name', b.name, 'phone', b.phone, 'day', b.day, 'slot', b.slot, 'identity', b.identity));
end $$;

-- 6. 查詢自己的預約（姓名 + 電話 都相符），可能有多天 → 回傳陣列
create or replace function public.lookup_booking(p_name text, p_phone text)
returns json language sql security definer set search_path = public as $$
  select coalesce(json_agg(json_build_object(
      'name', name, 'day', day, 'slot', slot, 'identity', identity, 'status', status) order by day, slot), '[]'::json)
    from public.bookings
    where regexp_replace(phone, '\D', '', 'g') = regexp_replace(coalesce(p_phone,''), '\D', '', 'g')
      and trim(name) = trim(p_name);
$$;

-- 7. 取消某一天的預約（尚未報到、且報名仍開放時），名額立即釋出
create or replace function public.cancel_booking(p_name text, p_phone text, p_day text)
returns json language plpgsql security definer set search_path = public as $$
declare s public.event_settings; d int;
begin
  select * into s from public.event_settings where id = 1;
  if not s.is_open then return json_build_object('ok', false, 'error', 'closed'); end if;
  delete from public.bookings
    where regexp_replace(phone, '\D', '', 'g') = regexp_replace(coalesce(p_phone,''), '\D', '', 'g')
      and trim(name) = trim(p_name) and day = p_day and status = 'booked';
  get diagnostics d = row_count;
  return json_build_object('ok', d > 0);
end $$;

grant execute on function public.get_public_state() to anon, authenticated;
grant execute on function public.book_slot(text,text,text,text,text,text,text) to anon, authenticated;
grant execute on function public.lookup_booking(text,text) to anon, authenticated;
grant execute on function public.cancel_booking(text,text,text) to anon, authenticated;

-- 8. 後台即時更新
alter publication supabase_realtime add table public.bookings;
