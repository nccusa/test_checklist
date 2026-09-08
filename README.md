# 氣墊樂園 預約系統

前台報名 + 現場報到後台。前端放 GitHub Pages，資料存 Supabase（免費方案就夠）。

```
key-visual.jpg        前台用的主視覺圖
manifest.json, sw.js, icon-*.png   PWA（可加到手機主畫面當 App 用）
index.html            前台：選身分 → 姓名 + 手機（學生另填學號、教職員另填編號）→ 選日期與時段 → 預約完成；可查詢/取消
admin.html            後台：登入 → 各時段名單、現場報到（到場/遲到/缺席）、編輯/替換/刪除、手動補登、匯出 CSV、活動設定
config.js             修改區：Supabase 連線、GA 量測 ID、各身分票價、現場名額數（活動須知改在後台設定）
supabase/schema.sql   資料庫、權限、預約函式（一次貼進 Supabase 執行）
```

## 架設步驟（約 15 分鐘）

### 1. 建 Supabase 專案
1. https://supabase.com → New project（Region 選 Singapore 或 Tokyo）。
2. 左側 **SQL Editor** → New query → 把 `supabase/schema.sql` 整份貼上 → Run。
3. 左側 **Project Settings → API**，複製 `Project URL` 和 `anon public` key，填進 `config.js`。

### 2. 建後台管理員帳號
1. 左側 **Authentication → Users → Add user**，填 email 與密碼（可建多個，給各組工作人員）。
2. **Authentication → Providers → Email**：把 **Allow new users to sign up** 關掉，避免外人自己註冊變管理員。
3. 若不想寄驗證信：同頁把 **Confirm email** 關掉。

### 3. 放上 GitHub Pages
1. 在 GitHub 開一個 repo，把 index.html、admin.html、config.js、key-visual.jpg、README.md 推上去。
2. Settings → Pages → Source 選 `main` branch → Save。
3. 網址會是 `https://nccusa.github.io/qidian-booking/`（前台）與 `.../admin.html`（後台）。

> anon key 放在前端是 Supabase 的正常用法。沒登入的人只能呼叫 `book_slot`（預約）、`lookup_booking`、`cancel_booking` 和 `get_public_state`（只回傳各時段人數），讀不到任何個資。名單只有登入的管理員看得到（Row Level Security）。

## 規則一覽（都在 schema.sql 裡，可改）
- 三天（9/21、9/22、9/23）每天 16 場（12:00–19:55，每 30 分鐘一場、每場 25 分鐘），每場上限 **65 人**，由資料庫端鎖定檢查，多人同時搶最後一個名額不會超收。
- 所有人都要填手機（09 開頭 10 碼，需輸入兩次確認一致）；學生另填學號、教職員另填教職員編號、校外人士只填手機。
- 同一支手機 **每天最多預約一場**（三天可各約一場）。想換時段要先取消當天的預約再重約。
- 前台每個日期／時段都顯示剩餘名額，一群人一起來可先確認夠不夠。
- 使用者可自行取消（需姓名+手機相符、尚未報到、報名仍開放），查詢時會列出自己每天的預約，可分別取消；取消後名額立即釋出。預約完成畫面與查詢區都會提醒「不能來請先取消」。
- 要改日期、時段、名額、開關報名、前台公告 → 後台「活動設定」，不用改程式。

## 現場報到怎麼用
1. 開 `admin.html` 登入（手機可以）。
2. 最上面黃色搜尋框輸入手機／學號／教職員編號／姓名 → 出現的人按 **到場** 或 **遲到**（按 Enter 會直接對第一筆按「到場」）。
3. 先選日期分頁（今天會標「今天」），再看時段分頁，會標出「目前時段 ◀」，可看該場誰還沒到；每個人可直接切換 未到／到場／遲到／缺席。
4. **編輯** 可改姓名、換時段、寫備註（例如「改由 ○○○ 代替」）、或刪除釋出名額。
5. 沒預約的人現場來 → **手動新增**（超過 65 人會提醒，可強制加入）。
6. 多台裝置同時操作會即時同步；結束後 **匯出 CSV** 存檔。

## 常見調整
- 換活動名稱／日期／時段／名額：後台「活動設定」，不用改程式。
- 已有人預約的日期或時段請不要改名（預約資料是用文字對應）。
- 想把 admin.html 網址藏起來：改檔名即可，例如 `admin-2026.html`。
