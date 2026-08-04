--[[
	TRust Menu - GitHub Raw executor loader

	Before publishing, replace YOUR_GITHUB_USERNAME below once. After that,
	every script can load this file directly from GitHub Raw.
]]

local DEFAULT_RAW_BASE = "https://raw.githubusercontent.com/nadmksa123456-lgtm/TRusthub/refs/heads/main"
local environment = type(getgenv) == "function" and getgenv() or _G

local function trimTrailingSlash(value)
	return tostring(value or ""):gsub("\\", "/"):gsub("/+$", "")
end

local function joinPath(root, fileName)
	root = trimTrailingSlash(root)
	fileName = tostring(fileName or ""):gsub("\\", "/"):gsub("^/+", "")
	if root == "" or root == "." then return fileName end
	return root .. "/" .. fileName
end

local configuredBase = environment.TRUST_MENU_BASE_URL
local remoteBase = trimTrailingSlash(configuredBase or DEFAULT_RAW_BASE)

local localRoot = tostring(environment.TRUST_MENU_ROOT or ".")
local cacheRoot = tostring(environment.TRUST_MENU_CACHE_ROOT or "TRust-Menu/assets")
local agendaFontFile = "assets/Agenda-Semibold.ttf"
local agendaFontCacheFile = joinPath(cacheRoot, "Agenda-Semibold.ttf")
local agendaFamilyCacheFile = joinPath(cacheRoot, "Agenda-One-SemiBold.json")

local function executorRequest()
	local direct = environment.request or environment.http_request
	if type(direct) == "function" then return direct end
	if type(environment.syn) == "table" and type(environment.syn.request) == "function" then
		return environment.syn.request
	end
	if type(environment.http) == "table" and type(environment.http.request) == "function" then
		return environment.http.request
	end
	return nil
end

local function httpGet(url)
	local gameOk, gameBody = pcall(function()
		return game:HttpGet(url)
	end)
	if gameOk and type(gameBody) == "string" and #gameBody > 0 then
		return gameBody
	end

	local requestFunction = executorRequest()
	if requestFunction then
		local requestOk, response = pcall(requestFunction, {
			Url = url,
			Method = "GET",
			Headers = {Accept = "application/octet-stream,text/plain,*/*"},
		})
		if requestOk and type(response) == "table" then
			local statusCode = tonumber(response.StatusCode or response.Status)
			local body = response.Body or response.body
			if (response.Success == true or (statusCode and statusCode >= 200 and statusCode < 300))
				and type(body) == "string" and #body > 0 then
				return body
			end
		end
	end

	return nil, tostring(gameBody or "HTTP request failed")
end

local function environmentFunction(name)
	local value = environment[name]
	return type(value) == "function" and value or nil
end

local function fileExists(path)
	local isFile = environmentFunction("isfile")
	if not isFile then return nil end

	local ok, exists = pcall(isFile, path)
	return ok and exists == true
end

local function ensureFolder(path)
	local makeFolder = environmentFunction("makefolder")
	if not makeFolder or not path or path == "" then return end

	local isFolder = environmentFunction("isfolder")
	if isFolder then
		local ok, exists = pcall(isFolder, path)
		if ok and exists then return end
	end
	pcall(makeFolder, path)
end

local function isTrueTypeFont(data)
	if type(data) ~= "string" or #data < 1024 then return false end

	local signature = string.sub(data, 1, 4)
	return signature == "\0\1\0\0"
		or signature == "OTTO"
		or signature == "true"
		or signature == "ttcf"
end

local function writeExecutorFile(path, data)
	local writeFile = environmentFunction("writefile")
	if not writeFile then return false, "writefile is unavailable" end

	ensureFolder(cacheRoot)
	local ok, message = pcall(writeFile, path, data)
	if not ok then return false, tostring(message) end
	return true
end

local function resolveCustomAsset(path)
	local resolver = environmentFunction("getcustomasset") or environmentFunction("getsynasset")
	if not resolver then return nil, "getcustomasset/getsynasset is unavailable" end

	local ok, asset = pcall(resolver, path)
	if ok and type(asset) == "string" and asset ~= "" then return asset end
	return nil, tostring(asset or "unable to create custom asset")
end

local function prepareAgendaFont()
	if type(environment.TRUST_MENU_FONT_FAMILY) == "string"
		and environment.TRUST_MENU_FONT_FAMILY ~= "" then
		return environment.TRUST_MENU_FONT_FAMILY
	end

	local fontPath = agendaFontCacheFile
	if fileExists(fontPath) ~= true then
		local fontUrl = joinPath(remoteBase, agendaFontFile)
		local fontData, downloadError = httpGet(fontUrl)
		if not isTrueTypeFont(fontData) then
			return nil, downloadError or "downloaded Agenda font is not a valid TTF/OTF file"
		end

		local saved, saveError = writeExecutorFile(fontPath, fontData)
		if not saved then return nil, saveError end
	end

	local fontAsset, fontAssetError = resolveCustomAsset(fontPath)
	if not fontAsset then return nil, fontAssetError end

	local familyData = game:GetService("HttpService"):JSONEncode({
		name = "Agenda One",
		faces = {
			{
				name = "Semi Bold",
				weight = 600,
				style = "normal",
				assetId = fontAsset,
			},
		},
	})

	local familySaved, familySaveError = writeExecutorFile(agendaFamilyCacheFile, familyData)
	if not familySaved then return nil, familySaveError end

	local familyAsset, familyAssetError = resolveCustomAsset(agendaFamilyCacheFile)
	if not familyAsset then return nil, familyAssetError end

	environment.TRUST_MENU_FONT_FAMILY = familyAsset
	environment.TRUST_MENU_FONT_NAME = "Agenda One Semi Bold"
	environment.TRUST_MENU_FONT_SINGLE_WEIGHT = true
	return familyAsset
end

local function readLocal(fileName)
	local readFile = environment.readfile
	if type(readFile) ~= "function" then return nil end

	local path = joinPath(localRoot, fileName)
	if type(environment.isfile) == "function" then
		local ok, exists = pcall(environment.isfile, path)
		if not ok or not exists then return nil end
	end

	local ok, source = pcall(readFile, path)
	if ok and type(source) == "string" and #source > 0 then
		return source, path
	end
	return nil
end

local function getModuleSource(fileName)
	if remoteBase then
		local url = joinPath(remoteBase, fileName)
		local source, message = httpGet(url)
		if source then return source, url end
		warn(("[TRust Menu] Remote load failed for %s: %s"):format(fileName, tostring(message)))
	end

	local source, path = readLocal(fileName)
	if source then return source, path end

	if not remoteBase then
		error(("[TRust Menu] Raw repository URL is not configured. Set getgenv().TRUST_MENU_BASE_URL, "
			.. "or replace YOUR_GITHUB_USERNAME in loader.lua before publishing. Missing: %s")
			:format(fileName), 3)
	end

	error(("[TRust Menu] Unable to load %s from GitHub Raw or local executor files."):format(fileName), 3)
end

local function loadModule(fileName)
	local source, origin = getModuleSource(fileName)
	local compiler = environment.loadstring or loadstring
	if type(compiler) ~= "function" then
		error("[TRust Menu] This executor does not expose loadstring.", 3)
	end

	local compileOk, chunkOrError = pcall(compiler, source, "@" .. origin)
	if not compileOk or type(chunkOrError) ~= "function" then
		error(("[TRust Menu] Failed to compile %s: %s"):format(origin, tostring(chunkOrError)), 3)
	end

	local runOk, moduleOrError = pcall(chunkOrError)
	if not runOk then
		error(("[TRust Menu] Failed to run %s: %s"):format(origin, tostring(moduleOrError)), 3)
	end
	return moduleOrError
end

local Icons = loadModule("icons.lua")
assert(type(Icons) == "table", "[TRust Menu] icons.lua did not return its registry")

Icons:Configure({
	Root = localRoot,
	BaseUrl = remoteBase,
	CacheRoot = remoteBase and cacheRoot or nil,
})

local preparedAssets, missingAssets = Icons:PrepareAll(false)
if #missingAssets > 0 then
	warn("[TRust Menu] Some images could not be prepared: " .. table.concat(missingAssets, ", "))
end

local preparedFont, fontError = prepareAgendaFont()
if not preparedFont then
	warn("[TRust Menu] Agenda One Semi Bold could not be loaded; using the safe fallback: "
		.. tostring(fontError))
end

local Library = loadModule("source.lua")
assert(type(Library) == "table", "[TRust Menu] source.lua did not return the library")

Library.Icons = Icons
Library.AssetBaseUrl = remoteBase
Library.PreparedAssets = preparedAssets
Library.MissingAssets = missingAssets
Library.PreparedFont = preparedFont
Library.FontError = fontError

function Library:GetIcon(index, forceRefresh)
	return self.Icons:Resolve(index, forceRefresh == true)
end

function Library:PrepareAssets(forceRefresh)
	local ready, missing = self.Icons:PrepareAll(forceRefresh == true)
	self.PreparedAssets = ready
	self.MissingAssets = missing
	return ready, missing
end

function Library:GetAssetStatus()
	return self.Icons.Status()
end

local createWindow = Library.CreateWindow
function Library:CreateWindow(options)
	options = options or {}
	local preparedOptions = {}
	for key, value in options do preparedOptions[key] = value end

	if preparedOptions.Logo == nil and preparedOptions.LogoFile == nil then
		preparedOptions.Logo = self:GetIcon(0)
	end
	if preparedOptions.ShowBrandName == nil then
		preparedOptions.ShowBrandName = false
	end

	return createWindow(self, preparedOptions)
end

return Library
