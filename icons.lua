--[[
	TRust Menu - Icon Registry
	سجل الأيقونات والشعار مع دعم التحميل التلقائي عبر GitHub Raw/Executors
]]

local Icons = {
	[0] = { Id = 0, Name = "Logo",     File = "assets/0.png", AssetId = "rbxassetid://0" },
	[1] = { Id = 1, Name = "Cube",     File = "assets/1.png", AssetId = "rbxassetid://0" },
	[2] = { Id = 2, Name = "Scope",    File = "assets/2.png", AssetId = "rbxassetid://0" },
	[3] = { Id = 3, Name = "View",     File = "assets/3.png", AssetId = "rbxassetid://0" },
	[4] = { Id = 4, Name = "User",     File = "assets/4.png", AssetId = "rbxassetid://0" },
	[5] = { Id = 5, Name = "Settings", File = "assets/5.png", AssetId = "rbxassetid://0" },
	[6] = { Id = 6, Name = "Pick",     File = "assets/6.png", AssetId = "rbxassetid://0" },
}

Icons.Root = "."
Icons.BaseUrl = ""

local function keyFromCall(selfOrKey, key)
	if selfOrKey == Icons then
		return key
	end
	return selfOrKey
end

local function validEntry(key)
	key = tonumber(key)
	return key and Icons[key] or nil
end

local function normalizeAssetId(assetId)
	local numericId
	if type(assetId) == "number" then
		numericId = assetId
	elseif type(assetId) == "string" then
		numericId = assetId:match("^rbxassetid://(%d+)$") or assetId:match("^(%d+)$")
	end

	numericId = tonumber(numericId)
	if not numericId or numericId <= 0 or numericId % 1 ~= 0 then
		return nil
	end

	return "rbxassetid://" .. tostring(numericId)
end

local function joinPath(root, fileName)
	root = tostring(root or ""):gsub("[\\/]+$", "")
	if root == "" or root == "." then
		return fileName
	end
	return root .. "/" .. fileName
end

function Icons.SetBaseUrl(selfOrUrl, url)
	if selfOrUrl ~= Icons then url = selfOrUrl end
	if url == nil then url = "" end
	Icons.BaseUrl = tostring(url)
	return Icons.BaseUrl
end

function Icons.Get(selfOrKey, key)
	return validEntry(keyFromCall(selfOrKey, key))
end

function Icons.File(selfOrKey, key)
	local entry = validEntry(keyFromCall(selfOrKey, key))
	return entry and entry.File or nil
end

function Icons.SetRoot(selfOrRoot, root)
	if selfOrRoot ~= Icons then root = selfOrRoot end
	if root == nil or root == "" then root = "." end
	Icons.Root = tostring(root)
	return Icons.Root
end

function Icons.Path(selfOrKey, key, root)
	local requestedKey
	if selfOrKey == Icons then
		requestedKey = key
	else
		requestedKey = selfOrKey
		root = key
	end

	local entry = validEntry(requestedKey)
	return entry and joinPath(root or Icons.Root, entry.File) or nil
end

function Icons.AssetId(selfOrKey, key)
	local entry = validEntry(keyFromCall(selfOrKey, key))
	return entry and normalizeAssetId(entry.AssetId) or nil
end

function Icons.Resolve(selfOrKey, key, root)
	local requestedKey
	if selfOrKey == Icons then
		requestedKey = key
	else
		requestedKey = selfOrKey
		root = key
	end

	local entry = validEntry(requestedKey)
	if not entry then
		return nil
	end

	local assetId = normalizeAssetId(entry.AssetId)
	if assetId then return assetId end

	local customAsset = getcustomasset or getsynasset
	if type(customAsset) == "function" then
		local filePath = joinPath(root or Icons.Root, entry.File)
		local fileExists = false
		if type(isfile) == "function" then
			local ok, exists = pcall(isfile, filePath)
			fileExists = ok and exists
		end

		if not fileExists then
			if type(writefile) == "function" and type(makefolder) == "function" and type(game) == "userdata" and type(game.HttpGet) == "function" then
				local baseUrl = Icons.BaseUrl
				local env = type(getgenv) == "function" and getgenv() or _G
				if (not baseUrl or baseUrl == "") and env.TRUST_MENU_URL then
					baseUrl = env.TRUST_MENU_URL
				end

				if baseUrl and baseUrl ~= "" then
					if not baseUrl:find("/$") then baseUrl = baseUrl .. "/" end
					local fetchUrl = baseUrl .. entry.File:gsub("^[\\/]+", "")

					pcall(function()
						local dir = filePath:match("^(.+)[\\/]")
						if dir and type(isfolder) == "function" and not isfolder(dir) then
							makefolder(dir)
						end
					end)

					local ok, content = pcall(function() return game:HttpGet(fetchUrl) end)
					if ok and content and #content > 0 then
						pcall(writefile, filePath, content)
						fileExists = true
					end
				end
			end
		end

		if fileExists then
			local ok, result = pcall(customAsset, filePath)
			if ok and type(result) == "string" and result ~= "" then
				return result
			end
		end
	end

	return nil
end

return Icons
