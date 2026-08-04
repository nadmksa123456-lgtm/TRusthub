--[[
	TRust Menu - executor-ready script template

	The feature categories intentionally start empty. Add each script's tabs,
	sections, and controls through the returned API tables.
]]

local DEFAULT_RAW_BASE = "https://raw.githubusercontent.com/nadmksa123456-lgtm/TRusthub/refs/heads/main"
local environment = type(getgenv) == "function" and getgenv() or _G
local rawBase = tostring(environment.TRUST_MENU_BASE_URL or DEFAULT_RAW_BASE):gsub("/+$", "")

environment.TRUST_MENU_BASE_URL = rawBase

local compiler = environment.loadstring or loadstring
assert(type(compiler) == "function", "[TRust Menu] loadstring is unavailable in this executor")

local loaderSource = game:HttpGet(rawBase .. "/loader.lua")
local Library = compiler(loaderSource, "@TRust-Menu/loader.lua")()

local Window = Library:CreateWindow({
	Name = "TRust Menu",
	Size = Vector2.new(1000, 620),
	ThemeColor = Color3.fromRGB(7, 132, 255),
	ToggleKey = Enum.KeyCode.Insert,
	ShowBrandName = false,
})

local Categories = {}
local Tabs = {}
local Sections = {}
local Controls = {}

Categories.Main = Window:AddCategory({
	Name = "Main",
	Icon = Library:GetIcon(1),
	Symbol = "M",
	Order = 1,
})

Categories.Targeting = Window:AddCategory({
	Name = "Targeting",
	Icon = Library:GetIcon(2),
	Symbol = "T",
	Order = 2,
})

Categories.Visuals = Window:AddCategory({
	Name = "Visuals",
	Icon = Library:GetIcon(3),
	Symbol = "V",
	Order = 3,
})

Categories.Players = Window:AddCategory({
	Name = "Players",
	Icon = Library:GetIcon(4),
	Symbol = "P",
	Order = 4,
})

Categories.Settings = Window:AddCategory({
	Name = "Settings",
	Icon = Library:GetIcon(5),
	Symbol = "S",
	Order = 5,
})

-- Build the permanent settings while its page is visible. This keeps layout
-- measurements reliable in executors, then Main is restored as the start page.
Categories.Settings:Select()
Tabs.Settings = Categories.Settings:AddTab({Name = "Settings", Order = 1})
Sections.MenuSettings = Tabs.Settings:AddSection({Name = "Menu Settings", Column = 1, Order = 1})
Sections.Settings = Sections.MenuSettings

Controls.MenuColor = Sections.MenuSettings:AddColorPicker({
	Text = "Menu Color",
	Flag = "menu_color",
	Order = 1,
	Default = Color3.fromRGB(7, 132, 255),
	ApplyToTheme = true,
	Continuous = true,
})

Controls.MenuOpacity = Sections.MenuSettings:AddSlider({
	Text = "Menu Opacity",
	Flag = "menu_opacity",
	Order = 2,
	Min = 20,
	Max = 100,
	Step = 1,
	Default = 100,
	Suffix = "%",
	Callback = function(value)
		Window:SetOpacity(value, true)
	end,
})

local function refreshMenuSettings()
	Controls.MenuColor.Row.Visible = true
	Controls.MenuOpacity.Row.Visible = true
	Sections.MenuSettings:Refresh()
	Tabs.Settings:RefreshCanvas()
end

refreshMenuSettings()
task.defer(refreshMenuSettings)
task.delay(0.1, refreshMenuSettings)

-- Start on the empty Main category, ready for the consuming script to add UI.
Categories.Main:Select()

return {
	Library = Library,
	Window = Window,
	Categories = Categories,
	Tabs = Tabs,
	Sections = Sections,
	Controls = Controls,
}
