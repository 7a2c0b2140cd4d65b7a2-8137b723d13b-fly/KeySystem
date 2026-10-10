-- ═══════════════════════════════════════════════════════════════
--  CORE SECURITY: ANTI-HOOK, ANTI-SPY, & ANTI-TAMPER
--  Flycer Hub Protection V1.0
-- ═══════════════════════════════════════════════════════════════
local Proteksi = { Aman = true }

-- GANTI dengan URL Webhook Discord Anda sendiri untuk menerima log deteksi
local FLYCER_ALERT_WEBHOOK = "YOUR_DISCORD_WEBHOOK_HERE"
local FLYCER_VERSION = "v1.0.0"

local function GenerateDetectionID()
	return string.format("FLYCER-%06X", math.random(0, 0xFFFFFF))
end

local function Banned(alasan)
	Proteksi.Aman = false

	pcall(function()
		local HttpService = game:GetService("HttpService")

		local gameName = "Unknown"
		pcall(function()
			local info = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
			gameName = info.Name or "Unknown"
		end)

		local detectionId = GenerateDetectionID()
		local timeNow = DateTime.now():ToIsoDate()
		local alasanStr = tostring(alasan)

		-- Format payload pesan untuk Discord Webhook
		local body = HttpService:JSONEncode({
			username = "Flycer Security",
			embeds = {{
				title = "🛡️ Flycer Hub — Proteksi Terpicu",
				color = 16711680, -- Merah
				fields = {
					{ name = "Alasan Deteksi", value = "```" .. alasanStr .. "```", inline = false },
					{ name = "Game", value = gameName, inline = true },
					{ name = "Place ID", value = "`" .. tostring(game.PlaceId) .. "`", inline = true },
					{ name = "Action", value = "`Execution Blocked & Player Kicked`", inline = false },
					{ name = "Detection ID", value = "`" .. detectionId .. "`", inline = true }
				},
				footer = { text = "Flycer Protection " .. FLYCER_VERSION .. " • " .. timeNow }
			}}
		})

		local req = (syn and syn.request) or (http and http.request) or http_request or request
		if req then
			req({
				Url = FLYCER_ALERT_WEBHOOK,
				Method = "POST",
				Headers = { ["Content-Type"] = "application/json" },
				Body = body,
			})
		end
	end)

	local p = game:GetService("Players").LocalPlayer
	if p then
		p:Kick("Flycer Hub — Access Denied: " .. tostring(alasan))
	end
	task.wait(9e9)
end

-- Deteksi Metamethod & Hooking (Anti-RemoteSpy)
pcall(function()
	local dummyEvent = Instance.new("RemoteEvent")
	local dummyFunc = Instance.new("RemoteFunction")

	local realFire = dummyEvent.FireServer
	local realInvoke = dummyFunc.InvokeServer

	if ishooked then
		if ishooked(realFire) and ishooked(realInvoke) then
			Banned("RemoteSpy Detected (FireServer & InvokeServer Hook)")
		end
	end

	if iscclosure and islclosure then
		if islclosure(realFire) and islclosure(realInvoke) then
			Banned("RemoteSpy Detected (Remote Closure Hook)")
		end
	end

	if getrawmetatable then
		local ok, mt = pcall(getrawmetatable, game)
		if ok and mt then
			local namecall = mt.__namecall
			if namecall then
				if ishooked and ishooked(namecall) then
					Banned("RemoteSpy Detected (__namecall Hook)")
				end
				if islclosure and islclosure(namecall) then
					Banned("RemoteSpy Detected (__namecall Lua Closure)")
				end
			end
		end
	end

	-- Deteksi UI Ilegal (Dex Explorer, SimpleSpy, Hydroxide, dll.)
	local KataTerlarang = {
		"hydroxide", "turtle spy", "cobalt", "bypasser", "remote spy",
		"simple spy", "ultimate debugging suite", "dark dex", "dex++", "httpspy", "http spy"
	}
	local SafeWords = {
		"codex", "index", "pokedex", "delta", "arceus", "fluxus", "hydrogen",
		"macsploit", "vegas", "evon", "furk", "trigon", "executor", "menu", "hub", "solana", "naaellx"
	}
	local IgnoreGuis = {
		"robloxgui", "chat", "bubblechat", "playerlist", "teleportgui",
		"robloxpromptgui", "purchaseprompt", "corescriptsroot"
	}

	local function isDexOrSpy(str)
		str = string.lower(str)
		if str == "dex" or str == "spy" then return false end
		if string.find(str, "dex") or string.find(str, "spy") then
			for _, safe in ipairs(SafeWords) do
				if string.find(str, safe) then return false end
			end
			return true
		end
		return false
	end

	task.spawn(function()
		while Proteksi.Aman do
			task.wait(3)
			local currentContainers = { game:GetService("CoreGui") }
			pcall(function()
				if gethui then table.insert(currentContainers, gethui()) end
			end)

			for _, container in ipairs(currentContainers) do
				pcall(function()
					for _, ui in ipairs(container:GetChildren()) do
						pcall(function()
							local name = string.lower(ui.Name)
							if table.find(IgnoreGuis, name) then return end

							for _, bad in ipairs(KataTerlarang) do
								if string.find(name, bad) then
									Banned("Illegal UI Detected (" .. bad .. ")")
								end
							end
							if isDexOrSpy(name) then
								Banned("Illegal UI Detected (" .. name .. ")")
							end

							for _, desc in pairs(ui:GetDescendants()) do
								pcall(function()
									if desc:IsA("TextLabel") or desc:IsA("TextButton") or desc:IsA("TextBox") then
										local textStr = string.lower(desc.Text)
										if string.len(textStr) < 40 then
											for _, bad in ipairs(KataTerlarang) do
												if string.find(textStr, bad) then
													Banned("Illegal Text Element Detected (" .. textStr .. ")")
												end
											end
										end
									end
								end)
							end
						end)
					end
				end)
			end
		end
	end)
end)

-- Deteksi HTTP Logger / Env Logger
pcall(function()
	local candidates = {
		{ "request", request },
		{ "http_request", http_request },
		{ "syn.request", syn and syn.request },
		{ "http.request", http and http.request },
		{ "fluxus.request", fluxus and fluxus.request },
	}

	for _, pair in ipairs(candidates) do
		local name, fn = pair[1], pair[2]
		if fn then
			if ishooked and ishooked(fn) then
				Banned("HTTP Logger Detected (" .. name .. " hooked)")
			end
			if islclosure and islclosure(fn) then
				Banned("HTTP Logger Detected (" .. name .. " is Lua closure)")
			end
		end
	end

	local suspiciousNames = { "envlog", "httplog", "logrequest", "hookhttp", "spyhttp" }
	pcall(function()
		for k, v in pairs(getgenv and getgenv() or {}) do
			if type(k) == "string" and type(v) == "function" then
				local lower = string.lower(k)
				for _, bad in ipairs(suspiciousNames) do
					if string.find(lower, bad) then
						Banned("HTTP Logger Detected (getgenv()." .. k .. ")")
					end
				end
			end
		end
	end)
end)

-- Cegah eksekusi jika salah satu proteksi terpicu
if not Proteksi.Aman then
	return
end

-- ═══════════════════════════════════════════════════════════════
--  CONFIG - EDIT DI SINI
-- ═══════════════════════════════════════════════════════════════
local CONFIG = {
	DATABASE_URL = "https://raw.githubusercontent.com/Lyfe-e40d0ba8-d728-4fcf-9e39/403/refs/heads/main/api/whitelist.json",
	LOADER_DATABASE_URL = "https://raw.githubusercontent.com/Lyfe-e40d0ba8-d728-4fcf-9e39/flycer-3c54-4ef4-a15e-619d/main/loader/Creator.lua", 
	DISCORD_LINK = "discord.gg/RCASHh828K",
	SaveKey = true,
	SaveFolder = "FlycerHub_LicenseKeys",
}

-- ═══════════════════════════════════════════════════════════════
--  SERVICES
-- ═══════════════════════════════════════════════════════════════
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local player = Players.LocalPlayer

-- ═══════════════════════════════════════════════════════════════
--  LOAD ICONS V2 - BY : FOOTAGESUS
-- ═══════════════════════════════════════════════════════════════
local IconsV2 = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Footagesus/Icons/main/Main-v2.lua"))()
IconsV2.SetIconsType("lucide")

local ICON_KEY = IconsV2.GetIcon("key-round")
local ICON_SEND = IconsV2.GetIcon("send")
local ICON_COPY = IconsV2.GetIcon("copy")
local ICON_DISCORD = IconsV2.GetIcon("message-circle")
local ICON_UNLOCK = IconsV2.GetIcon("key-round")
local ICON_FINGER = IconsV2.GetIcon("fingerprint")
local ICON_CLOSE = IconsV2.GetIcon("x")

-- ═══════════════════════════════════════════════════════════════
--  ASSETS
-- ═══════════════════════════════════════════════════════════════
local FONT = Font.new("rbxassetid://12187365364", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
local FONT_BOLD = Font.new("rbxassetid://12187365364", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
local GLOW = "rbxassetid://8992230677"
local LOGO = "rbxassetid://103859712365480"

-- ═══════════════════════════════════════════════════════════════
--  SIZES
-- ═══════════════════════════════════════════════════════════════
local INTRO_SIZE = 80
local LOADING_TIME = 3
local SQUARE_TIME = 3
local FINAL_W = 460
local FINAL_H = 260
local PADDING = 1.4

-- ═══════════════════════════════════════════════════════════════
--  COLORS
-- ═══════════════════════════════════════════════════════════════
local C = {
	bg = Color3.fromRGB(20, 16, 20),
	input = Color3.fromRGB(24, 19, 24),
	card = Color3.fromRGB(28, 22, 28),
	stroke = Color3.fromRGB(40, 32, 41),
	btn2 = Color3.fromRGB(42, 36, 43),
	btn2Hover = Color3.fromRGB(54, 47, 55),
	text = Color3.fromRGB(233, 229, 234),
	muted = Color3.fromRGB(125, 115, 126),
	accent = Color3.fromRGB(235, 199, 246),
	dark = Color3.fromRGB(24, 18, 26),
	warn = Color3.fromRGB(240, 176, 108),
}

-- ═══════════════════════════════════════════════════════════════
--  UI HELPERS
-- ═══════════════════════════════════════════════════════════════
local function make(class, props, parent)
	local inst = Instance.new(class)
	for k, v in pairs(props) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function frame(parent, x, y, w, h, color, transparency)
	return make("Frame", {
		Position = UDim2.new(0, x, 0, y),
		Size = UDim2.new(0, w, 0, h),
		BackgroundColor3 = color or C.bg,
		BackgroundTransparency = transparency or 1,
		BorderSizePixel = 0,
	}, parent)
end

local function text(parent, str, x, y, w, h, size, color, align)
	return make("TextLabel", {
		Position = UDim2.new(0, x, 0, y),
		Size = UDim2.new(0, w, 0, h),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = str,
		TextSize = size,
		TextColor3 = color,
		TextXAlignment = align or Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		FontFace = FONT,
	}, parent)
end

local function round(parent, radius, strokeColor)
	make("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
	if strokeColor then
		make("UIStroke", {
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			Color = strokeColor,
		}, parent)
	end
end

local function icon(parent, x, y, color, iconImg, size)
	size = size or 16
	local holder = frame(parent, x, y, size, size)
	make("ImageLabel", {
		Name = "iconglow",
		Size = UDim2.new(2, 0, 2, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = GLOW,
		ImageColor3 = color,
		ImageTransparency = 0.9,
		ZIndex = 0,
	}, holder)
	make("ImageLabel", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Image = iconImg,
		ImageColor3 = color,
	}, holder)
	return holder
end

local function decor(parent, w, h, x, y, transparency, rotation)
	local img = make("ImageLabel", {
		Size = UDim2.new(0, w, 0, h),
		Position = UDim2.new(0, x, 0, y),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = GLOW,
		ImageColor3 = Color3.fromRGB(226, 218, 230),
		ImageTransparency = transparency,
		ScaleType = Enum.ScaleType.Stretch,
	}, parent)
	make("UIGradient", {
		Rotation = rotation,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(1, C.accent),
		}),
	}, img)
	return img
end

local function centered(parent, w, h)
	return make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, w, 0, h),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, parent)
end

local function tween(inst, time, props, style, dir)
	local t = TweenService:Create(
		inst,
		TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end

local function prep(container)
	local items = {}
	local function add(inst)
		if inst:IsA("GuiObject") then
			items[#items + 1] = { inst, "BackgroundTransparency", inst.BackgroundTransparency }
			if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
				items[#items + 1] = { inst, "TextTransparency", inst.TextTransparency }
			elseif inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
				items[#items + 1] = { inst, "ImageTransparency", inst.ImageTransparency }
			end
		elseif inst:IsA("UIStroke") then
			items[#items + 1] = { inst, "Transparency", inst.Transparency }
		end
	end
	add(container)
	for _, d in ipairs(container:GetDescendants()) do
		add(d)
	end
	return items
end

local function fade(items, alpha, time)
	for _, it in ipairs(items) do
		local inst, prop, orig = it[1], it[2], it[3]
		local target = 1 - (1 - orig) * alpha
		if time and time > 0 then
			tween(inst, time, { [prop] = target })
		else
			inst[prop] = target
		end
	end
end

-- ═══════════════════════════════════════════════════════════════
--  SHA256 & HWID GETTER (PERSIS SEPERTI PLATOBOOST / 64-HEX)
-- ═══════════════════════════════════════════════════════════════
local function sha256(msg)
	msg = tostring(msg)
	
	-- Coba gunakan fungsi hash bawaan executor jika tersedia
	if crypt and crypt.hash then
		local ok, res = pcall(crypt.hash, msg, "sha256")
		if ok and res then return string.lower(tostring(res)) end
	end
	if syn and syn.crypt and syn.crypt.hash then
		local ok, res = pcall(syn.crypt.hash, msg, "sha256")
		if ok and res then return string.lower(tostring(res)) end
	end

	-- Pure Luau / Bitwise SHA-256 fallback
	local band, bxor, bnot = bit32.band, bit32.bxor, bit32.bnot
	local rshift, lshift = bit32.rshift, bit32.lshift
	local rrotate = bit32.rrotate or function(x, n)
		return bxor(rshift(x, n), lshift(x, 32 - n))
	end

	local K = {
		0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
		0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
		0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
		0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
		0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
		0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
		0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
		0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
		0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
		0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
		0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
		0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
		0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
		0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
		0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
		0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
	}

	local H = {
		0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
		0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
	}

	local msgLen = #msg * 8
	local padded = msg .. "\128"
	local padLen = (56 - (#padded % 64)) % 64
	padded = padded .. string.rep("\0", padLen)
	
	local highLen = math.floor(msgLen / 4294967296)
	local lowLen = msgLen % 4294967296
	padded = padded .. string.char(
		rshift(highLen, 24), band(rshift(highLen, 16), 0xFF), band(rshift(highLen, 8), 0xFF), band(highLen, 0xFF),
		rshift(lowLen, 24), band(rshift(lowLen, 16), 0xFF), band(rshift(lowLen, 8), 0xFF), band(lowLen, 0xFF)
	)

	local W = {}
	for i = 1, #padded, 64 do
		for j = 0, 15 do
			local idx = i + j * 4
			local b1, b2, b3, b4 = string.byte(padded, idx, idx + 3)
			W[j + 1] = lshift(b1, 24) + lshift(b2, 16) + lshift(b3, 8) + b4
		end

		for j = 17, 64 do
			local v1 = W[j - 2]
			local s1 = bxor(rrotate(v1, 17), rrotate(v1, 19), rshift(v1, 10))
			local v2 = W[j - 15]
			local s0 = bxor(rrotate(v2, 7), rrotate(v2, 18), rshift(v2, 3))
			W[j] = (W[j - 16] + s0 + W[j - 7] + s1) % 4294967296
		end

		local a, b, c, d, e, f, g, h = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]

		for j = 1, 64 do
			local S1 = bxor(rrotate(e, 6), rrotate(e, 11), rrotate(e, 25))
			local ch = bxor(band(e, f), band(bnot(e), g))
			local temp1 = (h + S1 + ch + K[j] + W[j]) % 4294967296
			local S0 = bxor(rrotate(a, 2), rrotate(a, 13), rrotate(a, 22))
			local maj = bxor(band(a, b), band(a, c), band(b, c))
			local temp2 = (S0 + maj) % 4294967296

			h = g
			g = f
			f = e
			e = (d + temp1) % 4294967296
			d = c
			c = b
			b = a
			a = (temp1 + temp2) % 4294967296
		end

		H[1] = (H[1] + a) % 4294967296
		H[2] = (H[2] + b) % 4294967296
		H[3] = (H[3] + c) % 4294967296
		H[4] = (H[4] + d) % 4294967296
		H[5] = (H[5] + e) % 4294967296
		H[6] = (H[6] + f) % 4294967296
		H[7] = (H[7] + g) % 4294967296
		H[8] = (H[8] + h) % 4294967296
	end

	local result = {}
	for i = 1, 8 do
		table.insert(result, string.format("%08x", H[i]))
	end
	return table.concat(result)
end

local function getHwid()
	if gethwid then
		local ok, hwid = pcall(gethwid)
		if ok and hwid ~= nil and tostring(hwid) ~= "" then
			return tostring(hwid)
		end
	end
	local lp = Players.LocalPlayer
	return tostring(lp and lp.UserId or 0)
end

local _cachedHWID = nil
local function getCachedHWID()
	if _cachedHWID then
		return _cachedHWID
	end
	_cachedHWID = sha256(getHwid())
	return _cachedHWID
end

-- ═══════════════════════════════════════════════════════════════
--  SAVE KEY HELPERS
-- ═══════════════════════════════════════════════════════════════
local function getSavePath()
	return CONFIG.SaveFolder .. "/" .. getCachedHWID() .. ".key"
end

local function ensureFolder()
	pcall(function()
		if makefolder and isfolder then
			if not isfolder(CONFIG.SaveFolder) then
				makefolder(CONFIG.SaveFolder)
			end
		elseif makefolder then
			makefolder(CONFIG.SaveFolder)
		end
	end)
end

local function saveKeyToFile(key)
	if not CONFIG.SaveKey then
		return
	end
	ensureFolder()
	pcall(function()
		writefile(getSavePath(), key)
	end)
end

local function loadKeyFromFile()
	if not CONFIG.SaveKey then
		return nil
	end
	local ok, r = pcall(function()
		local p = getSavePath()
		if isfile and readfile and isfile(p) then
			local c = readfile(p)
			if c and c ~= "" then
				return c
			end
		end
		return nil
	end)
	return ok and r or nil
end

local function clearSavedKey()
	pcall(function()
		local p = getSavePath()
		if isfile and isfile(p) then
			if delfile then
				delfile(p)
			elseif writefile then
				writefile(p, "")
			end
		end
	end)
end

-- ═══════════════════════════════════════════════════════════════
--  LOADER DATABASE (FETCH DARI GITHUB)
-- ═══════════════════════════════════════════════════════════════
local SUPPORTED_GAMES = {} -- PlaceId → loader URL
local loaderDataReady = false
local loaderFetchFailed = false

local function fetchLoaderDatabase()
	local ok, result = pcall(function()
		local raw = game:HttpGet(CONFIG.LOADER_DATABASE_URL .. "?nocache=" .. tostring(math.floor(tick() * 1000)))
		if raw and raw ~= "" then
			local fn = loadstring(raw)
			if fn then
				local data = fn()
				if type(data) == "table" then
					return data
				end
			end
		end
		return nil
	end)
	if ok and result then
		SUPPORTED_GAMES = result
		loaderDataReady = true
	else
		loaderFetchFailed = true
		loaderDataReady = true
	end
end

-- ═══════════════════════════════════════════════════════════════
--  KEY VERIFICATION
-- ═══════════════════════════════════════════════════════════════
local function formatRemainingTime(sec)
	if sec <= 0 then
		return "Expired"
	end
	local parts, rem = {}, sec
	for _, u in ipairs({ { 86400, "Day" }, { 3600, "Hours" }, { 60, "Minute" } }) do
		local v = math.floor(rem / u[1])
		rem = rem % u[1]
		if v > 0 then
			table.insert(parts, v .. " " .. u[2])
		end
	end
	return #parts == 0 and "< 1 Minute" or table.concat(parts, " ")
end

local function fetchDatabase()
	local ok, resp = pcall(function()
		return game:HttpGet(CONFIG.DATABASE_URL .. "?nocache=" .. tostring(math.floor(tick() * 1000)))
	end)
	if not ok or not resp then
		return nil, "Failed to connect to server."
	end
	local ok2, db = pcall(function()
		return HttpService:JSONDecode(resp)
	end)
	if not ok2 or not db or type(db) ~= "table" then
		return nil, "Invalid database format."
	end
	return db, nil
end

local function verifyKey(inputKey)
	local db, err = fetchDatabase()
	if not db then
		return false, err
	end
	local playerHWID = getCachedHWID()
	local keyData = nil
	for _, entry in ipairs(db) do
		if entry["user key"] == inputKey then
			keyData = entry
			break
		end
	end
	if not keyData then
		return false, "The key is incorrect or not found."
	end
	if keyData.active == false then
		return false, "This key has been deactivated."
	end
	local keyType = keyData["type key"]
	local hwidList = keyData["user hwid"] or {}
	local maxDev = keyData["max_devices"] or 1
	local expireTS = keyData["expiredkey_timestamp"] or 0
	if keyType == "free" then
		if expireTS > 0 then
			local rem = expireTS - os.time()
			if rem <= 0 then
				return false, "Free key has expired."
			end
			return true, "Free key verified. Time remaining: " .. formatRemainingTime(rem), keyData
		end
		return true, "Free key verified. Unlimited Access.", keyData
	end
	local found = false
	for _, h in ipairs(hwidList) do
		if tostring(h):lower() == playerHWID then
			found = true
			break
		end
	end
	if not found then
		if #hwidList >= maxDev then
			return false, "Max devices reached. HWID not whitelisted."
		else
			return false, "HWID is not registered for this key."
		end
	end
	if keyType == "lifetime" then
		return true, "Key verified. Lifetime Access.", keyData
	end
	if keyType == "duration" then
		if expireTS > 0 then
			local rem = expireTS - os.time()
			if rem <= 0 then
				return false, "Your key has expired."
			end
			return true, "Key verified. Time remaining: " .. formatRemainingTime(rem), keyData
		end
		return true, "Key verified.", keyData
	end
	return false, "Unknown key type. Contact support."
end

-- ═══════════════════════════════════════════════════════════════
--  DESTROY EXISTING GUI
-- ═══════════════════════════════════════════════════════════════
pcall(function()
	local e = CoreGui:FindFirstChild("FlycerKeySystem")
	if e then
		e:Destroy()
	end
end)

-- ═══════════════════════════════════════════════════════════════
--  BUILD GUI
-- ═══════════════════════════════════════════════════════════════
local root = Instance.new("ScreenGui")
root.Name = "FlycerKeySystem"
root.Enabled = true
root.DisplayOrder = 999
root.IgnoreGuiInset = true
root.ResetOnSpawn = false
root.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
root.ClipToDeviceSafeArea = true

-- ═══════════════════════════════════════════════════════════════
--  AUTO SCALE SYSTEM
-- ═══════════════════════════════════════════════════════════════
local WINDOW_SIZE = Vector2.new(FINAL_W * PADDING, FINAL_H * PADDING)

local uiScaleObject = Instance.new("UIScale")
uiScaleObject.Scale = 1
uiScaleObject.Parent = root

local currentScale = 1

local function applyScale()
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or root.AbsoluteSize
	local ns = math.min(vp.X / WINDOW_SIZE.X, vp.Y / WINDOW_SIZE.Y)
	if math.abs(ns - currentScale) > 0.005 then
		currentScale = ns
		TweenService
			:Create(uiScaleObject, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Scale = ns })
			:Play()
	end
end

local function connectScaleUpdater()
	local cam = workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(applyScale)
	end
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyScale)
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		connectScaleUpdater()
		applyScale()
	end)
end
connectScaleUpdater()

-- Main frame
local main = make("Frame", {
	Name = "Frame",
	Size = UDim2.new(0, INTRO_SIZE, 0, INTRO_SIZE),
	Position = UDim2.new(0.5, 0, 0.5, 0),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
}, root)

local shadow = make("ImageLabel", {
	Size = UDim2.new(1, 50, 1, 50),
	Position = UDim2.new(0, -25, 0, -25),
	BackgroundTransparency = 1,
	Image = "rbxassetid://6014261993",
	ImageColor3 = Color3.fromRGB(0, 0, 0),
	ImageTransparency = 1,
	ScaleType = Enum.ScaleType.Slice,
	SliceCenter = Rect.new(49, 49, 450, 450),
}, main)

local canvas = make("Frame", {
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundColor3 = C.bg,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ClipsDescendants = true,
}, main)
make("UICorner", { CornerRadius = UDim.new(0, 10) }, canvas)

local borderStroke = make("UIStroke", {
	Thickness = 1,
	ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	Color = C.accent,
	Transparency = 1,
}, canvas)

local decorGroup = make("CanvasGroup", {
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	GroupTransparency = 1,
}, canvas)
make("UICorner", { CornerRadius = UDim.new(0, 10) }, decorGroup)

local bgFrame = centered(decorGroup, FINAL_W, FINAL_H)
decor(bgFrame, 380, 140, 230, 266, 0.86, 270)
decor(bgFrame, 100, 46, -8, 252, 0.75, 90)
decor(bgFrame, 400, 184, 450, 8, 0.92, 90)
decor(bgFrame, 70, 138, 5, -5, 0.78, 90)

-- Intro
local intro = centered(canvas, FINAL_W, FINAL_H)
local introLogo = make("ImageLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, 0),
	Size = UDim2.new(0, 64, 0, 58),
	BackgroundTransparency = 1,
	Image = LOGO,
	ImageColor3 = C.accent,
	ImageTransparency = 1,
	ScaleType = Enum.ScaleType.Fit,
}, intro)

local spinnerHolder = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, 36),
	Size = UDim2.new(0, 36, 0, 36),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
}, intro)

local ringTrack = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, 0),
	Size = UDim2.new(0, 24, 0, 24),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
}, spinnerHolder)
make("UICorner", { CornerRadius = UDim.new(1, 0) }, ringTrack)
make("UIStroke", { Thickness = 2.5, Color = C.muted, Transparency = 0.75 }, ringTrack)

local spinner = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, 0),
	Size = UDim2.new(0, 24, 0, 24),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
}, spinnerHolder)
make("UICorner", { CornerRadius = UDim.new(1, 0) }, spinner)
local spinnerStroke = make("UIStroke", { Thickness = 2.5, Color = C.accent }, spinner)
make("UIGradient", {
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.35, 0),
		NumberSequenceKeypoint.new(0.7, 1),
		NumberSequenceKeypoint.new(1, 1),
	}),
}, spinnerStroke)

local spin = TweenService:Create(
	spinner,
	TweenInfo.new(0.9, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1),
	{ Rotation = 360 }
)

-- ═══════════════════════════════════════════════════════════════
--  CONTENT
-- ═══════════════════════════════════════════════════════════════
local content = centered(canvas, FINAL_W, FINAL_H)
content.Visible = false

local left = frame(content, 0, 0, 272, 260)

make("ImageLabel", {
	Position = UDim2.new(0, 22, 0, 20),
	Size = UDim2.new(0, 36, 0, 32),
	BackgroundTransparency = 1,
	Image = LOGO,
	ImageColor3 = C.accent,
	ScaleType = Enum.ScaleType.Fit,
}, left)

text(left, "Flycer Hub", 66, 20, 190, 22, 20, C.text)
text(left, "Key system", 66, 42, 190, 14, 12, C.muted)
text(left, "License key", 22, 78, 228, 14, 11, C.muted)

local inputBox = frame(left, 22, 96, 228, 36, C.input, 0)
round(inputBox, 8, C.stroke)
icon(inputBox, 12, 10, C.muted, ICON_KEY)

local keyBox = make("TextBox", {
	Name = "TextBox",
	Position = UDim2.new(0, 38, 0, 0),
	Size = UDim2.new(1, -48, 1, 0),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Text = "",
	TextSize = 13,
	TextColor3 = C.text,
	TextXAlignment = Enum.TextXAlignment.Left,
	PlaceholderText = "Paste your key here",
	PlaceholderColor3 = C.muted,
	ClearTextOnFocus = false,
	MultiLine = false,
	TextScaled = false,
	TextTruncate = Enum.TextTruncate.AtEnd,
	ClipsDescendants = true,
	FontFace = FONT,
})
keyBox.Parent = inputBox

keyBox:GetPropertyChangedSignal("Text"):Connect(function()
	local cleaned = keyBox.Text:gsub("[\n\r]", "")
	if cleaned ~= keyBox.Text then
		keyBox.Text = cleaned
		keyBox:ReleaseFocus(false)
	end
end)

local submit = make("TextButton", {
	Name = "TextButton",
	Position = UDim2.new(0, 22, 0, 142),
	Size = UDim2.new(0, 110, 0, 34),
	BackgroundColor3 = C.accent,
	BackgroundTransparency = 0.12,
	BorderSizePixel = 0,
	AutoButtonColor = false,
	Text = "Submit",
	TextSize = 13,
	TextColor3 = C.dark,
	FontFace = FONT,
}, left)
round(submit, 8, C.accent)
submit.UIStroke.Transparency = 0.4
make("UIPadding", { PaddingLeft = UDim.new(0, 24) }, submit)
icon(submit, -12, 9, C.dark, ICON_SEND)

local copyHwidBtn = make("TextButton", {
	Name = "TextButton",
	Position = UDim2.new(0, 140, 0, 142),
	Size = UDim2.new(0, 110, 0, 34),
	BackgroundColor3 = C.btn2,
	BorderSizePixel = 0,
	AutoButtonColor = false,
	Text = "Copy HWID",
	TextSize = 11,
	TextColor3 = C.text,
	FontFace = FONT,
}, left)
round(copyHwidBtn, 8, C.stroke)
make("UIPadding", { PaddingLeft = UDim.new(0, 24) }, copyHwidBtn)
icon(copyHwidBtn, -12, 9, C.text, ICON_COPY)

local statusLabel = text(left, "", 22, 186, 228, 16, 12, C.muted)

local avatar = make("ImageLabel", {
	Position = UDim2.new(0, 22, 0, 214),
	Size = UDim2.new(0, 32, 0, 32),
	BackgroundColor3 = C.input,
	BorderSizePixel = 0,
	Image = player and ("rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150") or "",
	ScaleType = Enum.ScaleType.Crop,
}, left)
round(avatar, 16, C.stroke)

text(left, "Welcome Back", 62, 215, 188, 14, 11, C.muted)
local welcomeName = text(left, ((player and player.DisplayName) or "User") .. "!", 62, 229, 188, 16, 14, C.text)
welcomeName.FontFace = FONT_BOLD
welcomeName.TextTruncate = Enum.TextTruncate.AtEnd

frame(content, 272, 20, 1, 220, C.stroke, 0)

-- Right Panel
local right = frame(content, 273, 0, 187, 260)

text(right, "Detected game", 20, 24, 147, 14, 11, C.muted)

local gameCard = frame(right, 20, 42, 147, 52, C.card, 0)
round(gameCard, 8, C.stroke)

local gameImg = make("ImageLabel", {
	Position = UDim2.new(0, 9, 0, 9),
	Size = UDim2.new(0, 34, 0, 34),
	BackgroundColor3 = C.input,
	BorderSizePixel = 0,
	Image = "rbxassetid://74584987850498",
	ScaleType = Enum.ScaleType.Stretch,
}, gameCard)
round(gameImg, 7, C.stroke)

local gameName = text(gameCard, "Loading...", 52, 10, 90, 14, 12, C.text)
local gameStatus = text(gameCard, "Checking...", 52, 27, 90, 13, 11, C.muted)
gameName.TextTruncate = Enum.TextTruncate.AtEnd
gameStatus.TextTruncate = Enum.TextTruncate.AtEnd

text(right, "Executor", 20, 106, 60, 14, 11, C.muted)
local executorLabel = text(right, "Detecting...", 80, 106, 87, 14, 11, C.text, Enum.TextXAlignment.Right)
executorLabel.TextTruncate = Enum.TextTruncate.AtEnd

text(right, "Status", 20, 126, 60, 14, 11, C.muted)
local statusValue = text(right, "Key required", 80, 126, 87, 14, 11, C.warn, Enum.TextXAlignment.Right)

frame(right, 20, 148, 147, 1, C.stroke, 0)

local function linkButton(y, title, subtitle, iconImg)
	local btn = make("TextButton", {
		Name = "TextButton",
		Position = UDim2.new(0, 20, 0, y),
		Size = UDim2.new(0, 147, 0, 40),
		BackgroundColor3 = C.card,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
	}, right)
	round(btn, 8, C.stroke)
	icon(btn, 11, 12, C.accent, iconImg)
	text(btn, title, 36, 6, 106, 14, 12, C.text)
	text(btn, subtitle, 36, 21, 106, 13, 11, C.muted)
	return btn
end

local discordBtn = linkButton(158, "Discord", CONFIG.DISCORD_LINK, ICON_DISCORD)
local getKeyBtn = linkButton(206, "Get Key", "Get your license key", ICON_UNLOCK)

-- Close Button
local closeBtn = make("TextButton", {
	Name = "CloseButton",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 12),
	Size = UDim2.new(0, 26, 0, 26),
	BackgroundColor3 = C.card,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	AutoButtonColor = false,
	Text = "",
	ZIndex = 5,
}, content)
make("UICorner", { CornerRadius = UDim.new(0, 7) }, closeBtn)

local closeIcon = make("ImageLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, 0),
	Size = UDim2.new(0, 12, 0, 12),
	BackgroundTransparency = 1,
	Image = ICON_CLOSE,
	ImageColor3 = C.muted,
	ZIndex = 6,
}, closeBtn)

-- ═══════════════════════════════════════════════════════════════
--  POPUP CLOSE
-- ═══════════════════════════════════════════════════════════════
local popup = make("Frame", {
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 10,
	Visible = false,
}, canvas)

local dim = make("TextButton", {
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0.4,
	BorderSizePixel = 0,
	AutoButtonColor = false,
	Text = "",
}, popup)
make("UICorner", { CornerRadius = UDim.new(0, 10) }, dim)

local popupCard = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, 0),
	Size = UDim2.new(0, 270, 0, 132),
	BackgroundColor3 = C.card,
	BorderSizePixel = 0,
}, popup)
round(popupCard, 12, C.stroke)

local closeBadge = frame(popupCard, 22, 20, 32, 32, C.input, 0)
round(closeBadge, 16, C.stroke)
make("ImageLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, 0),
	Size = UDim2.new(0, 12, 0, 12),
	BackgroundTransparency = 1,
	Image = ICON_CLOSE,
	ImageColor3 = C.accent,
}, closeBadge)

local popupTitle = text(popupCard, "Close Key System?", 66, 19, 182, 16, 14, C.text)
popupTitle.FontFace = FONT_BOLD
local popupDesc = text(popupCard, "Are you sure you want to close the Key System?", 66, 38, 182, 30, 12, C.muted)
popupDesc.TextWrapped = true
popupDesc.TextYAlignment = Enum.TextYAlignment.Top

local function popupButton(label, x, primary)
	local btn = make("TextButton", {
		Position = UDim2.new(0, x, 0, 86),
		Size = UDim2.new(0, 109, 0, 32),
		BackgroundColor3 = primary and C.accent or C.btn2,
		BackgroundTransparency = primary and 0.12 or 0,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = label,
		TextSize = 13,
		TextColor3 = primary and C.dark or C.text,
		FontFace = FONT,
	}, popupCard)
	round(btn, 8, primary and C.accent or C.stroke)
	if primary then
		btn.UIStroke.Transparency = 0.4
	end
	return btn
end

local cancelBtn = popupButton("Cancel", 22, false)
local confirmBtn = popupButton("Close", 139, true)

-- ═══════════════════════════════════════════════════════════════
--  POPUP HWID
-- ═══════════════════════════════════════════════════════════════
local hwidPopup = make("Frame", {
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 10,
	Visible = false,
}, canvas)

local hwidDim = make("TextButton", {
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0.4,
	BorderSizePixel = 0,
	AutoButtonColor = false,
	Text = "",
}, hwidPopup)
make("UICorner", { CornerRadius = UDim.new(0, 10) }, hwidDim)

local hwidCard = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, 0),
	Size = UDim2.new(0, 270, 0, 158),
	BackgroundColor3 = C.card,
	BorderSizePixel = 0,
}, hwidPopup)
round(hwidCard, 12, C.stroke)

local hwidBadge = frame(hwidCard, 22, 18, 32, 32, C.input, 0)
round(hwidBadge, 16, C.stroke)
make("ImageLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, 0),
	Size = UDim2.new(0, 16, 0, 16),
	BackgroundTransparency = 1,
	Image = ICON_FINGER,
	ImageColor3 = C.accent,
}, hwidBadge)

local hwidTitle = text(hwidCard, "Your HWID", 66, 18, 182, 16, 14, C.text)
hwidTitle.FontFace = FONT_BOLD
local hwidSubtitle = text(hwidCard, "Copy and send this to whitelist admin", 66, 36, 182, 13, 11, C.muted)
hwidSubtitle.TextWrapped = true

local hwidInputFrame = frame(hwidCard, 18, 68, 234, 36, C.input, 0)
round(hwidInputFrame, 8, C.stroke)
icon(hwidInputFrame, 10, 10, C.muted, ICON_FINGER)

local hwidDisplay = make("TextLabel", {
	Name = "HwidDisplay",
	Position = UDim2.new(0, 34, 0, 0),
	Size = UDim2.new(1, -44, 1, 0),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Text = "",
	TextSize = 10,
	TextColor3 = C.text,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Center,
	TextTruncate = Enum.TextTruncate.AtEnd,
	FontFace = FONT,
}, hwidInputFrame)

local hwidCloseBtn = make("TextButton", {
	Position = UDim2.new(0, 18, 0, 114),
	Size = UDim2.new(0, 109, 0, 32),
	BackgroundColor3 = C.btn2,
	BackgroundTransparency = 0,
	BorderSizePixel = 0,
	AutoButtonColor = false,
	Text = "Close",
	TextSize = 12,
	TextColor3 = C.text,
	FontFace = FONT,
}, hwidCard)
round(hwidCloseBtn, 8, C.stroke)

local hwidCopyBtn = make("TextButton", {
	Position = UDim2.new(0, 143, 0, 114),
	Size = UDim2.new(0, 109, 0, 32),
	BackgroundColor3 = C.accent,
	BackgroundTransparency = 0.12,
	BorderSizePixel = 0,
	AutoButtonColor = false,
	Text = "Copy HWID",
	TextSize = 12,
	TextColor3 = C.dark,
	FontFace = FONT,
}, hwidCard)
round(hwidCopyBtn, 8, C.accent)
hwidCopyBtn.UIStroke.Transparency = 0.4
make("UIPadding", { PaddingLeft = UDim.new(0, 22) }, hwidCopyBtn)
icon(hwidCopyBtn, -10, 8, C.dark, ICON_COPY)

-- ═══════════════════════════════════════════════════════════════
--  STATE
-- ═══════════════════════════════════════════════════════════════
local ready = false
local popupOpen = false
local hwidPopupOpen = false
local closing = false
local checkingKey = false

-- ═══════════════════════════════════════════════════════════════
--  FADE INIT
-- ═══════════════════════════════════════════════════════════════
local spinnerItems = prep(spinnerHolder)
local contentItems = prep(content)
local popupItems = prep(popup)
local hwidPopupItems = prep(hwidPopup)
fade(spinnerItems, 0)
fade(contentItems, 0)
fade(popupItems, 0)
fade(hwidPopupItems, 0)

-- ═══════════════════════════════════════════════════════════════
--  GAME INFO & EXECUTOR
-- ═══════════════════════════════════════════════════════════════
local function detectExecutor()
	local ok, name = pcall(function()
		if identifyexecutor then
			return identifyexecutor()
		elseif getexecutorname then
			return getexecutorname()
		end
	end)
	if ok and name and tostring(name) ~= "" then
		return tostring(name)
	end
	return "Unknown"
end
executorLabel.Text = detectExecutor()

-- Update game info - akan diperbarui lagi setelah loader database siap
task.spawn(function()
	local MS = game:GetService("MarketplaceService")
	local ok, info = pcall(function()
		return MS:GetProductInfo(game.PlaceId)
	end)
	gameName.Text = (ok and info and info.Name) or "Unknown game"
	if game.GameId ~= 0 then
		gameImg.Image = "rbxthumb://type=GameIcon&id=" .. game.GameId .. "&w=150&h=150"
	end
end)

-- Fungsi untuk update status game setelah loader database siap
local function updateGameStatus()
	if SUPPORTED_GAMES[game.PlaceId] then
		gameStatus.Text = "Supported"
		gameStatus.TextColor3 = Color3.fromRGB(120, 210, 140)
	else
		if loaderFetchFailed then
			gameStatus.Text = "List unavailable"
			gameStatus.TextColor3 = C.warn
		else
			gameStatus.Text = "Not in our list"
			gameStatus.TextColor3 = C.muted
		end
	end
end

-- ═══════════════════════════════════════════════════════════════
--  STATUS COLORS
-- ═══════════════════════════════════════════════════════════════
local KIND_COLORS = {
	success = Color3.fromRGB(120, 210, 140),
	error = Color3.fromRGB(240, 120, 120),
}

-- ═══════════════════════════════════════════════════════════════
--  POPUP HWID SHOW/HIDE
-- ═══════════════════════════════════════════════════════════════
local function showHwidPopup()
	if not ready or popupOpen or hwidPopupOpen or closing then
		return
	end
	hwidPopupOpen = true
	hwidDisplay.Text = getCachedHWID()
	hwidPopup.Visible = true
	hwidCard.Position = UDim2.new(0.5, 0, 0.5, 8)
	fade(hwidPopupItems, 1, 0.22)
	tween(hwidCard, 0.35, { Position = UDim2.new(0.5, 0, 0.5, 0) }, Enum.EasingStyle.Quint)
end

local function hideHwidPopup()
	if not hwidPopupOpen or closing then
		return
	end
	hwidPopupOpen = false
	fade(hwidPopupItems, 0, 0.18)
	task.delay(0.2, function()
		if not hwidPopupOpen then
			hwidPopup.Visible = false
		end
	end)
end

-- ═══════════════════════════════════════════════════════════════
--  POPUP CLOSE SHOW/HIDE
-- ═══════════════════════════════════════════════════════════════
local function showPopup()
	if not ready or popupOpen or hwidPopupOpen or closing then
		return
	end
	popupOpen = true
	popup.Visible = true
	popupCard.Position = UDim2.new(0.5, 0, 0.5, 8)
	tween(closeIcon, 0.15, { ImageColor3 = C.muted })
	tween(closeBtn, 0.15, { BackgroundTransparency = 1 })
	fade(popupItems, 1, 0.22)
	tween(popupCard, 0.35, { Position = UDim2.new(0.5, 0, 0.5, 0) }, Enum.EasingStyle.Quint)
end

local function hidePopup()
	if not popupOpen or closing then
		return
	end
	popupOpen = false
	fade(popupItems, 0, 0.18)
	task.delay(0.2, function()
		if not popupOpen then
			popup.Visible = false
		end
	end)
end

-- ═══════════════════════════════════════════════════════════════
--  CLOSE GUI
-- ═══════════════════════════════════════════════════════════════
local function closeGui()
	if closing then
		return
	end
	closing = true
	ready = false
	popupOpen = false
	hwidPopupOpen = false
	tween(closeIcon, 0.15, { ImageColor3 = C.muted })
	tween(closeBtn, 0.15, { BackgroundTransparency = 1 })
	fade(popupItems, 0, 0.15)
	fade(hwidPopupItems, 0, 0.15)
	fade(contentItems, 0, 0.2)
	task.wait(0.2)
	popup.Visible = false
	hwidPopup.Visible = false
	content.Visible = false
	introLogo.Position = UDim2.new(0.5, 0, 0.5, 0)
	tween(introLogo, 0.4, { ImageTransparency = 0 })
	tween(borderStroke, 0.5, { Transparency = 0.55 })
	tween(
		main,
		0.65,
		{ Size = UDim2.new(0, INTRO_SIZE, 0, INTRO_SIZE) },
		Enum.EasingStyle.Quart,
		Enum.EasingDirection.InOut
	)
	task.wait(0.7)
	tween(canvas, 0.35, { BackgroundTransparency = 1 })
	tween(decorGroup, 0.35, { GroupTransparency = 1 })
	tween(introLogo, 0.35, { ImageTransparency = 1 })
	tween(borderStroke, 0.35, { Transparency = 1 })
	tween(shadow, 0.35, { ImageTransparency = 1 })
	task.wait(0.4)
	root:Destroy()
end

-- ═══════════════════════════════════════════════════════════════
--  BUTTON INTERACTIONS
-- ═══════════════════════════════════════════════════════════════
closeBtn.MouseEnter:Connect(function()
	if closing or popupOpen or hwidPopupOpen or not ready then
		return
	end
	tween(closeIcon, 0.15, { ImageColor3 = C.text })
	tween(closeBtn, 0.15, { BackgroundTransparency = 0 })
end)
closeBtn.MouseLeave:Connect(function()
	if closing or popupOpen or hwidPopupOpen or not ready then
		return
	end
	tween(closeIcon, 0.15, { ImageColor3 = C.muted })
	tween(closeBtn, 0.15, { BackgroundTransparency = 1 })
end)
closeBtn.MouseButton1Click:Connect(showPopup)

cancelBtn.MouseEnter:Connect(function()
	if closing or not popupOpen then
		return
	end
	tween(cancelBtn, 0.15, { BackgroundColor3 = C.btn2Hover })
end)
cancelBtn.MouseLeave:Connect(function()
	if closing or not popupOpen then
		return
	end
	tween(cancelBtn, 0.15, { BackgroundColor3 = C.btn2 })
end)
cancelBtn.MouseButton1Click:Connect(hidePopup)

confirmBtn.MouseEnter:Connect(function()
	if closing or not popupOpen then
		return
	end
	tween(confirmBtn, 0.15, { BackgroundTransparency = 0 })
end)
confirmBtn.MouseLeave:Connect(function()
	if closing or not popupOpen then
		return
	end
	tween(confirmBtn, 0.15, { BackgroundTransparency = 0.12 })
end)
confirmBtn.MouseButton1Click:Connect(function()
	task.spawn(closeGui)
end)

copyHwidBtn.MouseEnter:Connect(function()
	if not ready or closing then
		return
	end
	tween(copyHwidBtn, 0.15, { BackgroundColor3 = C.btn2Hover })
end)
copyHwidBtn.MouseLeave:Connect(function()
	if not ready or closing then
		return
	end
	tween(copyHwidBtn, 0.15, { BackgroundColor3 = C.btn2 })
end)
copyHwidBtn.MouseButton1Click:Connect(function()
	if not ready or closing then
		return
	end
	showHwidPopup()
end)

hwidCloseBtn.MouseEnter:Connect(function()
	if not hwidPopupOpen or closing then
		return
	end
	tween(hwidCloseBtn, 0.15, { BackgroundColor3 = C.btn2Hover })
end)
hwidCloseBtn.MouseLeave:Connect(function()
	if not hwidPopupOpen or closing then
		return
	end
	tween(hwidCloseBtn, 0.15, { BackgroundColor3 = C.btn2 })
end)
hwidCloseBtn.MouseButton1Click:Connect(function()
	if not hwidPopupOpen or closing then
		return
	end
	hideHwidPopup()
end)

hwidCopyBtn.MouseEnter:Connect(function()
	if not hwidPopupOpen or closing then
		return
	end
	tween(hwidCopyBtn, 0.15, { BackgroundTransparency = 0 })
end)
hwidCopyBtn.MouseLeave:Connect(function()
	if not hwidPopupOpen or closing then
		return
	end
	tween(hwidCopyBtn, 0.15, { BackgroundTransparency = 0.12 })
end)
hwidCopyBtn.MouseButton1Click:Connect(function()
	if not hwidPopupOpen or closing then
		return
	end
	pcall(function()
		if setclipboard then
			setclipboard(getCachedHWID())
		end
	end)
end)

discordBtn.MouseButton1Click:Connect(function()
	if not ready or closing then
		return
	end
	pcall(function()
		if setclipboard then
			setclipboard(CONFIG.DISCORD_LINK)
		end
	end)
end)
getKeyBtn.MouseButton1Click:Connect(function()
	if not ready or closing then
		return
	end
	pcall(function()
		if setclipboard then
			setclipboard(CONFIG.DISCORD_LINK)
		end
	end)
end)

-- ═══════════════════════════════════════════════════════════════
--  SMART LOADER EXECUTION
-- ═══════════════════════════════════════════════════════════════
local function executePayload()
	local loaderURL = SUPPORTED_GAMES[game.PlaceId]
	if loaderURL and loaderURL ~= "" then
		pcall(function()
			loadstring(game:HttpGet(loaderURL))()
		end)
	end
end

-- ═══════════════════════════════════════════════════════════════
--  SUBMIT
-- ═══════════════════════════════════════════════════════════════
local function doSubmit()
	if not ready or closing or checkingKey then
		return
	end
	local key = keyBox.Text:gsub("[\n\r]", ""):match("^%s*(.-)%s*$")
	if key == "" then
		statusLabel.Text = "Please enter your key first."
		statusLabel.TextColor3 = C.warn
		return
	end
	checkingKey = true
	statusValue.Text = "Checking..."
	statusValue.TextColor3 = C.muted
	statusLabel.Text = "Verifying key, please wait..."
	statusLabel.TextColor3 = C.muted
	task.spawn(function()
		local valid, msg, keyData = verifyKey(key)
		checkingKey = false
		if valid then
			saveKeyToFile(key)
			pcall(function()
				if getgenv then
					getgenv()._FlycerKeyData = {
						keyType = keyData["type key"],
						expireTimestamp = keyData["expiredkey_timestamp"] or nil,
						note = keyData["note"] or "",
						verifiedAt = os.time(),
					}
				end
			end)
			statusValue.Text = "Key valid"
			statusValue.TextColor3 = KIND_COLORS.success
			statusLabel.Text = msg
			statusLabel.TextColor3 = KIND_COLORS.success
			task.wait(1.5)
			task.spawn(closeGui)
			task.wait(0.5)
			executePayload()
		else
			clearSavedKey()
			statusValue.Text = "Key invalid"
			statusValue.TextColor3 = KIND_COLORS.error
			statusLabel.Text = msg
			statusLabel.TextColor3 = KIND_COLORS.error
		end
	end)
end
submit.MouseButton1Click:Connect(doSubmit)

-- ═══════════════════════════════════════════════════════════════
--  PARENT & SNAP
-- ═══════════════════════════════════════════════════════════════
root.Parent = CoreGui

main.AnchorPoint = Vector2.new(0.5, 0.5)
main.Position = UDim2.new(0.5, 0, 0.5, 0)
applyScale()

-- ═══════════════════════════════════════════════════════════════
--  INTRO ANIMATION + FETCH LOADER DATABASE + AUTO-LOAD KEY
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
	-- Mulai fetch loader database bersamaan dengan animasi intro
	task.spawn(fetchLoaderDatabase)

	main.Size = UDim2.new(0, INTRO_SIZE - 20, 0, INTRO_SIZE - 20)
	tween(main, 0.6, { Size = UDim2.new(0, INTRO_SIZE, 0, INTRO_SIZE) }, Enum.EasingStyle.Quint)
	tween(canvas, 0.5, { BackgroundTransparency = 0 })
	tween(decorGroup, 0.5, { GroupTransparency = 0 })
	tween(introLogo, 0.5, { ImageTransparency = 0 })
	tween(borderStroke, 0.5, { Transparency = 0.55 })
	tween(shadow, 0.5, { ImageTransparency = 0.6 })
	task.wait(SQUARE_TIME)

	tween(borderStroke, 0.7, { Transparency = 1 })
	main.Size = UDim2.new(0, FINAL_W, 0, FINAL_H)
	tween(main, 0.85, { Size = UDim2.new(0, FINAL_W, 0, FINAL_H) }, Enum.EasingStyle.Quint)
	tween(introLogo, 0.7, { Position = UDim2.new(0.5, 0, 0.5, -20) }, Enum.EasingStyle.Quint)
	task.wait(0.35)
	spin:Play()
	fade(spinnerItems, 1, 0.4)

	-- Tunggu loader database siap (max LOADING_TIME detik)
	local elapsed = 0
	while not loaderDataReady and elapsed < LOADING_TIME do
		task.wait(0.1)
		elapsed = elapsed + 0.1
	end

	-- Sisa waktu loading jika loader database selesai lebih cepat
	local remaining = LOADING_TIME - elapsed
	if remaining > 0 then
		task.wait(remaining)
	end

	fade(spinnerItems, 0, 0.3)
	tween(introLogo, 0.3, { ImageTransparency = 1 })
	task.wait(0.2)

	-- Update game status setelah loader database siap
	updateGameStatus()

	content.Visible = true
	fade(contentItems, 1, 0.45)
	task.wait(0.3)
	spin:Cancel()
	ready = true

	task.spawn(function()
		local savedKey = loadKeyFromFile()
		if savedKey and savedKey ~= "" then
			keyBox.Text = savedKey
			statusLabel.Text = "Saved key found. Verifying automatically..."
			statusLabel.TextColor3 = C.muted
			task.wait(1)
			doSubmit()
		end
	end)
end)
