--[[
	TRust Menu - clean executor script template

	This file creates only the menu structure. Add each script's features to the
	ready sections at the bottom of the file or through the returned Sections table.
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

Categories.Main = Window:AddCategory({
	Name = "Main",
	Icon = Library:GetIcon(1),
	Symbol = "M",
	Order = 1,
})
Tabs.Main = Categories.Main:AddTab({Name = "General", Order = 1})
Sections.Main = Tabs.Main:AddSection({Name = "Main", Column = 1, Order = 1})
Sections.MainOptions = Tabs.Main:AddSection({Name = "Options", Column = 2, Order = 1})

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

return {
	Library = Library,
	Window = Window,
	Categories = Categories,
	Tabs = Tabs,
	Sections = Sections,
}
