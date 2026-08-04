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
Sections.MainOptions = Tabs.Main:AddSection({Name = "Theme Preview", Column = 2, Order = 1})
Sections.GeneralControls = Sections.Main
Sections.ThemePreview = Sections.MainOptions

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

-- Typography-only preview. This field does not call any game or money logic.
Controls.AddMoneyPreview = Sections.GeneralControls:AddTextbox({
	Text = "Add Money",
	Flag = "preview_add_money_text",
	Placeholder = "Enter amount...",
	Default = "10000",
})

Controls.MenuOpacity = Sections.ThemePreview:AddSlider({
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

Controls.MenuColor = Sections.ThemePreview:AddColorPicker({
	Text = "Menu Color",
	Flag = "menu_color",
	Order = 1,
	Default = Color3.fromRGB(7, 132, 255),
	ApplyToTheme = true,
	Continuous = true,
})

-- Force one post-layout refresh for executors that report UIListLayout content
-- size a frame late. The library also measures the rows directly as a fallback.
local function refreshThemePreview()
	if Controls.MenuOpacity and Controls.MenuOpacity.Row then
		Controls.MenuOpacity.Row.LayoutOrder = 2
		Controls.MenuOpacity.Row.Visible = true
	end
	Sections.ThemePreview:Refresh()
end

refreshThemePreview()
task.defer(refreshThemePreview)
task.delay(0.1, refreshThemePreview)

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

-- Keep the Theme Preview card in Main, but move its populated controls into
-- Menu Settings. Building them on the visible initial tab first avoids hidden
-- page layout issues in some executors.
local function moveControlToSection(control, targetSection, layoutOrder)
	local sourceSection = control.Section
	if sourceSection == targetSection then return end

	local searchItem = control.SearchItem
	if searchItem then
		local sourceIndex = table.find(sourceSection.Items, searchItem)
		if sourceIndex then
			table.remove(sourceSection.Items, sourceIndex)
		end
		table.insert(targetSection.Items, searchItem)
	end

	control.Row.Parent = targetSection.Content
	control.Row.LayoutOrder = layoutOrder
	control.Section = targetSection

	sourceSection:Refresh()
	targetSection:Refresh()
end

moveControlToSection(Controls.MenuColor, Sections.MenuSettings, 1)
moveControlToSection(Controls.MenuOpacity, Sections.MenuSettings, 2)

local function refreshThemeCards()
	Controls.MenuColor.Row.Visible = true
	Controls.MenuOpacity.Row.Visible = true
	Sections.ThemePreview:Refresh()
	Sections.MenuSettings:Refresh()
	Tabs.Main:RefreshCanvas()
	Tabs.Settings:RefreshCanvas()
end

refreshThemeCards()
task.defer(refreshThemeCards)
task.delay(0.1, refreshThemeCards)

return {
	Library = Library,
	Window = Window,
	Categories = Categories,
	Tabs = Tabs,
	Sections = Sections,
	Controls = Controls,
}
