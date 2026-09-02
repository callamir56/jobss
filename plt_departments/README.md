# plt_departments — ESX Edition

Department Creator (Pluto Dev) — کانفیگ‌شده برای سرور **ESX**.

## ✅ تنظیمات اعمال‌شده (ESX)

| مورد | وضعیت |
|---|---|
| فریم‌ورک | `Config.Framework = "esx"` (فقط ESX) |
| دسترسی مدیریت | گروپ **`gamemaster`** (و `admin` / `superadmin`) با `setgroup <id> gamemaster` |
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
2. در `server.cfg`:

```cfg
ensure es_extended
ensure oxmysql
ensure ox_lib
ensure ox_target
ensure ox_inventory
ensure plt_departments
```

## 🔐 دسترسی (Permission)

برای دادن دسترسی مدیریت دپارتمان‌ها به یک پلیر، گروپ او را `gamemaster` کنید:

```
/managedepts   → فقط برای گروپ‌های داخل سرور (کنسول) یا از طریق ادمین
add_principal identifier.license:xxxx group.gamemaster   (روش ACE)
```

یا به‌صورت مستقیم در بازی با دستور ای‌اس‌ایکس:

```
/setgroup <id> gamemaster
```

بعد از ست شدن گروپ، پلیر می‌تواند با `/managedepts` منوی ساخت و مدیریت دپارتمان را باز کند.
گروپ‌های مجاز در `shared/config.lua` قابل ویرایش هستند:

```lua
Config.ESXAdminGroups = {
    "gamemaster",
    "admin",
    "superadmin",
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
