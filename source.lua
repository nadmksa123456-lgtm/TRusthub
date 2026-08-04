--[[
    TRust Menu
    Official reusable Roblox/Luau UI library

    Visual structure:
      - slim icon sidebar with the logo in the top-left
      - horizontal tabs across the top
      - searchable two-column section cards
      - runtime accent themes and polished motion
      - reusable controls (toggle, slider, dropdown, textbox, button, label, keybind, color picker)

    Logo setup:
      1) Executor/local asset: use assets/0.png as LogoFile.
      2) Roblox Studio: upload the PNG and replace Logo with rbxassetid://YOUR_ID.
]]

local Services = setmetatable({}, {
    __index = function(_, serviceName)
        return game:GetService(serviceName)
    end,
})

local Players = Services.Players
local UserInputService = Services.UserInputService
local TweenService = Services.TweenService
local Workspace = Services.Workspace

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local rgb = Color3.fromRGB
local fromOffset = UDim2.fromOffset
local clamp = math.clamp
local floor = math.floor
local max = math.max
local min = math.min
local insert = table.insert

local environment = getgenv and getgenv() or _G

local function getGuiParent()
    if gethui then
        local ok, result = pcall(gethui)
        if ok and result then
            return result
        end
    end

    return LocalPlayer:WaitForChild("PlayerGui")
end

local customAsset = getcustomasset or getsynasset

local Theme = {
    Accent = rgb(0, 202, 255),       -- #00CAFF Primary Accent
    AccentSoft = rgb(20, 206, 255),  -- #14CEFF Accent Soft
    AccentLight = rgb(71, 217, 255), -- #47D9FF Hover / Active
    Window = rgb(15, 13, 18),        -- #0F0D12 Background
    Sidebar = rgb(15, 13, 18),
    Topbar = rgb(15, 13, 18),
    Content = rgb(22, 19, 26),       -- #16131A Surface
    Card = rgb(30, 26, 35),          -- #1E1A23 Card
    CardBottom = rgb(22, 19, 26),
    Shadow = rgb(15, 13, 18),
    TabActive = rgb(30, 26, 35),
    Control = rgb(44, 37, 51),       -- #2C2533 Border / control depth
    ControlBottom = rgb(30, 26, 35),
    ControlHover = rgb(44, 37, 51),
    Track = rgb(44, 37, 51),
    Border = rgb(44, 37, 51),
    Text = rgb(255, 255, 255),
    Muted = rgb(179, 179, 184),      -- #B3B3B8 Text Secondary
    Dim = rgb(179, 179, 184),
    White = rgb(255, 255, 255),
}

-- These surface roles stay fixed when Menu Color changes. Only accent-bound
-- details such as lines, active icons, toggles, sliders, and glow are recolored.
local SurfaceThemeRoles = {
    "Window",
    "Sidebar",
    "Topbar",
    "Content",
    "Card",
    "CardBottom",
    "Shadow",
    "TabActive",
    "Control",
    "ControlBottom",
    "ControlHover",
    "Track",
    "Border",
    "Muted",
    "Dim",
}

local ROBOTO_FAMILY = "rbxasset://fonts/families/Roboto.json"
local GOTHAM_FALLBACK = "rbxasset://fonts/families/GothamSSm.json"
local TYPOGRAPHY_SCALE = clamp(tonumber(environment.TRUST_MENU_FONT_SCALE) or 1.2, 1, 1.5)

local function robotoFont(weight)
    local ok, font = pcall(function()
        return Font.new(ROBOTO_FAMILY, weight, Enum.FontStyle.Normal)
    end)
    if ok and font then return font end
    return Font.new(GOTHAM_FALLBACK, weight, Enum.FontStyle.Normal)
end

local function interfaceTextSize(size)
    return floor(size * TYPOGRAPHY_SCALE + 0.5)
end

-- The hierarchy intentionally keeps control names light and reserves stronger
-- weight for section titles. This matches the simulator without visual noise.
local Fonts = {
    Regular = robotoFont(Enum.FontWeight.Regular),
    Semibold = robotoFont(Enum.FontWeight.Medium),
    Bold = robotoFont(Enum.FontWeight.Bold),
}

local Library = {
    Version = "1.2.0",
    Build = "stable-v1.2.0",
    FontName = "Roboto",
    FontScale = TYPOGRAPHY_SCALE,
    Theme = Theme,
    Flags = {},
    Setters = {},
    Connections = {},
    Windows = {},
    ThemeBindings = {},
    ThemeListeners = {},
    _flagIndex = 0,
}
Library.__index = Library

local function create(className, properties)
    local object = Instance.new(className)
    local parent = properties.Parent

    if object:IsA("GuiObject") then
        object.BorderSizePixel = 0
    end

    for property, value in properties do
        if property ~= "Parent" then
            object[property] = value
        end
    end

    if parent then
        object.Parent = parent
    end

    return object
end

local function corner(parent, radius)
    return create("UICorner", {
        Parent = parent,
        CornerRadius = UDim.new(0, radius or 8),
    })
end

local function stroke(parent, color, transparency, thickness)
    return create("UIStroke", {
        Parent = parent,
        Color = color or Theme.Border,
        Transparency = transparency or 0,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
end

local function gradient(parent, topColor, bottomColor, rotation)
    -- Roblox multiplies UIGradient colors by the GuiObject's base color.
    -- Keep that base neutral so the requested theme colors render exactly.
    parent.BackgroundColor3 = Theme.White

    return create("UIGradient", {
        Parent = parent,
        Rotation = rotation or 90,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, topColor),
            ColorSequenceKeypoint.new(1, bottomColor),
        }),
    })
end

local activeTweens = setmetatable({}, {__mode = "k"})

local function cancelTweenProperties(object, properties)
    local propertyTweens = activeTweens[object]
    if not propertyTweens then return end

    local cancelled = {}
    for property in properties do
        local animation = propertyTweens[property]
        if animation and not cancelled[animation] then
            cancelled[animation] = true
            local clear = {}
            for trackedProperty, trackedAnimation in propertyTweens do
                if trackedAnimation == animation then
                    table.insert(clear, trackedProperty)
                end
            end
            for _, trackedProperty in clear do propertyTweens[trackedProperty] = nil end
            animation:Cancel()
        end
    end

    if next(propertyTweens) == nil then activeTweens[object] = nil end
end

local function setProperties(object, properties)
    if not object or not object.Parent then return end
    cancelTweenProperties(object, properties)
    for property, value in properties do
        object[property] = value
    end
end

local function tween(object, properties, duration, style, direction)
    if not object or not object.Parent then return end
    cancelTweenProperties(object, properties)

    local animation = TweenService:Create(
        object,
        TweenInfo.new(
            duration or 0.2,
            style or Enum.EasingStyle.Quint,
            direction or Enum.EasingDirection.Out
        ),
        properties
    )
    local propertyTweens = activeTweens[object]
    if not propertyTweens then
        propertyTweens = {}
        activeTweens[object] = propertyTweens
    end
    for property in properties do
        propertyTweens[property] = animation
    end

    animation.Completed:Connect(function()
        local tracked = activeTweens[object]
        if not tracked then return end
        local clear = {}
        for property, trackedAnimation in tracked do
            if trackedAnimation == animation then table.insert(clear, property) end
        end
        for _, property in clear do tracked[property] = nil end
        if next(tracked) == nil then activeTweens[object] = nil end
    end)
    animation:Play()
    return animation
end

local function colorToHex(color)
    return string.format(
        "#%02X%02X%02X",
        floor(color.R * 255 + 0.5),
        floor(color.G * 255 + 0.5),
        floor(color.B * 255 + 0.5)
    )
end

local function parseColor(value)
    if typeof(value) == "Color3" then
        return value
    end

    if type(value) == "string" then
        local hex = value:gsub("#", ""):gsub("%s", "")
        if #hex == 3 then
            hex = hex:sub(1, 1):rep(2)
                .. hex:sub(2, 2):rep(2)
                .. hex:sub(3, 3):rep(2)
        end
        if #hex == 6 then
            local red = tonumber(hex:sub(1, 2), 16)
            local green = tonumber(hex:sub(3, 4), 16)
            local blue = tonumber(hex:sub(5, 6), 16)
            if red and green and blue then
                return rgb(red, green, blue)
            end
        end
    end

    if type(value) == "table" then
        local red = tonumber(value.R or value.r or value[1])
        local green = tonumber(value.G or value.g or value[2])
        local blue = tonumber(value.B or value.b or value[3])
        if red and green and blue then
            if red <= 1 and green <= 1 and blue <= 1 then
                return Color3.new(red, green, blue)
            end
            return rgb(clamp(red, 0, 255), clamp(green, 0, 255), clamp(blue, 0, 255))
        end
    end
end

local function bindTheme(object, property, resolver, instant)
    local binding = {
        Object = setmetatable({object}, {__mode = "v"}),
        Property = property,
        Resolver = resolver,
        Instant = instant == true,
    }
    insert(Library.ThemeBindings, binding)
    object[property] = resolver(Theme)
    return binding
end

local function onThemeChanged(owner, callback)
    local listener = {Owner = owner, Callback = callback}
    insert(Library.ThemeListeners, listener)
    callback(Theme, false)
    return listener
end

local function colorsClose(first, second)
    return math.abs(first.R - second.R) < 0.0001
        and math.abs(first.G - second.G) < 0.0001
        and math.abs(first.B - second.B) < 0.0001
end

local function snapshotSurfaceTheme()
    local snapshot = {}
    for _, role in SurfaceThemeRoles do
        snapshot[role] = Theme[role]
    end
    return snapshot
end

local function remapSurfaceColor(color, previousTheme)
    for _, role in SurfaceThemeRoles do
        local previous = previousTheme[role]
        if previous and colorsClose(color, previous) then
            return Theme[role]
        end
    end
    return color
end

local function remapGradient(sequence, previousTheme)
    local changed = false
    local keypoints = {}
    for _, keypoint in sequence.Keypoints do
        local nextColor = remapSurfaceColor(keypoint.Value, previousTheme)
        if not colorsClose(nextColor, keypoint.Value) then changed = true end
        insert(keypoints, ColorSequenceKeypoint.new(keypoint.Time, nextColor))
    end
    return changed and ColorSequence.new(keypoints) or sequence
end

local function applySurfaceTheme(library, previousTheme)
    for _, window in library.Windows do
        local screenGui = window.ScreenGui
        if screenGui and screenGui.Parent then
            for _, object in screenGui:GetDescendants() do
                if object:IsA("GuiObject") then
                    local nextBackground = remapSurfaceColor(object.BackgroundColor3, previousTheme)
                    if not colorsClose(nextBackground, object.BackgroundColor3) then
                        setProperties(object, {BackgroundColor3 = nextBackground})
                    end
                end

                if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
                    local nextText = remapSurfaceColor(object.TextColor3, previousTheme)
                    if not colorsClose(nextText, object.TextColor3) then
                        setProperties(object, {TextColor3 = nextText})
                    end
                    if object:IsA("TextBox") then
                        local nextPlaceholder = remapSurfaceColor(object.PlaceholderColor3, previousTheme)
                        if not colorsClose(nextPlaceholder, object.PlaceholderColor3) then
                            setProperties(object, {PlaceholderColor3 = nextPlaceholder})
                        end
                    end
                elseif object:IsA("ImageLabel") or object:IsA("ImageButton") then
                    local nextImage = remapSurfaceColor(object.ImageColor3, previousTheme)
                    if not colorsClose(nextImage, object.ImageColor3) then
                        setProperties(object, {ImageColor3 = nextImage})
                    end
                end

                if object:IsA("ScrollingFrame") then
                    local nextScroll = remapSurfaceColor(object.ScrollBarImageColor3, previousTheme)
                    if not colorsClose(nextScroll, object.ScrollBarImageColor3) then
                        setProperties(object, {ScrollBarImageColor3 = nextScroll})
                    end
                elseif object:IsA("UIStroke") then
                    local nextStroke = remapSurfaceColor(object.Color, previousTheme)
                    if not colorsClose(nextStroke, object.Color) then
                        setProperties(object, {Color = nextStroke})
                    end
                elseif object:IsA("UIGradient") then
                    local nextSequence = remapGradient(object.Color, previousTheme)
                    if nextSequence ~= object.Color then
                        setProperties(object, {Color = nextSequence})
                    end
                end
            end
        end
    end
end

local function deriveSurfaceTheme()
    Theme.Window = rgb(15, 13, 18)
    Theme.Sidebar = rgb(15, 13, 18)
    Theme.Topbar = rgb(15, 13, 18)
    Theme.Content = rgb(22, 19, 26)
    Theme.Card = rgb(30, 26, 35)
    Theme.CardBottom = rgb(22, 19, 26)
    Theme.Shadow = rgb(15, 13, 18)
    Theme.TabActive = rgb(30, 26, 35)
    Theme.Control = rgb(44, 37, 51)
    Theme.ControlBottom = rgb(30, 26, 35)
    Theme.ControlHover = rgb(44, 37, 51)
    Theme.Track = rgb(44, 37, 51)
    Theme.Border = rgb(44, 37, 51)
    Theme.Muted = rgb(179, 179, 184)
    Theme.Dim = rgb(179, 179, 184)
end

function Library:SetThemeColor(value, animate)
    local color = parseColor(value)
    if not color then
        warn("[TRust Menu] Invalid theme color: " .. tostring(value))
        return self.Theme.Accent
    end

    local previousTheme = snapshotSurfaceTheme()
    Theme.Accent = color
    if colorsClose(color, rgb(255, 5, 126)) then
        Theme.AccentSoft = rgb(255, 20, 147)
        Theme.AccentLight = rgb(255, 77, 157)
    else
        Theme.AccentSoft = color:Lerp(Theme.White, 0.08)
        Theme.AccentLight = color:Lerp(Theme.White, 0.28)
    end
    deriveSurfaceTheme()
    applySurfaceTheme(self, previousTheme)

    for index = #self.ThemeBindings, 1, -1 do
        local binding = self.ThemeBindings[index]
        local object = binding.Object[1]
        if not object or not object.Parent then
            table.remove(self.ThemeBindings, index)
        else
            local nextValue = binding.Resolver(Theme)
            if animate ~= false and not binding.Instant and typeof(nextValue) == "Color3" then
                tween(object, {[binding.Property] = nextValue}, 0.24, Enum.EasingStyle.Quart)
            else
                setProperties(object, {[binding.Property] = nextValue})
            end
        end
    end

    for index = #self.ThemeListeners, 1, -1 do
        local listener = self.ThemeListeners[index]
        if listener.Owner and listener.Owner.Destroyed then
            table.remove(self.ThemeListeners, index)
        else
            local ok, message = pcall(listener.Callback, Theme, animate ~= false)
            if not ok then warn("[TRust Menu] Theme listener error: " .. tostring(message)) end
        end
    end

    return color
end


Library.SetAccent = Library.SetThemeColor
Library.ColorToHex = colorToHex
Library.ParseColor = parseColor

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    insert(Library.Connections, connection)
    return connection
end

local function disconnectTracked(connection)
    if not connection then return end
    if connection.Connected then connection:Disconnect() end

    local index = table.find(Library.Connections, connection)
    if index then table.remove(Library.Connections, index) end
end

local function safeCallback(callback, ...)
    local arguments = table.pack(...)
    task.spawn(function()
        local ok, message = pcall(callback, table.unpack(arguments, 1, arguments.n))
        if not ok then
            warn("[TRust Menu] Callback error: " .. tostring(message))
        end
    end)
end

local function resolveImage(assetId, localPath)
    if localPath and localPath ~= "" and customAsset then
        local exists = true
        if type(isfile) == "function" then
            local ok
            ok, exists = pcall(isfile, localPath)
            exists = ok and exists
        end

        if exists then
            local success, asset = pcall(customAsset, localPath)
            if success and asset then
                return asset
            end
        end
    end

    return assetId or ""
end

local function formatKey(key)
    if not key then return "NONE" end

    local aliases = {
        [Enum.KeyCode.Insert] = "INS",
        [Enum.KeyCode.LeftShift] = "LSHIFT",
        [Enum.KeyCode.RightShift] = "RSHIFT",
        [Enum.KeyCode.LeftControl] = "LCTRL",
        [Enum.KeyCode.RightControl] = "RCTRL",
        [Enum.KeyCode.LeftAlt] = "LALT",
        [Enum.KeyCode.RightAlt] = "RALT",
        [Enum.KeyCode.Return] = "ENTER",
        [Enum.KeyCode.Backspace] = "BACK",
        [Enum.UserInputType.MouseButton1] = "MB1",
        [Enum.UserInputType.MouseButton2] = "MB2",
        [Enum.UserInputType.MouseButton3] = "MB3",
    }

    return aliases[key]
        or tostring(key):gsub("Enum.KeyCode.", ""):gsub("Enum.UserInputType.", "")
end

local function inputMatches(input, key)
    return input.KeyCode == key or input.UserInputType == key
end

function Library:NextFlag()
    self._flagIndex += 1
    return "trust_flag_" .. tostring(self._flagIndex)
end

function Library:SetFlag(flag, value, emit)
    local setter = self.Setters[flag]
    if setter then
        return setter(value, emit)
    end

    self.Flags[flag] = value
    return value
end

function Library:GetFlag(flag)
    return self.Flags[flag]
end

function Library:Unload()
    for _, window in self.Windows do
        if window.ScreenGui and window.ScreenGui.Parent then
            window.ScreenGui:Destroy()
        end
    end

    for _, connection in self.Connections do
        if connection.Connected then
            connection:Disconnect()
        end
    end

    table.clear(self.Windows)
    table.clear(self.Connections)
    table.clear(self.Flags)
    table.clear(self.Setters)
    table.clear(self.ThemeBindings)
    table.clear(self.ThemeListeners)

    if environment.__TRUST_MENU_LIBRARY == self then
        environment.__TRUST_MENU_LIBRARY = nil
    end
end

local previousLibrary = environment.__TRUST_MENU_LIBRARY
if previousLibrary and previousLibrary ~= Library and previousLibrary.Unload then
    pcall(function()
        previousLibrary:Unload()
    end)
end
environment.__TRUST_MENU_LIBRARY = Library

local function makeDraggable(frame, handles, closePopups)
    local dragging = false
    local dragStart
    local startPosition

    local function begin(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        dragging = true
        dragStart = input.Position
        startPosition = frame.Position
        if closePopups then closePopups() end
    end

    for _, handle in handles do
        handle.Active = true
        handle.InputBegan:Connect(begin)
    end

    connect(UserInputService.InputChanged, function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        local delta = input.Position - dragStart
        local width = frame.AbsoluteSize.X
        local height = frame.AbsoluteSize.Y
        local activeCamera = Workspace.CurrentCamera or Camera
        local viewport = activeCamera and activeCamera.ViewportSize or Vector2.new(1280, 720)

        local x = startPosition.X.Offset + delta.X
        local y = startPosition.Y.Offset + delta.Y
        x = clamp(x, -(width - 80), viewport.X - 80)
        y = clamp(y, 0, viewport.Y - 48)
        frame.Position = fromOffset(x, y)
    end)

    connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

local SectionMethods = {}
SectionMethods.__index = SectionMethods

function Library:CreateWindow(options)
    options = options or {}

    if #self.Windows > 0 then
        self:Unload()
        environment.__TRUST_MENU_LIBRARY = self
    end

    local initialThemeColor = options.ThemeColor or options.Accent
    if initialThemeColor then self:SetThemeColor(initialThemeColor, false) end

    local requestedSize = options.Size or Vector2.new(1000, 620)
    local activeCamera = Workspace.CurrentCamera or Camera
    if not activeCamera then
        Workspace:GetPropertyChangedSignal("CurrentCamera"):Wait()
        activeCamera = Workspace.CurrentCamera
    end
    local viewport = activeCamera and activeCamera.ViewportSize or Vector2.new(1280, 720)
    local availableWidth = max(1, viewport.X - 28)
    local availableHeight = max(1, viewport.Y - 28)
    local minimumWidth = min(options.MinimumWidth or 560, availableWidth)
    local minimumHeight = min(options.MinimumHeight or 420, availableHeight)
    local width = max(minimumWidth, min(requestedSize.X, availableWidth))
    local height = max(minimumHeight, min(requestedSize.Y, availableHeight))
    local sidebarWidth = options.SidebarWidth or 78
    local topbarHeight = options.TopbarHeight or 64

    local guiParent = getGuiParent()
    local existing = guiParent:FindFirstChild("TRustMenuUI") or guiParent:FindFirstChild("TRustMidnightUI")
    if existing then existing:Destroy() end

    local screenGui = create("ScreenGui", {
        Parent = guiParent,
        Name = "TRustMenuUI",
        IgnoreGuiInset = true,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Global,
        DisplayOrder = options.DisplayOrder or 999,
    })

    local initialX = floor((viewport.X - width) / 2)
    local initialY = floor((viewport.Y - height) / 2)

    local windowShadowFar = create("Frame", {
        Parent = screenGui,
        Name = "WindowShadowFar",
        Position = fromOffset(initialX + 8, initialY + 13),
        Size = fromOffset(width + 4, height + 5),
        BackgroundColor3 = Theme.Shadow,
        BackgroundTransparency = 1,
        Visible = false,
    })
    corner(windowShadowFar, 18)

    local windowGlow = create("Frame", {
        Parent = screenGui,
        Name = "WindowAccentGlow",
        Position = fromOffset(initialX - 5, initialY - 5),
        Size = fromOffset(width + 10, height + 10),
        BackgroundColor3 = Theme.Accent,
        BackgroundTransparency = 1,
        Visible = false,
    })
    corner(windowGlow, 18)
    local windowGlowStroke = stroke(windowGlow, Theme.Accent, 0.76, 2)
    bindTheme(windowGlow, "BackgroundColor3", function(theme) return theme.Accent end)
    bindTheme(windowGlowStroke, "Color", function(theme) return theme.Accent end)

    local windowShadowNear = create("Frame", {
        Parent = screenGui,
        Name = "WindowShadowNear",
        Position = fromOffset(initialX + 4, initialY + 7),
        Size = fromOffset(width, height + 2),
        BackgroundColor3 = Theme.Shadow,
        BackgroundTransparency = 1,
        Visible = false,
    })
    corner(windowShadowNear, 16)

    local main = create("CanvasGroup", {
        Parent = screenGui,
        Name = "MainWindow",
        Position = fromOffset(initialX, initialY),
        Size = fromOffset(width, height),
        BackgroundColor3 = Theme.Window,
        GroupTransparency = 0,
        ClipsDescendants = true,
    })
    corner(main, 14)
    stroke(main, Theme.Border, 0.05, 1)
    gradient(main, Theme.Window, Theme.Content, 90)

    -- Accent depth is rendered inside the window bounds. The old outer shadow
    -- layers remain hidden for field compatibility, preventing bright themes
    -- and high opacity from leaking glow beyond the menu frame.
    local windowInnerGlow = create("Frame", {
        Parent = main,
        Name = "WindowInnerGlow",
        Position = fromOffset(2, 2),
        Size = UDim2.new(1, -4, 1, -4),
        BackgroundTransparency = 1,
        Active = false,
        ZIndex = 50,
    })
    corner(windowInnerGlow, 12)
    local windowInnerGlowStroke = stroke(windowInnerGlow, Theme.Accent, 0.78, 2)
    bindTheme(windowInnerGlowStroke, "Color", function(theme) return theme.Accent end)

    local sidebar = create("Frame", {
        Parent = main,
        Name = "Sidebar",
        Size = UDim2.new(0, sidebarWidth, 1, 0),
        BackgroundColor3 = Theme.Sidebar,
        ClipsDescendants = false,
    })
    corner(sidebar, 14)

    create("Frame", {
        Parent = sidebar,
        Name = "SidebarDivider",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.new(0, 1, 1, 0),
        BackgroundColor3 = Theme.Border,
    })

    local logoZone = create("Frame", {
        Parent = sidebar,
        Name = "LogoZone",
        Size = fromOffset(sidebarWidth, topbarHeight),
        BackgroundTransparency = 1,
    })

    local logoImage = resolveImage(options.Logo, options.LogoFile)
    local logo = create("ImageLabel", {
        Parent = logoZone,
        Name = "Logo",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = options.LogoPosition or UDim2.new(0.5, 0, 0, 30),
        Size = options.LogoSize or fromOffset(54, 54),
        BackgroundTransparency = 1,
        Image = logoImage,
        ImageColor3 = Theme.Accent,
        ImageRectOffset = options.LogoRectOffset or Vector2.new(0, 0),
        ImageRectSize = options.LogoRectSize or Vector2.new(0, 0),
        ScaleType = Enum.ScaleType.Fit,
        Visible = logoImage ~= "",
    })
    if typeof(options.LogoTint) == "Color3" then
        logo.ImageColor3 = options.LogoTint
    else
        local logoRole = type(options.LogoTint) == "string" and options.LogoTint or "Accent"
        bindTheme(logo, "ImageColor3", function(theme)
            return theme[logoRole] or theme.Accent
        end)
    end

    local logoFallback = create("TextLabel", {
        Parent = logoZone,
        Name = "LogoFallback",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = options.LogoPosition or UDim2.new(0.5, 0, 0, 30),
        Size = options.LogoSize or fromOffset(54, 54),
        BackgroundTransparency = 1,
        Text = options.LogoFallback or "",
        TextColor3 = Theme.Accent,
        TextSize = interfaceTextSize(21),
        FontFace = Fonts.Bold,
        Visible = logoImage == "" and type(options.LogoFallback) == "string" and options.LogoFallback ~= "",
    })
    bindTheme(logoFallback, "TextColor3", function(theme) return theme.Accent end)

    local brand = create("Frame", {
        Parent = logoZone,
        Name = "Brand",
        Position = fromOffset(0, 53),
        Size = UDim2.new(1, 0, 0, 15),
        BackgroundTransparency = 1,
        Visible = options.ShowBrandName == true,
    })
    create("UIListLayout", {
        Parent = brand,
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
    })

    local brandAccent = create("TextLabel", {
        Parent = brand,
        Size = fromOffset(0, 15),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        Text = options.BrandAccentText or "TRust",
        TextColor3 = Theme.Accent,
        TextSize = interfaceTextSize(10),
        FontFace = Fonts.Bold,
        LayoutOrder = 1,
    })
    bindTheme(brandAccent, "TextColor3", function(theme) return theme.Accent end)

    create("TextLabel", {
        Parent = brand,
        Size = fromOffset(0, 15),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        Text = options.BrandText or " Menu",
        TextColor3 = Theme.White,
        TextSize = interfaceTextSize(10),
        FontFace = Fonts.Bold,
        LayoutOrder = 2,
    })

    local categoryHolder = create("ScrollingFrame", {
        Parent = sidebar,
        Name = "CategoryHolder",
        Position = fromOffset(0, topbarHeight + 22),
        Size = UDim2.new(1, 0, 1, -(topbarHeight + 34)),
        BackgroundTransparency = 1,
        CanvasSize = fromOffset(0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 0,
    })
    create("UIListLayout", {
        Parent = categoryHolder,
        Padding = UDim.new(0, 14),
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
    })

    local topbar = create("Frame", {
        Parent = main,
        Name = "Topbar",
        Position = fromOffset(sidebarWidth, 0),
        Size = UDim2.new(1, -sidebarWidth, 0, topbarHeight),
        BackgroundColor3 = Theme.Topbar,
    })
    corner(topbar, 14)

    create("Frame", {
        Parent = topbar,
        Name = "TopbarDivider",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Theme.Border,
    })

    local topTabs = create("ScrollingFrame", {
        Parent = topbar,
        Name = "TopTabs",
        Position = fromOffset(18, 0),
        Size = UDim2.new(1, -92, 1, 0),
        BackgroundTransparency = 1,
        CanvasSize = fromOffset(0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.X,
        ScrollingDirection = Enum.ScrollingDirection.X,
        ScrollBarThickness = 0,
    })
    create("UIListLayout", {
        Parent = topTabs,
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 8),
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
    })

    local searchButton = create("TextButton", {
        Parent = topbar,
        Name = "SearchButton",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = fromOffset(46, 46),
        BackgroundColor3 = Theme.TabActive,
        AutoButtonColor = false,
        Text = "",
        TextColor3 = Theme.Muted,
        TextSize = interfaceTextSize(28),
        FontFace = Fonts.Regular,
    })
    corner(searchButton, 9)
    stroke(searchButton, Theme.Border, 0.15, 1)
    bindTheme(searchButton, "BackgroundColor3", function(theme) return theme.TabActive end)

    local searchLens = create("Frame", {
        Parent = searchButton,
        Position = fromOffset(12, 10),
        Size = fromOffset(17, 17),
        BackgroundTransparency = 1,
    })
    corner(searchLens, 10)
    stroke(searchLens, Theme.Muted, 0, 2)

    create("Frame", {
        Parent = searchButton,
        Position = fromOffset(28, 27),
        Size = fromOffset(2, 10),
        Rotation = -45,
        BackgroundColor3 = Theme.Muted,
    })

    local searchBox = create("TextBox", {
        Parent = topbar,
        Name = "SearchBox",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = fromOffset(230, 42),
        BackgroundColor3 = Theme.ControlBottom,
        Text = "",
        PlaceholderText = "Search controls...",
        PlaceholderColor3 = Theme.Dim,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextSize = interfaceTextSize(14),
        FontFace = Fonts.Regular,
        ClearTextOnFocus = false,
        Visible = false,
        ZIndex = 20,
    })
    corner(searchBox, 8)
    stroke(searchBox, Theme.Border, 0, 1)
    create("UIPadding", {
        Parent = searchBox,
        PaddingLeft = UDim.new(0, 14),
        PaddingRight = UDim.new(0, 14),
    })

    local content = create("Frame", {
        Parent = main,
        Name = "Content",
        Position = fromOffset(sidebarWidth, topbarHeight),
        Size = UDim2.new(1, -sidebarWidth, 1, -topbarHeight),
        BackgroundColor3 = Theme.Content,
        ClipsDescendants = true,
    })
    corner(content, 14)
    gradient(content, Theme.Content, Theme.Window, 90)

    local popupLayer = create("CanvasGroup", {
        Parent = screenGui,
        Name = "PopupLayer",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        GroupTransparency = 0,
        ClipsDescendants = false,
        ZIndex = 100,
    })

    local window = {
        Library = Library,
        Name = options.Name or "TRust Menu",
        ScreenGui = screenGui,
        Main = main,
        WindowGlow = windowGlow,
        WindowGlowStroke = windowGlowStroke,
        WindowShadowNear = windowShadowNear,
        WindowShadowFar = windowShadowFar,
        WindowInnerGlow = windowInnerGlow,
        WindowInnerGlowStroke = windowInnerGlowStroke,
        Sidebar = sidebar,
        Topbar = topbar,
        TopTabs = topTabs,
        Content = content,
        PopupLayer = popupLayer,
        SearchBox = searchBox,
        SearchButton = searchButton,
        SearchQuery = "",
        Categories = {},
        SearchSections = {},
        CurrentCategory = nil,
        OpenPopup = nil,
        CapturingKeybind = nil,
        Visible = true,
        Opacity = 1,
        GlowBindings = {},
        ToggleKey = options.ToggleKey or Enum.KeyCode.Insert,
        Flags = {},
        Setters = {},
        CameraConnection = nil,
    }
    screenGui:SetAttribute("MenuName", window.Name)
    screenGui:SetAttribute("LibraryVersion", Library.Version)
    screenGui:SetAttribute("LibraryBuild", Library.Build)

    local function syncWindowDepth()
        if not main.Parent then return end

        local position = main.Position
        local size = main.Size
        windowGlow.Position = UDim2.new(
            position.X.Scale,
            position.X.Offset - 5,
            position.Y.Scale,
            position.Y.Offset - 5
        )
        windowGlow.Size = UDim2.new(
            size.X.Scale,
            size.X.Offset + 10,
            size.Y.Scale,
            size.Y.Offset + 10
        )
        windowShadowNear.Position = UDim2.new(
            position.X.Scale,
            position.X.Offset + 4,
            position.Y.Scale,
            position.Y.Offset + 7
        )
        windowShadowNear.Size = UDim2.new(
            size.X.Scale,
            size.X.Offset,
            size.Y.Scale,
            size.Y.Offset + 2
        )
        windowShadowFar.Position = UDim2.new(
            position.X.Scale,
            position.X.Offset + 8,
            position.Y.Scale,
            position.Y.Offset + 13
        )
        windowShadowFar.Size = UDim2.new(
            size.X.Scale,
            size.X.Offset + 4,
            size.Y.Scale,
            size.Y.Offset + 5
        )
    end

    connect(main:GetPropertyChangedSignal("Position"), syncWindowDepth)
    connect(main:GetPropertyChangedSignal("Size"), syncWindowDepth)

    local function normalizeOpacity(value)
        value = tonumber(value) or 100
        if value > 1 then value /= 100 end
        return clamp(value, 0.2, 1)
    end

    function window:GlowTransparency(baseTransparency, active)
        if active == false then return 1 end
        return 1 - ((1 - baseTransparency) * self.Opacity)
    end

    function window:RegisterGlow(object, property, baseTransparency, activeResolver)
        local binding = {
            Object = object,
            Property = property or "BackgroundTransparency",
            BaseTransparency = clamp(tonumber(baseTransparency) or 0.85, 0, 1),
            ActiveResolver = activeResolver,
        }
        insert(self.GlowBindings, binding)
        self:ApplyGlowBinding(binding, false)
        return binding
    end

    function window:ApplyGlowBinding(binding, animate)
        local object = binding.Object
        if not object or not object.Parent then return end

        local active = true
        if binding.ActiveResolver then
            local ok, result = pcall(binding.ActiveResolver)
            active = ok and result ~= false
        end

        local target = self:GlowTransparency(binding.BaseTransparency, active)
        if animate then
            tween(object, {[binding.Property] = target}, 0.2, Enum.EasingStyle.Quart)
        else
            setProperties(object, {[binding.Property] = target})
        end
    end

    function window:RefreshGlowVisuals(animate)
        for index = #self.GlowBindings, 1, -1 do
            local binding = self.GlowBindings[index]
            if not binding.Object or not binding.Object.Parent then
                table.remove(self.GlowBindings, index)
            else
                self:ApplyGlowBinding(binding, animate == true)
            end
        end
    end

    function window:SetOpacity(value, animate)
        self.Opacity = normalizeOpacity(value)

        -- Keep the menu usable at the minimum while still making the opacity
        -- change visually clear. Internal glows fade again through the group.
        local groupTransparency = (1 - self.Opacity) * 0.7
        if animate ~= false then
            tween(self.Main, {GroupTransparency = groupTransparency}, 0.24, Enum.EasingStyle.Quart)
            tween(self.PopupLayer, {GroupTransparency = groupTransparency}, 0.24, Enum.EasingStyle.Quart)
        else
            setProperties(self.Main, {GroupTransparency = groupTransparency})
            setProperties(self.PopupLayer, {GroupTransparency = groupTransparency})
        end

        self:RefreshGlowVisuals(animate ~= false)
        return floor(self.Opacity * 100 + 0.5)
    end

    function window:GetOpacity()
        return floor(self.Opacity * 100 + 0.5)
    end

    window:RegisterGlow(windowInnerGlowStroke, "Transparency", 0.78)
    window:SetOpacity(options.MenuOpacity or options.Opacity or 100, false)

    function window:FitToViewport()
        local liveCamera = Workspace.CurrentCamera or Camera
        if not liveCamera then return end

        local liveViewport = liveCamera.ViewportSize
        local availableX = max(1, liveViewport.X - 28)
        local availableY = max(1, liveViewport.Y - 28)
        local minX = min(options.MinimumWidth or 560, availableX)
        local minY = min(options.MinimumHeight or 420, availableY)
        local nextWidth = max(minX, min(requestedSize.X, availableX))
        local nextHeight = max(minY, min(requestedSize.Y, availableY))

        self.Main.Size = fromOffset(nextWidth, nextHeight)
        local nextX = clamp(self.Main.Position.X.Offset, 0, max(0, liveViewport.X - nextWidth))
        local nextY = clamp(self.Main.Position.Y.Offset, 0, max(0, liveViewport.Y - nextHeight))
        self.Main.Position = fromOffset(nextX, nextY)
        if self.ClosePopup then self:ClosePopup() end
    end

    local function bindViewport(cameraObject)
        disconnectTracked(window.CameraConnection)
        window.CameraConnection = nil
        if cameraObject then
            window.CameraConnection = connect(cameraObject:GetPropertyChangedSignal("ViewportSize"), function()
                window:FitToViewport()
            end)
        end
    end

    bindViewport(activeCamera)
    connect(Workspace:GetPropertyChangedSignal("CurrentCamera"), function()
        bindViewport(Workspace.CurrentCamera)
        window:FitToViewport()
    end)

    function window:ClosePopup(except)
        if self.OpenPopup and self.OpenPopup ~= except then
            self.OpenPopup:Close()
        end
        self.OpenPopup = except
    end

    function window:SetVisible(state)
        state = state == true
        self.Visible = state
        if not state then self:ClosePopup() end
        if self.ScreenGui and self.ScreenGui.Parent then
            self.ScreenGui.Enabled = state
        end
    end

    function window:Toggle()
        self:SetVisible(not self.Visible)
    end

    function window:SetThemeColor(color, animate)
        return Library:SetThemeColor(color, animate)
    end

    window.SetAccent = window.SetThemeColor

    function window:GetThemeColor()
        return Theme.Accent
    end

    function window:SetFlag(flag, value, emit)
        local setter = self.Setters[flag]
        if setter then
            return setter(value, emit)
        end

        self.Flags[flag] = value
        Library.Flags[flag] = value
        return value
    end

    function window:GetFlag(flag)
        return self.Flags[flag]
    end

    function window:Destroy()
        -- The library is intentionally singleton, so destroy also clears
        -- global input listeners created by controls in this window.
        Library:Unload()
    end

    function window:ApplySearch(query)
        self:ClosePopup()
        query = string.lower(query or "")
        self.SearchQuery = query
        for _, sectionObject in self.SearchSections do
            sectionObject:ApplySearch(query)
        end
    end

    searchButton.Activated:Connect(function()
        window:ClosePopup()
        searchButton.Visible = false
        searchBox.Visible = true
        searchBox:CaptureFocus()
    end)

    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        window:ClosePopup()
        window:ApplySearch(searchBox.Text)
    end)

    searchBox.FocusLost:Connect(function(enterPressed)
        if searchBox.Text == "" then
            searchBox.Visible = false
            searchButton.Visible = true
        end
    end)

    connect(UserInputService.InputBegan, function(input, processed)
        if window.CapturingKeybind then return end

        if input.KeyCode == Enum.KeyCode.Escape and searchBox.Visible then
            searchBox.Text = ""
            searchBox.Visible = false
            searchButton.Visible = true
            searchBox:ReleaseFocus()
            return
        end

        if processed then return end

        if inputMatches(input, window.ToggleKey) then
            window:Toggle()
        end
    end)

    local function pointerInside(guiObject, position)
        if not guiObject or not guiObject.Parent or not guiObject.Visible then return false end
        local topLeft = guiObject.AbsolutePosition
        local bottomRight = topLeft + guiObject.AbsoluteSize
        return position.X >= topLeft.X and position.X <= bottomRight.X
            and position.Y >= topLeft.Y and position.Y <= bottomRight.Y
    end

    connect(UserInputService.InputBegan, function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        local openPopup = window.OpenPopup
        if not openPopup then return end
        if pointerInside(openPopup.Field, input.Position)
            or pointerInside(openPopup.Popup, input.Position) then
            return
        end
        openPopup:Close()
    end)

    makeDraggable(main, {logoZone, topbar}, function()
        window:ClosePopup()
    end)

    insert(Library.Windows, window)

    function window:Category(categoryOptions)
        categoryOptions = categoryOptions or {}

        local category = {
            Window = self,
            Name = categoryOptions.Name or "Category",
            Tabs = {},
            CurrentTab = nil,
        }

        local categoryButton = create("TextButton", {
            Parent = categoryHolder,
            Name = category.Name,
            Size = fromOffset(58, 58),
            BackgroundColor3 = Theme.TabActive,
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            Text = "",
            LayoutOrder = categoryOptions.Order or (#self.Categories + 1),
        })
        corner(categoryButton, 10)
        bindTheme(categoryButton, "BackgroundColor3", function(theme) return theme.TabActive end)

        local sideAccentGlowOuter = create("Frame", {
            Parent = categoryButton,
            Name = "AccentGlowOuter",
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 0, 0.5, 0),
            Size = fromOffset(9, 44),
            BackgroundColor3 = Theme.Accent,
            BackgroundTransparency = 1,
        })
        corner(sideAccentGlowOuter, 5)
        bindTheme(sideAccentGlowOuter, "BackgroundColor3", function(theme) return theme.Accent end)

        local sideAccentGlowInner = create("Frame", {
            Parent = categoryButton,
            Name = "AccentGlowInner",
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 1, 0.5, 0),
            Size = fromOffset(7, 40),
            BackgroundColor3 = Theme.Accent,
            BackgroundTransparency = 1,
        })
        corner(sideAccentGlowInner, 4)
        bindTheme(sideAccentGlowInner, "BackgroundColor3", function(theme) return theme.Accent end)

        local sideAccent = create("Frame", {
            Parent = categoryButton,
            Name = "Accent",
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 3, 0.5, 0),
            Size = fromOffset(3, 34),
            BackgroundColor3 = Theme.Accent,
            BackgroundTransparency = 1,
        })
        corner(sideAccent, 3)
        bindTheme(sideAccent, "BackgroundColor3", function(theme) return theme.Accent end)

        local iconAsset = resolveImage(categoryOptions.Icon, categoryOptions.IconFile)
        local icon = create("ImageLabel", {
            Parent = categoryButton,
            Name = "Icon",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            Size = fromOffset(30, 30),
            BackgroundTransparency = 1,
            Image = iconAsset,
            ImageColor3 = Theme.White,
            ScaleType = Enum.ScaleType.Fit,
            Visible = iconAsset ~= "",
        })

        -- A second aligned pass keeps the thin PNG strokes visibly white after
        -- Roblox downsamples the 512px source to the compact sidebar size.
        -- Both passes are tinted together, so selected icons still use Accent.
        local iconBrightLayer = create("ImageLabel", {
            Parent = categoryButton,
            Name = "IconBrightLayer",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            Size = fromOffset(30, 30),
            BackgroundTransparency = 1,
            Image = iconAsset,
            ImageColor3 = Theme.White,
            ImageTransparency = 0.15,
            ScaleType = Enum.ScaleType.Fit,
            Visible = iconAsset ~= "",
            ZIndex = 2,
        })

        local iconFallback = create("TextLabel", {
            Parent = categoryButton,
            Name = "IconFallback",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            Size = fromOffset(34, 34),
            BackgroundTransparency = 1,
            Text = categoryOptions.Symbol or string.sub(category.Name, 1, 1),
            TextColor3 = Theme.White,
            TextSize = interfaceTextSize(19),
            FontFace = Fonts.Bold,
            Visible = iconAsset == "",
        })

        local tooltip = create("TextLabel", {
            Parent = main,
            Name = category.Name .. "Tooltip",
            AnchorPoint = Vector2.new(0, 0.5),
            Position = fromOffset(sidebarWidth + 10, 0),
            Size = fromOffset(0, 34),
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundColor3 = Theme.ControlBottom,
            BackgroundTransparency = 1,
            Text = category.Name,
            TextColor3 = Theme.Text,
            TextTransparency = 1,
            TextSize = interfaceTextSize(14),
            FontFace = Fonts.Semibold,
            Visible = false,
            ZIndex = 80,
        })
        corner(tooltip, 8)
        local tooltipStroke = stroke(tooltip, Theme.Accent, 1, 1)
        create("UIPadding", {
            Parent = tooltip,
            PaddingLeft = UDim.new(0, 12),
            PaddingRight = UDim.new(0, 12),
        })
        local tooltipScale = create("UIScale", {
            Parent = tooltip,
            Scale = 0.92,
        })
        bindTheme(tooltip, "BackgroundColor3", function(theme) return theme.ControlBottom end)
        bindTheme(tooltipStroke, "Color", function(theme) return theme.Accent end)

        local tooltipRevision = 0

        local function showTooltip()
            tooltipRevision += 1
            local centerY = categoryButton.AbsolutePosition.Y
                - main.AbsolutePosition.Y
                + categoryButton.AbsoluteSize.Y * 0.5

            setProperties(tooltip, {
                Position = fromOffset(sidebarWidth + 10, centerY),
                BackgroundTransparency = 1,
                TextTransparency = 1,
                Visible = true,
            })
            setProperties(tooltipStroke, {Transparency = 1})
            setProperties(tooltipScale, {Scale = 0.92})

            tween(tooltip, {
                BackgroundTransparency = 0.08,
                TextTransparency = 0,
            }, 0.14, Enum.EasingStyle.Quart)
            tween(tooltipStroke, {Transparency = 0.42}, 0.14, Enum.EasingStyle.Quart)
            tween(tooltipScale, {Scale = 1}, 0.18, Enum.EasingStyle.Back)
        end

        local function hideTooltip()
            tooltipRevision += 1
            local revision = tooltipRevision

            tween(tooltip, {
                BackgroundTransparency = 1,
                TextTransparency = 1,
            }, 0.11, Enum.EasingStyle.Quart)
            tween(tooltipStroke, {Transparency = 1}, 0.11, Enum.EasingStyle.Quart)
            tween(tooltipScale, {Scale = 0.96}, 0.11, Enum.EasingStyle.Quart)

            task.delay(0.12, function()
                if tooltipRevision == revision and tooltip.Parent then
                    tooltip.Visible = false
                end
            end)
        end

        category.Button = categoryButton
        category.Accent = sideAccent
        category.AccentGlowOuter = sideAccentGlowOuter
        category.AccentGlowInner = sideAccentGlowInner
        category.Icon = icon
        category.IconBrightLayer = iconBrightLayer
        category.IconFallback = iconFallback
        category.Tooltip = tooltip
        category.TooltipStroke = tooltipStroke
        category.TooltipScale = tooltipScale
        category.Selected = false
        category.Hovered = false
        category.Pressed = false

        window:RegisterGlow(sideAccentGlowOuter, "BackgroundTransparency", 0.94, function()
            return category.Selected
        end)
        window:RegisterGlow(sideAccentGlowInner, "BackgroundTransparency", 0.82, function()
            return category.Selected
        end)

        function category:ApplyTheme(animate)
            local iconColor = self.Selected and Theme.Accent or Theme.White
            if animate == false then
                setProperties(self.Icon, {ImageColor3 = iconColor})
                setProperties(self.IconBrightLayer, {ImageColor3 = iconColor})
                setProperties(self.IconFallback, {TextColor3 = iconColor})
            else
                tween(self.Icon, {ImageColor3 = iconColor}, 0.2, Enum.EasingStyle.Quart)
                tween(self.IconBrightLayer, {ImageColor3 = iconColor}, 0.2, Enum.EasingStyle.Quart)
                tween(self.IconFallback, {TextColor3 = iconColor}, 0.2, Enum.EasingStyle.Quart)
            end
        end

        function category:ApplyInteractionVisual(animate)
            local iconSize = self.Pressed and 27 or (self.Hovered and 34 or 30)
            local fallbackSize = self.Pressed and 31 or (self.Hovered and 38 or 34)
            local iconPosition = UDim2.new(0.5, 0, 0.5, self.Pressed and 2 or 0)
            local backgroundTransparency = self.Selected and 0
                or (self.Hovered and 0.42 or 1)

            if animate == false then
                setProperties(self.Button, {BackgroundTransparency = backgroundTransparency})
                setProperties(self.Icon, {
                    Position = iconPosition,
                    Size = fromOffset(iconSize, iconSize),
                })
                setProperties(self.IconBrightLayer, {
                    Position = iconPosition,
                    Size = fromOffset(iconSize, iconSize),
                })
                setProperties(self.IconFallback, {
                    Position = iconPosition,
                    Size = fromOffset(fallbackSize, fallbackSize),
                })
                return
            end

            local duration = self.Pressed and 0.07 or 0.16
            local easing = self.Pressed and Enum.EasingStyle.Quad or Enum.EasingStyle.Back
            tween(self.Button, {BackgroundTransparency = backgroundTransparency}, 0.14, Enum.EasingStyle.Quart)
            tween(self.Icon, {
                Position = iconPosition,
                Size = fromOffset(iconSize, iconSize),
            }, duration, easing)
            tween(self.IconBrightLayer, {
                Position = iconPosition,
                Size = fromOffset(iconSize, iconSize),
            }, duration, easing)
            tween(self.IconFallback, {
                Position = iconPosition,
                Size = fromOffset(fallbackSize, fallbackSize),
            }, duration, easing)
        end

        function category:SetSelectedVisual(selected)
            self.Selected = selected == true
            tween(self.Accent, {
                BackgroundTransparency = self.Selected and 0 or 1,
            })
            self:ApplyInteractionVisual(true)
            self:ApplyTheme(true)
            self.Window:RefreshGlowVisuals(true)
        end

        onThemeChanged(category, function(_, animate)
            category:ApplyTheme(animate)
        end)

        function category:Select()
            if self.Window.CurrentCategory == self then return end
            self.Window:ClosePopup()

            local previous = self.Window.CurrentCategory
            if previous then
                previous:SetSelectedVisual(false)
                for _, tabObject in previous.Tabs do
                    tabObject.Button.Visible = false
                    tabObject.Page.Visible = false
                end
            end

            self.Window.CurrentCategory = self
            self:SetSelectedVisual(true)

            for _, tabObject in self.Tabs do
                tabObject.Button.Visible = true
            end

            if self.CurrentTab then
                self.CurrentTab:Select(true)
            elseif self.Tabs[1] then
                self.Tabs[1]:Select(true)
            end
        end

        categoryButton.MouseEnter:Connect(function()
            category.Hovered = true
            showTooltip()
            category:ApplyInteractionVisual(true)
        end)

        categoryButton.MouseLeave:Connect(function()
            category.Hovered = false
            category.Pressed = false
            hideTooltip()
            category:ApplyInteractionVisual(true)
        end)

        categoryButton.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                category.Pressed = true
                category:ApplyInteractionVisual(true)
            end
        end)

        categoryButton.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                category.Pressed = false
                category:ApplyInteractionVisual(true)
            end
        end)

        categoryButton.Activated:Connect(function()
            category.Pressed = false
            category:Select()
            category:ApplyInteractionVisual(true)
        end)

        insert(self.Categories, category)

        function category:Tab(tabOptions)
            tabOptions = tabOptions or {}

            local tab = {
                Category = self,
                Window = self.Window,
                Name = tabOptions.Name or "Tab",
                Sections = {},
            }

            local tabButton = create("TextButton", {
                Parent = topTabs,
                Name = tab.Name,
                Size = fromOffset(0, 50),
                AutomaticSize = Enum.AutomaticSize.X,
                BackgroundColor3 = Theme.TabActive,
                BackgroundTransparency = 1,
                AutoButtonColor = false,
                Text = tab.Name,
                TextTransparency = 1,
                TextColor3 = Theme.Muted,
                TextSize = interfaceTextSize(17),
                FontFace = Fonts.Semibold,
                Visible = self.Window.CurrentCategory == self,
                LayoutOrder = tabOptions.Order or (#self.Tabs + 1),
            })
            corner(tabButton, 9)
            bindTheme(tabButton, "BackgroundColor3", function(theme) return theme.TabActive end)
            create("UIPadding", {
                Parent = tabButton,
                PaddingLeft = UDim.new(0, 18),
                PaddingRight = UDim.new(0, 18),
            })

            -- Keep the button's hidden text for AutomaticSize, while the visible
            -- label can animate without changing the top-tab layout.
            local tabLabel = create("TextLabel", {
                Parent = tabButton,
                Name = "AnimatedLabel",
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                Text = tab.Name,
                TextColor3 = Theme.Muted,
                TextSize = interfaceTextSize(17),
                FontFace = Fonts.Semibold,
                ZIndex = 2,
            })
            local tabLabelScale = create("UIScale", {
                Parent = tabLabel,
                Scale = 1,
            })

            local underlineGlowOuter = create("Frame", {
                Parent = tabButton,
                Name = "UnderlineGlowOuter",
                AnchorPoint = Vector2.new(0.5, 1),
                Position = UDim2.new(0.5, 0, 1, 4),
                Size = UDim2.new(1, -8, 0, 11),
                BackgroundColor3 = Theme.Accent,
                BackgroundTransparency = 1,
            })
            corner(underlineGlowOuter, 6)
            bindTheme(underlineGlowOuter, "BackgroundColor3", function(theme) return theme.Accent end)

            local underlineGlowInner = create("Frame", {
                Parent = tabButton,
                Name = "UnderlineGlowInner",
                AnchorPoint = Vector2.new(0.5, 1),
                Position = UDim2.new(0.5, 0, 1, 2),
                Size = UDim2.new(1, -12, 0, 7),
                BackgroundColor3 = Theme.Accent,
                BackgroundTransparency = 1,
            })
            corner(underlineGlowInner, 4)
            bindTheme(underlineGlowInner, "BackgroundColor3", function(theme) return theme.Accent end)

            local underline = create("Frame", {
                Parent = tabButton,
                Name = "Underline",
                AnchorPoint = Vector2.new(0.5, 1),
                Position = UDim2.new(0.5, 0, 1, 0),
                Size = UDim2.new(1, -14, 0, 3),
                BackgroundColor3 = Theme.Accent,
                BackgroundTransparency = 1,
            })
            corner(underline, 3)
            bindTheme(underline, "BackgroundColor3", function(theme) return theme.Accent end)

            local page = create("ScrollingFrame", {
                Parent = content,
                Name = tab.Name .. "Page",
                Position = fromOffset(14, 14),
                Size = UDim2.new(1, -28, 1, -28),
                BackgroundTransparency = 1,
                CanvasSize = fromOffset(0, 0),
                AutomaticCanvasSize = Enum.AutomaticSize.None,
                ScrollingDirection = Enum.ScrollingDirection.Y,
                ScrollBarThickness = 2,
                ScrollBarImageColor3 = Theme.AccentSoft,
                ScrollBarImageTransparency = 0.25,
                Visible = false,
            })
            bindTheme(page, "ScrollBarImageColor3", function(theme) return theme.AccentSoft end)

            local leftColumn = create("Frame", {
                Parent = page,
                Name = "LeftColumn",
                Size = UDim2.new(0.5, -6, 0, 0),
                BackgroundTransparency = 1,
            })
            local leftLayout = create("UIListLayout", {
                Parent = leftColumn,
                Padding = UDim.new(0, 12),
                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                SortOrder = Enum.SortOrder.LayoutOrder,
            })

            local rightColumn = create("Frame", {
                Parent = page,
                Name = "RightColumn",
                Position = UDim2.new(0.5, 6, 0, 0),
                Size = UDim2.new(0.5, -6, 0, 0),
                BackgroundTransparency = 1,
            })
            local rightLayout = create("UIListLayout", {
                Parent = rightColumn,
                Padding = UDim.new(0, 12),
                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                SortOrder = Enum.SortOrder.LayoutOrder,
            })

            local function refreshPageCanvas()
                task.defer(function()
                    if not page.Parent then return end

                    local leftHeight = leftLayout.AbsoluteContentSize.Y + 14
                    local rightHeight = rightLayout.AbsoluteContentSize.Y + 14

                    if page.AbsoluteSize.X < 620 then
                        leftColumn.Position = fromOffset(0, 0)
                        leftColumn.Size = UDim2.new(1, -4, 0, leftHeight)
                        rightColumn.Position = fromOffset(0, leftHeight + 12)
                        rightColumn.Size = UDim2.new(1, -4, 0, rightHeight)
                        page.CanvasSize = fromOffset(0, leftHeight + rightHeight + 12)
                    else
                        leftColumn.Position = fromOffset(0, 0)
                        leftColumn.Size = UDim2.new(0.5, -6, 0, leftHeight)
                        rightColumn.Position = UDim2.new(0.5, 6, 0, 0)
                        rightColumn.Size = UDim2.new(0.5, -6, 0, rightHeight)
                        page.CanvasSize = fromOffset(0, max(leftHeight, rightHeight))
                    end
                end)
            end

            connect(leftLayout:GetPropertyChangedSignal("AbsoluteContentSize"), refreshPageCanvas)
            connect(rightLayout:GetPropertyChangedSignal("AbsoluteContentSize"), refreshPageCanvas)
            connect(page:GetPropertyChangedSignal("AbsoluteSize"), refreshPageCanvas)
            connect(page:GetPropertyChangedSignal("CanvasPosition"), function()
                window:ClosePopup()
            end)

            tab.Button = tabButton
            tab.Label = tabLabel
            tab.LabelScale = tabLabelScale
            tab.Underline = underline
            tab.UnderlineGlowOuter = underlineGlowOuter
            tab.UnderlineGlowInner = underlineGlowInner
            tab.Page = page
            tab.Columns = {leftColumn, rightColumn}
            tab.RefreshCanvas = refreshPageCanvas
            tab.Selected = false
            tab.Hovered = false
            tab.Pressed = false

            window:RegisterGlow(underlineGlowOuter, "BackgroundTransparency", 0.94, function()
                return tab.Selected
            end)
            window:RegisterGlow(underlineGlowInner, "BackgroundTransparency", 0.82, function()
                return tab.Selected
            end)

            function tab:ApplyTheme(animate)
                local textColor = self.Selected and Theme.Accent or Theme.Muted
                if animate == false then
                    setProperties(self.Label, {TextColor3 = textColor})
                else
                    tween(self.Label, {TextColor3 = textColor}, 0.2, Enum.EasingStyle.Quart)
                end
            end

            function tab:ApplyInteractionVisual(animate)
                local labelScale = self.Pressed and 0.93 or (self.Hovered and 1.06 or 1)
                local labelPosition = UDim2.new(0.5, 0, 0.5, self.Pressed and 2 or 0)
                local backgroundTransparency = self.Selected and 0
                    or (self.Hovered and 0.42 or 1)

                if animate == false then
                    setProperties(self.Button, {BackgroundTransparency = backgroundTransparency})
                    setProperties(self.Label, {Position = labelPosition})
                    setProperties(self.LabelScale, {Scale = labelScale})
                    return
                end

                local duration = self.Pressed and 0.07 or 0.16
                local easing = self.Pressed and Enum.EasingStyle.Quad or Enum.EasingStyle.Back
                tween(self.Button, {BackgroundTransparency = backgroundTransparency}, 0.14, Enum.EasingStyle.Quart)
                tween(self.Label, {Position = labelPosition}, duration, easing)
                tween(self.LabelScale, {Scale = labelScale}, duration, easing)
            end

            function tab:SetSelectedVisual(selected)
                self.Selected = selected == true
                tween(self.Underline, {
                    BackgroundTransparency = self.Selected and 0 or 1,
                })
                self:ApplyInteractionVisual(true)
                self:ApplyTheme(true)
                self.Window:RefreshGlowVisuals(true)
            end

            onThemeChanged(tab, function(_, animate)
                tab:ApplyTheme(animate)
            end)

            function tab:Select(force)
                if self.Category.CurrentTab == self and not force then return end
                self.Window:ClosePopup()

                local previous = self.Category.CurrentTab
                if previous and previous ~= self then
                    previous.Page.Visible = false
                    previous:SetSelectedVisual(false)
                end

                self.Category.CurrentTab = self
                self.Page.Visible = true
                self:SetSelectedVisual(true)
            end

            tabButton.MouseEnter:Connect(function()
                tab.Hovered = true
                tab:ApplyInteractionVisual(true)
            end)

            tabButton.MouseLeave:Connect(function()
                tab.Hovered = false
                tab.Pressed = false
                tab:ApplyInteractionVisual(true)
            end)

            tabButton.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.Touch then
                    tab.Pressed = true
                    tab:ApplyInteractionVisual(true)
                end
            end)

            tabButton.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.Touch then
                    tab.Pressed = false
                    tab:ApplyInteractionVisual(true)
                end
            end)

            connect(tabButton:GetPropertyChangedSignal("Visible"), function()
                if not tabButton.Visible then
                    tab.Hovered = false
                    tab.Pressed = false
                    tab:ApplyInteractionVisual(false)
                end
            end)

            tabButton.Activated:Connect(function()
                tab.Pressed = false
                tab:Select()
                tab:ApplyInteractionVisual(true)
            end)

            insert(self.Tabs, tab)

            function tab:Section(sectionOptions)
                sectionOptions = sectionOptions or {}
                local columnIndex = clamp(sectionOptions.Column or 1, 1, 2)
                local parentColumn = self.Columns[columnIndex]

                local sectionObject = setmetatable({
                    Tab = self,
                    Window = self.Window,
                    Name = sectionOptions.Name or "Section",
                    Items = {},
                }, SectionMethods)

                local sectionFrame = create("Frame", {
                    Parent = parentColumn,
                    Name = sectionObject.Name,
                    Size = UDim2.new(1, -4, 0, 90),
                    BackgroundTransparency = 1,
                    ClipsDescendants = false,
                    LayoutOrder = sectionOptions.Order or (#self.Sections + 1),
                })

                local cardSurface = create("Frame", {
                    Parent = sectionFrame,
                    Name = "Surface",
                    Size = UDim2.fromScale(1, 1),
                    BackgroundColor3 = Theme.Card,
                    ClipsDescendants = true,
                })
                corner(cardSurface, 12)
                local cardStroke = stroke(cardSurface, rgb(7, 132, 255), 0.68, 1)
                bindTheme(cardStroke, "Color", function(theme)
                    return theme.Accent
                end)
                gradient(cardSurface, Theme.Card, Theme.CardBottom, 90)

                local cardHighlight = create("Frame", {
                    Parent = cardSurface,
                    Name = "TopLeftHighlight",
                    Size = UDim2.fromScale(1, 1),
                    BackgroundColor3 = Theme.White,
                })
                corner(cardHighlight, 12)
                local cardHighlightGradient = create("UIGradient", {
                    Parent = cardHighlight,
                    Rotation = 32,
                    Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Theme.AccentLight),
                        ColorSequenceKeypoint.new(0.46, Theme.Card),
                        ColorSequenceKeypoint.new(1, Theme.CardBottom),
                    }),
                    Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 0.86),
                        NumberSequenceKeypoint.new(0.38, 0.955),
                        NumberSequenceKeypoint.new(0.72, 0.99),
                        NumberSequenceKeypoint.new(1, 1),
                    }),
                })
                bindTheme(cardHighlightGradient, "Color", function(theme)
                    return ColorSequence.new({
                        ColorSequenceKeypoint.new(0, theme.AccentLight),
                        ColorSequenceKeypoint.new(0.46, theme.Card),
                        ColorSequenceKeypoint.new(1, theme.CardBottom),
                    })
                end, true)

                local title = create("TextLabel", {
                    Parent = cardSurface,
                    Name = "Title",
                    Position = fromOffset(20, 16),
                    Size = UDim2.new(1, -40, 0, 26),
                    BackgroundTransparency = 1,
                    Text = sectionObject.Name,
                    TextColor3 = Theme.Text,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextSize = interfaceTextSize(19),
                    FontFace = Fonts.Bold,
                })

                local titleWidth = min(260, max(92, 34 + #sectionObject.Name * 8))
                local titleAccentGlowOuter = create("Frame", {
                    Parent = cardSurface,
                    Name = "TitleAccentGlowOuter",
                    Position = fromOffset(18, 45),
                    Size = fromOffset(titleWidth + 4, 14),
                    BackgroundColor3 = Theme.Accent,
                    BackgroundTransparency = 1,
                })
                corner(titleAccentGlowOuter, 7)
                bindTheme(titleAccentGlowOuter, "BackgroundColor3", function(theme) return theme.Accent end)

                local titleAccentGlowInner = create("Frame", {
                    Parent = cardSurface,
                    Name = "TitleAccentGlowInner",
                    Position = fromOffset(19, 48),
                    Size = fromOffset(titleWidth + 2, 8),
                    BackgroundColor3 = Theme.Accent,
                    BackgroundTransparency = 1,
                })
                corner(titleAccentGlowInner, 4)
                bindTheme(titleAccentGlowInner, "BackgroundColor3", function(theme) return theme.Accent end)

                local titleAccent = create("Frame", {
                    Parent = cardSurface,
                    Name = "TitleAccent",
                    Position = fromOffset(20, 50),
                    Size = fromOffset(titleWidth, 4),
                    BackgroundColor3 = Theme.Accent,
                })
                corner(titleAccent, 4)
                bindTheme(titleAccent, "BackgroundColor3", function(theme) return theme.Accent end)
                window:RegisterGlow(titleAccentGlowOuter, "BackgroundTransparency", 0.94)
                window:RegisterGlow(titleAccentGlowInner, "BackgroundTransparency", 0.82)

                local elements = create("Frame", {
                    Parent = cardSurface,
                    Name = "Elements",
                    Position = fromOffset(20, 70),
                    Size = UDim2.new(1, -40, 0, 0),
                    BackgroundTransparency = 1,
                })
                local elementsLayout = create("UIListLayout", {
                    Parent = elements,
                    Padding = UDim.new(0, 12),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                })

                sectionObject.Frame = sectionFrame
                sectionObject.Surface = cardSurface
                sectionObject.Title = title
                sectionObject.TitleAccent = titleAccent
                sectionObject.TitleAccentGlowOuter = titleAccentGlowOuter
                sectionObject.TitleAccentGlowInner = titleAccentGlowInner
                sectionObject.Content = elements
                sectionObject.Layout = elementsLayout

                function sectionObject:MeasureContentHeight()
                    local visibleRows = 0
                    local measuredHeight = 0

                    for _, item in self.Items do
                        local row = item.Row
                        if row and row.Parent == self.Content and row.Visible then
                            local rowHeight = row.Size.Y.Offset
                                + (self.Content.AbsoluteSize.Y * row.Size.Y.Scale)
                            measuredHeight += max(row.AbsoluteSize.Y, rowHeight)
                            visibleRows += 1
                        end
                    end

                    if visibleRows > 1 then
                        local padding = self.Layout.Padding
                        measuredHeight += (visibleRows - 1)
                            * (padding.Offset + self.Content.AbsoluteSize.Y * padding.Scale)
                    end

                    return measuredHeight
                end

                function sectionObject:Refresh()
                    task.defer(function()
                        if not self.Frame.Parent then return end

                        -- Some executor builds update UIListLayout.AbsoluteContentSize one
                        -- frame late. Measure registered rows as a deterministic fallback so
                        -- newly-added controls are never clipped by the card surface.
                        local contentHeight = max(
                            self.Layout.AbsoluteContentSize.Y,
                            self:MeasureContentHeight()
                        )
                        self.Content.Size = UDim2.new(1, -40, 0, contentHeight)
                        self.Frame.Size = UDim2.new(1, -4, 0, 90 + contentHeight)
                        self.Tab:RefreshCanvas()
                    end)
                end

                connect(elementsLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
                    sectionObject:Refresh()
                end)

                function sectionObject:Register(row, searchText)
                    local item = {
                        Row = row,
                        Text = string.lower(searchText or ""),
                        ManualVisible = true,
                        FilterVisible = true,
                    }
                    insert(self.Items, item)
                    self:Refresh()
                    return item
                end

                function sectionObject:ApplySearch(query)
                    if query == "" then
                        self.Frame.Visible = true
                        for _, item in self.Items do
                            item.FilterVisible = true
                            item.Row.Visible = item.ManualVisible
                        end
                        self:Refresh()
                        return
                    end

                    local sectionMatch = string.find(string.lower(self.Name), query, 1, true) ~= nil
                    local visibleItems = 0

                    for _, item in self.Items do
                        local matches = sectionMatch or string.find(item.Text, query, 1, true) ~= nil
                        item.FilterVisible = matches
                        item.Row.Visible = item.ManualVisible and matches
                        if item.Row.Visible then visibleItems += 1 end
                    end

                    self.Frame.Visible = sectionMatch or visibleItems > 0
                    self:Refresh()
                end

                function sectionObject:NextFlag(provided)
                    if provided and (self.Window.Setters[provided] or Library.Setters[provided]) then
                        warn("[TRust Menu] Duplicate flag '" .. tostring(provided) .. "'; generated a unique flag instead.")
                        return Library:NextFlag()
                    end
                    return provided or Library:NextFlag()
                end

                insert(self.Sections, sectionObject)
                insert(self.Window.SearchSections, sectionObject)
                sectionObject:Refresh()
                return sectionObject
            end

            tab.AddSection = tab.Section

            if not self.CurrentTab then
                self.CurrentTab = tab
                if self.Window.CurrentCategory == self then
                    tab:Select(true)
                end
            end

            return tab
        end

        category.AddTab = category.Tab

        if not self.CurrentCategory then
            self.CurrentCategory = category
            category:SetSelectedVisual(true)
        end

        return category
    end

    window.AddCategory = window.Category

    return window
end

local function controlSearchText(options)
    local parts = {
        tostring(options.Text or options.Name or ""),
        tostring(options.Description or ""),
    }

    if type(options.Keywords) == "table" then
        for _, keyword in options.Keywords do
            insert(parts, tostring(keyword))
        end
    elseif options.Keywords then
        insert(parts, tostring(options.Keywords))
    end

    return table.concat(parts, " ")
end

local function registerSetter(section, flag, setter)
    section.Window.Setters[flag] = setter
    Library.Setters[flag] = setter
    return setter
end

local function connectControl(control, signal, callback)
    local connection = connect(signal, callback)
    insert(control.Connections, connection)
    return connection
end

local function setControlVisible(control, value)
    if control.Destroyed then return end
    local manuallyVisible = value ~= false
    if control.SearchItem then
        control.SearchItem.ManualVisible = manuallyVisible
        control.Row.Visible = manuallyVisible and control.SearchItem.FilterVisible
    else
        control.Row.Visible = manuallyVisible
    end

    if control.Section.Window.SearchQuery ~= "" then
        control.Section:ApplySearch(control.Section.Window.SearchQuery)
    else
        control.Section:Refresh()
    end
end

local function unregisterControl(control)
    if control.Destroyed then return end
    control.Destroyed = true

    if control.Section.Window.CapturingKeybind == control then
        control.Section.Window.CapturingKeybind = nil
    end

    for _, connection in control.Connections or {} do
        disconnectTracked(connection)
    end

    for index = #Library.ThemeListeners, 1, -1 do
        if Library.ThemeListeners[index].Owner == control then
            table.remove(Library.ThemeListeners, index)
        end
    end

    if control.Flag and control.Setter then
        if control.Section.Window.Setters[control.Flag] == control.Setter then
            control.Section.Window.Setters[control.Flag] = nil
        end
        if Library.Setters[control.Flag] == control.Setter then
            Library.Setters[control.Flag] = nil
        end
    end

    for index = #control.Section.Items, 1, -1 do
        if control.Section.Items[index] == control.SearchItem then
            table.remove(control.Section.Items, index)
            break
        end
    end

    if control.Row and control.Row.Parent then
        control.Row:Destroy()
    end
    if control.Section.Window.SearchQuery ~= "" then
        control.Section:ApplySearch(control.Section.Window.SearchQuery)
    else
        control.Section:Refresh()
    end
end

function SectionMethods:AddToggle(options)
    options = options or {}
    local text = options.Text or options.Name or "Toggle"
    local callback = options.Callback or options.OnChanged
    local flag = self:NextFlag(options.Flag)
    local defaultState = options.Default == true

    local row = create("TextButton", {
        Parent = self.Content,
        Name = text,
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Text = "",
        LayoutOrder = options.Order or (#self.Items + 1),
    })

    local label = create("TextLabel", {
        Parent = row,
        Size = UDim2.new(1, -78, 1, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Theme.Muted,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextSize = interfaceTextSize(15),
        FontFace = Fonts.Regular,
    })

    local switchGlow = create("Frame", {
        Parent = row,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 2, 0.5, 0),
        Size = fromOffset(58, 34),
        BackgroundColor3 = Theme.Accent,
        BackgroundTransparency = 1,
        ZIndex = 1,
    })
    corner(switchGlow, 17)

    local switch = create("Frame", {
        Parent = row,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = fromOffset(52, 28),
        BackgroundColor3 = Theme.Track,
        ZIndex = 2,
    })
    corner(switch, 14)
    local switchStroke = stroke(switch, Theme.Border, 0.1, 1)

    local knob = create("Frame", {
        Parent = switch,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 4, 0.5, 0),
        Size = fromOffset(20, 20),
        BackgroundTransparency = 1,
        ZIndex = 3,
    })

    local knobShadowOuter = create("Frame", {
        Parent = knob,
        Name = "KnobShadowOuter",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 1),
        Size = UDim2.new(1, 10, 1, 10),
        BackgroundColor3 = Theme.Shadow,
        BackgroundTransparency = 0.92,
        ZIndex = 4,
    })
    corner(knobShadowOuter, 15)

    local knobShadowMiddle = create("Frame", {
        Parent = knob,
        Name = "KnobShadowMiddle",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 1),
        Size = UDim2.new(1, 6, 1, 6),
        BackgroundColor3 = Theme.Shadow,
        BackgroundTransparency = 0.86,
        ZIndex = 4,
    })
    corner(knobShadowMiddle, 13)

    local knobShadowInner = create("Frame", {
        Parent = knob,
        Name = "KnobShadowInner",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 1),
        Size = UDim2.new(1, 2, 1, 2),
        BackgroundColor3 = Theme.Shadow,
        BackgroundTransparency = 0.74,
        ZIndex = 4,
    })
    corner(knobShadowInner, 11)

    local knobFace = create("Frame", {
        Parent = knob,
        Name = "KnobFace",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.White,
        ZIndex = 5,
    })
    corner(knobFace, 10)
    local knobStroke = stroke(knobFace, Theme.Border:Lerp(Theme.White, 0.48), 0.22, 1)
    create("UIGradient", {
        Parent = knobFace,
        Rotation = 90,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, rgb(255, 255, 255)),
            ColorSequenceKeypoint.new(0.52, rgb(249, 250, 252)),
            ColorSequenceKeypoint.new(1, rgb(231, 235, 240)),
        }),
    })

    local knobHighlight = create("Frame", {
        Parent = knobFace,
        Name = "KnobHighlight",
        Position = fromOffset(3, 2),
        Size = UDim2.new(1, -7, 0, 7),
        BackgroundColor3 = Theme.White,
        BackgroundTransparency = 0.58,
        ZIndex = 6,
    })
    corner(knobHighlight, 7)
    create("UIGradient", {
        Parent = knobHighlight,
        Rotation = 0,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.08),
            NumberSequenceKeypoint.new(1, 0.82),
        }),
    })

    local control = {
        Section = self,
        Row = row,
        Label = label,
        Switch = switch,
        SwitchStroke = switchStroke,
        Glow = switchGlow,
        Knob = knob,
        KnobShadows = {knobShadowOuter, knobShadowMiddle, knobShadowInner},
        KnobFace = knobFace,
        KnobStroke = knobStroke,
        KnobHighlight = knobHighlight,
        Flag = flag,
        Value = defaultState,
        Initialized = false,
    }

    function control:ApplyTheme(animate)
        local switchColor = self.Value and Theme.Accent or Theme.Track
        local strokeColor = self.Value and Theme.AccentSoft or Theme.Border
        local labelColor = self.Value and Theme.Text or Theme.Muted
        local knobStrokeColor = Theme.Border:Lerp(Theme.White, 0.48)

        if animate then
            tween(self.Switch, {BackgroundColor3 = switchColor}, 0.18, Enum.EasingStyle.Quart)
            tween(self.SwitchStroke, {Color = strokeColor}, 0.18, Enum.EasingStyle.Quart)
            tween(self.Label, {TextColor3 = labelColor}, 0.18, Enum.EasingStyle.Quart)
            tween(self.Glow, {BackgroundColor3 = Theme.Accent}, 0.18, Enum.EasingStyle.Quart)
            for _, shadow in self.KnobShadows do
                tween(shadow, {BackgroundColor3 = Theme.Shadow}, 0.18, Enum.EasingStyle.Quart)
            end
            tween(self.KnobStroke, {Color = knobStrokeColor}, 0.18, Enum.EasingStyle.Quart)
        else
            setProperties(self.Switch, {BackgroundColor3 = switchColor})
            setProperties(self.SwitchStroke, {Color = strokeColor})
            setProperties(self.Label, {TextColor3 = labelColor})
            setProperties(self.Glow, {BackgroundColor3 = Theme.Accent})
            for _, shadow in self.KnobShadows do
                setProperties(shadow, {BackgroundColor3 = Theme.Shadow})
            end
            setProperties(self.KnobStroke, {Color = knobStrokeColor})
        end
    end

    function control:ApplyVisual(animate)
        self:ApplyTheme(animate)
        local knobPosition = UDim2.new(0, self.Value and 28 or 4, 0.5, 0)
        local glowTransparency = self.Value and 0.82 or 1
        local shadowTransparency = self.Value
            and {0.89, 0.82, 0.7}
            or {0.93, 0.87, 0.76}

        if animate then
            tween(self.Glow, {BackgroundTransparency = glowTransparency}, 0.18, Enum.EasingStyle.Quart)
            tween(self.Knob, {Position = knobPosition}, 0.22, Enum.EasingStyle.Quint)
            for index, shadow in self.KnobShadows do
                tween(shadow, {BackgroundTransparency = shadowTransparency[index]}, 0.2, Enum.EasingStyle.Quart)
            end
        else
            setProperties(self.Glow, {BackgroundTransparency = glowTransparency})
            setProperties(self.Knob, {Position = knobPosition})
            for index, shadow in self.KnobShadows do
                setProperties(shadow, {BackgroundTransparency = shadowTransparency[index]})
            end
        end
    end

    function control:Set(value, emit)
        if self.Destroyed then return self.Value end
        local nextValue = value == true
        local changed = self.Value ~= nextValue
        self.Value = nextValue
        self.Section.Window.Flags[self.Flag] = self.Value
        Library.Flags[self.Flag] = self.Value
        self:ApplyVisual(self.Initialized)
        self.Initialized = true

        if emit and changed and callback then safeCallback(callback, self.Value) end
        return self.Value
    end

    function control:Get()
        return self.Value
    end

    function control:SetText(value)
        label.Text = tostring(value)
    end

    function control:SetVisible(value)
        setControlVisible(self, value)
    end

    function control:Destroy()
        unregisterControl(self)
    end

    row.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            tween(knob, {Size = fromOffset(23, 23)}, 0.08, Enum.EasingStyle.Sine)
            tween(switchGlow, {Size = fromOffset(62, 38)}, 0.08, Enum.EasingStyle.Sine)
        end
    end)

    row.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            tween(knob, {Size = fromOffset(20, 20)}, 0.16, Enum.EasingStyle.Back)
            tween(switchGlow, {Size = fromOffset(58, 34)}, 0.16, Enum.EasingStyle.Back)
        end
    end)

    row.Activated:Connect(function()
        control:Set(not control.Value, true)
    end)

    onThemeChanged(control, function(_, animate)
        control:ApplyTheme(animate)
    end)

    control.SearchItem = self:Register(row, controlSearchText(options))
    control.Setter = registerSetter(self, flag, function(value, emit)
        return control:Set(value, emit)
    end)
    control:Set(defaultState, false)
    self:Refresh()
    return control
end

function SectionMethods:AddSlider(options)
    options = options or {}
    local text = options.Text or options.Name or "Slider"
    local callback = options.Callback or options.OnChanged
    local minimum = tonumber(options.Min) or 0
    local maximum = tonumber(options.Max) or 100
    if maximum < minimum then
        minimum, maximum = maximum, minimum
    end
    if maximum == minimum then maximum = minimum + 1 end

    local step = math.abs(tonumber(options.Step) or 1)
    if step == 0 then step = 1 end
    local flag = self:NextFlag(options.Flag)
    local dragging = false
    local activeTouch = nil

    local row = create("Frame", {
        Parent = self.Content,
        Name = text,
        Size = UDim2.new(1, 0, 0, 68),
        BackgroundTransparency = 1,
        LayoutOrder = options.Order or (#self.Items + 1),
    })

    local label = create("TextLabel", {
        Parent = row,
        Size = UDim2.new(1, -94, 0, 25),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextSize = interfaceTextSize(15),
        FontFace = Fonts.Regular,
    })

    local valueLabel = create("TextLabel", {
        Parent = row,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = fromOffset(90, 25),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextSize = interfaceTextSize(15),
        FontFace = Fonts.Regular,
    })

    local hitbox = create("TextButton", {
        Parent = row,
        Position = fromOffset(0, 32),
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Text = "",
    })

    local rail = create("Frame", {
        Parent = hitbox,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(1, 0, 0, 8),
        BackgroundColor3 = Theme.Track,
    })
    corner(rail, 6)

    local fill = create("Frame", {
        Parent = rail,
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = Theme.White,
    })
    corner(fill, 6)

    local fillGradient = gradient(fill, Theme.Accent, Theme.AccentLight, 0)

    local thumbGlow = create("Frame", {
        Parent = rail,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = fromOffset(30, 30),
        BackgroundColor3 = Theme.Accent,
        BackgroundTransparency = 0.84,
        ZIndex = 2,
    })
    corner(thumbGlow, 15)

    local knob = create("Frame", {
        Parent = thumbGlow,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = fromOffset(18, 18),
        BackgroundColor3 = Theme.White,
        ZIndex = 3,
    })
    corner(knob, 9)
    local knobStroke = stroke(knob, Theme.AccentSoft, 0.1, 1)

    local control = {
        Section = self,
        Row = row,
        Label = label,
        ValueLabel = valueLabel,
        Hitbox = hitbox,
        Rail = rail,
        Fill = fill,
        FillGradient = fillGradient,
        Glow = thumbGlow,
        Knob = knob,
        KnobStroke = knobStroke,
        Flag = flag,
        Value = minimum,
        Connections = {},
        Initialized = false,
    }

    local function snap(value)
        local stepped = minimum + floor(((value - minimum) / step) + 0.5) * step
        return clamp(stepped, minimum, maximum)
    end

    local function formatValue(value)
        if type(options.Format) == "function" then
            local ok, result = pcall(options.Format, value)
            if ok then return tostring(result) end
        elseif type(options.Format) == "string" then
            local ok, result = pcall(string.format, options.Format, value)
            if ok then return result end
        end

        local display = step % 1 == 0 and tostring(floor(value + 0.5))
            or string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", "")
        return display .. tostring(options.Suffix or "")
    end

    function control:ApplyTheme()
        setProperties(self.FillGradient, {Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Theme.Accent),
            ColorSequenceKeypoint.new(1, Theme.AccentLight),
        })})
        setProperties(self.Glow, {BackgroundColor3 = Theme.Accent})
        setProperties(self.KnobStroke, {Color = Theme.AccentSoft})
        setProperties(self.ValueLabel, {TextColor3 = dragging and Theme.AccentLight or Theme.Text})
    end

    function control:Set(value, emit, animate, visualRatio)
        if self.Destroyed then return self.Value end
        value = snap(tonumber(value) or minimum)
        local changed = self.Value ~= value
        self.Value = value
        self.Section.Window.Flags[self.Flag] = value
        Library.Flags[self.Flag] = value

        local ratio = visualRatio or ((value - minimum) / (maximum - minimum))
        local fillSize = UDim2.new(ratio, 0, 1, 0)
        local thumbPosition = UDim2.new(ratio, 0, 0.5, 0)
        local shouldAnimate = self.Initialized and animate ~= false
        if shouldAnimate then
            tween(self.Fill, {Size = fillSize}, 0.16, Enum.EasingStyle.Quart)
            tween(self.Glow, {Position = thumbPosition}, 0.16, Enum.EasingStyle.Quart)
        else
            setProperties(self.Fill, {Size = fillSize})
            setProperties(self.Glow, {Position = thumbPosition})
        end
        self.ValueLabel.Text = formatValue(value)
        self:ApplyTheme()
        self.Initialized = true

        if emit and changed and callback then safeCallback(callback, value) end
        return value
    end

    function control:Get()
        return self.Value
    end

    function control:SetText(value)
        label.Text = tostring(value)
    end

    function control:SetVisible(value)
        setControlVisible(self, value)
    end

    function control:Destroy()
        unregisterControl(self)
    end

    local function setFromPointer(pointerX)
        local railWidth = max(1, rail.AbsoluteSize.X)
        local ratio = clamp((pointerX - rail.AbsolutePosition.X) / railWidth, 0, 1)
        control:Set(minimum + (maximum - minimum) * ratio, true, false, ratio)
    end

    hitbox.MouseEnter:Connect(function()
        if not dragging then tween(thumbGlow, {Size = fromOffset(33, 33)}, 0.1, Enum.EasingStyle.Sine) end
    end)
    hitbox.MouseLeave:Connect(function()
        if not dragging then tween(thumbGlow, {Size = fromOffset(30, 30)}, 0.12, Enum.EasingStyle.Sine) end
    end)

    hitbox.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            activeTouch = input.UserInputType == Enum.UserInputType.Touch and input or nil
            tween(thumbGlow, {
                Size = fromOffset(36, 36),
                BackgroundTransparency = 0.72,
            }, 0.1, Enum.EasingStyle.Back)
            tween(knob, {Size = fromOffset(21, 21)}, 0.1, Enum.EasingStyle.Back)
            valueLabel.TextColor3 = Theme.AccentLight
            setFromPointer(input.Position.X)
        end
    end)

    connectControl(control, UserInputService.InputChanged, function(input)
        local validMouse = input.UserInputType == Enum.UserInputType.MouseMovement and activeTouch == nil
        local validTouch = activeTouch ~= nil and input == activeTouch
        if dragging and (validMouse or validTouch) then
            setFromPointer(input.Position.X)
        end
    end)

    connectControl(control, UserInputService.InputEnded, function(input)
        local mouseEnded = input.UserInputType == Enum.UserInputType.MouseButton1 and activeTouch == nil
        local touchEnded = activeTouch ~= nil and input == activeTouch
        if dragging and (mouseEnded or touchEnded) then
            dragging = false
            activeTouch = nil
            local ratio = (control.Value - minimum) / (maximum - minimum)
            tween(fill, {Size = UDim2.new(ratio, 0, 1, 0)}, 0.12, Enum.EasingStyle.Quart)
            tween(thumbGlow, {Position = UDim2.new(ratio, 0, 0.5, 0)}, 0.12, Enum.EasingStyle.Quart)
            tween(thumbGlow, {
                Size = fromOffset(30, 30),
                BackgroundTransparency = 0.84,
            }, 0.16, Enum.EasingStyle.Back)
            tween(knob, {Size = fromOffset(18, 18)}, 0.16, Enum.EasingStyle.Back)
            valueLabel.TextColor3 = Theme.Text
        end
    end)

    onThemeChanged(control, function()
        control:ApplyTheme()
    end)

    local defaultValue = options.Default
    if defaultValue == nil then defaultValue = minimum end
    control.SearchItem = self:Register(row, controlSearchText(options))
    control.Setter = registerSetter(self, flag, function(value, emit)
        return control:Set(value, emit)
    end)
    control:Set(defaultValue, false, false)
    self:Refresh()
    return control
end

function SectionMethods:AddDropdown(options)
    options = options or {}
    local text = options.Text or options.Name or "Dropdown"
    local callback = options.Callback or options.OnChanged
    local flag = self:NextFlag(options.Flag)
    local values = options.Values or options.Options or {}

    local row = create("Frame", {
        Parent = self.Content,
        Name = text,
        Size = UDim2.new(1, 0, 0, 82),
        BackgroundTransparency = 1,
        LayoutOrder = options.Order or (#self.Items + 1),
    })

    local label = create("TextLabel", {
        Parent = row,
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextSize = interfaceTextSize(15),
        FontFace = Fonts.Regular,
    })

    local field = create("TextButton", {
        Parent = row,
        Position = fromOffset(0, 35),
        Size = UDim2.new(1, 0, 0, 43),
        BackgroundColor3 = Theme.Control,
        AutoButtonColor = false,
        Text = "",
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextSize = interfaceTextSize(15),
        FontFace = Fonts.Regular,
    })
    corner(field, 7)
    stroke(field, Theme.Border, 0.15, 1)
    gradient(field, Theme.Control, Theme.ControlBottom, 90)
    create("UIPadding", {
        Parent = field,
        PaddingLeft = UDim.new(0, 14),
        PaddingRight = UDim.new(0, 40),
    })

    local arrow = create("TextLabel", {
        Parent = field,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -13, 0.5, 0),
        Size = fromOffset(22, 22),
        BackgroundTransparency = 1,
        Text = "v",
        TextColor3 = Theme.Muted,
        TextSize = interfaceTextSize(16),
        FontFace = Fonts.Bold,
        ZIndex = 3,
    })

    local popup = create("ScrollingFrame", {
        Parent = self.Window.PopupLayer,
        Name = text .. "Options",
        Size = fromOffset(200, 80),
        BackgroundColor3 = Theme.Card,
        CanvasSize = fromOffset(0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = Theme.Accent,
        Visible = false,
        ZIndex = 100,
    })
    bindTheme(popup, "ScrollBarImageColor3", function(theme) return theme.Accent end)
    corner(popup, 7)
    stroke(popup, Theme.Border, 0, 1)
    create("UIPadding", {
        Parent = popup,
        PaddingTop = UDim.new(0, 4),
        PaddingBottom = UDim.new(0, 4),
        PaddingLeft = UDim.new(0, 4),
        PaddingRight = UDim.new(0, 4),
    })
    create("UIListLayout", {
        Parent = popup,
        Padding = UDim.new(0, 3),
        SortOrder = Enum.SortOrder.LayoutOrder,
    })

    local control = {
        Section = self,
        Window = self.Window,
        Row = row,
        Label = label,
        Field = field,
        Popup = popup,
        Arrow = arrow,
        Flag = flag,
        Values = values,
        Value = nil,
        IsOpen = false,
    }

    function control:Set(value, emit)
        if self.Destroyed then return self.Value end
        self.Value = value
        self.Field.Text = value == nil and tostring(options.Placeholder or "Select...") or tostring(value)
        self.Section.Window.Flags[self.Flag] = value
        Library.Flags[self.Flag] = value

        if emit and callback then
            safeCallback(callback, value)
        end
        return value
    end

    function control:Get()
        return self.Value
    end

    function control:Close()
        self.IsOpen = false
        if self.Popup and self.Popup.Parent then self.Popup.Visible = false end
        if self.Arrow and self.Arrow.Parent then self.Arrow.Text = "v" end
        if self.Window.OpenPopup == self then
            self.Window.OpenPopup = nil
        end
    end

    function control:Open()
        if self.Destroyed then return end
        self.Window:ClosePopup(self)
        self.IsOpen = true

        local activeCamera = Workspace.CurrentCamera or Camera
        local viewportSize = activeCamera and activeCamera.ViewportSize or Vector2.new(1920, 1080)
        local width = max(180, self.Field.AbsoluteSize.X)
        local height = min(184, max(42, #self.Values * 37 + 8))
        local x = clamp(self.Field.AbsolutePosition.X, 8, max(8, viewportSize.X - width - 8))
        local y = self.Field.AbsolutePosition.Y + self.Field.AbsoluteSize.Y + 4
        if y + height > viewportSize.Y - 8 then
            y = self.Field.AbsolutePosition.Y - height - 4
        end
        y = clamp(y, 8, max(8, viewportSize.Y - height - 8))

        self.Popup.Position = fromOffset(x, y)
        self.Popup.Size = fromOffset(width, height)
        self.Popup.Visible = true
        self.Arrow.Text = "^"
        self.Window.OpenPopup = self
    end

    function control:SetValues(newValues, keepValue)
        if self.Destroyed then return end
        self.Values = newValues or {}

        for _, child in self.Popup:GetChildren() do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end

        for index, value in self.Values do
            local optionButton = create("TextButton", {
                Parent = self.Popup,
                Size = UDim2.new(1, -8, 0, 34),
                BackgroundColor3 = Theme.ControlBottom,
                BackgroundTransparency = 1,
                AutoButtonColor = false,
                Text = tostring(value),
                TextColor3 = Theme.Muted,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextSize = interfaceTextSize(14),
                FontFace = Fonts.Regular,
                LayoutOrder = index,
                ZIndex = 101,
            })
            corner(optionButton, 6)
            create("UIPadding", {
                Parent = optionButton,
                PaddingLeft = UDim.new(0, 12),
                PaddingRight = UDim.new(0, 12),
            })

            optionButton.MouseEnter:Connect(function()
                tween(optionButton, {
                    BackgroundTransparency = 0,
                    TextColor3 = Theme.Text,
                }, 0.12)
            end)
            optionButton.MouseLeave:Connect(function()
                tween(optionButton, {
                    BackgroundTransparency = 1,
                    TextColor3 = Theme.Muted,
                }, 0.12)
            end)
            optionButton.Activated:Connect(function()
                control:Set(value, true)
                control:Close()
            end)
        end

        local currentExists = table.find(self.Values, self.Value) ~= nil
        if keepValue and currentExists then
            self:Set(self.Value, false)
            return
        end

        local nextValue = options.Default
        if table.find(self.Values, nextValue) == nil then
            nextValue = self.Values[1]
        end
        self:Set(nextValue, false)
    end

    function control:SetText(value)
        label.Text = tostring(value)
    end

    function control:SetVisible(value)
        if value == false then self:Close() end
        setControlVisible(self, value)
    end

    function control:Destroy()
        self:Close()
        if popup.Parent then popup:Destroy() end
        unregisterControl(self)
    end

    field.Activated:Connect(function()
        if control.IsOpen then
            control:Close()
        else
            control:Open()
        end
    end)

    control.SearchItem = self:Register(row, controlSearchText(options))
    control.Setter = registerSetter(self, flag, function(value, emit)
        return control:Set(value, emit)
    end)
    control:SetValues(values, false)
    self:Refresh()
    return control
end

function SectionMethods:AddTextbox(options)
    options = options or {}
    local text = options.Text or options.Name or "Textbox"
    local onChanged = options.OnChanged
    local onSubmitted = options.OnSubmitted or options.Callback
    local flag = self:NextFlag(options.Flag)
    local suppressChange = false

    local row = create("Frame", {
        Parent = self.Content,
        Name = text,
        Size = UDim2.new(1, 0, 0, 82),
        BackgroundTransparency = 1,
        LayoutOrder = options.Order or (#self.Items + 1),
    })

    local label = create("TextLabel", {
        Parent = row,
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextSize = interfaceTextSize(15),
        FontFace = Fonts.Regular,
    })

    -- Keep the gradient on a separate surface. A UIGradient attached directly
    -- to a TextBox also multiplies its glyph color, which made typed values
    -- nearly invisible against dark themes.
    local boxSurface = create("Frame", {
        Parent = row,
        Name = "TextboxSurface",
        Position = fromOffset(0, 35),
        Size = UDim2.new(1, 0, 0, 43),
        BackgroundColor3 = Theme.Control,
        ZIndex = 1,
    })
    corner(boxSurface, 7)
    stroke(boxSurface, Theme.Border, 0.15, 1)
    gradient(boxSurface, Theme.Control, Theme.ControlBottom, 90)

    local box = create("TextBox", {
        Parent = row,
        Position = fromOffset(0, 35),
        Size = UDim2.new(1, 0, 0, 43),
        BackgroundTransparency = 1,
        ClearTextOnFocus = options.ClearOnFocus == true,
        Text = "",
        PlaceholderText = options.Placeholder or "Type here...",
        PlaceholderColor3 = Theme.Dim,
        TextColor3 = Theme.Text,
        TextTransparency = 0,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextSize = interfaceTextSize(15),
        FontFace = Fonts.Regular,
        ZIndex = 2,
    })
    corner(box, 7)
    create("UIPadding", {
        Parent = box,
        PaddingLeft = UDim.new(0, 14),
        PaddingRight = UDim.new(0, 14),
    })

    local control = {
        Section = self,
        Row = row,
        Label = label,
        Box = box,
        Flag = flag,
        Value = "",
    }

    function control:Set(value, emit)
        if self.Destroyed then return self.Value end
        value = tostring(value or "")
        self.Value = value
        self.Section.Window.Flags[self.Flag] = value
        Library.Flags[self.Flag] = value
        suppressChange = true
        self.Box.Text = value
        suppressChange = false

        if emit then
            local callback = onChanged or onSubmitted
            if callback then safeCallback(callback, value) end
        end
        return value
    end

    function control:Get()
        return self.Value
    end

    function control:SetText(value)
        label.Text = tostring(value)
    end

    function control:SetVisible(value)
        setControlVisible(self, value)
    end

    function control:Destroy()
        unregisterControl(self)
    end

    box:GetPropertyChangedSignal("Text"):Connect(function()
        if suppressChange then return end
        control.Value = box.Text
        control.Section.Window.Flags[flag] = box.Text
        Library.Flags[flag] = box.Text
        if onChanged then safeCallback(onChanged, box.Text) end
    end)

    box.FocusLost:Connect(function(enterPressed)
        if onSubmitted then
            safeCallback(onSubmitted, box.Text, enterPressed)
        end
    end)

    control.SearchItem = self:Register(row, controlSearchText(options))
    control.Setter = registerSetter(self, flag, function(value, emit)
        return control:Set(value, emit)
    end)
    control:Set(options.Default or "", false)
    self:Refresh()
    return control
end

function SectionMethods:AddButton(options)
    options = options or {}
    local text = options.Text or options.Name or "Button"
    local callback = options.Callback or options.OnClick

    local button = create("TextButton", {
        Parent = self.Content,
        Name = text,
        Size = UDim2.new(1, 0, 0, 45),
        BackgroundColor3 = Theme.Control,
        AutoButtonColor = false,
        Text = text,
        TextColor3 = Theme.Text,
        TextSize = interfaceTextSize(15),
        FontFace = Fonts.Regular,
        LayoutOrder = options.Order or (#self.Items + 1),
    })
    corner(button, 7)
    local buttonStroke = stroke(button, Theme.Border, 0.15, 1)
    gradient(button, Theme.Control, Theme.ControlBottom, 90)

    local control = {
        Section = self,
        Row = button,
        Button = button,
        Enabled = true,
    }

    function control:SetText(value)
        button.Text = tostring(value)
    end

    function control:SetEnabled(value)
        self.Enabled = value ~= false
        tween(button, {
            TextColor3 = self.Enabled and Theme.Text or Theme.Dim,
            BackgroundTransparency = self.Enabled and 0 or 0.35,
        }, 0.15)
    end

    function control:SetVisible(value)
        setControlVisible(self, value)
    end

    function control:Fire(...)
        if not self.Destroyed and self.Enabled and callback then
            safeCallback(callback, ...)
        end
    end

    function control:Destroy()
        unregisterControl(self)
    end

    button.MouseEnter:Connect(function()
        if control.Enabled then
            tween(buttonStroke, {Color = Theme.AccentSoft}, 0.12)
        end
    end)
    button.MouseLeave:Connect(function()
        tween(buttonStroke, {Color = Theme.Border}, 0.12)
    end)
    button.Activated:Connect(function()
        control:Fire(control)
    end)

    control.SearchItem = self:Register(button, controlSearchText(options))
    self:Refresh()
    return control
end

function SectionMethods:AddLabel(options)
    if type(options) == "string" then
        options = {Text = options}
    else
        options = options or {}
    end

    local text = options.Text or "Label"
    local label = create("TextLabel", {
        Parent = self.Content,
        Name = options.Name or "Label",
        Size = UDim2.new(1, 0, 0, 28),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = options.Color or Theme.Muted,
        TextXAlignment = options.Alignment or Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        RichText = options.RichText == true,
        TextSize = options.TextSize or interfaceTextSize(14),
        FontFace = options.Bold and Fonts.Semibold or Fonts.Regular,
        LayoutOrder = options.Order or (#self.Items + 1),
    })

    local control = {
        Section = self,
        Row = label,
        Label = label,
        Value = text,
    }

    function control:Set(value)
        if self.Destroyed then return self.Value end
        self.Value = tostring(value or "")
        label.Text = self.Value
        self.Section:Refresh()
        return self.Value
    end

    function control:Get()
        return self.Value
    end

    function control:SetVisible(value)
        setControlVisible(self, value)
    end

    function control:Destroy()
        unregisterControl(self)
    end

    control.SearchItem = self:Register(label, controlSearchText(options))
    self:Refresh()
    return control
end

function SectionMethods:AddKeybind(options)
    options = options or {}
    local text = options.Text or options.Name or "Keybind"
    local callback = options.Callback or options.OnTriggered
    local changedCallback = options.OnChanged
    local mode = string.lower(options.Mode or "Press")
    local flag = self:NextFlag(options.Flag)
    local active = false

    local row = create("Frame", {
        Parent = self.Content,
        Name = text,
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundTransparency = 1,
        LayoutOrder = options.Order or (#self.Items + 1),
    })

    local label = create("TextLabel", {
        Parent = row,
        Size = UDim2.new(1, -118, 1, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Theme.Muted,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextSize = interfaceTextSize(15),
        FontFace = Fonts.Regular,
    })

    local bindButton = create("TextButton", {
        Parent = row,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = fromOffset(104, 30),
        BackgroundColor3 = Theme.ControlBottom,
        AutoButtonColor = false,
        Text = "",
        TextColor3 = Theme.Text,
        TextSize = interfaceTextSize(12),
        FontFace = Fonts.Semibold,
    })
    corner(bindButton, 6)
    stroke(bindButton, Theme.Border, 0.1, 1)

    local control = {
        Section = self,
        Row = row,
        Label = label,
        Button = bindButton,
        Flag = flag,
        Value = options.Default or Enum.KeyCode.RightShift,
        Connections = {},
    }

    local function inputKey(input)
        if input.UserInputType == Enum.UserInputType.Keyboard
            and input.KeyCode ~= Enum.KeyCode.Unknown then
            return input.KeyCode
        end

        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.MouseButton2
            or input.UserInputType == Enum.UserInputType.MouseButton3 then
            return input.UserInputType
        end
    end

    local function matches(input, key)
        return input.KeyCode == key or input.UserInputType == key
    end

    function control:Set(value, emit)
        if self.Destroyed then return self.Value end
        if value == nil then return self.Value end
        if mode == "hold" and active then
            active = false
            if callback then safeCallback(callback, false, self.Value) end
        end
        self.Value = value
        self.Button.Text = formatKey(value)
        self.Section.Window.Flags[self.Flag] = value
        Library.Flags[self.Flag] = value

        if emit and changedCallback then
            safeCallback(changedCallback, value)
        end
        return value
    end

    function control:Get()
        return self.Value
    end

    function control:SetText(value)
        label.Text = tostring(value)
    end

    local function releaseHold()
        if mode == "hold" and active then
            active = false
            if callback then safeCallback(callback, false, control.Value) end
        end
    end

    function control:SetVisible(value)
        setControlVisible(self, value)
    end

    function control:Destroy()
        releaseHold()
        unregisterControl(self)
    end

    function control:CancelCapture()
        if self.Section.Window.CapturingKeybind == self then
            self.Section.Window.CapturingKeybind = nil
        end
        bindButton.Text = formatKey(self.Value)
        bindButton.TextColor3 = Theme.Text
    end

    bindButton.Activated:Connect(function()
        local previousCapture = control.Section.Window.CapturingKeybind
        if previousCapture and previousCapture ~= control and previousCapture.CancelCapture then
            previousCapture:CancelCapture()
        end
        control.Section.Window.CapturingKeybind = control
        bindButton.Text = "..."
        tween(bindButton, {TextColor3 = Theme.Accent}, 0.12)
    end)

    connectControl(control, UserInputService.InputBegan, function(input, processed)
        local captureOwner = control.Section.Window.CapturingKeybind
        if captureOwner then
            if captureOwner ~= control then return end

            if input.KeyCode == Enum.KeyCode.Escape then
                bindButton.Text = formatKey(control.Value)
                bindButton.TextColor3 = Theme.Text
                task.defer(function()
                    if control.Section.Window.CapturingKeybind == control then
                        control.Section.Window.CapturingKeybind = nil
                    end
                end)
                return
            end

            local key = inputKey(input)
            if key then
                bindButton.TextColor3 = Theme.Text
                control:Set(key, true)
                task.defer(function()
                    if control.Section.Window.CapturingKeybind == control then
                        control.Section.Window.CapturingKeybind = nil
                    end
                end)
            end
            return
        end

        if processed or not matches(input, control.Value) then return end

        if mode == "toggle" then
            active = not active
            if callback then safeCallback(callback, active, control.Value) end
        elseif mode == "hold" then
            active = true
            if callback then safeCallback(callback, true, control.Value) end
        elseif callback then
            safeCallback(callback, control.Value)
        end
    end)

    connectControl(control, UserInputService.InputEnded, function(input)
        if mode == "hold" and active and matches(input, control.Value) then
            releaseHold()
        end
    end)

    connectControl(control, control.Section.Window.ScreenGui.Destroying, releaseHold)

    control.SearchItem = self:Register(row, controlSearchText(options))
    control.Setter = registerSetter(self, flag, function(value, emit)
        return control:Set(value, emit)
    end)
    control:Set(control.Value, false)
    self:Refresh()
    return control
end

function SectionMethods:AddColorPicker(options)
    options = options or {}
    local text = options.Text or options.Name or "Color"
    local callback = options.Callback or options.OnChanged
    local applyToTheme = options.ApplyToTheme == true
    local continuous = options.Continuous == true
    local flag = self:NextFlag(options.Flag)
    local draggingMode = nil
    local activeTouch = nil
    local dragStartColor = nil

    local row = create("Frame", {
        Parent = self.Content,
        Name = text,
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundTransparency = 1,
        LayoutOrder = options.Order or (#self.Items + 1),
    })

    local label = create("TextLabel", {
        Parent = row,
        Size = UDim2.new(1, -132, 1, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Theme.Muted,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextSize = interfaceTextSize(15),
        FontFace = Fonts.Regular,
    })

    local field = create("TextButton", {
        Parent = row,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = fromOffset(118, 32),
        BackgroundColor3 = Theme.Control,
        AutoButtonColor = false,
        Text = "",
    })
    corner(field, 7)
    local fieldStroke = stroke(field, Theme.Border, 0.1, 1)

    local swatch = create("Frame", {
        Parent = field,
        Position = fromOffset(5, 5),
        Size = fromOffset(22, 22),
        BackgroundColor3 = Theme.Accent,
        ZIndex = 2,
    })
    corner(swatch, 5)
    stroke(swatch, Theme.White, 0.7, 1)

    local hexPreview = create("TextLabel", {
        Parent = field,
        Position = fromOffset(35, 0),
        Size = UDim2.new(1, -42, 1, 0),
        BackgroundTransparency = 1,
        Text = colorToHex(Theme.Accent),
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextSize = interfaceTextSize(12),
        FontFace = Fonts.Semibold,
        ZIndex = 2,
    })

    local popup = create("Frame", {
        Parent = self.Window.PopupLayer,
        Name = text .. "Picker",
        Size = fromOffset(260, 246),
        BackgroundColor3 = Theme.Card,
        BackgroundTransparency = 0.02,
        Visible = false,
        ClipsDescendants = true,
        ZIndex = 120,
    })
    corner(popup, 10)
    local popupStroke = stroke(popup, Theme.Border, 0, 1)
    local popupScale = create("UIScale", {
        Parent = popup,
        Scale = 0.97,
    })

    local svField = create("TextButton", {
        Parent = popup,
        Position = fromOffset(14, 14),
        Size = fromOffset(232, 138),
        BackgroundColor3 = Color3.fromHSV(0, 1, 1),
        AutoButtonColor = false,
        Text = "",
        ZIndex = 121,
    })
    corner(svField, 7)

    local whiteLayer = create("Frame", {
        Parent = svField,
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.White,
        ZIndex = 122,
    })
    corner(whiteLayer, 7)
    create("UIGradient", {
        Parent = whiteLayer,
        Rotation = 0,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1),
        }),
    })

    local blackLayer = create("Frame", {
        Parent = svField,
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = rgb(0, 0, 0),
        ZIndex = 123,
    })
    corner(blackLayer, 7)
    create("UIGradient", {
        Parent = blackLayer,
        Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0),
        }),
    })

    local svSelector = create("Frame", {
        Parent = svField,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(1, 0),
        Size = fromOffset(14, 14),
        BackgroundColor3 = Theme.White,
        BackgroundTransparency = 1,
        ZIndex = 125,
    })
    corner(svSelector, 8)
    stroke(svSelector, Theme.White, 0, 2)

    local hueField = create("TextButton", {
        Parent = popup,
        Position = fromOffset(14, 166),
        Size = fromOffset(232, 14),
        BackgroundColor3 = Theme.White,
        AutoButtonColor = false,
        Text = "",
        ZIndex = 121,
    })
    corner(hueField, 7)
    create("UIGradient", {
        Parent = hueField,
        Rotation = 0,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
            ColorSequenceKeypoint.new(1 / 6, Color3.fromHSV(1 / 6, 1, 1)),
            ColorSequenceKeypoint.new(2 / 6, Color3.fromHSV(2 / 6, 1, 1)),
            ColorSequenceKeypoint.new(3 / 6, Color3.fromHSV(3 / 6, 1, 1)),
            ColorSequenceKeypoint.new(4 / 6, Color3.fromHSV(4 / 6, 1, 1)),
            ColorSequenceKeypoint.new(5 / 6, Color3.fromHSV(5 / 6, 1, 1)),
            ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)),
        }),
    })

    local hueSelector = create("Frame", {
        Parent = hueField,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        Size = fromOffset(6, 22),
        BackgroundColor3 = Theme.White,
        ZIndex = 125,
    })
    corner(hueSelector, 4)
    stroke(hueSelector, rgb(10, 18, 25), 0.15, 1)

    local hexBox = create("TextBox", {
        Parent = popup,
        Position = fromOffset(14, 194),
        Size = fromOffset(232, 38),
        BackgroundColor3 = Theme.Control,
        ClearTextOnFocus = false,
        Text = colorToHex(Theme.Accent),
        PlaceholderText = "#0084FF",
        PlaceholderColor3 = Theme.Dim,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextSize = interfaceTextSize(14),
        FontFace = Fonts.Semibold,
        ZIndex = 121,
    })
    corner(hexBox, 7)
    stroke(hexBox, Theme.Border, 0.1, 1)

    local control = {
        Section = self,
        Window = self.Window,
        Row = row,
        Label = label,
        Field = field,
        FieldStroke = fieldStroke,
        Popup = popup,
        PopupStroke = popupStroke,
        PopupScale = popupScale,
        Swatch = swatch,
        HexPreview = hexPreview,
        HexBox = hexBox,
        SVField = svField,
        SVSelector = svSelector,
        HueSelector = hueSelector,
        Flag = flag,
        Value = Theme.Accent,
        Hue = 0,
        Saturation = 1,
        Brightness = 1,
        IsOpen = false,
        ApplyingTheme = false,
        Initialized = false,
        Connections = {},
    }

    local function colorsEqual(first, second)
        if not first or not second then return false end
        return math.abs(first.R - second.R) < 0.0001
            and math.abs(first.G - second.G) < 0.0001
            and math.abs(first.B - second.B) < 0.0001
    end

    function control:UpdateDisplay()
        local color = Color3.fromHSV(self.Hue, self.Saturation, self.Brightness)
        local hex = colorToHex(color)
        self.Value = color
        self.SVField.BackgroundColor3 = Color3.fromHSV(self.Hue, 1, 1)
        self.SVSelector.Position = UDim2.fromScale(self.Saturation, 1 - self.Brightness)
        self.HueSelector.Position = UDim2.fromScale(self.Hue, 0.5)
        self.Swatch.BackgroundColor3 = color
        self.HexPreview.Text = hex
        if not self.HexBox:IsFocused() then self.HexBox.Text = hex end
        return color
    end

    function control:SetHSV(hue, saturation, brightness, emit, animateTheme, skipTheme)
        if self.Destroyed then return self.Value end
        local previous = self.Value
        self.Hue = clamp(tonumber(hue) or 0, 0, 1)
        self.Saturation = clamp(tonumber(saturation) or 0, 0, 1)
        self.Brightness = clamp(tonumber(brightness) or 0, 0, 1)
        local color = self:UpdateDisplay()
        local changed = not colorsEqual(previous, color)

        self.Section.Window.Flags[self.Flag] = color
        Library.Flags[self.Flag] = color

        if applyToTheme and not skipTheme then
            self.ApplyingTheme = true
            self.Window:SetThemeColor(color, animateTheme)
            self.ApplyingTheme = false
        end

        self.Initialized = true
        if emit and changed and callback then safeCallback(callback, color, colorToHex(color)) end
        return color
    end

    function control:Set(value, emit, animateTheme, skipTheme)
        local color = parseColor(value)
        if not color then
            warn("[TRust Menu] Invalid color picker value: " .. tostring(value))
            return self.Value
        end
        local hue, saturation, brightness = Color3.toHSV(color)
        return self:SetHSV(hue, saturation, brightness, emit, animateTheme, skipTheme)
    end

    function control:Get()
        return self.Value
    end

    function control:GetHex()
        return colorToHex(self.Value)
    end

    function control:Close()
        self.IsOpen = false
        draggingMode = nil
        activeTouch = nil
        tween(self.FieldStroke, {Color = Theme.Border}, 0.14, Enum.EasingStyle.Quart)
        setProperties(self.PopupScale, {Scale = 0.97})
        setProperties(self.SVSelector, {Size = fromOffset(14, 14)})
        setProperties(self.HueSelector, {Size = fromOffset(6, 22)})
        if self.Popup and self.Popup.Parent then self.Popup.Visible = false end
        if self.Window.OpenPopup == self then self.Window.OpenPopup = nil end
    end

    function control:Open()
        if self.Destroyed then return end
        self.Window:ClosePopup(self)
        self.IsOpen = true

        local activeCamera = Workspace.CurrentCamera or Camera
        local viewportSize = activeCamera and activeCamera.ViewportSize or Vector2.new(1920, 1080)
        local width = self.Popup.Size.X.Offset > 0 and self.Popup.Size.X.Offset or 260
        local height = self.Popup.Size.Y.Offset > 0 and self.Popup.Size.Y.Offset or 246
        local x = clamp(self.Field.AbsolutePosition.X + self.Field.AbsoluteSize.X - width, 8, max(8, viewportSize.X - width - 8))
        local y = self.Field.AbsolutePosition.Y + self.Field.AbsoluteSize.Y + 6
        if y + height > viewportSize.Y - 8 then
            y = self.Field.AbsolutePosition.Y - height - 6
        end
        y = clamp(y, 8, max(8, viewportSize.Y - height - 8))

        self.Popup.Position = fromOffset(x, y)
        setProperties(self.PopupScale, {Scale = 0.97})
        self.Popup.Visible = true
        tween(self.PopupScale, {Scale = 1}, 0.18, Enum.EasingStyle.Back)
        tween(self.FieldStroke, {Color = Theme.AccentSoft}, 0.16, Enum.EasingStyle.Quart)
        self.Window.OpenPopup = self
    end

    function control:SetText(value)
        label.Text = tostring(value)
    end

    function control:SetVisible(value)
        if value == false then self:Close() end
        setControlVisible(self, value)
    end

    function control:Destroy()
        self:Close()
        if popup.Parent then popup:Destroy() end
        unregisterControl(self)
    end

    local function updateFromPointer(position)
        if draggingMode == "sv" then
            local width = max(1, svField.AbsoluteSize.X)
            local height = max(1, svField.AbsoluteSize.Y)
            local saturation = clamp((position.X - svField.AbsolutePosition.X) / width, 0, 1)
            local brightness = 1 - clamp((position.Y - svField.AbsolutePosition.Y) / height, 0, 1)
            control:SetHSV(control.Hue, saturation, brightness, continuous, false)
        elseif draggingMode == "hue" then
            local width = max(1, hueField.AbsoluteSize.X)
            local hue = clamp((position.X - hueField.AbsolutePosition.X) / width, 0, 1)
            control:SetHSV(hue, control.Saturation, control.Brightness, continuous, false)
        end
    end

    local function beginDrag(mode, input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        draggingMode = mode
        activeTouch = input.UserInputType == Enum.UserInputType.Touch and input or nil
        dragStartColor = control.Value
        if mode == "sv" then
            tween(svSelector, {Size = fromOffset(18, 18)}, 0.1, Enum.EasingStyle.Back)
        else
            tween(hueSelector, {Size = fromOffset(9, 24)}, 0.1, Enum.EasingStyle.Back)
        end
        updateFromPointer(input.Position)
    end

    svField.InputBegan:Connect(function(input)
        beginDrag("sv", input)
    end)

    hueField.InputBegan:Connect(function(input)
        beginDrag("hue", input)
    end)

    connectControl(control, UserInputService.InputChanged, function(input)
        local validMouse = input.UserInputType == Enum.UserInputType.MouseMovement and activeTouch == nil
        local validTouch = activeTouch ~= nil and input == activeTouch
        if draggingMode and (validMouse or validTouch) then
            updateFromPointer(input.Position)
        end
    end)

    connectControl(control, UserInputService.InputEnded, function(input)
        local mouseEnded = input.UserInputType == Enum.UserInputType.MouseButton1 and activeTouch == nil
        local touchEnded = activeTouch ~= nil and input == activeTouch
        if draggingMode and (mouseEnded or touchEnded) then
            local changedDuringDrag = not colorsEqual(dragStartColor, control.Value)
            draggingMode = nil
            activeTouch = nil
            tween(svSelector, {Size = fromOffset(14, 14)}, 0.16, Enum.EasingStyle.Back)
            tween(hueSelector, {Size = fromOffset(6, 22)}, 0.16, Enum.EasingStyle.Back)
            if not continuous and changedDuringDrag and callback then
                safeCallback(callback, control.Value, colorToHex(control.Value))
            end
            dragStartColor = nil
        end
    end)

    field.MouseEnter:Connect(function()
        tween(field, {BackgroundColor3 = Theme.ControlHover}, 0.12, Enum.EasingStyle.Quart)
    end)
    field.MouseLeave:Connect(function()
        tween(field, {BackgroundColor3 = Theme.Control}, 0.12, Enum.EasingStyle.Quart)
    end)
    field.Activated:Connect(function()
        if control.IsOpen then control:Close() else control:Open() end
    end)

    hexBox.FocusLost:Connect(function()
        local parsed = parseColor(hexBox.Text)
        if parsed then
            control:Set(parsed, true, true)
        else
            hexBox.Text = colorToHex(control.Value)
        end
    end)

    control.SearchItem = self:Register(row, controlSearchText(options))
    control.Setter = registerSetter(self, flag, function(value, emit)
        return control:Set(value, emit, true)
    end)
    control:Set(options.Default or Theme.Accent, false, false)

    onThemeChanged(control, function(_, animate)
        setProperties(popupStroke, {Color = Theme.Border})
        local fieldColor = control.IsOpen and Theme.AccentSoft or Theme.Border
        if animate then
            tween(fieldStroke, {Color = fieldColor}, 0.16, Enum.EasingStyle.Quart)
        else
            setProperties(fieldStroke, {Color = fieldColor})
        end
        if applyToTheme and control.Initialized and not control.ApplyingTheme then
            control:Set(Theme.Accent, false, false, true)
        end
    end)

    self:Refresh()
    return control
end

SectionMethods.Toggle = SectionMethods.AddToggle
SectionMethods.Slider = SectionMethods.AddSlider
SectionMethods.Dropdown = SectionMethods.AddDropdown
SectionMethods.Textbox = SectionMethods.AddTextbox
SectionMethods.Button = SectionMethods.AddButton
SectionMethods.Label = SectionMethods.AddLabel
SectionMethods.Keybind = SectionMethods.AddKeybind
SectionMethods.ColorPicker = SectionMethods.AddColorPicker

return Library
