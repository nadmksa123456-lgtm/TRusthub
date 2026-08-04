local files = {}
local folders = {}
local httpCount = 0

local function isfile(path)
	return files[path] ~= nil
end

local function isfolder(path)
	return folders[path] == true
end

local function makefolder(path)
	folders[path] = true
end

local function writefile(path, data)
	files[path] = data
end

local function getcustomasset(path)
	assert(files[path] ~= nil, "missing custom asset file: " .. path)
	return "rbxasset://" .. path
end

local gameMock = {
	HttpGet = function(_, url)
		httpCount += 1
		return string.char(137) .. "PNG\r\n" .. string.char(26) .. "\n" .. "fake:" .. url
	end,
}

local Icons = require("../icons")
Icons:Configure({
	BaseUrl = "https://raw.githubusercontent.com/example/TRust-Menu/main",
	CacheRoot = "TRust-Menu/assets",
	Environment = {
		game = gameMock,
		isfile = isfile,
		isfolder = isfolder,
		makefolder = makefolder,
		writefile = writefile,
		getcustomasset = getcustomasset,
	},
})

local resolved, missing = Icons:PrepareAll()
assert(#missing == 0, "all seven images should resolve")
assert(httpCount == 7, "every missing image should download once")

for index = 0, 6 do
	local path = "TRust-Menu/assets/" .. tostring(index) .. ".png"
	assert(files[path] ~= nil, "image was not cached: " .. path)
	assert(resolved[index] == "rbxasset://" .. path, "unexpected resolved asset")
end

Icons.Resolved = {}
local cached, cachedMissing = Icons:PrepareAll()
assert(#cachedMissing == 0, "cached images should resolve")
assert(httpCount == 7, "cached images must not download twice")
assert(cached[0] == "rbxasset://TRust-Menu/assets/0.png", "logo should resolve from cache")

print("icons.spec.lua: PASS")
