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
	Size = Vector2.new(1000, 620),
	ToggleKey = Enum.KeyCode.Insert,
	ThemeColor = Color3.fromRGB(7, 132, 255),
	Logo = Icons:AssetId(0),
	LogoFile = Icons:Path(0),
	LogoSize = UDim2.fromOffset(54, 54),
	LogoFallback = "",
	ShowBrandName = false,
})

local WorkspaceCategory = Window:AddCategory({
	Name = "Workspace",
	Icon = Icons:AssetId(1),
	IconFile = Icons:Path(1),
	Symbol = "W",
	Order = 1,
})

local GeneralTab = WorkspaceCategory:AddTab({
	Name = "General",
	Order = 1,
})

local statusLabel
local function setStatus(message)
	if statusLabel then
		statusLabel:Set("Status: " .. tostring(message))
	end
end

local Controls = GeneralTab:AddSection({
	Name = "General Controls",
	Column = 1,
	Order = 1,
})

Controls:AddToggle({
	Text = "Enable Module",
	Flag = "module_enabled",
	Default = true,
	Callback = function(value)
		setStatus(value and "module enabled" or "module disabled")
	end,
})

Controls:AddSlider({
	Text = "Intensity",
	Flag = "module_intensity",
	Min = 0,
	Max = 100,
	Step = 1,
	Default = 50,
	Suffix = "%",
	Callback = function(value)
		setStatus("intensity " .. tostring(value) .. "%")
	end,
})

Controls:AddDropdown({
	Text = "Operating Mode",
	Flag = "operating_mode",
	Values = {"Balanced", "Performance", "Custom"},
	Default = "Balanced",
	Callback = function(value)
		setStatus("mode changed to " .. tostring(value))
	end,
})

local Inputs = GeneralTab:AddSection({
	Name = "Inputs & Actions",
	Column = 2,
	Order = 1,
})

Inputs:AddTextbox({
	Text = "Profile Name",
	Flag = "profile_name",
	Placeholder = "Enter a profile name...",
	Default = "Default",
	OnSubmitted = function(value, enterPressed)
		if enterPressed then
			setStatus("profile: " .. value)
		end
	end,
})

Inputs:AddKeybind({
	Text = "Quick Action",
	Flag = "quick_action_key",
	Default = Enum.KeyCode.RightShift,
	Mode = "Press",
	Callback = function()
		setStatus("quick action triggered")
	end,
})

Inputs:AddButton({
	Text = "Run Example Action",
	Callback = function()
		setStatus("example action completed")
	end,
})

local Appearance = GeneralTab:AddSection({
	Name = "Appearance",
	Column = 2,
	Order = 2,
})

Appearance:AddColorPicker({
	Text = "Menu Accent",
	Flag = "menu_accent",
	Default = Color3.fromRGB(8, 126, 255),
	ApplyToTheme = true,
	Callback = function(color)
		local hex = Library.ColorToHex and Library.ColorToHex(color) or tostring(color)
		setStatus("theme changed to " .. hex)
	end,
})

statusLabel = Appearance:AddLabel({
	Text = "Status: ready",
	Keywords = {"status", "information"},
})

local ToolsTab = WorkspaceCategory:AddTab({
	Name = "Tools",
	Order = 2,
})

local ToolActions = ToolsTab:AddSection({
	Name = "Tool Actions",
	Column = 1,
})

ToolActions:AddButton({
	Text = "Primary Tool Action",
	Callback = function()
		setStatus("primary tool action")
	end,
})

local ToolOptions = ToolsTab:AddSection({
	Name = "Tool Options",
	Column = 2,
})

ToolOptions:AddToggle({
	Text = "Confirm Before Running",
	Flag = "confirm_actions",
	Default = true,
})

local InspectCategory = Window:AddCategory({
	Name = "Inspect",
	Icon = Icons:AssetId(2),
	IconFile = Icons:Path(2),
	Symbol = "I",
	Order = 2,
})

local InspectTab = InspectCategory:AddTab({Name = "Overview"})
local InspectSection = InspectTab:AddSection({Name = "Overview", Column = 1})
InspectSection:AddLabel({
	Text = "Use this neutral section for information generated by your own script.",
})

local ProfileCategory = Window:AddCategory({
	Name = "Profiles",
	Icon = Icons:AssetId(4),
	IconFile = Icons:Path(4),
	Symbol = "P",
	Order = 3,
})

local ProfilesTab = ProfileCategory:AddTab({Name = "Profiles"})
local ProfilesSection = ProfilesTab:AddSection({Name = "Profile Manager", Column = 1})
ProfilesSection:AddDropdown({
	Text = "Saved Profile",
	Values = {"Default", "Profile 1", "Profile 2"},
	Default = "Default",
})

local SettingsCategory = Window:AddCategory({
	Name = "Settings",
	Icon = Icons:AssetId(5),
	IconFile = Icons:Path(5),
	Symbol = "S",
	Order = 4,
})

local SettingsTab = SettingsCategory:AddTab({Name = "Configuration"})
local MenuSettings = SettingsTab:AddSection({Name = "Menu Settings", Column = 1})

MenuSettings:AddKeybind({
	Text = "Show / Hide Menu",
	Default = Enum.KeyCode.Insert,
	OnChanged = function(key)
		Window.ToggleKey = key
	end,
})

MenuSettings:AddButton({
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
