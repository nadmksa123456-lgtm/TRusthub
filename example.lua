--[[
	TRust Menu - Neutral Example

	يمكن تحديد مسار المشروع قبل تشغيل الملف:
	getgenv().TRUST_MENU_ROOT = "TRust-Menu"
	وإذا لم تحدده، سيحاول المثال اكتشافه تلقائيًا.
]]

local environment = type(getgenv) == "function" and getgenv() or _G
local configuredRoot = environment.TRUST_MENU_ROOT
local projectRoot = configuredRoot

local function joinPath(root, fileName)
	if root == nil or root == "" or root == "." then
		return fileName
	end

	return tostring(root):gsub("[\\/]+$", "") .. "/" .. fileName
end

local function runChunk(chunk, path)
	local ok, result = pcall(chunk)
	if not ok then
		error(("[TRust Menu] Failed to run %s: %s"):format(path, tostring(result)), 3)
	end

	return result
end

local function candidateRoots()
	local roots = {}
	local seen = {}
	local function add(root)
		if root == nil or root == "" then return end
		root = tostring(root)
		if not seen[root] then
			seen[root] = true
			table.insert(roots, root)
		end
	end

	add(projectRoot)
	add(configuredRoot)
	add(".")
	add("TRust-Menu")
	add("outputs/TRust-Menu")
	return roots
end

local function loadProjectFile(fileName)
	local failures = {}

	for _, root in ipairs(candidateRoots()) do
		local path = joinPath(root, fileName)
		if type(loadfile) == "function" then
			local ok, chunk, compileError = pcall(loadfile, path)
			if ok and type(chunk) == "function" then
				projectRoot = root
				return runChunk(chunk, path)
			end

			table.insert(failures, tostring(compileError or chunk))
		end

		if type(readfile) == "function" and type(loadstring) == "function" then
			local readOk, sourceOrError = pcall(readfile, path)
			if readOk then
				local compileOk, chunk, compileError = pcall(loadstring, sourceOrError, "@" .. path)
				if compileOk and type(chunk) == "function" then
					projectRoot = root
					return runChunk(chunk, path)
				end

				table.insert(failures, tostring(compileError or chunk))
			else
				table.insert(failures, tostring(sourceOrError))
			end
		end
	end

	error(("[TRust Menu] Unable to load %s. Set TRUST_MENU_ROOT to the project folder.\n%s")
		:format(fileName, table.concat(failures, "\n")), 2)
end

local Icons = loadProjectFile("icons.lua")
if type(Icons) == "table" and type(Icons.SetRoot) == "function" then
	Icons:SetRoot(projectRoot)
end
local Library = loadProjectFile("source.lua")

assert(type(Icons) == "table", "[TRust Menu] icons.lua did not return its registry")
assert(type(Library) == "table", "[TRust Menu] source.lua did not return the library")

local Window = Library:CreateWindow({
	Name = "TRust Menu",
	Size = Vector2.new(960, 680),
	ToggleKey = Enum.KeyCode.Insert,
	ThemeColor = Color3.fromRGB(7, 132, 255),
	Logo = Icons:Resolve(0),
	LogoFile = Icons:Path(0),
	LogoSize = UDim2.fromOffset(52, 52),
	LogoFallback = "TR",
	ShowBrandName = false,
})

-- Category 1: General (Cube Icon 1.png)
local GeneralCategory = Window:AddCategory({
	Name = "General",
	Icon = Icons:Resolve(1),
	IconFile = Icons:Path(1),
	Symbol = "G",
	Order = 1,
})

-- Category 2: Combat (Scope Icon 2.png)
local CombatCategory = Window:AddCategory({
	Name = "Combat",
	Icon = Icons:Resolve(2),
	IconFile = Icons:Path(2),
	Symbol = "C",
	Order = 2,
})

-- Category 3: Visuals (Eye Icon 3.png)
local VisualsCategory = Window:AddCategory({
	Name = "Visuals",
	Icon = Icons:Resolve(3),
	IconFile = Icons:Path(3),
	Symbol = "V",
	Order = 3,
})

-- Category 4: Players (User Icon 4.png)
local PlayersCategory = Window:AddCategory({
	Name = "Players",
	Icon = Icons:Resolve(4),
	IconFile = Icons:Path(4),
	Symbol = "P",
	Order = 4,
})

-- Category 5: Settings (Gear Icon 5.png)
local SettingsCategory = Window:AddCategory({
	Name = "Settings",
	Icon = Icons:Resolve(5),
	IconFile = Icons:Path(5),
	Symbol = "S",
	Order = 5,
})

---------------------------------------------------------
-- General Category Tabs
---------------------------------------------------------
local GeneralTab = GeneralCategory:AddTab({ Name = "General", Order = 1 })
local SubVisualsTab = GeneralCategory:AddTab({ Name = "Visuals", Order = 2 })
local SubSettingsTab = GeneralCategory:AddTab({ Name = "Settings", Order = 3 })

---------------------------------------------------------
-- General Tab Sections (Exact match to reference image)
---------------------------------------------------------

-- Left Column: General Controls
local Controls = GeneralTab:AddSection({
	Name = "General Controls",
	Column = 1,
	Order = 1,
})

Controls:AddToggle({
	Text = "Enable Module",
	Flag = "enable_module",
	Default = true,
})

Controls:AddToggle({
	Text = "Smooth Movement",
	Flag = "smooth_movement",
	Default = false,
})

Controls:AddSlider({
	Text = "Power",
	Flag = "power",
	Min = 0,
	Max = 100,
	Default = 45,
	Suffix = "%",
})

Controls:AddSlider({
	Text = "Range",
	Flag = "range",
	Min = 0,
	Max = 500,
	Default = 150,
})

-- Right Column: Theme Preview
local ThemePreview = GeneralTab:AddSection({
	Name = "Theme Preview",
	Column = 2,
	Order = 1,
})

ThemePreview:AddColorPicker({
	Text = "Menu Color",
	Flag = "menu_color",
	Default = Color3.fromRGB(7, 132, 255),
	ApplyToTheme = true,
})

ThemePreview:AddCard({
	Title = "Active Accent",
	Value = "TRust",
})

ThemePreview:AddToggle({
	Text = "Interface Enabled",
	Flag = "interface_enabled",
	Default = true,
})

ThemePreview:AddSlider({
	Text = "Menu Opacity",
	Flag = "menu_opacity",
	Min = 0,
	Max = 100,
	Default = 92,
	Suffix = "%",
})

--------------------------------0-------------------------
-- Other Categories & Tabs
---------------------------------------------------------
local SubVisualsSection = SubVisualsTab:AddSection({ Name = "Display Settings", Column = 1 })
SubVisualsSection:AddToggle({ Text = "Show Crosshair", Flag = "show_crosshair", Default = true })
SubVisualsSection:AddToggle({ Text = "Highlight Targets", Flag = "highlight_targets", Default = true })

local SubSettingsSection = SubSettingsTab:AddSection({ Name = "Quick Configuration", Column = 1 })
SubSettingsSection:AddKeybind({ Text = "Toggle Menu Key", Flag = "toggle_key", Default = Enum.KeyCode.Insert })

local AimbotTab = CombatCategory:AddTab({ Name = "Aimbot" })
local AimbotSection = AimbotTab:AddSection({ Name = "Aimbot Configuration", Column = 1 })
AimbotSection:AddToggle({ Text = "Aimbot Enabled", Flag = "aimbot_enabled", Default = false })
AimbotSection:AddSlider({ Text = "FOV Radius", Flag = "fov_radius", Min = 30, Max = 500, Default = 120 })

local EspTab = VisualsCategory:AddTab({ Name = "ESP" })
local EspSection = EspTab:AddSection({ Name = "ESP Settings", Column = 1 })
EspSection:AddToggle({ Text = "Box ESP", Flag = "esp_box", Default = true })
EspSection:AddToggle({ Text = "Tracers", Flag = "esp_tracers", Default = false })

local PlayerTab = PlayersCategory:AddTab({ Name = "Local Player" })
local PlayerSection = PlayerTab:AddSection({ Name = "Movement Options", Column = 1 })
PlayerSection:AddSlider({ Text = "WalkSpeed", Flag = "walkspeed", Min = 16, Max = 250, Default = 16 })
PlayerSection:AddSlider({ Text = "JumpPower", Flag = "jumppower", Min = 50, Max = 300, Default = 50 })

local MenuConfigTab = SettingsCategory:AddTab({ Name = "Menu Config" })
local MenuConfigSection = MenuConfigTab:AddSection({ Name = "Menu Controls", Column = 1 })
MenuConfigSection:AddKeybind({
	Text = "Show / Hide Menu",
	Default = Enum.KeyCode.Insert,
	OnChanged = function(key)
		Window.ToggleKey = key
	end,
})
MenuConfigSection:AddButton({
	Text = "Unload Menu",
	Callback = function()
		Library:Unload()
	end,
})

return {
	Library = Library,
	Icons = Icons,
	Window = Window,
}
