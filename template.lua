--[[
	TRust Menu - executor-ready script template

	The General tab includes neutral preview controls for testing the official UI.
	Add each script's features through the returned Sections and Controls tables.
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
Tabs.Main = Categories.Main:AddTab({Name = "General", Order = 1})
Sections.Main = Tabs.Main:AddSection({Name = "General Controls", Column = 1, Order = 1})
Sections.GeneralControls = Sections.Main

Controls.EnableModule = Sections.GeneralControls:AddToggle({
	Text = "Enable Module",
	Flag = "preview_module_enabled",
	Default = true,
})

Controls.SmoothMovement = Sections.GeneralControls:AddToggle({
	Text = "Smooth Movement",
	Flag = "preview_smooth_movement",
	Default = false,
})

Controls.Power = Sections.GeneralControls:AddSlider({
	Text = "Power",
	Flag = "preview_power",
	Min = 0,
	Max = 100,
	Step = 1,
	Default = 45,
	Suffix = "%",
})

Controls.Range = Sections.GeneralControls:AddSlider({
	Text = "Range",
	Flag = "preview_range",
	Min = 0,
	Max = 300,
	Step = 1,
	Default = 150,
})

Categories.Targeting = Window:AddCategory({
	Name = "Targeting",
	Icon = Library:GetIcon(2),
	Symbol = "T",
	Order = 2,
})
Tabs.Targeting = Categories.Targeting:AddTab({Name = "Targeting", Order = 1})
Sections.Targeting = Tabs.Targeting:AddSection({Name = "Targeting", Column = 1, Order = 1})
Sections.TargetingOptions = Tabs.Targeting:AddSection({Name = "Options", Column = 2, Order = 1})

Categories.Visuals = Window:AddCategory({
	Name = "Visuals",
	Icon = Library:GetIcon(3),
	Symbol = "V",
	Order = 3,
})
Tabs.Visuals = Categories.Visuals:AddTab({Name = "Visuals", Order = 1})
Sections.Visuals = Tabs.Visuals:AddSection({Name = "Visuals", Column = 1, Order = 1})
Sections.VisualOptions = Tabs.Visuals:AddSection({Name = "Options", Column = 2, Order = 1})

Categories.Players = Window:AddCategory({
	Name = "Players",
	Icon = Library:GetIcon(4),
	Symbol = "P",
	Order = 4,
})
Tabs.Players = Categories.Players:AddTab({Name = "Players", Order = 1})
Sections.Players = Tabs.Players:AddSection({Name = "Players", Column = 1, Order = 1})
Sections.PlayerOptions = Tabs.Players:AddSection({Name = "Options", Column = 2, Order = 1})

Categories.Settings = Window:AddCategory({
	Name = "Settings",
	Icon = Library:GetIcon(5),
	Symbol = "S",
	Order = 5,
})
Tabs.Settings = Categories.Settings:AddTab({Name = "Settings", Order = 1})
Sections.Settings = Tabs.Settings:AddSection({Name = "Menu Settings", Column = 1, Order = 1})
Sections.SettingsExtra = Tabs.Settings:AddSection({Name = "Extra", Column = 2, Order = 1})
Sections.MenuSettings = Sections.Settings

-- Backward-compatible aliases now point to the official Settings card.
Sections.MainOptions = Sections.Settings
Sections.ThemePreview = Sections.Settings

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

Controls.MenuColor = Sections.MenuSettings:AddColorPicker({
	Text = "Menu Color",
	Flag = "menu_color",
	Order = 1,
	Default = Color3.fromRGB(7, 132, 255),
	ApplyToTheme = true,
	Continuous = true,
})

-- Force one post-layout refresh for executors that report UIListLayout content
-- size a frame late. The library also measures the rows directly as a fallback.
local function refreshMenuSettings()
	if Controls.MenuOpacity and Controls.MenuOpacity.Row then
		Controls.MenuOpacity.Row.LayoutOrder = 2
		Controls.MenuOpacity.Row.Visible = true
	end
	Sections.MenuSettings:Refresh()
end

refreshMenuSettings()
task.defer(refreshMenuSettings)
task.delay(0.1, refreshMenuSettings)

return {
	Library = Library,
	Window = Window,
	Categories = Categories,
	Tabs = Tabs,
	Sections = Sections,
	Controls = Controls,
}
