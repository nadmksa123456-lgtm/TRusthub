# TRust Menu

مكتبة واجهة **Luau** رسمية وقابلة لإعادة الاستخدام لكل سكربتاتك. تحافظ على هوية TRust Menu: تصميم navy داكن، شعار النسر أعلى اليسار، اسم باللونين الأزرق والأبيض، أقسام جانبية، تبويبات علوية، وبطاقات مرتبة في عمودين.

## المميزات

- Toggle متحرك مع إلغاء تلقائي للحركة السابقة عند النقر السريع.
- Slider بمنطقة سحب مريحة، تعبئة كاملة بلون الثيم، وحركة ناعمة عند الإفلات والتغيير البرمجي.
- ColorPicker بنظام HSV وحقل Hex لتغيير هوية المنيو كلها لحظيًا.
- Dropdown وTextbox وButton وLabel وKeybind.
- بحث، فئات، تبويبات، عمودان يتحولان تلقائيًا إلى عمود واحد في المقاسات الصغيرة.
- API موحّد للـFlags وتغيير القيم برمجيًا.

## الملفات

- `source.lua`: المكتبة فقط، ويُرجع كائن `Library` دون تشغيل مثال تلقائي.
- `example.lua`: محاكي مستقل ومحايد يعرض كل العناصر الجاهزة.
- `icons.lua`: سجل الشعار والأيقونات الرقمية.
- `assets/`: صور PNG بيضاء وشفافة قابلة للتلوين عبر `ImageColor3`.

## تشغيل المثال

يكتشف `example.lua` مكان المشروع تلقائيًا من المسارات `.`, و`TRust-Menu`, و`outputs/TRust-Menu`. ويمكنك تحديده يدويًا قبل التشغيل:

```lua
getgenv().TRUST_MENU_ROOT = "TRust-Menu" -- أو "." من داخل المشروع
local Demo = loadfile("TRust-Menu/example.lua")()
```

إذا كانت بيئتك توفر `readfile` و`loadstring` بدل `loadfile`، فالمحمّل الموجود داخل `example.lua` يدعمهما تلقائيًا.

## استخدام المكتبة في سكربتك

```lua
local Library = loadfile("source.lua")()
local Icons = loadfile("icons.lua")()
Icons:SetRoot(".")

local Window = Library:CreateWindow({
    Name = "TRust Menu",
    ThemeColor = Color3.fromRGB(0, 132, 255),
    Logo = Icons:AssetId(0),
    LogoFile = Icons:Path(0),
    ToggleKey = Enum.KeyCode.Insert,
})

local Main = Window:AddCategory({
    Name = "Main",
    Icon = Icons:AssetId(1),
    IconFile = Icons:Path(1),
})

local Tab = Main:AddTab({Name = "General"})
local Section = Tab:AddSection({Name = "Settings", Column = 1})

Section:AddToggle({Text = "Enabled", Flag = "enabled", Default = true})
Section:AddSlider({Text = "Value", Flag = "value", Min = 0, Max = 100, Default = 50})
Section:AddColorPicker({
    Text = "Menu Color",
    Flag = "menu_color",
    Default = Color3.fromRGB(0, 132, 255),
    ApplyToTheme = true,
})
```

داخل Roblox Studio يمكنك وضع الملفين كـModuleScript واستخدام `require` بدل تحميل ملفات النظام.

## سجل الأيقونات

| الرقم | الاستخدام |
|---:|---|
| 0 | Eagle Logo |
| 1 | Cube |
| 2 | Scope |
| 3 | View |
| 4 | User |
| 5 | Settings |
| 6 | Pick |

```lua
Icons:SetRoot("TRust-Menu")

local icon = Icons:Get(1)
print(icon.File)          -- assets/1.png
print(Icons:Path(1))      -- TRust-Menu/assets/1.png
print(Icons:AssetId(1))   -- nil قبل وضع AssetId صحيح
print(Icons:Resolve(1))   -- AssetId أو local asset، وإلا nil
```

## رفع الصور إلى Roblox

1. ارفع كل صورة من `assets` إلى Roblox Creator Dashboard.
2. انسخ رقم الأصل المنشور.
3. استبدل `rbxassetid://0` للصورة داخل `icons.lua`، مثل:

```lua
[1] = {
    Id = 1,
    Name = "Cube",
    File = "assets/1.png",
    AssetId = "rbxassetid://1234567890",
}
```

داخل Roblox استخدم `AssetId`. الملفات المحلية تعمل فقط في البيئات التي توفر `getcustomasset` أو `getsynasset`؛ وإذا توفر `isfile` فسيُستخدم للتحقق من المسار بأمان.

عند إضافة أيقونة جديدة، ضعها باسم رقمي داخل `assets` ثم أضف سجلها إلى `icons.lua`. لا تغيّر أسماء الأيقونات الحالية حتى تبقى جميع سكربتاتك متوافقة مع نفس الهوية.
