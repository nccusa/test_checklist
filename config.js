/* ==================== 修改區 ====================
   前台 index.html 與後台 admin.html 都會讀這個檔案。
   時段、名額、活動名稱、開放/關閉報名 → 在後台「活動設定」改，不用動這裡。
   ================================================ */
window.APP_CONFIG = {
  SUPABASE_URL: "https://xxxxxxxxxxxxxxxx.supabase.co",   // Supabase → Project Settings → API → Project URL
  SUPABASE_ANON_KEY: "eyJ...",                             // Supabase → Project Settings → API → anon public key
};
