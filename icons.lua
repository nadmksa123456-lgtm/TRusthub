--[[
	TRust Menu - executor image registry

	The registry supports two modes:
	1. Local development: assets/0.png ... assets/6.png already exist.
	2. GitHub Raw: missing images are downloaded once, cached in the
	   executor workspace, then converted with getcustomasset/getsynasset.
]]

local environment = type(getgenv) == "function" and getgenv() or _G

local Icons = {
	[0] = {Id = 0, Name = "Logo", File = "assets/0.png", AssetId = "rbxassetid://0"},
	[1] = {Id = 1, Name = "Cube", File = "assets/1.png", AssetId = "rbxassetid://0"},
	[2] = {Id = 2, Name = "Scope", File = "assets/2.png", AssetId = "rbxassetid://0"},
	[3] = {Id = 3, Name = "View", File = "assets/3.png", AssetId = "rbxassetid://0"},
	[4] = {Id = 4, Name = "User", File = "assets/4.png", AssetId = "rbxassetid://0"},
	[5] = {Id = 5, Name = "Settings", File = "assets/5.png", AssetId = "rbxassetid://0"},
	[6] = {Id = 6, Name = "Pick", File = "assets/6.png", AssetId = "rbxassetid://0"},
}

Icons.Root = "."
Icons.BaseUrl = nil
Icons.CacheRoot = nil
Icons.Resolved = {}
Icons.Errors = {}
Icons.Environment = environment

local function normalizeSlashes(value)
	return tostring(value or ""):gsub("\\", "/")
end

local function trimTrailingSlash(value)
	return normalizeSlashes(value):gsub("/+$", "")
end

local function joinPath(root, fileName)
	root = trimTrailingSlash(root)
	fileName = normalizeSlashes(fileName):gsub("^/+", "")
	if root == "" or root == "." then
		return fileName
	end
	return root .. "/" .. fileName
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

local function entryFromCall(selfOrKey, key)
	local requestedKey = selfOrKey == Icons and key or selfOrKey
	requestedKey = tonumber(requestedKey)
	return requestedKey and Icons[requestedKey] or nil
end

local function functionFromEnvironment(name)
	local value = Icons.Environment and Icons.Environment[name]
	if type(value) == "function" then return value end
	return nil
end

local function executorRequest()
	local direct = functionFromEnvironment("request") or functionFromEnvironment("http_request")
	if direct then return direct end

	local activeEnvironment = Icons.Environment
	local synTable = activeEnvironment and activeEnvironment.syn
	if type(synTable) == "table" and type(synTable.request) == "function" then
		return synTable.request
	end

	local httpTable = activeEnvironment and activeEnvironment.http
	if type(httpTable) == "table" and type(httpTable.request) == "function" then
		return httpTable.request
	end

	return nil
end

local function httpGet(url)
	local activeEnvironment = Icons.Environment
	local gameObject = activeEnvironment and activeEnvironment.game or game
	local gameOk, gameBody = pcall(function()
		return gameObject:HttpGet(url)
	end)
	if gameOk and type(gameBody) == "string" and #gameBody > 0 then
		return gameBody
	end

	local requestFunction = executorRequest()
	if requestFunction then
		local requestOk, response = pcall(requestFunction, {
			Url = url,
			Method = "GET",
			Headers = {Accept = "image/png,application/octet-stream,*/*"},
		})
		if requestOk and type(response) == "table" then
			local success = response.Success
			local statusCode = tonumber(response.StatusCode or response.Status)
			local body = response.Body or response.body
			if (success == true or (statusCode and statusCode >= 200 and statusCode < 300))
				and type(body) == "string" and #body > 0 then
				return body
			end
		end
	end

	return nil, tostring(gameBody or "HTTP request failed")
end

local function isPng(data)
	return type(data) == "string"
		and #data >= 8
		and string.byte(data, 1) == 137
		and string.sub(data, 2, 4) == "PNG"
end

local function fileExists(path)
	local isFile = functionFromEnvironment("isfile")
	if not isFile then return nil end
	local ok, result = pcall(isFile, path)
	return ok and result == true
end

local function ensureFolder(path)
	local makeFolder = functionFromEnvironment("makefolder")
	if not makeFolder or not path or path == "" then return end

	local isFolder = functionFromEnvironment("isfolder")
	if isFolder then
		local ok, exists = pcall(isFolder, path)
		if ok and exists then return end
	end
	pcall(makeFolder, path)
end

local function parentFolder(path)
	return normalizeSlashes(path):match("^(.*)/[^/]+$")
end

local function writeBinary(path, data)
	local writeFile = functionFromEnvironment("writefile")
	if not writeFile then return false, "writefile is unavailable" end

	ensureFolder(parentFolder(path))
	local ok, message = pcall(writeFile, path, data)
	if not ok then return false, tostring(message) end
	return true
end

local function customAsset(path)
	local resolver = functionFromEnvironment("getcustomasset") or functionFromEnvironment("getsynasset")
	if not resolver then return nil, "getcustomasset/getsynasset is unavailable" end

	local ok, asset = pcall(resolver, path)
	if ok and type(asset) == "string" and asset ~= "" then
		return asset
	end
	return nil, tostring(asset or "unable to create custom asset")
end

local function resolvedPath(entry)
	if Icons.CacheRoot and Icons.CacheRoot ~= "" then
		return joinPath(Icons.CacheRoot, tostring(entry.Id) .. ".png")
	end
	return joinPath(Icons.Root, entry.File)
end

local function remoteUrl(entry)
	if not Icons.BaseUrl or Icons.BaseUrl == "" then return nil end
	return joinPath(Icons.BaseUrl, entry.File)
end

function Icons.Get(selfOrKey, key)
	return entryFromCall(selfOrKey, key)
end

function Icons.Configure(selfOrOptions, options)
	if selfOrOptions ~= Icons then options = selfOrOptions end
	options = options or {}

	if options.Root ~= nil then Icons.Root = tostring(options.Root) end
	if options.BaseUrl ~= nil then Icons.BaseUrl = trimTrailingSlash(options.BaseUrl) end
	if options.CacheRoot ~= nil then Icons.CacheRoot = trimTrailingSlash(options.CacheRoot) end
	if type(options.Environment) == "table" then Icons.Environment = options.Environment end

	Icons.Resolved = {}
	Icons.Errors = {}
	return Icons
end

function Icons.SetRoot(selfOrRoot, root)
	if selfOrRoot ~= Icons then root = selfOrRoot end
	if root == nil or root == "" then root = "." end
	Icons.Root = tostring(root)
	Icons.Resolved = {}
	return Icons.Root
end

function Icons.SetBaseUrl(selfOrUrl, url)
	if selfOrUrl ~= Icons then url = selfOrUrl end
	Icons.BaseUrl = trimTrailingSlash(url)
	Icons.Resolved = {}
	return Icons.BaseUrl
end

function Icons.SetCacheRoot(selfOrRoot, root)
	if selfOrRoot ~= Icons then root = selfOrRoot end
	Icons.CacheRoot = trimTrailingSlash(root)
	Icons.Resolved = {}
	return Icons.CacheRoot
end

function Icons.Path(selfOrKey, key)
	local entry = entryFromCall(selfOrKey, key)
	return entry and resolvedPath(entry) or nil
end

function Icons.Url(selfOrKey, key)
	local entry = entryFromCall(selfOrKey, key)
	return entry and remoteUrl(entry) or nil
end

function Icons.AssetId(selfOrKey, key)
	local entry = entryFromCall(selfOrKey, key)
	return entry and normalizeAssetId(entry.AssetId) or nil
end

function Icons.Resolve(selfOrKey, key, forceRefresh)
	local entry = entryFromCall(selfOrKey, key)
	if not entry then return nil end

	if forceRefresh ~= true and Icons.Resolved[entry.Id] then
		return Icons.Resolved[entry.Id]
	end

	local path = resolvedPath(entry)
	local exists = fileExists(path)
	if exists ~= false then
		local localAsset = customAsset(path)
		if localAsset then
			Icons.Resolved[entry.Id] = localAsset
			Icons.Errors[entry.Id] = nil
			return localAsset
		end
	end

	local url = remoteUrl(entry)
	if url then
		local data, downloadError = httpGet(url)
		if data and isPng(data) then
			local saved, saveError = writeBinary(path, data)
			if saved then
				local downloadedAsset, assetError = customAsset(path)
				if downloadedAsset then
					Icons.Resolved[entry.Id] = downloadedAsset
					Icons.Errors[entry.Id] = nil
					return downloadedAsset
				end
				Icons.Errors[entry.Id] = assetError
			else
				Icons.Errors[entry.Id] = saveError
			end
		else
			Icons.Errors[entry.Id] = downloadError or "downloaded file is not a PNG"
		end
	end

	local assetId = normalizeAssetId(entry.AssetId)
	if assetId then
		Icons.Resolved[entry.Id] = assetId
		return assetId
	end

	Icons.Errors[entry.Id] = Icons.Errors[entry.Id] or "no usable local, remote, or Roblox asset"
	return nil
end

function Icons.PrepareAll(selfOrForce, forceRefresh)
	if selfOrForce ~= Icons then forceRefresh = selfOrForce end

	local resolved = {}
	local missing = {}
	for index = 0, 6 do
		local asset = Icons:Resolve(index, forceRefresh == true)
		resolved[index] = asset
		if not asset then table.insert(missing, index) end
	end
	return resolved, missing
end

function Icons.Status()
	local status = {}
	for index = 0, 6 do
		status[index] = {
			Ready = Icons.Resolved[index] ~= nil,
			Path = Icons:Path(index),
			Url = Icons:Url(index),
			Error = Icons.Errors[index],
		}
	end
	return status
end

return Icons
