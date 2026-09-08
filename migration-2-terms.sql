-- 讓「活動須知與免責聲明」可以在後台活動設定直接修改
-- 在 SQL Editor 貼上執行一次

alter table public.event_settings add column if not exists terms text not null default '';

-- 把 config.js 裡原本那幾條放進去當初始值（之後在後台改）
update public.event_settings set terms = E'參加活動須全程穿著襪子，未穿襪者工作人員有權不允許進場。
請在預約時段開始前 5 分鐘抵達報到，遲到者名額不予保留，將釋出給現場名額。
報到時請出示預約完成畫面截圖及身分證明文件（身分證、健保卡等；校內學生請出示學生證）。
每場次 25 分鐘，時間到請配合工作人員指示離場，以利下一場次進行。
活動期間請遵守工作人員指示，禁止推擠、跳躍衝撞、攜帶尖銳物品或食物飲料進入氣墊區。
身體不適、孕婦、受傷或有心血管疾病者，請自行評估是否參加。
參加者於活動中因個人行為或未遵守規範造成之受傷或財物損失，主辦單位不負賠償責任。
主辦單位保留調整活動內容、時段及終止活動之權利。
填寫本表單即表示同意主辦單位蒐集姓名、電話、學號等資料，僅作為本次活動報到與聯絡使用，活動結束後刪除。'
where id = 1 and terms = '';

create or replace function public.get_public_state()
returns json language sql security definer set search_path = public as $$
  select json_build_object(
    'settings', (select row_to_json(s) from (
       select event_name, days, slots, capacity, is_open, notice, terms
       from public.event_settings where id = 1) s),
    'counts', (select coalesce(json_object_agg(k, c), '{}'::json) from (
       select day || '|' || slot as k, count(*) c from public.bookings group by day, slot) t)
  );
$$;
