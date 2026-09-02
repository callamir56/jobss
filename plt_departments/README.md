# plt_departments — ESX Edition

Department Creator (Pluto Dev) — کانفیگ‌شده برای سرور **ESX**.

## ✅ تنظیمات اعمال‌شده (ESX)

| مورد | وضعیت |
|---|---|
| فریم‌ورک | `Config.Framework = "esx"` (فقط ESX) |
| دسترسی مدیریت | **فقط گروپ `gamemaster`** با `setgroup <id> gamemaster` |
| دیتابیس | فایل `plt_departments.sql` — همه جدول‌ها آماده ایمپورت |
| کامندها | بدون تغییر — مثل قبل: `/managedepts`, `/mydept`, `/duty`, `/cuff`, `/searchperson` و … |
| نوتیفیکیشن‌ها | همه با **`ESX.ShowNotification`** (`Config.NotificationSystem = "esx"`) |

## 📦 پیش‌نیازها

- `es_extended`
- `oxmysql`
- `ox_lib`
- `ox_target`
- `ox_inventory` (`Config.Inventory = "ox"`)

## 🚀 نصب

1. پوشه `plt_departments` را در `resources` سرور کپی کنید.
2. فایل **`plt_departments.sql`** را داخل دیتابیس ایمپورت کنید (HeidiSQL یا phpMyAdmin).
   شامل ۱۴ جدول: دیتا، اعضا، وارنت، BOLO، پرونده‌ها، لاگ دیوتی، تراکنش‌ها، خودروهای ضبط‌شده، رادارها، دوربین‌ها، ردیاب‌ها، ارتباطات + جدول‌های سینک MDT.
   (اسکریپت جدول‌ها را موقع استارت هم خودش می‌سازد، پس ایمپورت اختیاری ولی پیشنهادی است.)
3. در `server.cfg`:

```cfg
ensure es_extended
ensure oxmysql
ensure ox_lib
ensure ox_target
ensure ox_inventory
ensure plt_departments
```

## 🔐 دسترسی (Permission)

**فقط گروپ `gamemaster` به منوی مدیریت دسترسی دارد** — هیچ گروپ دیگری (حتی admin) دسترسی ندارد.

در بازی با دستور:

```
/setgroup <id> gamemaster
```

بعد از ست شدن گروپ، پلیر می‌تواند با `/managedepts` منوی ساخت و مدیریت دپارتمان را باز کند.
لیست گروپ‌های مجاز در `shared/config.lua`:

```lua
Config.ESXAdminGroups = {
    "gamemaster",
}
```

## 🔔 نوتیفیکیشن

تمام نوتیفیکیشن‌های اسکریپت از `ESX.ShowNotification` استفاده می‌کنند.
در `shared/config.lua`:

```lua
Config.NotificationSystem = "esx"   -- گزینه‌ها: "esx" | "ox_lib" | "nui"
```

## ⌨️ کامندها

| کامند | کاربرد |
|---|---|
| `/managedepts` | منوی مدیریت/ساخت دپارتمان (گروپ `gamemaster`) |
| `/mydept` | نمایش دپارتمان فعلی پلیر |
| `/duty` | رفتن/آمدن از دیوتی |
| `/officermenu` | منوی افسر |
| `/cuff` ، `/searchperson` ، `/escort` ، `/putinvehicle` ، `/outofvehicle` ، `/plate` ، `/seize` | دستورات پلیسی |
| `/alpr` ، `/alprsize` | سیستم پلاک‌خوان |
| `/dispatch` | دیسپچ |
| `/911` | تماس 911 |
| `/k9menu` | منوی سگ پلیس |
| `/animposes` | پوز/انیمیشن |
