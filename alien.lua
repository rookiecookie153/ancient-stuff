local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Debris = game:GetService("Debris")
local LogService = game:GetService("LogService")

local WEBHOOK = getfenv().WEBHOOK

local function recurse(t, f, search, depth)
	search = search or {}
	depth = depth or 0

	search[tostring(t)] = true

	for i, v in t do
		if type(v) == 'table' then
			local memind = tostring(v)
			local exists = search[memind]
			if not exists then
				search[memind] = true
				recurse(v, f, search, depth+1)
			end
		else
			f(t, i, v, depth)
		end
	end
end

local BlockedIDs = {}

local function getModuleScriptFromFunction(func)
	local env = getfenv(func)
	local sc = env.script
	if not sc or sc == script then return end
	return sc
end

local function onlog(msg, msgType)
	if not msg:find("Requiring asset") or msgType ~= Enum.MessageType.MessageOutput then return end
	local id = tonumber(string.match(msg, "%d+"))
	if not id or BlockedIDs[id] then return end
	BlockedIDs[id] = true
	local s, e = pcall(function(id)
		local data = require(id)
		local module
		if type(data) == "table" then
			recurse(data, function(_t, index, value)
				if module then return end
				if type(value) ~= "function" then return end
				pcall(function()
					module = getModuleScriptFromFunction(value)
				end)
			end)
		elseif type(data) == "function" then
			pcall(function()
				module = getModuleScriptFromFunction(data)
			end)
		end
		
		if not module then
			return
		end
		
		local truename = "MainModule"
		local creator = "Unknown"
		pcall(function()
			local data = MarketplaceService:GetProductInfo(id)
			truename = data.Name or truename
			creator = data.Creator and data.Creator.Name or creator
		end)
		
		local s, e = pcall(function()
			HttpService:PostAsync(WEBHOOK, HttpService:JSONEncode {
				content = string.format("# %s by %s\nhttps://create.roblox.com/store/asset/%s", truename, creator, tostring(id));
			}, Enum.HttpContentType.ApplicationJson)
		end)
	end, id)
end

LogService.MessageOut:Connect(onlog)
for i, v in pairs(LogService:GetLogHistory()) do
	onlog(v.message, v.messageType)
end

return 0
