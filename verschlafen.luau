local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local env = getgenv and getgenv() or _G

local previousUnload = env.verschlafenUnload or env.prismUnload

if previousUnload then
	pcall(previousUnload)
end

local function purgeStale()
	local visited = {}
	local roots = { game:GetService("CoreGui") }

	if gethui then
		local ok, hui = pcall(gethui)
		if ok and hui then
			table.insert(roots, hui)
		end
	end

	for _, root in ipairs(roots) do
		if root and not visited[root] then
			visited[root] = true
			pcall(function()
				for _, item in ipairs(root:GetChildren()) do
					if item:IsA("ScreenGui") and (item.Name == "verschlafen" or item.Name == "prism") then
						item:Destroy()
					end
				end
			end)
		end
	end
end

purgeStale()

local ACCENT = Color3.fromRGB(176, 136, 255)
local ACCENT_2 = Color3.fromRGB(255, 122, 208)
local SURFACE = Color3.fromRGB(12, 11, 20)
local CARD = Color3.fromRGB(23, 21, 35)
local CARD_HOT = Color3.fromRGB(33, 30, 49)
local LINE = Color3.fromRGB(49, 44, 70)
local MUTED = Color3.fromRGB(141, 136, 170)
local TEXT = Color3.fromRGB(242, 240, 253)
local OFF = Color3.fromRGB(55, 51, 77)

local ACCENT_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, ACCENT),
	ColorSequenceKeypoint.new(1, ACCENT_2),
})

local function spaced(text)
	local letters = {}

	for index = 1, #text do
		local char = string.sub(text, index, index)
		if char == " " then
			if #letters > 0 then
				letters[#letters + 1] = " "
			end
		else
			letters[#letters + 1] = string.upper(char)
		end
	end

	return table.concat(letters, " ")
end

local config = {
	chams = { enabled = false, fill = 0.95 },
	loot = {
		enabled = false,
		highlight = false,
		labels = false,
		showName = true,
		showValue = true,
		showDistance = false,
		tracers = false,
		minValue = 0,
		range = 0,
		fill = 0.8,
	},
	world = {
		stamina = false,
		instant = false,
		weight = false,
		vision = false,
		autokill = false,
		farm = false,
	},
}

local rarityColour = {
	Common = Color3.fromRGB(156, 162, 170),
	Uncommon = Color3.fromRGB(84, 184, 104),
	Rare = Color3.fromRGB(152, 98, 216),
	Legendary = Color3.fromRGB(228, 184, 62),
	Mythic = Color3.fromRGB(208, 62, 58),
	Secret = Color3.fromRGB(110, 60, 170),
}

local itemInfo = {}

task.spawn(function()
	pcall(function()
		local cfg = require(ReplicatedStorage:WaitForChild("GameConfig", 8))
		if type(cfg) ~= "table" then
			return
		end
		for name, colour in pairs(cfg.RarityColour or {}) do
			if typeof(colour) == "Color3" then
				rarityColour[name] = colour
			end
		end
		for key, item in pairs(cfg.Items or {}) do
			itemInfo[key] = item
		end
	end)
end)

local function make(class, props, parent)
	local instance = Instance.new(class)
	for key, value in pairs(props) do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

local function corner(instance, radius)
	make("UICorner", { CornerRadius = UDim.new(0, radius) }, instance)
end

local function stroke(instance, colour, transparency, thickness)
	local line = make("UIStroke", {
		Color = colour,
		Transparency = transparency or 0.5,
		Thickness = thickness or 1,
	}, instance)
	return line
end

local function label(parent, text, size, textSize)
	return make("TextLabel", {
		BackgroundTransparency = 1,
		Size = size,
		Text = text,
		TextColor3 = TEXT,
		TextSize = textSize,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, parent)
end

local function shortNumber(value)
	if value >= 1e6 then
		return string.format("%.1fm", value / 1e6)
	elseif value >= 1e3 then
		return string.format("%.1fk", value / 1e3)
	end
	return tostring(math.floor(value + 0.5))
end

local guiParent = game:GetService("CoreGui")
if gethui then
	local ok, hidden = pcall(gethui)
	if ok and hidden then
		guiParent = hidden
	end
end

for _, root in ipairs({ guiParent, game:GetService("CoreGui"), LocalPlayer:FindFirstChild("PlayerGui") }) do
	if root then
		for _, item in ipairs(root:GetDescendants()) do
			if item:IsA("ScreenGui") and (item.Name == "verschlafen" or item.Name == "prism") then
				pcall(function()
					item:Destroy()
				end)
			end
		end
	end
end

local gui = make("ScreenGui", {
	Name = "verschlafen",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 2000000,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, nil)

pcall(function()
	gui.Parent = guiParent
end)
if not gui.Parent then
	gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

if syn and syn.protect_gui then
	pcall(syn.protect_gui, gui)
end

local WINDOW_W, WINDOW_H
local window, header, body, footer, tabbar, windowScale
local section, toggleRow, sliderRow
local connect, connections, showTab, toggleMenu, finishMenuMotion

do
WINDOW_W = 340
WINDOW_H = 476

window = make("Frame", {
	Name = "window",
	Size = UDim2.fromOffset(WINDOW_W, WINDOW_H),
	Position = UDim2.new(0, 150, 0, 100),
	BackgroundColor3 = SURFACE,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 10,
}, gui)
corner(window, 18)

local windowStroke = make("UIStroke", {
	Color = Color3.fromRGB(255, 255, 255),
	Transparency = 0.55,
	Thickness = 1,
	ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
}, window)

local borderGradient = make("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, ACCENT),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(148, 120, 208)),
		ColorSequenceKeypoint.new(1, ACCENT_2),
	}),
	Rotation = 45,
	Offset = Vector2.new(0, 0),
}, windowStroke)

windowScale = make("UIScale", { Scale = 1 }, window)

local backdrop = make("Frame", {
	Name = "backdrop",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(22, 18, 34),
	BorderSizePixel = 0,
	ZIndex = 0,
}, window)
corner(backdrop, 18)

local backdropGradient = make("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(36, 34, 84)),
		ColorSequenceKeypoint.new(0.42, Color3.fromRGB(16, 15, 34)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(26, 19, 56)),
	}),
	Rotation = 118,
	Offset = Vector2.new(0, 0),
}, backdrop)

local auroraLayer = make("Frame", {
	Name = "aurora",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	ZIndex = 1,
}, window)
corner(auroraLayer, 17)

local function aurora(size, colour, transparency)
	local blob = make("Frame", {
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = colour,
		BackgroundTransparency = transparency,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, auroraLayer)
	corner(blob, size * 0.5)
	make("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, blob)
	return blob
end

local auroraA = aurora(300, Color3.fromRGB(118, 110, 255), 0.87)
local auroraB = aurora(320, Color3.fromRGB(168, 124, 255), 0.9)
local auroraC = aurora(250, Color3.fromRGB(88, 118, 255), 0.91)

local mistLayer = make("Frame", {
	Name = "mist",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	ZIndex = 1,
}, window)
corner(mistLayer, 17)

local mist = {}

-- fixed cycle length: the fog must keep drifting through a tab change, so the
-- wrap span can never be derived from the panel height (387 vs 502)
local MIST_SPAN = 520

local function mistBand(height, colour, density, speed, phase, sway)
	local band = make("Frame", {
		Size = UDim2.new(1, 120, 0, height),
		Position = UDim2.fromOffset(-60, 0),
		BackgroundColor3 = colour,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, mistLayer)

	make("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.42, density),
			NumberSequenceKeypoint.new(0.64, density),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, band)

	table.insert(mist, {
		band = band,
		height = height,
		speed = speed,
		phase = phase,
		sway = sway,
	})
end

mistBand(104, ACCENT, 0.93, 11, 0.08, 16)
mistBand(78, ACCENT_2, 0.95, 17, 0.44, 22)
mistBand(128, Color3.fromRGB(96, 132, 255), 0.945, 7, 0.77, 12)

local particleLayer = make("Frame", {
	Name = "particles",
	Size = UDim2.new(1, -2, 1, -2),
	Position = UDim2.fromOffset(1, 1),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	ZIndex = 2,
}, window)
corner(particleLayer, 17)

local particles = {}
local sleepers = {}

for index = 1, 38 do
	local size = index % 7 == 0 and 2 or 1
	local dot = make("Frame", {
		Name = "star",
		Size = UDim2.fromOffset(size, size),
		Position = UDim2.fromOffset(0, 0),
		BackgroundColor3 = index % 5 == 0 and ACCENT_2 or Color3.fromRGB(226, 230, 255),
		BackgroundTransparency = 0.45 + math.random() * 0.4,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, particleLayer)
	corner(dot, 4)

	particles[index] = {
		frame = dot,
		x = math.random() * WINDOW_W,
		y = math.random() * WINDOW_H,
		speed = 1.5 + math.random() * 4,
		sway = 1 + math.random() * 3,
		swayRate = 0.22 + math.random() * 0.35,
		phase = math.random() * math.pi * 2,
		base = dot.BackgroundTransparency,
	}
end

for index = 1, 5 do
	local glyph = label(particleLayer, "z", UDim2.fromOffset(32, 32), 15 + index * 3)
	glyph.Font = Enum.Font.GothamBlack
	glyph.TextColor3 = Color3.fromRGB(198, 188, 255)
	glyph.TextTransparency = 1
	glyph.TextXAlignment = Enum.TextXAlignment.Left
	glyph.Rotation = -14
	glyph.ZIndex = 2

	sleepers[index] = {
		frame = glyph,
		x = 14 + math.random() * (WINDOW_W - 70),
		y = math.random() * WINDOW_H,
		speed = 9 + math.random() * 13,
		phase = math.random() * math.pi * 2,
	}
end

local glass = make("Frame", {
	Name = "glass",
	Size = UDim2.new(1, -34, 0, 1),
	Position = UDim2.fromOffset(17, 0),
	BackgroundColor3 = Color3.fromRGB(255, 255, 255),
	BackgroundTransparency = 0.84,
	BorderSizePixel = 0,
	ZIndex = 3,
}, window)

make("UIGradient", {
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 1),
	}),
}, glass)

header = make("Frame", {
	Name = "header",
	Size = UDim2.new(1, 0, 0, 62),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 4,
}, window)

local logoHolder = make("Frame", {
	Name = "logo",
	Size = UDim2.fromOffset(30, 30),
	Position = UDim2.fromOffset(16, 16),
	BackgroundTransparency = 1,
	ZIndex = 5,
}, header)

local logoHalo = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(28, 28),
	BackgroundColor3 = ACCENT,
	BackgroundTransparency = 0.88,
	BorderSizePixel = 0,
	ZIndex = 1,
}, logoHolder)
corner(logoHalo, 14)

local logoRing = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(27, 27),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 2,
}, logoHolder)
corner(logoRing, 14)

local logoRingStroke = make("UIStroke", {
	Color = ACCENT,
	Transparency = 0.62,
	Thickness = 1,
	ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
}, logoRing)

local sleepMarks = {}

for index, spec in ipairs({
	{ text = "z", size = 9, x = 2, y = 14 },
	{ text = "z", size = 12, x = 10, y = 7 },
	{ text = "z", size = 15, x = 17, y = -1 },
}) do
	local mark = label(logoHolder, spec.text, UDim2.fromOffset(16, 16), spec.size)
	mark.Position = UDim2.fromOffset(spec.x, spec.y)
	mark.Font = Enum.Font.GothamBlack
	mark.TextColor3 = Color3.fromRGB(255, 255, 255)
	mark.TextTransparency = 0.12
	mark.TextXAlignment = Enum.TextXAlignment.Left
	mark.TextYAlignment = Enum.TextYAlignment.Center
	mark.Rotation = 0
	mark.ZIndex = 3

	make("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(248, 244, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(178, 148, 255)),
		}),
		Rotation = 65,
	}, mark)

	sleepMarks[index] = { mark = mark, x = spec.x, y = spec.y, phase = index * 0.9 }
end

local title = label(header, "verschlafen", UDim2.fromOffset(124, 22), 16)
title.Position = UDim2.fromOffset(56, 14)
title.Font = Enum.Font.GothamBold
title.ZIndex = 6

local titleGradient = make("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(178, 148, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(238, 245, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 138, 214)),
	}),
	Rotation = 0,
}, title)

local titleShine = label(header, "verschlafen", UDim2.fromOffset(124, 22), 16)
titleShine.Position = UDim2.fromOffset(56, 14)
titleShine.Font = Enum.Font.GothamBold
titleShine.TextColor3 = Color3.fromRGB(255, 255, 255)
titleShine.ZIndex = 7

local shineGradient = make("UIGradient", {
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.44, 0.94),
		NumberSequenceKeypoint.new(0.5, 0.15),
		NumberSequenceKeypoint.new(0.56, 0.94),
		NumberSequenceKeypoint.new(1, 1),
	}),
	Rotation = 0,
}, titleShine)

local versionChip = make("Frame", {
	Name = "version",
	Size = UDim2.fromOffset(32, 15),
	Position = UDim2.fromOffset(150, 18),
	BackgroundColor3 = CARD_HOT,
	BackgroundTransparency = 0.35,
	BorderSizePixel = 0,
	ZIndex = 6,
}, header)
corner(versionChip, 5)
stroke(versionChip, ACCENT, 0.55)

local versionText = label(versionChip, "2.0", UDim2.fromScale(1, 1), 8)
versionText.Font = Enum.Font.GothamBold
versionText.TextColor3 = ACCENT
versionText.TextXAlignment = Enum.TextXAlignment.Center
versionText.ZIndex = 7

local kicker = label(header, "STEAL OR DIE", UDim2.new(1, -190, 0, 12), 9)
kicker.Position = UDim2.fromOffset(56, 36)
kicker.Font = Enum.Font.GothamBold
kicker.TextColor3 = MUTED
kicker.ZIndex = 6

-- the visible rule lives inside a taller transparent clip box so a 1px clip
-- rect can never round away while the panel is scaled/rotated
local hairline = make("Frame", {
	Name = "hairline",
	Size = UDim2.new(1, -32, 0, 9),
	Position = UDim2.fromOffset(16, 58),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	ZIndex = 4,
}, window)

make("UIGradient", {
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.18, 0.2),
		NumberSequenceKeypoint.new(0.82, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	}),
}, make("Frame", {
	Name = "line",
	Size = UDim2.new(1, 0, 0, 1),
	Position = UDim2.fromOffset(0, 4),
	BackgroundColor3 = LINE,
	BorderSizePixel = 0,
	ZIndex = 4,
}, hairline))

local comet = make("Frame", {
	Name = "comet",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 4),
	Size = UDim2.new(0, 90, 0, 1),
	BackgroundColor3 = ACCENT,
	BorderSizePixel = 0,
	ZIndex = 5,
}, hairline)

local cometGradient = make("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, ACCENT_2),
		ColorSequenceKeypoint.new(0.7, Color3.fromRGB(246, 228, 255)),
		ColorSequenceKeypoint.new(1, ACCENT),
	}),
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.35, 0.88),
		NumberSequenceKeypoint.new(0.68, 0.5),
		NumberSequenceKeypoint.new(0.88, 0),
		NumberSequenceKeypoint.new(1, 0),
	}),
}, comet)

tabbar = make("Frame", {
	Name = "tabbar",
	Size = UDim2.new(1, -32, 0, 34),
	Position = UDim2.fromOffset(16, 68),
	BackgroundColor3 = CARD,
	BackgroundTransparency = 0.35,
	BorderSizePixel = 0,
	ZIndex = 5,
}, window)
corner(tabbar, 11)
stroke(tabbar, LINE, 0.55)

local TAB_COUNT = 2

local tabPill = make("Frame", {
	Name = "pill",
	Size = UDim2.new(1 / TAB_COUNT, -4, 1, -6),
	Position = UDim2.new(0, 2, 0, 3),
	BackgroundColor3 = ACCENT,
	BackgroundTransparency = 0.58,
	BorderSizePixel = 0,
	ZIndex = 6,
}, tabbar)
corner(tabPill, 8)
local tabPillStroke = stroke(tabPill, ACCENT, 0.4)

local tabPillGradient = make("UIGradient", {
	Color = ACCENT_GRADIENT,
	Rotation = 25,
}, tabPill)

local tabIndex = {}
local tabButtons = {}
local sectionRecords = {}
local tabHeights = {}
local currentTab = "world"

local function addTab(key, name)
	local index = #tabButtons + 1
	tabIndex[key] = index

	local button = make("TextButton", {
		Name = key,
		Size = UDim2.new(1 / TAB_COUNT, 0, 1, 0),
		Position = UDim2.new((index - 1) / TAB_COUNT, 0, 0, 0),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		ZIndex = 7,
	}, tabbar)

	local text = label(button, spaced(name), UDim2.fromScale(1, 1), 9)
	text.Font = Enum.Font.GothamBold
	text.TextColor3 = MUTED
	text.TextXAlignment = Enum.TextXAlignment.Center
	text.ZIndex = 8

	local textScale = make("UIScale", { Scale = 1 }, text)

	button.MouseButton1Down:Connect(function()
		TweenService:Create(textScale, TweenInfo.new(0.08), { Scale = 0.92 }):Play()
	end)

	button.MouseButton1Up:Connect(function()
		TweenService:Create(textScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end)

	tabButtons[index] = { key = key, label = text, button = button }
end

-- both UI sounds are created and preloaded while the menu is still being built:
-- creating them on the first click (or letting the asset stream in at that
-- point) puts the audio behind the animation it belongs to
local function ensureSound(name, soundId, volume)
	local service = game:GetService("SoundService")
	local sound = service:FindFirstChild(name)

	if sound then
		sound.Volume = volume
		return sound
	end

	sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = soundId
	sound.Volume = volume
	sound.Parent = service

	task.spawn(function()
		pcall(function()
			game:GetService("ContentProvider"):PreloadAsync({ sound })
		end)
	end)

	return sound
end

local function playSwitchSound()
	local sound = ensureSound("verschlafen_switch", "rbxasset://sounds/swordslash.wav", 0.26)
	sound.PlaybackSpeed = 1.35
	sound.TimePosition = 0
	sound:Play()
end

-- toggles get their own click: brighter going on, duller going off
local function playToggleSound(state)
	local sound = ensureSound("verschlafen_toggle", "rbxasset://sounds/switch.wav", 0.3)
	sound.PlaybackSpeed = state and 1.2 or 0.84
	sound.TimePosition = 0
	sound:Play()
end

ensureSound("verschlafen_switch", "rbxasset://sounds/swordslash.wav", 0.26)
ensureSound("verschlafen_toggle", "rbxasset://sounds/switch.wav", 0.3)

function showTab(key, instant)
	if key == "visual" then
		key = "vision"
	end

	local index = tabIndex[key]
	if not index then
		return
	end

	local switched = key ~= currentTab
	currentTab = key

	if switched and not instant then
		playSwitchSound()
	end

	TweenService:Create(tabPill, TweenInfo.new(instant and 0.01 or 0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Position = UDim2.new((index - 1) / TAB_COUNT, 2, 0, 3),
	}):Play()

	if not instant then
		tabPillStroke.Transparency = 0
		TweenService:Create(tabPillStroke, TweenInfo.new(0.45), { Transparency = 0.4 }):Play()
	end

	for _, tab in ipairs(tabButtons) do
		local active = tab.key == key
		TweenService:Create(tab.label, TweenInfo.new(0.18), { TextColor3 = active and TEXT or MUTED }):Play()
	end

	body.CanvasPosition = Vector2.new(0, 0)

	for _, record in ipairs(sectionRecords) do
		local visible = record.tab == key
		record.card.Visible = visible

		if visible then
			if instant then
				record.scale.Scale = 1
			else
				record.scale.Scale = 0.975
				task.delay(record.delay, function()
					if record.card.Visible then
						TweenService:Create(record.scale, TweenInfo.new(0.26, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
							Scale = 1,
						}):Play()
					end
				end)
			end
		end
	end

	local cached = tabHeights[key]
	if cached then
		TweenService:Create(window, TweenInfo.new(instant and 0.18 or 0.34, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(WINDOW_W, cached),
		}):Play()
	end

	task.delay(0.08, function()
		if currentTab ~= key then
			return
		end

		local content = 0
		local cards = 0

		for _, record in ipairs(sectionRecords) do
			if record.tab == key then
				local scale = record.scale.Scale
				content += record.card.AbsoluteSize.Y / (scale > 0.01 and scale or 1)
				cards += 1
			end
		end

		if cards == 0 or content < 60 then
			return
		end

		local goal = math.clamp(156 + content + (cards - 1) * 8 + 16, 300, 640)
		if tabHeights[key] and math.abs(tabHeights[key] - goal) < 0.5 then
			return
		end

		tabHeights[key] = goal
		TweenService:Create(window, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(WINDOW_W, goal),
		}):Play()
	end)
end

addTab("world", "world")
addTab("vision", "visual")

for _, tab in ipairs(tabButtons) do
	-- switch on press, not on release: waiting for MouseButton1Click adds the
	-- whole hold time to the audio and the pill slide, which reads as lag
	tab.button.MouseButton1Down:Connect(function()
		if currentTab ~= tab.key then
			showTab(tab.key, false)
		end
	end)
	tab.button.MouseEnter:Connect(function()
		if currentTab ~= tab.key then
			TweenService:Create(tab.label, TweenInfo.new(0.15), { TextColor3 = Color3.fromRGB(200, 192, 228) }):Play()
		end
	end)
	tab.button.MouseLeave:Connect(function()
		if currentTab ~= tab.key then
			TweenService:Create(tab.label, TweenInfo.new(0.15), { TextColor3 = MUTED }):Play()
		end
	end)
end

body = make("ScrollingFrame", {
	Name = "body",
	Size = UDim2.new(1, -32, 1, -156),
	Position = UDim2.fromOffset(16, 108),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 3,
	ScrollBarImageColor3 = ACCENT,
	ScrollBarImageTransparency = 0.6,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ZIndex = 4,
}, window)

make("UIListLayout", {
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, body)

make("UIPadding", {
	PaddingBottom = UDim.new(0, 10),
	PaddingRight = UDim.new(0, 4),
}, body)

footer = make("Frame", {
	Name = "footer",
	Size = UDim2.new(1, -32, 0, 24),
	Position = UDim2.new(0, 16, 1, -40),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 5,
}, window)

local statusDot = make("Frame", {
	Size = UDim2.fromOffset(6, 6),
	Position = UDim2.fromOffset(2, 9),
	BackgroundColor3 = ACCENT,
	BorderSizePixel = 0,
	ZIndex = 6,
}, footer)
corner(statusDot, 3)

local statusDotGlow = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(18, 18),
	BackgroundColor3 = ACCENT,
	BackgroundTransparency = 0.85,
	BorderSizePixel = 0,
	ZIndex = 5,
}, statusDot)
corner(statusDotGlow, 9)

local statusText = label(footer, "0 modules active", UDim2.new(1, -92, 0, 24), 10)
statusText.Position = UDim2.fromOffset(16, 0)
statusText.Font = Enum.Font.GothamMedium
statusText.TextColor3 = MUTED
statusText.ZIndex = 6

local keyChip = make("Frame", {
	Size = UDim2.fromOffset(74, 20),
	Position = UDim2.new(1, -74, 0, 2),
	BackgroundColor3 = CARD,
	BorderSizePixel = 0,
	ZIndex = 5,
}, footer)
corner(keyChip, 6)
stroke(keyChip, LINE, 0.45)

local keyChipText = label(keyChip, "R-SHIFT", UDim2.fromScale(1, 1), 10)
keyChipText.Font = Enum.Font.GothamBold
keyChipText.TextColor3 = MUTED
keyChipText.TextXAlignment = Enum.TextXAlignment.Center
keyChipText.ZIndex = 6

local toastLayer = make("Frame", {
	Name = "toasts",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 108),
	Size = UDim2.fromOffset(178, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 60,
}, window)

make("UIListLayout", {
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
}, toastLayer)

local toastOrder = 0
local toastCards = {}

local function toast(text, colour)
	toastOrder += 1

	local card = make("Frame", {
		Name = "toast",
		Size = UDim2.fromOffset(178, 26),
		BackgroundColor3 = CARD_HOT,
		BorderSizePixel = 0,
		LayoutOrder = toastOrder,
		ZIndex = 61,
	}, toastLayer)
	corner(card, 8)

	local line = stroke(card, colour or ACCENT, 0.35)

	local dot = make("Frame", {
		Size = UDim2.fromOffset(5, 5),
		Position = UDim2.fromOffset(11, 11),
		BackgroundColor3 = colour or ACCENT,
		BorderSizePixel = 0,
		ZIndex = 62,
	}, card)
	corner(dot, 3)

	local textLabel = label(card, text, UDim2.new(1, -30, 1, 1), 10)
	textLabel.Position = UDim2.fromOffset(22, 0)
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextColor3 = TEXT
	textLabel.ZIndex = 62

	local scale = make("UIScale", { Scale = 0.82 }, card)
	TweenService:Create(scale, TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	table.insert(toastCards, card)
	if #toastCards > 3 then
		local oldest = table.remove(toastCards, 1)
		if oldest then
			oldest:Destroy()
		end
	end

	task.delay(1.9, function()
		if not card.Parent then
			return
		end

		local info = TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		TweenService:Create(card, info, { BackgroundTransparency = 1, Size = UDim2.fromOffset(178, 0) }):Play()
		TweenService:Create(line, info, { Transparency = 1 }):Play()
		TweenService:Create(dot, info, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(textLabel, info, { TextTransparency = 1 }):Play()

		task.delay(0.3, function()
			card:Destroy()
			for index, item in ipairs(toastCards) do
				if item == card then
					table.remove(toastCards, index)
					break
				end
			end
		end)
	end)
end

connections = {}

function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end

local order = 0

local function nextOrder()
	order += 1
	return order
end

local currentSection
local sectionIndex = 0
local sliderFx = {}

local function rowShell(height, name, hideDot)
	local row = make("Frame", {
		Name = name or "row",
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = nextOrder(),
		ZIndex = 3,
	}, currentSection or body)

	local hover = make("Frame", {
		Name = "hover",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = CARD_HOT,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = true,
		ZIndex = 1,
	}, row)
	corner(hover, 8)

	local sweep = make("Frame", {
		Name = "sweep",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		ZIndex = 2,
	}, row)
	corner(sweep, 8)

	local sweepGradient = make("UIGradient", {
		Rotation = 18,
		Offset = Vector2.new(2, 0),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.94),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, sweep)

	local bar = make("Frame", {
		Name = "bar",
		Size = UDim2.fromOffset(2, 10),
		Position = UDim2.fromOffset(1, (height - 10) * 0.5),
		BackgroundColor3 = ACCENT,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, row)
	corner(bar, 1)

	local dot
	if not hideDot then
		dot = make("Frame", {
			Size = UDim2.fromOffset(6, 6),
			Position = UDim2.fromOffset(12, (height - 6) * 0.5),
			BackgroundColor3 = ACCENT,
			BackgroundTransparency = 0.75,
			BorderSizePixel = 0,
			ZIndex = 4,
		}, row)
		corner(dot, 3)
		make("UIGradient", { Color = ACCENT_GRADIENT }, dot)
	end

	local record = { hover = hover, bar = bar, height = height, on = false }

	hover.MouseEnter:Connect(function()
		record.on = true
		TweenService:Create(hover, TweenInfo.new(0.14), { BackgroundTransparency = 0.45 }):Play()
		TweenService:Create(bar, TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0.1,
			Size = UDim2.fromOffset(2, 16),
			Position = UDim2.fromOffset(1, (height - 16) * 0.5),
		}):Play()

		sweepGradient.Offset = Vector2.new(-1.4, 0)
		TweenService:Create(sweepGradient, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Offset = Vector2.new(1.4, 0),
		}):Play()
	end)

	hover.MouseLeave:Connect(function()
		record.on = false
		TweenService:Create(hover, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(bar, TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(2, 10),
			Position = UDim2.fromOffset(1, (height - 10) * 0.5),
		}):Play()
	end)

	return row, bar, dot
end

function section(text, tab)
	sectionIndex += 1
	tab = tab or "world"

	local card = make("Frame", {
		Name = text,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = CARD,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = nextOrder(),
		ZIndex = 1,
		Visible = tab == currentTab,
	}, body)
	corner(card, 14)

	local cardStroke = make("UIStroke", {
		Color = LINE,
		Transparency = 1,
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, card)

	local sheen = make("Frame", {
		Name = "sheen",
		Size = UDim2.new(1, -28, 0, 1),
		Position = UDim2.fromOffset(14, 0),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, card)
	make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.86),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, sheen)

	local inner = make("Frame", {
		Name = "inner",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, card)

	make("UIListLayout", {
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, inner)

	make("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 9),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
	}, inner)

	local head = make("Frame", {
		Name = "head",
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = nextOrder(),
		ZIndex = 2,
	}, inner)

	local caption = label(head, spaced(text), UDim2.fromScale(1, 1), 10)
	caption.Position = UDim2.fromOffset(0, 0)
	caption.Font = Enum.Font.GothamBold
	caption.TextColor3 = MUTED
	caption.TextXAlignment = Enum.TextXAlignment.Center
	caption.ZIndex = 3

	local divider = make("Frame", {
		Name = "divider",
		Size = UDim2.new(1, -4, 0, 1),
		Position = UDim2.new(0, 2, 1, -1),
		BackgroundColor3 = LINE,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, head)

	make("UIGradient", {
		Color = ACCENT_GRADIENT,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(0.5, 0.72),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, divider)

	local scale = make("UIScale", { Scale = 0.96 }, card)

	table.insert(sectionRecords, {
		card = card,
		scale = scale,
		tab = tab,
		delay = 0.02 * (sectionIndex % 4),
	})

	task.delay(0.05 * sectionIndex, function()
		if not card.Parent then
			return
		end

		if card.Visible and scale.Scale ~= 1 then
			TweenService:Create(scale, TweenInfo.new(0.34, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
				Scale = 1,
			}):Play()
		end
		TweenService:Create(card, TweenInfo.new(0.3), { BackgroundTransparency = 0 }):Play()
		TweenService:Create(cardStroke, TweenInfo.new(0.3), { Transparency = 0.4 }):Play()
		TweenService:Create(sheen, TweenInfo.new(0.3), { BackgroundTransparency = 0.9 }):Play()
	end)

	currentSection = inner
	return card
end

local uiClock = 0
local shineCycle = 3.4
local cometCycle = 4.6
local statusCount = -1
local statusFps = -1
local fpsSmooth = 60
local cometAccum = 0
local cometSequence

local function activeModules()
	local total = 0

	if config.chams.enabled then
		total += 1
	end
	if config.loot.enabled then
		total += 1
	end
	for _, state in pairs(config.world) do
		if state then
			total += 1
		end
	end

	return total
end

local function animateInterface(delta)
	delta = math.clamp(delta, 1 / 240, 0.1)
	uiClock += delta

	local frameRate = 1 / delta
	fpsSmooth += (frameRate - fpsSmooth) * 0.06

	local phase = (uiClock % shineCycle) / shineCycle
	shineGradient.Offset = Vector2.new(-1.3 + 2.6 * phase, 0)
	titleGradient.Offset = Vector2.new(math.sin(uiClock * 0.7) * 0.25, 0)
	backdropGradient.Offset = Vector2.new(math.sin(uiClock * 0.18) * 0.3, math.cos(uiClock * 0.13) * 0.2)
	borderGradient.Offset = Vector2.new(math.sin(uiClock * 0.35) * 0.4, 0)
	tabPillGradient.Offset = Vector2.new(math.sin(uiClock * 0.8) * 0.4, 0)

	auroraA.Position = UDim2.fromOffset(-70 + math.sin(uiClock * 0.11) * 44, 20 + math.cos(uiClock * 0.09) * 54)
	auroraB.Position = UDim2.fromOffset(160 + math.sin(uiClock * 0.09 + 2) * 48, 320 + math.sin(uiClock * 0.07) * 62)
	auroraC.Position = UDim2.fromOffset(40 + math.cos(uiClock * 0.08 + 4) * 60, 190 + math.sin(uiClock * 0.1 + 1) * 84)

	for _, item in ipairs(mist) do
		local span = MIST_SPAN + item.height
		local travel = (uiClock * item.speed + item.phase * span) % span
		item.band.Position = UDim2.fromOffset(math.sin(uiClock * 0.22 + item.phase * 7) * item.sway - 60, travel - item.height)
	end

	-- logo glow is static: the halo used to breathe here

	for _, item in ipairs(sleepMarks) do
		local bob = math.sin(uiClock * 1.5 + item.phase)
		item.mark.Position = UDim2.fromOffset(item.x, item.y - 1.6 - 1.6 * bob)
		item.mark.TextTransparency = 0.08 + 0.2 * (0.5 - 0.5 * bob)
	end

	local cometPhase = (uiClock % cometCycle) / cometCycle
	comet.Position = UDim2.new(-0.2 + 1.4 * cometPhase, 0, 0, 4)
	cometAccum += delta
	if cometAccum > 0.04 then
		cometAccum = 0

		-- the body is fully faded while any part of it would sit past the ends
		-- of the strip, so nothing can be drawn outside the panel even if the
		-- clip rect is dropped by the renderer
		local fade = math.clamp(math.min((cometPhase - 0.02) / 0.12, (0.98 - cometPhase) / 0.12), 0, 1)
		local dim = 1 - fade
		local head = math.clamp(dim + math.sin(uiClock * 2.4) * 0.05, 0, 1)

		cometSequence = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.35, math.clamp(0.88 + dim, 0, 1)),
			NumberSequenceKeypoint.new(0.68, math.clamp(0.5 + dim, 0, 1)),
			NumberSequenceKeypoint.new(0.88, head),
			NumberSequenceKeypoint.new(1, head),
		})
		cometGradient.Transparency = cometSequence
	end

	for _, fx in ipairs(sliderFx) do
		fx.gradient.Offset = Vector2.new(math.sin(uiClock * 1.1 + fx.phase) * 0.4, 0)

		local wave = 0.5 + 0.5 * math.sin(uiClock * 7.2 + fx.phase)
		local goal = 16
		local alpha = 1

		if fx.drag then
			goal = 25 + 7 * wave
			alpha = 0.5 + 0.24 * wave
		elseif fx.hover then
			goal = 20 + 2 * wave
			alpha = 0.78 + 0.1 * wave
		end

		local halo = fx.halo
		local current = halo.Size.X.Offset
		local eased = current + (goal - current) * math.min(1, delta * 14)
		halo.Size = UDim2.fromOffset(eased, eased)
		halo.BackgroundTransparency = halo.BackgroundTransparency + (alpha - halo.BackgroundTransparency) * math.min(1, delta * 12)
	end

	local modules = activeModules()
	local fps = math.floor(fpsSmooth + 0.5)
	if modules ~= statusCount or fps ~= statusFps then
		statusCount = modules
		statusFps = fps
		statusText.Text = string.format("%d active · %d fps", modules, fps)
	end

	if not window.Visible then
		return
	end

	local area = particleLayer.AbsoluteSize
	local width, height = area.X, area.Y
	if width < 1 or height < 1 then
		return
	end

	for _, star in ipairs(particles) do
		star.y -= star.speed * delta
		if star.y < -4 then
			star.y = height + 3
			star.x = math.random() * width
		end

		local sway = math.sin(uiClock * star.swayRate + star.phase) * star.sway
		star.frame.Position = UDim2.fromOffset(math.clamp(star.x + sway, -4, width - 2), star.y)
		star.frame.BackgroundTransparency = math.clamp(star.base + 0.24 * math.sin(uiClock * 1.1 + star.phase), 0, 1)
	end

	for _, sleeper in ipairs(sleepers) do
		sleeper.y -= sleeper.speed * delta
		if sleeper.y < -22 then
			sleeper.y = height + 14
			sleeper.x = 14 + math.random() * math.max(10, width - 70)
		end

		local rise = math.clamp(sleeper.y / math.max(height, 1), 0, 1)
		local fade = math.clamp(math.min(rise, 1 - rise) * 3.4, 0, 1)
		local drift = math.sin(uiClock * 0.6 + sleeper.phase) * 7

		sleeper.frame.Position = UDim2.fromOffset(sleeper.x + drift, sleeper.y)
		sleeper.frame.TextTransparency = 1 - 0.26 * fade
		sleeper.frame.Rotation = -14 + math.sin(uiClock * 0.7 + sleeper.phase) * 4
	end
end

function toggleRow(text, default, onChange)
	local row, bar, dot = rowShell(34, text)

	local caption = label(row, text, UDim2.new(1, -86, 0, 34), 13)
	caption.Position = UDim2.fromOffset(24, 0)
	caption.Font = Enum.Font.GothamMedium
	caption.TextColor3 = TEXT
	caption.ZIndex = 5

	local hitbox = make("TextButton", {
		Name = "switch",
		Size = UDim2.fromOffset(40, 34),
		Position = UDim2.new(1, -50, 0, 0),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		ZIndex = 6,
	}, row)

	local aura = make("Frame", {
		Name = "aura",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(48, 28),
		BackgroundColor3 = ACCENT,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 5,
	}, hitbox)
	corner(aura, 15)

	local track = make("Frame", {
		Name = "track",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(40, 20),
		BackgroundColor3 = Color3.fromRGB(46, 41, 68),
		BorderSizePixel = 0,
		ZIndex = 6,
	}, hitbox)
	corner(track, 10)

	local trackGradient = make("UIGradient", {
		Color = ACCENT_GRADIENT,
		Rotation = 0,
		Enabled = false,
	}, track)

	local trackStroke = make("UIStroke", {
		Color = LINE,
		Transparency = 0.45,
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, track)

	local knobShadow = make("Frame", {
		Size = UDim2.fromOffset(14, 14),
		Position = UDim2.fromOffset(3, 4),
		BackgroundColor3 = Color3.fromRGB(5, 4, 12),
		BackgroundTransparency = 0.68,
		BorderSizePixel = 0,
		ZIndex = 7,
	}, track)
	corner(knobShadow, 7)

	local knob = make("Frame", {
		Name = "knob",
		Size = UDim2.fromOffset(14, 14),
		Position = UDim2.fromOffset(3, 3),
		BackgroundColor3 = Color3.fromRGB(248, 245, 255),
		BorderSizePixel = 0,
		ZIndex = 8,
	}, track)
	corner(knob, 7)

	local knobScale = make("UIScale", { Scale = 1 }, knob)
	local pressScale = make("UIScale", { Scale = 1 }, hitbox)

	local REST_X = 3
	local ON_X = 23
	local state = default

	local function render(animate)
		local targetX = state and ON_X or REST_X
		local dotAlpha = state and 0 or 0.8

		if not animate then
			trackGradient.Enabled = state
			track.BackgroundColor3 = state and ACCENT or Color3.fromRGB(46, 41, 68)
			trackStroke.Color = state and ACCENT or LINE
			trackStroke.Transparency = state and 0.72 or 0.45
			knob.Position = UDim2.fromOffset(targetX, 3)
			knobShadow.Position = UDim2.fromOffset(targetX, 4)
			aura.BackgroundTransparency = state and 0.92 or 1
			dot.BackgroundTransparency = dotAlpha
			return
		end

		trackGradient.Enabled = state

		TweenService:Create(knob, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(targetX, 3),
		}):Play()

		TweenService:Create(knobShadow, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(targetX, 4),
		}):Play()

		TweenService:Create(track, TweenInfo.new(0.2), {
			BackgroundColor3 = state and ACCENT or Color3.fromRGB(46, 41, 68),
		}):Play()

		TweenService:Create(trackStroke, TweenInfo.new(0.22), {
			Color = state and ACCENT or LINE,
			Transparency = state and 0.72 or 0.45,
		}):Play()

		TweenService:Create(aura, TweenInfo.new(0.3), {
			BackgroundTransparency = state and 0.92 or 1,
		}):Play()

		TweenService:Create(dot, TweenInfo.new(0.24), {
			BackgroundTransparency = dotAlpha,
		}):Play()
	end

	render(false)

	connect(hitbox.MouseEnter, function()
		TweenService:Create(knobScale, TweenInfo.new(0.16, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Scale = 1.08 }):Play()
		TweenService:Create(trackStroke, TweenInfo.new(0.16), {
			Transparency = state and 0.58 or 0.2,
		}):Play()
	end)

	connect(hitbox.MouseLeave, function()
		TweenService:Create(knobScale, TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		TweenService:Create(trackStroke, TweenInfo.new(0.2), {
			Transparency = state and 0.72 or 0.45,
		}):Play()
		TweenService:Create(pressScale, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end)

	connect(hitbox.MouseButton1Down, function()
		TweenService:Create(knobScale, TweenInfo.new(0.09, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Scale = 0.9 }):Play()
		TweenService:Create(pressScale, TweenInfo.new(0.09), { Scale = 0.94 }):Play()
	end)

	connect(hitbox.MouseButton1Up, function()
		TweenService:Create(knobScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.08 }):Play()
		TweenService:Create(pressScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end)

	local function set(nextState, animate)
		state = nextState
		render(animate)
	end

	local function ripple()
		local targetX = state and ON_X or REST_X
		local ring = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(targetX + 7, 10),
			Size = UDim2.fromOffset(14, 14),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 5,
		}, track)
		corner(ring, 7)

		local edge = make("UIStroke", {
			Color = Color3.fromRGB(255, 255, 255),
			Thickness = 1.5,
			Transparency = 0.35,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}, ring)

		TweenService:Create(ring, TweenInfo.new(0.42, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(44, 44),
			Position = UDim2.fromOffset(targetX + 7, 10),
		}):Play()
		TweenService:Create(edge, TweenInfo.new(0.42), { Transparency = 1 }):Play()

		task.delay(0.44, function()
			ring:Destroy()
		end)
	end

	hitbox.MouseButton1Click:Connect(function()
		state = not state
		playToggleSound(state)
		render(true)
		ripple()

		if state then
			bar.BackgroundTransparency = 0.12
			TweenService:Create(bar, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
				BackgroundTransparency = 1,
			}):Play()
		end

		onChange(state)
	end)

	return set
end

local KNOB_INSET = 7

function sliderRow(text, minimum, maximum, step, default, format, onChange)
	local row = rowShell(42, text, true)

	local caption = label(row, text, UDim2.new(1, -104, 0, 15), 13)
	caption.Position = UDim2.fromOffset(24, 3)
	caption.Font = Enum.Font.GothamMedium
	caption.TextColor3 = TEXT
	caption.ZIndex = 5

	local readout = label(row, "", UDim2.fromOffset(84, 15), 11)
	readout.AnchorPoint = Vector2.new(1, 0)
	readout.Position = UDim2.new(1, -10, 0, 3)
	readout.Font = Enum.Font.GothamBold
	readout.TextColor3 = ACCENT
	readout.TextXAlignment = Enum.TextXAlignment.Right
	readout.ZIndex = 5
	local readoutScale = make("UIScale", { Scale = 1 }, readout)

	local glow = make("Frame", {
		Name = "glow",
		Size = UDim2.new(1, -30, 0, 14),
		Position = UDim2.fromOffset(22, 22),
		BackgroundColor3 = ACCENT,
		BackgroundTransparency = 0.94,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, row)
	corner(glow, 7)

	local track = make("Frame", {
		Size = UDim2.new(1, -34, 0, 4),
		Position = UDim2.fromOffset(24, 27),
		BackgroundColor3 = OFF,
		BorderSizePixel = 0,
		ZIndex = 5,
	}, row)
	corner(track, 2)

	local fill = make("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = ACCENT,
		BorderSizePixel = 0,
		ZIndex = 6,
	}, track)
	corner(fill, 2)
	local fillGradient = make("UIGradient", {
		Color = ACCENT_GRADIENT,
		Rotation = 0,
	}, fill)

	local knobHalo = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = ACCENT,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 6,
	}, track)
	corner(knobHalo, 8)

	local knob = make("Frame", {
		Size = UDim2.fromOffset(12, 12),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		BackgroundColor3 = Color3.fromRGB(250, 247, 255),
		BorderSizePixel = 0,
		ZIndex = 7,
	}, track)
	corner(knob, 6)
	stroke(knob, ACCENT, 0.15, 1)

	local fx = {
		gradient = fillGradient,
		halo = knobHalo,
		phase = #sliderFx * 1.7,
		hover = false,
		drag = false,
	}
	table.insert(sliderFx, fx)

	local value = default
	local previousText = ""

	local function render()
		local alpha = math.clamp((value - minimum) / (maximum - minimum), 0, 1)
		local inset = KNOB_INSET - 2 * KNOB_INSET * alpha
		fill.Size = UDim2.new(alpha, inset, 1, 0)
		knob.Position = UDim2.new(alpha, inset, 0.5, 0)
		knobHalo.Position = UDim2.new(alpha, inset, 0.5, 0)

		local nextText = format(value)
		if nextText ~= previousText then
			previousText = nextText
			readout.Text = nextText
		end
	end

	local function apply(fraction)
		local raw = minimum + (maximum - minimum) * fraction
		local nextValue = math.clamp(math.floor(raw / step + 0.5) * step, minimum, maximum)
		if nextValue == value then
			return
		end

		value = nextValue
		render()
		onChange(value)
	end

	local function burst()
		local ring = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(knob.Position.X.Scale, knob.Position.X.Offset, 0.5, 0),
			Size = UDim2.fromOffset(16, 16),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 6,
		}, track)
		corner(ring, 8)

		local edge = make("UIStroke", {
			Color = ACCENT,
			Transparency = 0.25,
			Thickness = 1.5,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}, ring)

		TweenService:Create(ring, TweenInfo.new(0.42, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(44, 44),
		}):Play()
		TweenService:Create(edge, TweenInfo.new(0.42), { Transparency = 1 }):Play()

		task.delay(0.45, function()
			ring:Destroy()
		end)
	end

	local function knobSize()
		if fx.drag then
			return 15
		end
		return fx.hover and 14 or 12
	end

	local function resizeKnob()
		local size = knobSize()
		TweenService:Create(knob, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(size, size),
		}):Play()
	end

	local function setHover(state)
		if fx.hover == state then
			return
		end

		fx.hover = state
		resizeKnob()
		TweenService:Create(glow, TweenInfo.new(0.24), {
			BackgroundTransparency = fx.drag and 0.8 or (state and 0.86 or 0.94),
		}):Play()
		TweenService:Create(caption, TweenInfo.new(0.22), {
			TextColor3 = state and Color3.fromRGB(255, 255, 255) or TEXT,
		}):Play()
	end

	local function setDragging(state)
		if fx.drag == state then
			return
		end

		fx.drag = state
		resizeKnob()
		TweenService:Create(glow, TweenInfo.new(0.2), {
			BackgroundTransparency = state and 0.8 or (fx.hover and 0.86 or 0.94),
		}):Play()

		if not state then
			burst()
			readoutScale.Scale = 1.18
			TweenService:Create(readoutScale, TweenInfo.new(0.34, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = 1,
			}):Play()
		end
	end

	connect(row.MouseEnter, function()
		setHover(true)
	end)

	connect(row.MouseLeave, function()
		setHover(false)
	end)

	connect(track.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			setDragging(true)
			apply((input.Position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1))
		end
	end)

	connect(UserInputService.InputChanged, function(input)
		if not fx.drag then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			apply((input.Position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1))
		end
	end)

	connect(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			setDragging(false)
		end
	end)

	render()
end

local kickerAccumulator = 0

connect(RunService.Heartbeat, function(delta)
	kickerAccumulator += delta
	if kickerAccumulator < 0.5 then
		return
	end
	kickerAccumulator = 0

	local round = ReplicatedStorage:FindFirstChild("Round")
	local mapName = round and round:GetAttribute("Map")
	if type(mapName) == "string" and #mapName > 0 then
		kicker.Text = "STEAL OR DIE · " .. string.upper(mapName)
	else
		kicker.Text = "STEAL OR DIE"
	end
end)
connect(RunService.RenderStepped, animateInterface)

window.MouseEnter:Connect(function()
	TweenService:Create(windowStroke, TweenInfo.new(0.22), { Transparency = 0.3 }):Play()
end)

window.MouseLeave:Connect(function()
	TweenService:Create(windowStroke, TweenInfo.new(0.3), { Transparency = 0.55 }):Play()
end)

local menuMotion = 0
local menuOpen = false
local menuRestX, menuRestY = 150, 100
local menuTweens = {}

local function stopMenuTweens()
	for index = #menuTweens, 1, -1 do
		menuTweens[index]:Cancel()
		menuTweens[index] = nil
	end
end

local function restingPoint()
	local anchor = window.AnchorPoint
	if anchor.X == 0 and anchor.Y == 0 then
		return window.Position.X.Offset, window.Position.Y.Offset
	end
	return menuRestX, menuRestY
end

local function restAt(x, y)
	menuRestX, menuRestY = x, y
	window.AnchorPoint = Vector2.zero
	window.Position = UDim2.fromOffset(x, y)
	window.Rotation = 0
	windowScale.Scale = 1
end

function finishMenuMotion()
	if not menuOpen then
		return
	end

	local x, y = restingPoint()
	menuMotion += 1
	stopMenuTweens()
	restAt(x, y)
end

-- NOTE: the panel is never rotated. Rotating an ancestor breaks Roblox's
-- descendant clipping, which let the grid, aurora and comet spill outside the
-- rounded frame mid-animation. Scale + rise keeps every clip rect exact.
local function menuCentre(x, y, lift)
	return x + window.Size.X.Offset * 0.5, y + window.Size.Y.Offset * 0.5 + (lift or 0)
end

local function playOpen()
	local x, y = restingPoint()
	local token = menuMotion
	local cx, cy = menuCentre(x, y, 9)

	stopMenuTweens()
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromOffset(cx, cy)
	windowScale.Scale = 0.86
	window.Visible = true

	table.insert(menuTweens, TweenService:Create(window, TweenInfo.new(0.34, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Position = UDim2.fromOffset(cx, cy - 9),
	}))
	table.insert(menuTweens, TweenService:Create(windowScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}))

	for _, tween in ipairs(menuTweens) do
		tween:Play()
	end

	task.delay(0.44, function()
		if menuMotion == token and menuOpen then
			stopMenuTweens()
			restAt(x, y)
		end
	end)
end

local function playClose()
	local x, y = restingPoint()
	local token = menuMotion
	local cx, cy = menuCentre(x, y)

	stopMenuTweens()
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromOffset(cx, cy)

	table.insert(menuTweens, TweenService:Create(window, TweenInfo.new(0.16, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
		Position = UDim2.fromOffset(cx, cy + 8),
	}))
	table.insert(menuTweens, TweenService:Create(windowScale, TweenInfo.new(0.16, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
		Scale = 0.88,
	}))

	for _, tween in ipairs(menuTweens) do
		tween:Play()
	end

	task.delay(0.18, function()
		if menuMotion ~= token or menuOpen then
			return
		end

		stopMenuTweens()
		restAt(x, y)
		window.Visible = false
	end)
end

function toggleMenu()
	menuMotion += 1
	menuOpen = not menuOpen

	if menuOpen then
		playOpen()
	else
		playClose()
	end
end

showTab("world", true)
toggleMenu()
end

local chamByModel = {}
local lootEntries = {}

local boundsOffset

local CHAM_GREEN = Color3.fromRGB(90, 225, 130)
local CHAM_RED = Color3.fromRGB(255, 68, 68)

local function updateCham(model)
	local record = chamByModel[model]
	local isEntity = model:GetAttribute("EntityKind") ~= nil

	if not config.chams.enabled or not model.Parent then
		if record then
			record.highlight:Destroy()
			record.label:Destroy()
			chamByModel[model] = nil
		end
		return
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local anchor = model:FindFirstChild("Head") or (humanoid and humanoid.RootPart) or model.PrimaryPart
	if not anchor then
		anchor = model:FindFirstChildWhichIsA("BasePart")
	end
	if not anchor then
		return
	end

	if record and (not record.highlight.Parent or not record.label.Parent or record.anchor ~= anchor) then
		record.highlight:Destroy()
		record.label:Destroy()
		record = nil
	end

	if not record then
		local highlight = make("Highlight", {
			Name = "prism_cham",
			Adornee = model,
			DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
		}, nil)
		highlight.Parent = model

		local billboard = make("BillboardGui", {
			Name = "prism_cham_label",
			Adornee = anchor,
			AlwaysOnTop = true,
			LightInfluence = 0,
			MaxDistance = 500,
			Size = UDim2.fromOffset(200, 22),
			StudsOffsetWorldSpace = Vector3.new(0, anchor.Size.Y * 0.5 + 0.85, 0),
			ResetOnSpawn = false,
		}, nil)
		billboard.Parent = anchor

		local text = label(billboard, "", UDim2.fromScale(1, 1), 14)
		text.TextXAlignment = Enum.TextXAlignment.Center
		text.TextYAlignment = Enum.TextYAlignment.Center
		text.Font = Enum.Font.GothamBold
		text.TextTruncate = Enum.TextTruncate.None
		text.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		text.TextStrokeTransparency = 0.35

		record = {
			highlight = highlight,
			label = billboard,
			text = text,
			anchor = anchor,
		}
		chamByModel[model] = record
	end

	local colour = isEntity and CHAM_RED or CHAM_GREEN
	local highlight = record.highlight
	highlight.FillColor = colour
	highlight.OutlineColor = colour
	highlight.FillTransparency = config.chams.fill
	highlight.OutlineTransparency = 0

	local player = Players:GetPlayerFromCharacter(model)
	local nameText = player and player.Name or model.Name
	if record.text.Text ~= nameText then
		record.text.Text = nameText
	end
	if record.text.TextColor3 ~= colour then
		record.text.TextColor3 = colour
	end
end

local function updatePlayers()
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			local character = player.Character
			if character and character:FindFirstChildOfClass("Humanoid") then
				updateCham(character)
			end
		end
	end

	for _, child in ipairs(workspace:GetChildren()) do
		if child:IsA("Model") and child:GetAttribute("EntityKind") and child:FindFirstChildOfClass("Humanoid") then
			updateCham(child)
		end
	end

	for model, record in pairs(chamByModel) do
		if not model.Parent or not record.highlight.Parent then
			record.highlight:Destroy()
			record.label:Destroy()
			chamByModel[model] = nil
		end
	end
end

local function lootColour(part)
	local rarity = part:GetAttribute("Rarity")
	if type(rarity) == "string" and rarityColour[rarity] then
		return rarityColour[rarity]
	end
	return rarityColour.Common
end

local function lootName(part)
	local key = part:GetAttribute("ItemKey")
	local info = key and itemInfo[key]
	return (info and info.displayName) or key or part.Name
end

local function lootValue(part)
	return tonumber(part:GetAttribute("Value")) or tonumber(part:GetAttribute("BaseValue")) or 0
end

function boundsOffset(root, anchor, headroom)
	local minX, maxX = math.huge, -math.huge
	local minY, maxY = math.huge, -math.huge
	local minZ, maxZ = math.huge, -math.huge

	local function consider(object)
		if not object:IsA("BasePart") then
			return
		end

		local cframe = object.CFrame
		local size = object.Size
		local right, up, look = cframe.RightVector, cframe.UpVector, cframe.LookVector
		local halfX = math.abs(right.X) * size.X * 0.5 + math.abs(up.X) * size.Y * 0.5 + math.abs(look.X) * size.Z * 0.5
		local halfY = math.abs(right.Y) * size.X * 0.5 + math.abs(up.Y) * size.Y * 0.5 + math.abs(look.Y) * size.Z * 0.5
		local halfZ = math.abs(right.Z) * size.X * 0.5 + math.abs(up.Z) * size.Y * 0.5 + math.abs(look.Z) * size.Z * 0.5
		local position = cframe.Position

		minX = math.min(minX, position.X - halfX)
		maxX = math.max(maxX, position.X + halfX)
		minY = math.min(minY, position.Y - halfY)
		maxY = math.max(maxY, position.Y + halfY)
		minZ = math.min(minZ, position.Z - halfZ)
		maxZ = math.max(maxZ, position.Z + halfZ)
	end

	consider(root)
	for _, descendant in ipairs(root:GetDescendants()) do
		consider(descendant)
	end

	if minY == math.huge then
		return Vector3.new(0, headroom, 0)
	end

	local position = anchor.Position

	return Vector3.new(
		(minX + maxX) * 0.5 - position.X,
		maxY - position.Y + headroom,
		(minZ + maxZ) * 0.5 - position.Z
	)
end

local function labelOffset(part)
	return boundsOffset(part, part, 0.6)
end

local tracerLayer = make("Frame", {
	Name = "tracers",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 1,
}, gui)

local flashLayer = make("Frame", {
	Name = "flash",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 2,
}, gui)

local toastLayer = make("Frame", {
	Name = "toasts",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 8,
}, gui)

local SECRET_FILL = Color3.fromRGB(8, 8, 10)
local SECRET_EDGE = Color3.fromRGB(255, 255, 255)

local LEGENDARY_BAND = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(172, 116, 24)),
	ColorSequenceKeypoint.new(0.28, Color3.fromRGB(244, 190, 66)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 250, 222)),
	ColorSequenceKeypoint.new(0.72, Color3.fromRGB(244, 190, 66)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(172, 116, 24)),
})

local SECRET_BAND = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(138, 140, 152)),
	ColorSequenceKeypoint.new(0.28, Color3.fromRGB(226, 228, 238)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
	ColorSequenceKeypoint.new(0.72, Color3.fromRGB(226, 228, 238)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(138, 140, 152)),
})

local BAND_CYCLE = 2.6

local function animateBand(entry, clock)
	if not entry.band then
		return
	end

	local phase = (clock % BAND_CYCLE) / BAND_CYCLE
	local offset = Vector2.new(-1 + 2 * phase, 0)
	entry.band.Offset = offset
	entry.bandValue.Offset = offset
end

local function newTracer(colour, outlined)
	local frame = make("Frame", {
		Name = "prism_tracer",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(0, 2),
		Position = UDim2.fromOffset(0, 0),
		BackgroundColor3 = colour,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 1,
	}, tracerLayer)

	if outlined then
		make("UIStroke", {
			Color = SECRET_EDGE,
			Thickness = 1,
			Transparency = 0,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}, frame)
	end

	return frame
end

local function destroyTracer(entry)
	local frame = entry.tracer
	if not frame then
		return
	end

	entry.tracer = nil
	frame:Destroy()
end

local function readableColour(colour)
	local luma = colour.R * 0.299 + colour.G * 0.587 + colour.B * 0.114
	if luma >= 0.3 then
		return colour
	end
	return colour:Lerp(Color3.fromRGB(255, 255, 255), math.clamp((0.5 - luma) / (1 - luma), 0, 0.85))
end

local function auraCircle(parent, name, scale, colour, transparency, zIndex)
	local frame = make("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(scale, scale),
		BackgroundColor3 = colour,
		BackgroundTransparency = transparency,
		BorderSizePixel = 0,
		ZIndex = zIndex or 1,
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, frame)
	return frame
end

local function auraRing(parent, name, scale, colour, thickness, transparency, zIndex)
	local frame = auraCircle(parent, name, scale, colour, 1, zIndex)
	local line = make("UIStroke", {
		Color = colour,
		Thickness = thickness,
		Transparency = transparency,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, frame)
	return frame, line
end

local function buildLootEntry(part)
	local entry = { offsetAt = 0 }

	local highlight = make("Highlight", {
		Name = "prism_loot",
		Adornee = part,
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
		FillTransparency = 0.8,
		OutlineTransparency = 0,
	}, part)
	entry.highlight = highlight

	local billboard = make("BillboardGui", {
		Name = "prism_label",
		Adornee = part,
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 500,
		Size = UDim2.fromOffset(230, 52),
		StudsOffsetWorldSpace = labelOffset(part),
		ResetOnSpawn = false,
	}, part)

	local name = label(billboard, "", UDim2.new(1, 0, 0, 20), 13)
	name.Position = UDim2.fromOffset(0, 4)
	name.TextXAlignment = Enum.TextXAlignment.Center
	name.Font = Enum.Font.GothamMedium
	name.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	name.TextStrokeTransparency = 0.45

	local value = label(billboard, "", UDim2.new(1, 0, 0, 24), 17)
	value.Position = UDim2.fromOffset(0, 22)
	value.TextXAlignment = Enum.TextXAlignment.Center
	value.Font = Enum.Font.GothamBold
	value.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	value.TextStrokeTransparency = 0.45

	entry.name = name
	entry.value = value
	entry.billboard = billboard

	local rarity = part:GetAttribute("Rarity")
	if type(rarity) == "string" then
		local lower = string.lower(rarity)
		if lower == "legendary" or lower == "secret" then
			local secret = lower == "secret"
			entry.tracerRarity = lower
			entry.secret = secret
			entry.tracerColour = secret and SECRET_FILL or readableColour(lootColour(part))
			entry.tracer = newTracer(entry.tracerColour, secret)

			local band = secret and SECRET_BAND or LEGENDARY_BAND
			entry.band = make("UIGradient", {
				Color = band,
				Rotation = 0,
				Offset = Vector2.new(-1, 0),
			}, name)
			entry.bandValue = make("UIGradient", {
				Color = band,
				Rotation = 0,
				Offset = Vector2.new(-1, 0),
			}, value)

			name.TextColor3 = Color3.new(1, 1, 1)
			value.TextColor3 = Color3.new(1, 1, 1)

			entry.glow = true

			local auraColour = secret and Color3.fromRGB(242, 246, 255) or Color3.fromRGB(255, 209, 104)
			local auraAccent = secret and Color3.fromRGB(164, 138, 255) or Color3.fromRGB(255, 247, 216)

			local auraAttachment = make("Attachment", { Name = "prism_aura" }, part)
			entry.aura = make("ParticleEmitter", {
				Name = "prism_aura",
				Enabled = false,
				Texture = "rbxasset://textures/particles/sparkles_main.dds",
				Color = ColorSequence.new(auraColour),
				Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(0.3, secret and 0.28 or 0.34),
					NumberSequenceKeypoint.new(1, 0),
				}),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(0.75, 0.25),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Lifetime = NumberRange.new(1.4, 2.4),
				Rate = secret and 24 or 32,
				Speed = NumberRange.new(0.6, 1.5),
				SpreadAngle = Vector2.new(24, 24),
				Acceleration = Vector3.new(0, 2.2, 0),
				Drag = 0.8,
				LightEmission = 1,
				LightInfluence = 0,
				Rotation = NumberRange.new(0, 360),
				RotSpeed = NumberRange.new(-40, 40),
				EmissionDirection = Enum.NormalId.Top,
			}, auraAttachment)
			entry.auraAttachment = auraAttachment

			local motes = make("ParticleEmitter", {
				Name = "prism_motes",
				Enabled = false,
				Texture = "rbxasset://textures/particles/sparkles_main.dds",
				Color = ColorSequence.new(auraAccent),
				Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(0.5, secret and 0.16 or 0.2),
					NumberSequenceKeypoint.new(1, 0),
				}),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.35),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Lifetime = NumberRange.new(1.8, 3),
				Rate = secret and 10 or 14,
				Speed = NumberRange.new(0.25, 0.7),
				SpreadAngle = Vector2.new(180, 180),
				Acceleration = Vector3.new(0, -0.6, 0),
				Drag = 0.4,
				LightEmission = 1,
				LightInfluence = 0,
				Rotation = NumberRange.new(0, 360),
				RotSpeed = NumberRange.new(-25, 25),
			}, auraAttachment)
			entry.motes = motes

			entry.light = make("PointLight", {
				Name = "prism_glow",
				Color = auraColour,
				Range = secret and 11 or 13,
				Brightness = 0,
				Shadows = false,
				Enabled = false,
			}, part)

			local auraGui = make("BillboardGui", {
				Name = "prism_aura_overlay",
				Adornee = part,
				AlwaysOnTop = true,
				LightInfluence = 0,
				MaxDistance = 700,
				Size = UDim2.fromOffset(170, 170),
				ResetOnSpawn = false,
				ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			}, part)
			entry.auraGui = auraGui

			entry.auraGlow = auraCircle(auraGui, "glow_outer", 0.98, auraColour, 0.9, 1)
			entry.auraGlowInner = auraCircle(auraGui, "glow_inner", 0.6, auraColour, 0.82, 1)

			local ringOuter, ringOuterStroke = auraRing(auraGui, "ring", 0.98, auraColour, 3, 0.12, 3)
			local ringInner, ringInnerStroke = auraRing(auraGui, "ring_inner", 0.58, auraAccent, 1.5, 0.4, 3)
			local ringBand, ringBandStroke = auraRing(auraGui, "ring_band", 0.99, auraColour, 8, 0.9, 2)
			entry.auraRing = ringOuterStroke
			entry.auraInner = ringInnerStroke
			entry.auraBand = ringBandStroke

			local pulseRing, pulseStroke = auraRing(auraGui, "pulse", 0.3, auraAccent, 2, 0.1, 2)
			entry.auraPulse = pulseRing
			entry.auraPulseStroke = pulseStroke

			local pulseRing2, pulseStroke2 = auraRing(auraGui, "pulse_alt", 0.3, auraColour, 2, 0.1, 2)
			entry.auraPulse2 = pulseRing2
			entry.auraPulseStroke2 = pulseStroke2

			local tickLayer = make("Frame", {
				Name = "ticks",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 4,
			}, auraGui)

			entry.auraTicks = {}
			for index = 1, 8 do
				local tick = make("Frame", {
					Name = "tick",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Size = UDim2.fromOffset(3, index % 2 == 0 and 9 or 5),
					BackgroundColor3 = auraColour,
					BackgroundTransparency = 0.15,
					BorderSizePixel = 0,
					ZIndex = 4,
				}, tickLayer)
				make("UICorner", { CornerRadius = UDim.new(1, 0) }, tick)
				entry.auraTicks[index] = tick
			end

			local sparkLayer = make("Frame", {
				Name = "sparks",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 4,
			}, auraGui)

			entry.auraSparks = {}
			for index = 1, 20 do
				local size = 2 + index % 3
				local spark = make("Frame", {
					Name = "spark",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.62),
					Size = UDim2.fromOffset(size, size),
					BackgroundColor3 = index % 4 == 0 and auraAccent or auraColour,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ZIndex = 4,
				}, sparkLayer)
				make("UICorner", { CornerRadius = UDim.new(1, 0) }, spark)
				entry.auraSparks[index] = {
					frame = spark,
					size = size,
					phase = (index - 1) / 20 + (index % 5) * 0.037,
					speed = 0.26 + (index % 4) * 0.08,
					drift = 0.05 + (index % 3) * 0.03,
				}
			end

			entry.auraOrbs = {}
			for index = 1, 3 do
				local halo = make("Frame", {
					Name = "orb_halo",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromOffset(0, 0),
					Size = UDim2.fromOffset(10, 10),
					BackgroundColor3 = index == 2 and auraAccent or auraColour,
					BackgroundTransparency = 0.62,
					BorderSizePixel = 0,
					ZIndex = 5,
				}, auraGui)
				make("UICorner", { CornerRadius = UDim.new(1, 0) }, halo)

				local core = make("Frame", {
					Name = "orb_core",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromOffset(0, 0),
					Size = UDim2.fromOffset(4, 4),
					BackgroundColor3 = Color3.new(1, 1, 1),
					BackgroundTransparency = 0,
					BorderSizePixel = 0,
					ZIndex = 6,
				}, auraGui)
				make("UICorner", { CornerRadius = UDim.new(1, 0) }, core)

				entry.auraOrbs[index] = { halo = halo, core = core, offset = (index - 1) * 2.09 }
			end
		end
	end

	return entry
end

local recentLoot = {}

local function noteLootGone(part, entry)
	if not entry.tracerRarity then
		return
	end

	recentLoot[#recentLoot + 1] = {
		at = os.clock(),
		position = part.Position,
		rarity = entry.tracerRarity,
		name = lootName(part),
		value = lootValue(part),
	}

	while #recentLoot > 10 do
		table.remove(recentLoot, 1)
	end
end

local function removeLootEntry(part, entry)
	entry.highlight:Destroy()
	entry.billboard:Destroy()
	destroyTracer(entry)

	if entry.auraAttachment then
		entry.auraAttachment:Destroy()
	end

	if entry.auraGui then
		entry.auraGui:Destroy()
	end

	if entry.light then
		entry.light:Destroy()
	end

	noteLootGone(part, entry)
	lootEntries[part] = nil
end

local lootFolders = { "MyLoot", "LootItems" }

local function scanLoot()
	local seen = {}

	for _, folderName in ipairs(lootFolders) do
		local folder = workspace:FindFirstChild(folderName)
		if folder then
			for _, child in ipairs(folder:GetChildren()) do
				if child:IsA("BasePart") and child:GetAttribute("Loot") then
					seen[child] = true
					if not lootEntries[child] then
						lootEntries[child] = buildLootEntry(child)
					end
				end
			end
		end
	end

	for part, entry in pairs(lootEntries) do
		if not seen[part] or not part.Parent then
			removeLootEntry(part, entry)
		end
	end
end

local PICKUP_COLOURS = {
	legendary = Color3.fromRGB(255, 199, 96),
	secret = Color3.fromRGB(214, 198, 255),
}

local PICKUP_ACCENT = {
	legendary = Color3.fromRGB(255, 246, 214),
	secret = Color3.fromRGB(255, 255, 255),
}

local function pickupBurst(position, rarity)
	local colour = PICKUP_COLOURS[rarity] or PICKUP_COLOURS.legendary
	local accent = PICKUP_ACCENT[rarity] or PICKUP_ACCENT.legendary
	local secret = rarity == "secret"

	local holder = make("Part", {
		Name = "prism_pickup",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Transparency = 1,
		Size = Vector3.new(0.4, 0.4, 0.4),
		CFrame = CFrame.new(position),
	}, workspace)

	local light = make("PointLight", {
		Color = colour,
		Range = secret and 22 or 26,
		Brightness = 0,
		Shadows = false,
	}, holder)

	TweenService:Create(light, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Brightness = secret and 7 or 9,
	}):Play()

	task.delay(0.1, function()
		TweenService:Create(light, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Brightness = 0,
		}):Play()
	end)

	for index = 1, 3 do
		local shell = make("Part", {
			Name = "shell",
			Shape = Enum.PartType.Ball,
			Material = Enum.Material.Neon,
			Color = index == 3 and accent or colour,
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Size = Vector3.new(0.8, 0.8, 0.8),
			Transparency = 0.2,
			CFrame = CFrame.new(position),
		}, holder)

		task.delay((index - 1) * 0.07, function()
			TweenService:Create(shell, TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
				Size = Vector3.new(7 + index * 3, 7 + index * 3, 7 + index * 3),
				Transparency = 1,
			}):Play()
		end)
	end

	local emitter = make("ParticleEmitter", {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(colour),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.6),
			NumberSequenceKeypoint.new(0.35, 0.42),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.7, 0.25),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(0.55, 1.1),
		Speed = NumberRange.new(9, 18),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -22, 0),
		Drag = 1.6,
		Rate = 0,
		LightEmission = 1,
		LightInfluence = 0,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-180, 180),
	}, holder)

	emitter:Emit(secret and 110 or 85)

	task.delay(2, function()
		holder:Destroy()
	end)
end

local function pickupRing(position, rarity, value)
	local colour = PICKUP_COLOURS[rarity] or PICKUP_COLOURS.legendary
	local accent = PICKUP_ACCENT[rarity] or PICKUP_ACCENT.legendary
	local secret = rarity == "secret"

	local anchor = make("Part", {
		Name = "prism_pickup_anchor",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Transparency = 1,
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = CFrame.new(position),
	}, workspace)

	local billboard = make("BillboardGui", {
		Name = "prism_pickup_ring",
		Adornee = anchor,
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 500,
		Size = UDim2.fromOffset(240, 240),
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, anchor)

	local core = make("Frame", {
		Name = "flash",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(64, 64),
		BackgroundColor3 = accent,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, billboard)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, core)

	TweenService:Create(core, TweenInfo.new(0.34, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(190, 190),
		BackgroundTransparency = 1,
	}):Play()

	for index = 1, 3 do
		local wave = auraRing(billboard, "wave", 0.2, index == 2 and accent or colour, index == 3 and 1.5 or 3, 0.15, 2 + index)
		wave.Position = UDim2.fromScale(0.5, 0.5)
		wave.AnchorPoint = Vector2.new(0.5, 0.5)
		wave.ZIndex = 2

		task.delay((index - 1) * 0.09, function()
			TweenService:Create(wave, TweenInfo.new(0.72, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
				Size = UDim2.fromScale(1, 1),
			}):Play()

			local line = wave:FindFirstChildOfClass("UIStroke")
			if line then
				TweenService:Create(line, TweenInfo.new(0.72, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Transparency = 1,
					Thickness = 0.5,
				}):Play()
			end
		end)
	end

	local shaft = make("Frame", {
		Name = "shaft",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(3, 0),
		BackgroundColor3 = accent,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, billboard)

	TweenService:Create(shaft, TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(3, 120),
		BackgroundTransparency = 0.7,
	}):Play()

	task.delay(0.45, function()
		TweenService:Create(shaft, TweenInfo.new(0.35), {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(3, 150),
		}):Play()
	end)

	local labelHolder = make("TextLabel", {
		Name = "popup",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.46),
		Size = UDim2.fromOffset(240, 34),
		BackgroundTransparency = 1,
		Text = "+$" .. shortNumber(value or 0),
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 26,
		Font = Enum.Font.GothamBold,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.35,
		TextTransparency = 1,
		ZIndex = 4,
	}, billboard)
	make("UIGradient", { Color = secret and SECRET_BAND or LEGENDARY_BAND, Rotation = 0 }, labelHolder)

	local sparks = {}
	for index = 1, 10 do
		local dot = make("Frame", {
			Name = "spark",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(4 + index % 3, 4 + index % 3),
			BackgroundColor3 = index % 3 == 0 and accent or colour,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 3,
		}, billboard)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, dot)
		sparks[index] = { frame = dot, angle = (index - 1) / 10 * 6.283 + 0.3, distance = 46 + (index % 4) * 14 }
	end

	task.delay(0.05, function()
		TweenService:Create(labelHolder, TweenInfo.new(0.18), { TextTransparency = 0 }):Play()
		TweenService:Create(labelHolder, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(0.5, 0.24),
			TextTransparency = 1,
		}):Play()

		for _, spark in ipairs(sparks) do
			spark.frame.BackgroundTransparency = 0.1
			TweenService:Create(spark.frame, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
				Position = UDim2.fromScale(0.5 + math.cos(spark.angle) * spark.distance / 240, 0.5 + math.sin(spark.angle) * spark.distance / 240),
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(2, 2),
			}):Play()
		end
	end)

	task.delay(1.1, function()
		anchor:Destroy()
	end)
end

local function pickupToast(nameText, valueText, rarity, rawValue)
	local colour = PICKUP_COLOURS[rarity] or PICKUP_COLOURS.legendary
	local secret = rarity == "secret"

	local holder = make("Frame", {
		Name = "pickup_toast",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.63),
		Size = UDim2.fromOffset(360, 96),
		BackgroundTransparency = 1,
		ZIndex = 8,
	}, toastLayer)

	local beam = make("Frame", {
		Name = "beam",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 0, 0, 2),
		BackgroundColor3 = colour,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, holder)
	make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, beam)

	for index = 1, 2 do
		local shock = make("Frame", {
			Name = "shock",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(30, 30),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 0,
		}, holder)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, shock)

		local line = make("UIStroke", {
			Color = index == 2 and Color3.new(1, 1, 1) or colour,
			Thickness = 2,
			Transparency = 0.12,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}, shock)

		task.delay((index - 1) * 0.12, function()
			TweenService:Create(shock, TweenInfo.new(0.72, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
				Size = UDim2.fromOffset(430, 210),
			}):Play()
			TweenService:Create(line, TweenInfo.new(0.72, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Transparency = 1,
				Thickness = 0.5,
			}):Play()
		end)
	end

	local canvas = make("Frame", {
		Name = "canvas",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 2,
	}, holder)

	local tag = label(canvas, string.upper(rarity), UDim2.new(1, 0, 0, 16), 12)
	tag.Position = UDim2.fromOffset(0, 8)
	tag.TextXAlignment = Enum.TextXAlignment.Center
	tag.Font = Enum.Font.GothamBold
	tag.TextColor3 = colour
	tag.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	tag.TextStrokeTransparency = 0.55
	tag.TextTransparency = 1

	local title = label(canvas, nameText, UDim2.new(1, 0, 0, 32), 26)
	title.Position = UDim2.fromOffset(0, 26)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	title.TextStrokeTransparency = 0.4
	title.TextTransparency = 1

	local gradient = make("UIGradient", {
		Color = secret and SECRET_BAND or LEGENDARY_BAND,
		Rotation = 0,
		Offset = Vector2.new(-1, 0),
	}, title)

	local value = label(canvas, valueText, UDim2.new(1, 0, 0, 20), 16)
	value.Position = UDim2.fromOffset(0, 60)
	value.TextXAlignment = Enum.TextXAlignment.Center
	value.Font = Enum.Font.GothamMedium
	value.TextColor3 = colour
	value.TextTransparency = 1

	local pieces = { tag, title, value }

	if type(rawValue) == "number" and rawValue > 0 then
		local counter = make("NumberValue", { Value = 0 }, holder)
		TweenService:Create(counter, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Value = rawValue,
		}):Play()

		local link = counter.Changed:Connect(function(current)
			value.Text = "$" .. shortNumber(current)
		end)

		task.delay(0.65, function()
			link:Disconnect()
			counter:Destroy()
			value.Text = valueText
		end)
	end

	for _, piece in ipairs(pieces) do
		TweenService:Create(piece, TweenInfo.new(0.14), { TextTransparency = 0 }):Play()
	end

	TweenService:Create(holder, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(440, 96),
	}):Play()
	TweenService:Create(holder, TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0.5, 0.585),
	}):Play()
	TweenService:Create(beam, TweenInfo.new(0.34, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundTransparency = 0.55,
	}):Play()
	TweenService:Create(gradient, TweenInfo.new(1.1, Enum.EasingStyle.Linear), {
		Offset = Vector2.new(1, 0),
	}):Play()

	task.delay(1.15, function()
		for _, piece in ipairs(pieces) do
			TweenService:Create(piece, TweenInfo.new(0.55), { TextTransparency = 1 }):Play()
		end
		TweenService:Create(beam, TweenInfo.new(0.55), { BackgroundTransparency = 1 }):Play()
	end)

	task.delay(1.85, function()
		holder:Destroy()
	end)
end

local function pickupFlash(rarity)
	local colour = PICKUP_COLOURS[rarity] or PICKUP_COLOURS.legendary
	local accent = PICKUP_ACCENT[rarity] or PICKUP_ACCENT.legendary
	local secret = rarity == "secret"

	local flash = make("Frame", {
		Name = "pickup_flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, flashLayer)

	local tint = make("Frame", {
		Name = "tint",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = colour,
		BackgroundTransparency = secret and 0.86 or 0.9,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, flash)

	local bloom = make("Frame", {
		Name = "bloom",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(60, 60),
		BackgroundColor3 = accent,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, flash)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, bloom)

	TweenService:Create(tint, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()

	TweenService:Create(bloom, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(760, 760),
		BackgroundTransparency = 1,
	}):Play()

	task.delay(0.6, function()
		flash:Destroy()
	end)
end

local function playPickup(record)
	pickupBurst(record.position, record.rarity)
	pickupRing(record.position, record.rarity, record.value)
	pickupToast(record.name, "$" .. shortNumber(record.value), record.rarity, record.value)
	pickupFlash(record.rarity)
end

local function pickupOrigin()
	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera

	if root and (root.Position - camera.CFrame.Position).Magnitude <= 40 then
		return root.Position
	end

	return camera.CFrame.Position
end

local function pickupCandidate()
	local origin = pickupOrigin()
	local now = os.clock()
	local best, bestDistance = nil, 22

	for _, record in ipairs(recentLoot) do
		local distance = (record.position - origin).Magnitude
		if now - record.at <= 2.5 and distance < bestDistance then
			best, bestDistance = record, distance
		end
	end

	if best then
		return best
	end

	local limit = 12
	for part, entry in pairs(lootEntries) do
		if entry.tracerRarity and part.Parent then
			local distance = (part.Position - origin).Magnitude
			if distance < limit then
				best = {
					position = part.Position,
					rarity = entry.tracerRarity,
					name = lootName(part),
					value = lootValue(part),
				}
				limit = distance
			end
		end
	end

	return best
end

local lastCarryWeight = LocalPlayer:GetAttribute("CarryWeight") or 0

connect(LocalPlayer:GetAttributeChangedSignal("CarryWeight"), function()
	local weight = LocalPlayer:GetAttribute("CarryWeight")
	if type(weight) ~= "number" then
		return
	end

	local previous = lastCarryWeight
	lastCarryWeight = weight

	if weight <= previous + 1e-4 then
		return
	end

	local record = pickupCandidate()
	if record then
		playPickup(record)
	end
end)

local function refreshLoot(origin)
	local now = os.clock()

	for part, entry in pairs(lootEntries) do
		local colour = lootColour(part)
		local value = lootValue(part)
		local distance = (part.Position - origin).Magnitude
		local faded = (part.LocalTransparencyModifier or 0) > 0.5
		local inRange = config.loot.range <= 0 or distance <= config.loot.range
		local visible = config.loot.enabled and not faded and inRange and value >= config.loot.minValue

		if visible and now - entry.offsetAt > 0.4 then
			entry.offsetAt = now
			local offset = labelOffset(part)
			if (entry.billboard.StudsOffsetWorldSpace - offset).Magnitude > 0.05 then
				entry.billboard.StudsOffsetWorldSpace = offset
			end
		end

		entry.highlight.Enabled = visible and config.loot.highlight
		if entry.secret then
			entry.highlight.FillColor = SECRET_FILL
			entry.highlight.OutlineColor = SECRET_EDGE
		else
			entry.highlight.FillColor = colour
			entry.highlight.OutlineColor = colour
		end
		entry.highlight.FillTransparency = config.loot.fill
		if not entry.glow then
			entry.highlight.OutlineTransparency = 0
		end
		entry.visible = visible
		if entry.aura then
			entry.aura.Enabled = visible
			entry.motes.Enabled = visible
		end

		local showLabel = visible and config.loot.labels and (config.loot.showName or config.loot.showValue)
		entry.billboard.Enabled = showLabel
		if not showLabel then
			continue
		end

		local nameText
		if config.loot.showName then
			nameText = lootName(part)
			if config.loot.showDistance then
				nameText = string.format("%s  ·  %dm", nameText, math.floor(distance + 0.5))
			end
		elseif config.loot.showDistance then
			nameText = string.format("%dm", math.floor(distance + 0.5))
		else
			nameText = ""
		end

		local valueText = config.loot.showValue and ("$" .. shortNumber(value)) or ""

		if entry.name.Text ~= nameText then
			entry.name.Text = nameText
		end
		if entry.value.Text ~= valueText then
			entry.value.Text = valueText
		end
		local textColour = entry.band and Color3.new(1, 1, 1) or (entry.secret and SECRET_EDGE or colour)
		if entry.name.TextColor3 ~= textColour then
			entry.name.TextColor3 = textColour
			entry.value.TextColor3 = textColour
		end

		entry.value.Position = nameText == "" and UDim2.fromOffset(0, 14) or UDim2.fromOffset(0, 22)
	end
end

local ORBIT_SPEED = 1.6
local AURA_SCALE = 2700
local AURA_MIN_SIZE = 95
local AURA_MAX_SIZE = 360
local TICK_STEP = 360 / 8

local function updateAura(entry, part, camera, clock)
	if not entry.glow then
		return
	end

	local centre = part.Position
	local visible = entry.visible == true and part.Parent ~= nil
	local pulse = 0.5 + 0.5 * math.sin(clock * 3.2)
	local breathing = 0.5 + 0.5 * math.sin(clock * 2.4)

	if entry.highlight.Enabled then
		entry.highlight.OutlineTransparency = entry.secret and (0.32 - 0.32 * pulse) or (0.45 - 0.45 * pulse)
	end

	if entry.light then
		entry.light.Enabled = visible
		if visible then
			entry.light.Brightness = 1.2 + 1.6 * pulse
		end
	end

	local overlay = entry.auraGui
	if not overlay then
		return
	end

	overlay.Enabled = visible
	if not visible then
		return
	end

	local distance = (centre - camera.CFrame.Position).Magnitude
	local side = math.clamp(AURA_SCALE / math.max(distance, 1), AURA_MIN_SIZE, AURA_MAX_SIZE)
	if math.abs((entry.auraSide or 0) - side) > 2 then
		entry.auraSide = side
		overlay.Size = UDim2.fromOffset(side, side)
	end

	entry.auraGlow.BackgroundTransparency = 0.9 + 0.04 * breathing
	entry.auraGlowInner.BackgroundTransparency = 0.82 + 0.08 * (1 - breathing)
	entry.auraRing.Transparency = 0.1 + 0.35 * breathing
	entry.auraInner.Transparency = 0.38 + 0.3 * (1 - breathing)
	entry.auraBand.Transparency = 0.8 + 0.15 * breathing

	local progress = (clock * 0.75) % 1
	local spread = 0.35 + 0.72 * progress
	entry.auraPulse.Size = UDim2.fromScale(spread, spread)
	entry.auraPulseStroke.Transparency = 0.05 + 0.95 * progress

	local altProgress = (progress + 0.5) % 1
	local altSpread = 0.35 + 0.72 * altProgress
	entry.auraPulse2.Size = UDim2.fromScale(altSpread, altSpread)
	entry.auraPulseStroke2.Transparency = 0.05 + 0.95 * altProgress

	local cx, cy = side * 0.5, side * 0.5
	local spin = (clock * 16) % 360
	local tickRadius = side * 0.53

	for index, tick in ipairs(entry.auraTicks) do
		local angle = math.rad(spin + (index - 1) * TICK_STEP)
		tick.Position = UDim2.fromOffset(cx + math.sin(angle) * tickRadius, cy - math.cos(angle) * tickRadius)
		tick.Rotation = spin + (index - 1) * TICK_STEP
	end

	for _, spark in ipairs(entry.auraSparks) do
		local cycle = (clock * spark.speed + spark.phase) % 1
		local sway = math.sin(cycle * 6.283 + spark.phase * 21) * spark.drift
		spark.frame.Position = UDim2.fromScale(0.5 + sway, 0.62 - 0.8 * cycle)

		local fade = cycle < 0.12 and (0.12 - cycle) / 0.12 or math.max(0, (cycle - 0.45) / 0.55)
		spark.frame.BackgroundTransparency = math.clamp(fade, 0, 1)

		local flicker = 0.7 + 0.3 * math.sin(clock * 9 + spark.phase * 30)
		spark.frame.Size = UDim2.fromOffset(spark.size * flicker, spark.size * flicker)
	end

	local originPoint = camera:WorldToViewportPoint(centre)
	local orbRadius = math.clamp(part.Size.Magnitude * 0.34, 1.1, 2.6)
	local dotPx = math.clamp(side * 0.045, 4, 12)

	for _, orb in ipairs(entry.auraOrbs) do
		local phase = clock * ORBIT_SPEED + orb.offset
		local lift = 0.45 + 0.55 * math.sin(clock * 2 + orb.offset * 1.7)
		local world = centre + Vector3.new(math.cos(phase) * orbRadius, lift, math.sin(phase) * orbRadius)
		local point = camera:WorldToViewportPoint(world)

		if point.Z > 0 then
			local dx = point.X - originPoint.X
			local dy = point.Y - originPoint.Y
			orb.halo.Position = UDim2.fromOffset(cx + dx, cy + dy)
			orb.core.Position = UDim2.fromOffset(cx + dx, cy + dy)
			orb.halo.Size = UDim2.fromOffset(dotPx * 2.4, dotPx * 2.4)
			orb.core.Size = UDim2.fromOffset(dotPx, dotPx)
			orb.halo.BackgroundTransparency = 0.45 + 0.2 * math.sin(clock * 6 + orb.offset)
			orb.core.BackgroundTransparency = 0
		else
			orb.halo.BackgroundTransparency = 1
			orb.core.BackgroundTransparency = 1
		end
	end
end

local function renderTracers()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local viewport = camera.ViewportSize
	local width, height = viewport.X, viewport.Y
	if width < 1 or height < 1 then
		return
	end

	local originX, originY = width * 0.5, height * 0.5
	local margin = 26
	local now = os.clock()
	local enabled = config.loot.enabled and config.loot.tracers

	for part, entry in pairs(lootEntries) do
		animateBand(entry, now)

		if entry.glow then
			updateAura(entry, part, camera, now)
		end

		local frame = entry.tracer
		if frame then
			local target

			if enabled and entry.tracerRarity and entry.billboard.Enabled and part.Parent then
				local point, onScreen = camera:WorldToViewportPoint(part.Position)

				if point.Z > 0 and onScreen then
					target = Vector2.new(point.X, point.Y)
				else
					local dirX, dirY

					if point.Z > 0 then
						dirX, dirY = point.X - originX, point.Y - originY
					else
						local localPos = camera.CFrame:PointToObjectSpace(part.Position)
						dirX, dirY = localPos.X, -localPos.Y
					end

					local length = math.sqrt(dirX * dirX + dirY * dirY)
					if length < 1e-3 then
						dirX, dirY = 0, 1
					else
						dirX, dirY = dirX / length, dirY / length
					end

					local edge = math.huge
					if dirX > 1e-3 then
						edge = math.min(edge, (width - margin - originX) / dirX)
					elseif dirX < -1e-3 then
						edge = math.min(edge, (margin - originX) / dirX)
					end
					if dirY > 1e-3 then
						edge = math.min(edge, (height - margin - originY) / dirY)
					elseif dirY < -1e-3 then
						edge = math.min(edge, (margin - originY) / dirY)
					end
					if edge == math.huge or edge < 0 then
						edge = 0
					end

					target = Vector2.new(originX + dirX * edge, originY + dirY * edge)
				end
			end

			if not target then
				entry.tracerSeenAt = nil
				if frame.Visible then
					frame.Visible = false
				end
				continue
			end

			if not entry.tracerSeenAt then
				entry.tracerSeenAt = now
			end

			local age = now - entry.tracerSeenAt
			local pulse = age < 5 and (1 - age / 5) or 0
			local dx, dy = target.X - originX, target.Y - originY

			frame.AnchorPoint = Vector2.new(0.5, 0.5)
			frame.Position = UDim2.fromOffset((originX + target.X) * 0.5, (originY + target.Y) * 0.5)
			frame.Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy), 2 + 3 * pulse)
			frame.Rotation = math.deg(math.atan2(dy, dx))
			frame.BackgroundColor3 = entry.tracerColour
			frame.BackgroundTransparency = entry.secret and 0 or (0.3 - 0.3 * pulse)
			frame.Visible = true
		end
	end
end

local promptSet = setmetatable({}, { __mode = "k" })
local promptOriginals = {}
local staminaOriginal = LocalPlayer:GetAttribute("AdminInfStamina")

local function trackPrompt(prompt)
	if promptSet[prompt] then
		return
	end
	promptSet[prompt] = true
	if config.world.instant then
		promptOriginals[prompt] = prompt.HoldDuration
	end
end

for _, descendant in ipairs(workspace:GetDescendants()) do
	if descendant:IsA("ProximityPrompt") then
		trackPrompt(descendant)
	end
end

connect(workspace.DescendantAdded, function(descendant)
	if descendant:IsA("ProximityPrompt") then
		trackPrompt(descendant)
	end
end)

local function setStamina(state)
	config.world.stamina = state
	LocalPlayer:SetAttribute("AdminInfStamina", state and true or nil)
end

local function setInstant(state)
	config.world.instant = state
	if state then
		for prompt in pairs(promptSet) do
			if prompt.Parent then
				promptOriginals[prompt] = prompt.HoldDuration
			end
		end
	else
		for prompt, original in pairs(promptOriginals) do
			if prompt.Parent then
				prompt.HoldDuration = original
			end
		end
		table.clear(promptOriginals)
	end
end

local function enforceInstant()
	if not config.world.instant then
		return
	end
	for prompt in pairs(promptSet) do
		if not prompt.Parent then
			promptSet[prompt] = nil
			promptOriginals[prompt] = nil
		elseif prompt.HoldDuration ~= 0 then
			prompt.HoldDuration = 0
		end
	end
end

local weightHook
local weightNamecallOriginal

local function installWeightHook()
	if weightHook or not (getrawmetatable and newcclosure and setreadonly and debug) then
		return
	end

	local meta = getrawmetatable(game)
	weightNamecallOriginal = meta.__namecall

	setreadonly(meta, false)
	weightHook = newcclosure(function(self, ...)
		if getnamecallmethod() == "GetAttribute" then
			local attribute = select(1, ...)
			if attribute == "CarryWeight" and self == LocalPlayer then
				local source = debug.info(2, "s")
				if source and string.find(source, "Pickup", 1, true) then
					return 0
				end
			end
		end
		return weightNamecallOriginal(self, ...)
	end)
	meta.__namecall = weightHook
	setreadonly(meta, true)
end

local function removeWeightHook()
	if not weightHook then
		return
	end

	local meta = getrawmetatable(game)
	setreadonly(meta, false)
	if meta.__namecall == weightHook then
		meta.__namecall = weightNamecallOriginal
	end
	setreadonly(meta, true)
	weightHook = nil
	weightNamecallOriginal = nil
end

local function setAntiWeight(state)
	config.world.weight = state
	if state then
		installWeightHook()
	else
		removeWeightHook()
	end
end

-- darkness / fog suppression -------------------------------------------------
-- the game dims Lighting or drops post effects on certain events and monster
-- abilities, so the whole thing is neutralised while the toggle is up and the
-- exact pre-toggle values are written back when it goes down.

local visionState = {
	lighting = game:GetService("Lighting"),
	original = {},
	effects = setmetatable({}, { __mode = "k" }),
}

local VISION_BRIGHTNESS = 1.8
local VISION_AMBIENT = 0.62
local VISION_FOG_END = 100000

local function brighten(colour, floor)
	return Color3.new(math.max(colour.R, floor), math.max(colour.G, floor), math.max(colour.B, floor))
end

local function visionFields(effect)
	if effect:IsA("Atmosphere") then
		return { "Density", "Haze", "Glare", "Offset", "Color", "Decay" }
	elseif effect:IsA("BlurEffect") then
		return { "Size", "Enabled" }
	elseif effect:IsA("DepthOfFieldEffect") then
		return { "FarIntensity", "FocusDistance", "InFocusRadius", "NearIntensity", "Enabled" }
	elseif effect:IsA("ColorCorrectionEffect") then
		return { "Brightness", "Contrast", "Saturation", "TintColor", "Enabled" }
	elseif effect:IsA("SunRaysEffect") then
		return { "Intensity", "Spread", "Enabled" }
	end
	return nil
end

local function snapshotEffect(effect)
	local fields = visionFields(effect)
	if not fields then
		return nil
	end
	local values = {}
	for _, field in ipairs(fields) do
		local ok, value = pcall(function()
			return effect[field]
		end)
		if ok and value ~= nil then
			values[field] = value
		end
	end
	return values
end

local function neutraliseEffect(effect)
	if effect:IsA("Atmosphere") then
		effect.Density = 0
		effect.Haze = 0
		effect.Glare = 0
		effect.Offset = 0
		effect.Color = Color3.fromRGB(255, 255, 255)
	elseif effect:IsA("BlurEffect") then
		if effect.Size > 0 then
			effect.Size = 0
		end
	elseif effect:IsA("DepthOfFieldEffect") then
		effect.FarIntensity = 0
		effect.NearIntensity = 0
		effect.FocusDistance = 0
		effect.InFocusRadius = 100000
	elseif effect:IsA("ColorCorrectionEffect") then
		if effect.Brightness < 0 then
			effect.Brightness = 0
		end
		if effect.Contrast > 0.1 then
			effect.Contrast = 0.1
		end
		local tint = effect.TintColor
		if tint.R + tint.G + tint.B < 2.1 then
			effect.TintColor = Color3.fromRGB(255, 255, 255)
		end
	elseif effect:IsA("SunRaysEffect") then
		if effect.Intensity > 0 then
			effect.Intensity = 0
		end
	end
end

local function visionContainers()
	return { visionState.lighting, workspace.CurrentCamera }
end

local function enforceVision()
	if not config.world.vision then
		return
	end

	local lighting = visionState.lighting
	local original = visionState.original

	if not original.captured then
		original.captured = true
		original.brightness = lighting.Brightness
		original.ambient = lighting.Ambient
		original.outdoorAmbient = lighting.OutdoorAmbient
		original.exposure = lighting.ExposureCompensation
		original.fogStart = lighting.FogStart
		original.fogEnd = lighting.FogEnd
	end

	if lighting.Brightness < VISION_BRIGHTNESS then
		lighting.Brightness = VISION_BRIGHTNESS
	end
	lighting.Ambient = brighten(lighting.Ambient, VISION_AMBIENT)
	lighting.OutdoorAmbient = brighten(lighting.OutdoorAmbient, VISION_AMBIENT)
	if lighting.ExposureCompensation < 0.15 then
		lighting.ExposureCompensation = 0.15
	end
	lighting.FogStart = 0
	lighting.FogEnd = VISION_FOG_END

	for _, container in ipairs(visionContainers()) do
		if container then
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("PostEffect") or child:IsA("Atmosphere") then
					if not visionState.effects[child] then
						visionState.effects[child] = snapshotEffect(child)
					end
					neutraliseEffect(child)
				end
			end
		end
	end
end

local function setVision(state)
	config.world.vision = state

	if state then
		enforceVision()
		return
	end

	local lighting = visionState.lighting
	local original = visionState.original

	if original.captured then
		lighting.Brightness = original.brightness
		lighting.Ambient = original.ambient
		lighting.OutdoorAmbient = original.outdoorAmbient
		lighting.ExposureCompensation = original.exposure
		lighting.FogStart = original.fogStart
		lighting.FogEnd = original.fogEnd
		original.captured = false
	end

	for effect, values in pairs(visionState.effects) do
		if effect.Parent and values then
			for field, value in pairs(values) do
				pcall(function()
					effect[field] = value
				end)
			end
		end
		visionState.effects[effect] = nil
	end
end

local Remotes = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage:WaitForChild("Remotes", 5)
local EntityGrab = Remotes and Remotes:FindFirstChild("EntityGrab")

local KILL_RANGE = 4.2
local KILL_CONE = 0.2
local KILL_COOLDOWN = 0.45
local lastKillAt = 0

local function killTarget()
	local camera = workspace.CurrentCamera
	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")

	if not (root and root:IsA("BasePart")) then
		return nil
	end

	local look = camera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	local forward = flat.Magnitude > 0.001 and flat.Unit or Vector3.new(0, 0, -1)
	local reach = KILL_RANGE + 0.25

	pcall(function()
		reach += math.min(LocalPlayer:GetNetworkPing() * 5, 1.33)
	end)

	local candidates = {}

	for _, player in ipairs(Players:GetPlayers()) do
		if
			player ~= LocalPlayer
			and player:GetAttribute("InMatch") == true
			and player:GetAttribute("BeingKilled") ~= true
		then
			local model = player.Character
			local humanoid = model and model:FindFirstChildOfClass("Humanoid")
			local torso = model and model:FindFirstChild("HumanoidRootPart")

			if
				humanoid
				and humanoid.Health > 0
				and torso
				and torso:IsA("BasePart")
				and model:GetAttribute("BeingKilled") ~= true
			then
				local delta = torso.Position - root.Position
				local planar = Vector3.new(delta.X, 0, delta.Z)
				local distance = planar.Magnitude
				local dot = distance > 0.05 and planar.Unit:Dot(forward) or 1

				if math.abs(delta.Y) < 7 and distance <= reach and dot > KILL_CONE then
					table.insert(candidates, { model = model, dot = dot, distance = distance })
				end
			end
		end
	end

	if #candidates == 0 then
		return nil
	end

	table.sort(candidates, function(a, b)
		if math.abs(a.dot - b.dot) > 0.02 then
			return a.dot > b.dot
		end
		return a.distance < b.distance
	end)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local eye = camera.CFrame.Position

	for _, candidate in ipairs(candidates) do
		params.FilterDescendantsInstances = { character, candidate.model }

		for _, name in ipairs({ "HumanoidRootPart", "Head" }) do
			local part = candidate.model:FindFirstChild(name)

			if part and part:IsA("BasePart") then
				if not workspace:Raycast(eye, part.Position - eye, params) then
					return candidate.model
				end
			end
		end
	end

	return candidates[1].model
end

local function autoKill()
	if not config.world.autokill or not EntityGrab then
		return
	end

	if LocalPlayer:GetAttribute("EntityStage") ~= "hunt" then
		return
	end

	local now = os.clock()
	if now - lastKillAt < KILL_COOLDOWN then
		return
	end

	local gui = LocalPlayer:FindFirstChild("PlayerGui")
	local hint = gui and gui:FindFirstChild("EntityKillHint")
	if not (hint and hint.Enabled) then
		return
	end

	local target = killTarget()
	local camera = workspace.CurrentCamera
	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")

	if not (target and root and root:IsA("BasePart")) then
		return
	end

	lastKillAt = now
	pcall(function()
		EntityGrab:FireServer(camera.CFrame.LookVector, camera.CFrame.Position, root.Position, target)
	end)
end

local syncAutoKill

local function setAutoKill(state)
	config.world.autokill = state
	if syncAutoKill then
		syncAutoKill(state, false)
	end
end

connect(RunService.Heartbeat, function()
	if config.world.autokill then
		autoKill()
	end
end)

local PathfindingService = game:GetService("PathfindingService")
local PickupLoot = Remotes and Remotes:FindFirstChild("PickupLoot")
local Round = ReplicatedStorage:FindFirstChild("Round")

local FARM_FLEE_DISTANCE = 50
local FARM_PICKUP_DISTANCE = 7
local FARM_EXIT_DISTANCE = 8
local FARM_EXIT_MARGIN = 45

local farm = {
	target = nil,
	goal = nil,
	path = nil,
	index = 1,
	repathAt = 0,
	lastPos = nil,
	lastCheck = 0,
	stuck = 0,
	fleeUntil = 0,
	fleeGoal = nil,
	fleeAt = 0,
	pickupAt = 0,
	promptAt = 0,
	blacklist = {},
	failures = {},
}

local function farmCharacter()
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")

	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return humanoid, root
	end

	return nil, nil
end

local FARM_VIEW_RANGE = 95
local FARM_VIEW_COS = math.cos(math.rad(58))

local farmEntityModel

local function farmEntityPose()
	for _, model in ipairs(workspace:GetChildren()) do
		if model:IsA("Model") and model:GetAttribute("EntityKind") then
			local part = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart

			if part and part:IsA("BasePart") then
				farmEntityModel = model

				return part.Position, part.CFrame.LookVector
			end
		end
	end

	farmEntityModel = nil

	return nil, nil
end

local FARM_RAY = RaycastParams.new()
FARM_RAY.FilterType = Enum.RaycastFilterType.Exclude
FARM_RAY.RespectCanCollide = true

local function farmRay(exclude)
	FARM_RAY.FilterDescendantsInstances = exclude
	return FARM_RAY
end

local function farmSight(entityPos, entityLook, point)
	local delta = point - entityPos
	local distance = delta.Magnitude

	if distance > FARM_VIEW_RANGE then
		return false
	end

	if distance > 0.5 and entityLook and delta.Unit:Dot(entityLook) < FARM_VIEW_COS then
		return false
	end

	local hit = workspace:Raycast(entityPos + Vector3.new(0, 1.6, 0), delta, farmRay({ LocalPlayer.Character, farmEntityModel }))

	return hit == nil
end

local function farmTurn(flat, angle)
	local cos, sin = math.cos(angle), math.sin(angle)

	return Vector3.new(flat.X * cos + flat.Z * sin, 0, -flat.X * sin + flat.Z * cos)
end

-- a flee point has to actually buy distance: the old random ring sample kept
-- handing back spots that were 45 studs from the entity while we stood at 80,
-- so the run turned around and walked back into it
local function farmFleePoint(root, entityPos, entityLook, away)
	local best, bestScore
	local origin = Vector3.new(root.Position.X, 0, root.Position.Z)

	for _, radius in ipairs({ 55, 85 }) do
		for _, angle in ipairs({ 0, 0.5, -0.5, 1.0, -1.0, 1.6, -1.6 }) do
			local dir = farmTurn(away, angle)
			local flat = origin + dir * radius
			local ground = workspace:Raycast(flat + Vector3.new(0, 24, 0), Vector3.new(0, -50, 0), farmRay({ LocalPlayer.Character, farmEntityModel }))

			if ground and ground.Normal.Y >= 0.65 then
				local escape = (ground.Position - entityPos).Magnitude

				if escape > 40 then
					local hidden = not farmSight(entityPos, entityLook, ground.Position)

					-- line of sight is worth a detour, but never a shortcut toward it
					if hidden or escape > 70 then
						local score = escape + (hidden and 30 or 0) + dir:Dot(away) * 26

						if not bestScore or score > bestScore then
							best, bestScore = ground.Position, score
						end
					end
				end
			end
		end
	end

	return best or (origin + away * 58)
end

local function stopFarmMovement()
	local humanoid = farmCharacter()

	if humanoid then
		pcall(function()
			humanoid:Move(Vector3.zero, false)
			local root = humanoid.RootPart

			if root then
				humanoid:MoveTo(root.Position)
			end
		end)
	end
end

local function triggerPrompt(prompt)
	if not prompt then
		return false
	end

	local fire = rawget(env, "fireproximityprompt")

	if type(fire) == "function" then
		return pcall(fire, prompt)
	end

	local ok = pcall(function()
		prompt:InputHoldBegin()
	end)

	if ok then
		task.defer(function()
			pcall(function()
				prompt:InputHoldEnd()
			end)
		end)
	end

	return ok
end

local FARM_WALK_SPEED = 15
local FARM_FLEE_SPEED = 26

local function farmSprintSpeed()
	local weight = tonumber(LocalPlayer:GetAttribute("CarryWeight")) or 0
	local factor = math.clamp(0.86 - 0.034 * weight, 0.5, 0.86)

	return math.clamp(30 * factor, 14, 27)
end

local function farmRootOffset(root)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { LocalPlayer.Character }

	local ground = workspace:Raycast(root.Position, Vector3.new(0, -9, 0), params)

	return math.clamp(ground and (root.Position.Y - ground.Position.Y) or 3.1, 2.6, 3.6)
end

local function farmWalk(humanoid, root, point, dt, speed, maxTurn)
	local delta = Vector3.new(point.X - root.Position.X, 0, point.Z - root.Position.Z)
	local distance = delta.Magnitude

	if distance < 0.08 then
		return true
	end

	local step = math.min(speed * dt, distance, 3)
	local direction = delta.Unit

	if not farm.offset then
		farm.offset = farmRootOffset(root)
	end

	local goalY = point.Y + farm.offset
	if math.abs(goalY - root.Position.Y) > 6 then
		goalY = root.Position.Y
	end

	local function clear(dir)
		local origin = root.Position + Vector3.new(0, 0.6, 0)
		local side = Vector3.new(-dir.Z, 0, dir.X)

		for _, offset in ipairs({ 0, 1.3, -1.3 }) do
			local hit = workspace:Raycast(origin + side * offset, dir * (step + 2.2), farmRay({ root.Parent }))

			if hit and hit.Normal.Y < 0.65 then
				return false
			end
		end

		return true
	end

	local function supported(dir)
		if farm.drop then
			farm.drop = false
			return true
		end

		local origin = root.Position + dir * (step + 1.6) + Vector3.new(0, 1, 0)
		local hit = workspace:Raycast(origin, Vector3.new(0, -14, 0), farmRay({ root.Parent }))

		return hit ~= nil and hit.Normal.Y >= 0.65
	end

	local function turnTo(dir, angle)
		local cos, sin = math.cos(angle), math.sin(angle)

		return Vector3.new(dir.X * cos + dir.Z * sin, 0, -dir.X * sin + dir.Z * cos)
	end

	if not (clear(direction) and supported(direction)) then
		local turn
		local limit = maxTurn or 2.1

		-- sweep outward: 40deg takes a doorway, 120deg recovers from a corner
		for _, angle in ipairs({ 0.7, -0.7, 1.4, -1.4, 2.1, -2.1 }) do
			if math.abs(angle) > limit then
				continue
			end

			local candidate = turnTo(direction, angle)

			if clear(candidate) and supported(candidate) then
				turn = candidate
				break
			end
		end

		if not turn then
			farm.blockCount = (farm.blockCount or 0) + 1

			-- most blockers are waist high clutter, hop it before giving up on the segment
			if farm.blockCount >= 2 then
				pcall(function()
					humanoid.Jump = true
					root.CFrame = CFrame.new(root.Position + Vector3.new(0, 1.4, 0))
				end)
			end

			if farm.blockCount >= 6 then
				farm.blocked = true
			end

			return false
		end

		direction = turn
	end

	local position = Vector3.new(
		root.Position.X + direction.X * step,
		goalY,
		root.Position.Z + direction.Z * step
	)

	farm.blockCount = 0

	root.CFrame = CFrame.lookAt(position, position + direction)
	pcall(function()
		humanoid:Move(direction, false)
	end)

	return distance - step < 0.7
end

local function farmCompute(start, goal)
	for _, parameters in ipairs({
		{ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 6 },
		{ AgentRadius = 1.2, AgentHeight = 4, AgentCanJump = true, WaypointSpacing = 4 },
	}) do
		local path = PathfindingService:CreatePath(parameters)
		local ok = pcall(function()
			path:ComputeAsync(start, goal)
		end)

		if ok and path.Status == Enum.PathStatus.Success and #path:GetWaypoints() >= 2 then
			farm.lastStatus = "Success"
			return path
		end

		farm.lastStatus = tostring(path.Status)
	end

	return nil
end

local function farmGo(humanoid, root, goal, now, dt, speed)
	speed = speed or FARM_WALK_SPEED

	if farm.goal ~= goal then
		farm.goal = goal
		farm.path = nil
		farm.index = 1
		farm.repathAt = 0
		farm.pathFails = 0
	end

	if not farm.path or now >= farm.repathAt then
		farm.repathAt = now + 1.6
		farm.path = farmCompute(root.Position, goal)
		farm.index = 2
		farm.pathFails = farm.path and 0 or (farm.pathFails or 0) + 1

		local waypoints = farm.path and farm.path:GetWaypoints()

		-- a fresh path can start behind us when the solve finished late, skip those nodes
		if waypoints then
			local toGoal = Vector3.new(goal.X - root.Position.X, 0, goal.Z - root.Position.Z).Unit

			while farm.index < #waypoints do
				local candidate = waypoints[farm.index].Position
				local toWaypoint = Vector3.new(candidate.X - root.Position.X, 0, candidate.Z - root.Position.Z)

				if toWaypoint.Magnitude > 2.5 or toWaypoint.Unit:Dot(toGoal) > 0.2 then
					break
				end

				farm.index += 1
			end
		end
	end

	local path = farm.path

	if not path then
		return false
	end

	local waypoints = path:GetWaypoints()

	if farm.index > #waypoints then
		farmWalk(humanoid, root, goal, dt, speed)
	else
		local point = waypoints[farm.index]
		local flat = Vector3.new(point.Position.X, 0, point.Position.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)

		if flat.Magnitude < 2 and farm.index < #waypoints then
			farm.index += 1
			point = waypoints[farm.index]
		end

		if point.Action == Enum.PathWaypointAction.Jump and point.Position.Y - root.Position.Y > 1.5 then
			humanoid.Jump = true
			farm.drop = true
		end

		farmWalk(humanoid, root, point.Position, dt, speed)
	end

	if farm.blocked then
		farm.blocked = false
		farm.repathAt = math.min(farm.repathAt, now + 0.4)

		if (farm.blockCount or 0) >= 6 then
			farm.blockCount = 0
			farm.path = nil
			farm.goal = nil

			local spot = farm.target and farm.target:GetAttribute("SpotId")

			if farm.target then
				farm.blacklist[spot or farm.target] = now + 10
			end

			-- nudge forward over the obstruction instead of rewinding to where we came from
			local ahead = Vector3.new(goal.X - root.Position.X, 0, goal.Z - root.Position.Z)

			if ahead.Magnitude < 0.5 then
				ahead = root.CFrame.LookVector
			end

			pcall(function()
				root.CFrame = CFrame.new(root.Position + ahead.Unit * 4 + Vector3.new(0, 2.2, 0))
			end)
		end
	end

	return true
end

local function farmCheckStuck(root, now)
	if now < farm.lastCheck then
		return
	end

	local moved = farm.lastPos and (root.Position - farm.lastPos).Magnitude or 0
	farm.lastPos = root.Position
	farm.lastCheck = now + 1

	if moved < 1.2 then
		farm.stuck += 1
		farm.repathAt = 0

		if farm.stuck == 2 or farm.stuck == 3 then
			local lift = farmRootOffset(root)

			pcall(function()
				root.CFrame = CFrame.new(root.Position + Vector3.new(0, lift + 0.6, 0))

				local humanoid = root.Parent and root.Parent:FindFirstChildOfClass("Humanoid")

				if humanoid then
					humanoid.Jump = true
				end
			end)
		end

		if farm.stuck >= 5 then
			farm.stuck = 0
			local spot = farm.target and farm.target:GetAttribute("SpotId")

			if farm.target then
				farm.blacklist[spot or farm.target] = now + 10
			end

			-- drop the segment and climb out, never rewind toward the last safe point
			farm.path = nil
			farm.goal = nil

			pcall(function()
				root.CFrame = CFrame.new(root.Position + Vector3.new(0, 4, 0))

				local humanoid = root.Parent and root.Parent:FindFirstChildOfClass("Humanoid")

				if humanoid then
					humanoid.Jump = true
				end
			end)
		end
	else
		farm.stuck = 0
		farm.safe = root.Position
	end
end

local FARM_SKIP_NAMES = {
	minifridge = true,
	minirefrigerator = true,
}

local function farmSkipLoot(part)
	local name = part.Name:lower():gsub("[^%a]", "")

	return FARM_SKIP_NAMES[name] == true
end

local function farmCandidate(root, monsterPos, monsterLook)
	local now = os.clock()
	local candidates = {}
	local seen = {}
	local canSee = monsterPos ~= nil

	for _, folderName in ipairs({ "MyLoot", "LootItems" }) do
		local folder = workspace:FindFirstChild(folderName)

		if folder then
			for _, part in ipairs(folder:GetChildren()) do
				local ok = part:IsA("BasePart") and part:GetAttribute("Loot") and not farmSkipLoot(part)

				if ok and (part.LocalTransparencyModifier or 0) < 0.5 then
					local spot = part:GetAttribute("SpotId")
					local blocked = (farm.blacklist[part] or 0) > now
						or (type(spot) == "string" and (farm.blacklist[spot] or 0) > now)
					local firstForSpot = true

					if type(spot) == "string" then
						if seen[spot] then
							firstForSpot = false
						else
							seen[spot] = true
						end
					end

					if not blocked and firstForSpot then
						local prompt = part:FindFirstChildOfClass("ProximityPrompt")

						if not prompt or prompt.Enabled then
							candidates[#candidates + 1] = part
						end
					end
				end
			end
		end
	end

	-- nearest first, so the sight test only has to run on the handful that can win
	local current = farm.target
	local distances = {}

	if #candidates > 1 then
		local order = {}

		for index, part in ipairs(candidates) do
			order[index] = index
			distances[part] = (part.Position - root.Position).Magnitude
		end

		table.sort(order, function(a, b)
			return distances[candidates[a]] < distances[candidates[b]]
		end)

		local sorted = {}

		for index, slot in ipairs(order) do
			sorted[index] = candidates[slot]
		end

		candidates = sorted
	end

	local best, bestDistance

	for index, part in ipairs(candidates) do
		local distance = distances[part] or (part.Position - root.Position).Magnitude

		if monsterPos and (part.Position - monsterPos).Magnitude <= 45 then
			continue
		end

		-- only pay for the raycast when the entity is close enough to actually see it
		if canSee and farmSight(monsterPos, monsterLook, part.Position) then
			continue
		end

		best, bestDistance = part, distance
		break
	end

	if current and current.Parent and not farmSkipLoot(current) then
		local spot = current:GetAttribute("SpotId")
		local prompt = current:FindFirstChildOfClass("ProximityPrompt")
		local distance = (current.Position - root.Position).Magnitude
		local blacklisted = (farm.blacklist[current] or 0) > now or (type(spot) == "string" and (farm.blacklist[spot] or 0) > now)
		local risky = monsterPos
			and (
				(current.Position - monsterPos).Magnitude <= 45
				or farmSight(monsterPos, monsterLook, current.Position)
			)

		if
			not blacklisted
			and (current.LocalTransparencyModifier or 0) < 0.5
			and (not prompt or prompt.Enabled)
			and not risky
		then
			-- commit to the target in hand: only a clearly closer spot (20%) is worth
			-- dropping the path we already solved, otherwise it paces between two spots
			local settled = (now - (farm.targetAt or 0)) < 1.5

			if not best or best == current or settled or not (bestDistance < distance * 0.8) then
				return current, distance
			end
		end
	end

	return best, bestDistance
end

local function farmExit(root)
	local map = workspace:FindFirstChild("ActiveMap")

	if not map then
		farm.doors = nil
		return nil, nil
	end

	if not farm.doors then
		local doors = {}

		for _, part in ipairs(map:GetDescendants()) do
			if part:IsA("BasePart") and part:GetAttribute("ExitPoint") then
				doors[#doors + 1] = part
			end
		end

		farm.doors = doors
	end

	local best, bestDistance

	for _, part in ipairs(farm.doors) do
		if part.Parent then
			local distance = (part.Position - root.Position).Magnitude

			if not bestDistance or distance < bestDistance then
				best, bestDistance = part, distance
			end
		end
	end

	return best, bestDistance
end

local function farmTiming()
	local openAt = Round and tonumber(Round:GetAttribute("ExtractOpensAt")) or 0
	local endsAt = Round and tonumber(Round:GetAttribute("PhaseEnds")) or 0
	local now = os.time()

	return openAt > 0 and now >= openAt, endsAt > 0 and (endsAt - now) or math.huge
end

local function farmPickup(part)
	if farmSkipLoot(part) then
		return nil
	end

	local prompt = part:FindFirstChildOfClass("ProximityPrompt")
	local spot = part:GetAttribute("SpotId")
	local key = spot or part

	triggerPrompt(prompt)

	if PickupLoot and type(spot) == "string" then
		task.delay(0.3, function()
			if part.Parent and (part.LocalTransparencyModifier or 0) < 0.5 then
				pcall(function()
					PickupLoot:FireServer(spot)
				end)
			end
		end)
	end

	task.delay(1.1, function()
		if part.Parent and (part.LocalTransparencyModifier or 0) < 0.5 then
			local failures = (farm.failures[key] or 0) + 1

			-- give up on this spot for longer each time it refuses to come off the shelf
			farm.failures[key] = failures
			farm.blacklist[key] = os.clock() + math.min(6 * failures, 60)
		end
	end)

	return prompt
end

local function farmUseExit(door, now)
	if now < farm.promptAt then
		return
	end

	farm.promptAt = now + 1.5
	triggerPrompt(door:FindFirstChildOfClass("ProximityPrompt"))
end

local function farmSpectating()
	local gui = LocalPlayer:FindFirstChild("PlayerGui")
	local spectate = gui and gui:FindFirstChild("SpectateUI")

	if spectate and spectate.Enabled then
		return true
	end

	return LocalPlayer:GetAttribute("Dead") == true
end

-- catches the "orbiting a table forever" case: movement alone is not progress
local function farmProgress(root, goal, now)
	if farm.progressGoal ~= goal then
		farm.progressGoal = goal
		farm.progressDist = nil
		farm.progressAt = 0
		farm.progressFails = 0
	end

	if now < (farm.progressAt or 0) then
		return "ok"
	end

	local distance = (goal - root.Position).Magnitude

	if farm.progressDist and distance > farm.progressDist - 0.8 then
		farm.progressFails = (farm.progressFails or 0) + 1
	else
		farm.progressFails = 0
	end

	farm.progressDist = distance
	farm.progressAt = now + 1.6

	if (farm.progressFails or 0) >= 4 then
		farm.progressFails = 0
		farm.progressDist = nil
		return "giveup"
	end

	if (farm.progressFails or 0) >= 2 then
		-- second opinion: a fresh solve often finds the doorway the last one missed
		farm.path = nil
		farm.goal = nil
		return "retry"
	end

	return "ok"
end

local function farmRoamPoint(root, now, monsterPos, monsterLook)
	if not farm.roamGoal or now >= farm.roamAt then
		farm.roamGoal = nil
		farm.roamAt = now + 6

		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { LocalPlayer.Character }
		params.RespectCanCollide = true

		local best, bestScore

		for _ = 1, 12 do
			local angle = math.random() * math.pi * 2
			local radius = 30 + math.random() * 70
			local flat = root.Position + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
			local hit = workspace:Raycast(flat + Vector3.new(0, 26, 0), Vector3.new(0, -64, 0), params)

			if hit and hit.Normal.Y >= 0.65 then
				local score = 0

				if monsterPos then
					score = (hit.Position - monsterPos).Magnitude

					if farmSight(monsterPos, monsterLook, hit.Position) then
						score -= 200
					end
				else
					score = 1
				end

				if not bestScore or score > bestScore then
					best, bestScore = hit.Position, score
				end
			end
		end

		farm.roamGoal = best
	end

	return farm.roamGoal
end

local DOOR_WORDS = {
	door = true,
	doors = true,
	gate = true,
	gates = true,
	shutter = true,
	shutters = true,
	barrier = true,
	barriers = true,
	entrance = true,
	entrances = true,
}

local doorStore = {}
local doorNameCache = {}

-- the scan runs this over thousands of parts per tick, so the two gsub passes
-- are cached per name (maps reuse the same handful of part names everywhere)
local function doorName(name)
	local cached = doorNameCache[name]

	if cached ~= nil then
		return cached
	end

	local spaced = name:gsub("(%l)(%u)", "%1 %2"):gsub("[^%w]+", " ")
	local match = false

	for word in spaced:gmatch("%a+") do
		if DOOR_WORDS[word:lower()] then
			match = true
			break
		end
	end

	if #doorNameCache > 4000 then
		table.clear(doorNameCache)
	end

	doorNameCache[name] = match

	return match
end

-- doors are small assemblies; whole wings can also have few direct children,
-- so the footprint is what separates "Hallway Double Door" from "Entrance Hallway"
local function smallAssembly(node)
	if #node:GetChildren() > 20 then
		return false
	end

	if node:IsA("Model") then
		local ok, _, extent = pcall(node.GetBoundingBox, node)

		if ok and extent and (extent.X > 45 or extent.Y > 30 or extent.Z > 45) then
			return false
		end
	end

	return true
end

local function doorAssembly(node)
	return #node:GetChildren() <= 12 and doorName(node.Name) and smallAssembly(node)
end

local function exitLinked(part)
	local node = part

	while node and node ~= workspace do
		if node:GetAttribute("ExitPoint") then
			return true
		end
		node = node.Parent
	end

	return false
end

-- every part that belongs to a door, however deep the model nesting goes
local function doorOwned(part, roots)
	local node = part

	for _ = 1, 6 do
		node = node.Parent

		if not node or node == workspace then
			return false
		end

		if roots[node] then
			return true
		end
	end

	return false
end

local DOOR_SCAN_BATCH = 1500
local DOOR_RESCAN_INTERVAL = 90

local function clearDoors(now)
	local map = workspace:FindFirstChild("ActiveMap")

	if not map then
		return
	end

	if farm.doorMap ~= map then
		farm.doorMap = map
		farm.scan = nil
		farm.doorScanAt = 0
		table.clear(farm.failures)
		table.clear(farm.blacklist)
	end

	if now >= (farm.doorAt or 0) then
		farm.doorAt = now + 1.5

		for part, parent in pairs(doorStore) do
			if part.Parent ~= nil then
				doorStore[part] = nil
			elseif not parent or parent.Parent == nil then
				doorStore[part] = nil
				pcall(function()
					part:Destroy()
				end)
			end
		end
	end

	-- walking the map in one go stalled a frame (GetDescendants on a 77k map is
	-- ~30ms), so the sweep is a breadth-first crawl spread across ticks
	if not farm.scan then
		if (farm.doorScanAt or 0) > now then
			return
		end

		farm.scan = {
			queue = { map },
			head = 1,
			nodes = {},
			index = 1,
			phase = 1,
			roots = {},
			prompts = {},
			remove = {},
		}
	end

	local scan = farm.scan

	if scan.phase == 1 then
		local queue = scan.queue
		local budget = DOOR_SCAN_BATCH

		while scan.head <= #queue and budget > 0 do
			local node = queue[scan.head]
			scan.head += 1
			budget -= 1

			scan.nodes[#scan.nodes + 1] = node

			if node:IsA("ProximityPrompt") then
				if node.ObjectText == "Door" or node.ActionText == "Open" or node.ActionText == "Close" then
					scan.prompts[#scan.prompts + 1] = node
				end
			elseif node:IsA("Model") or node:IsA("Folder") then
				if doorAssembly(node) then
					scan.roots[node] = true
				end
			end

			local children = node:GetChildren()

			for index = 1, #children do
				queue[#queue + 1] = children[index]
			end
		end

		if scan.head > #queue then
			for _, prompt in ipairs(scan.prompts) do
				local anchor = prompt.Parent
				local holder = anchor and anchor.Parent

				if holder and holder ~= map and smallAssembly(holder) then
					scan.roots[holder] = true
				end
			end

			scan.queue = nil
			scan.prompts = nil
			scan.phase = 2
			scan.index = 1
		end

		return
	end

	local nodes = scan.nodes
	local last = math.min(#nodes, scan.index + DOOR_SCAN_BATCH * 2)

	if scan.phase == 3 then
		local budget = 40

		while scan.index <= #scan.remove and budget > 0 do
			local part = scan.remove[scan.index]
			scan.index += 1
			budget -= 1

			local parent = part.Parent

			if parent then
				doorStore[part] = parent
				pcall(function()
					part.Parent = nil
				end)
			end
		end

		if scan.index > #scan.remove then
			local total = 0

			for _ in pairs(doorStore) do
				total += 1
			end

			farm.doorsCleared = total
			farm.scan = nil
			farm.doorScanAt = now + DOOR_RESCAN_INTERVAL
		end

		return
	end

	for index = scan.index, last do
		local part = nodes[index]

		if
			part:IsA("BasePart")
			and part.Name ~= "PromptAnchor"
			and not part:GetAttribute("Loot")
			and not doorStore[part]
			and (doorName(part.Name) or doorOwned(part, scan.roots))
			and not exitLinked(part)
		then
			scan.remove[#scan.remove + 1] = part
		end
	end

	scan.index = last + 1

	if scan.index > #nodes then
		scan.phase = 3
		scan.index = 1
	end

	return
end

local restoreToken = 0

local function restoreDoors()
	restoreToken += 1

	local token = restoreToken
	local pending = {}

	for part, parent in pairs(doorStore) do
		pending[#pending + 1] = part
		pending[#pending + 1] = parent
	end

	table.clear(doorStore)

	if #pending == 0 then
		return
	end

	-- handing back a whole map's doors in one frame froze for ~200ms, so they
	-- come back in batches instead
	task.spawn(function()
		for index = 1, #pending, 300 do
			if token ~= restoreToken then
				return
			end

			for slot = index, math.min(index + 299, #pending), 2 do
				local part = pending[slot]
				local parent = pending[slot + 1]

				if part.Parent == nil and parent and parent.Parent ~= nil then
					pcall(function()
						part.Parent = parent
					end)
				end
			end

			RunService.Heartbeat:Wait()
		end
	end)
end

local function farmStep(now, dt)
	local humanoid, root = farmCharacter()

	clearDoors(now)

	if
		not humanoid
		or farmSpectating()
		or (Round and Round:GetAttribute("Phase") ~= "Match")
		or LocalPlayer:GetAttribute("InMatch") == false
	then
		farm.target = nil
		farm.goal = nil
		farm.path = nil
		farm.doors = nil
		stopFarmMovement()
		return
	end

	local open, remaining = farmTiming()
	local monsterPos, monsterLook = farmEntityPose()
	local monsterDistance = monsterPos and (monsterPos - root.Position).Magnitude or math.huge
	local watched = monsterPos and farmSight(monsterPos, monsterLook, root.Position) or false
	local chasing = false

	if monsterPos and monsterDistance < 85 then
		local body = farmEntityModel and (farmEntityModel.PrimaryPart or farmEntityModel:FindFirstChild("HumanoidRootPart"))

		if body then
			local velocity = body.AssemblyLinearVelocity

			if velocity.Magnitude > 6 then
				local toUs = root.Position - monsterPos

				if toUs.Magnitude > 0.5 and velocity.Unit:Dot(toUs.Unit) > 0.55 then
					chasing = true
				end
			end
		end
	end

	local sprint = farmSprintSpeed()
	local fleeing = now < (farm.fleeUntil or 0)

	if watched or chasing or monsterDistance < FARM_FLEE_DISTANCE or (fleeing and monsterDistance < 72) then
		if not fleeing then
			farm.fleeFails = 0
			farm.fleeDist = nil
			farm.fleeCheckAt = 0
			farm.boltUntil = 0
		end

		farm.fleeUntil = now + ((watched or chasing) and 2 or 1.2)
	elseif not monsterPos then
		farm.fleeUntil = 0
	end

	if now < farm.fleeUntil and monsterPos then
		farm.target = nil
		farm.pickTarget = nil

		local away = Vector3.new(root.Position.X - monsterPos.X, 0, root.Position.Z - monsterPos.Z)

		if away.Magnitude < 0.5 then
			away = Vector3.new(1, 0, 0)
		end

		away = away.Unit

		-- carry weight drops the sprint factor to 0.5, which is slower than the
		-- entity; a loaded player has to run flat out to survive a chase
		local fleeSpeed = math.max(sprint, FARM_FLEE_SPEED)

		-- a valid path that goes nowhere is the real killer: the entity closes
		-- while we lean on a wall, so watch the actual gap and bolt when it shrinks
		if now >= (farm.fleeCheckAt or 0) then
			if farm.fleeDist and monsterDistance <= farm.fleeDist + 1 then
				farm.fleeFails = (farm.fleeFails or 0) + 1
			else
				farm.fleeFails = 0
			end

			farm.fleeDist = monsterDistance
			farm.fleeCheckAt = now + 0.8
		end

		if (farm.fleeFails or 0) >= 2 then
			farm.fleeFails = 0
			farm.boltUntil = now + 1.1
			farm.fleeGoal = nil
			farm.fleeAt = 0
			farm.path = nil
			farm.goal = nil
		end

		-- straight-out burst: no path, no goal, just open ground away from it
		if now < (farm.boltUntil or 0) then
			farm.fleeGoal = nil
			farmWalk(humanoid, root, root.Position + away * 20, dt, fleeSpeed, 1.5)
			farmCheckStuck(root, now)
			return
		end

		local goal = farm.fleeGoal
		local goalGap = goal and (goal - monsterPos).Magnitude or 0
		local goalLeft = goal and (goal - root.Position).Magnitude or 0

		-- commit to one heading: rerolling the point every 0.6s reset the run
		-- before it covered any ground and let the entity walk us down
		if goal and ((goalGap < monsterDistance + 6) or goalLeft < 5 or (now >= (farm.fleeAt or 0) and goalLeft > 10)) then
			goal = nil
		end

		if not goal then
			goal = farmFleePoint(root, monsterPos, monsterLook, away)
			farm.fleeAt = now + 4.5
		end

		farm.fleeGoal = goal

		if monsterDistance < 34 then
			farmWalk(humanoid, root, goal, dt, fleeSpeed, 1.5)
		elseif not farmGo(humanoid, root, goal, now, dt, fleeSpeed) then
			-- pathfind refused, straight line beats standing still
			farmWalk(humanoid, root, goal, dt, fleeSpeed, 1.5)
		else
			-- a route that bends back past the entity gives the chase a free kill,
			-- drop it and run the direct line instead of following it
			local waypoints = farm.path and farm.path:GetWaypoints()

			if waypoints then
				for index = 2, math.min(4, #waypoints) do
					if (waypoints[index].Position - monsterPos).Magnitude < monsterDistance - 6 then
						farm.boltUntil = now + 1
						farm.fleeGoal = nil
						farm.fleeAt = 0
						farm.path = nil
						farm.goal = nil
						break
					end
				end
			end
		end

		farmCheckStuck(root, now)
		return
	end

	farm.fleeGoal = nil
	farm.fleeFails = 0
	farm.fleeDist = nil
	farm.boltUntil = 0

	local target, targetDistance

	if now >= (farm.pickAt or 0) then
		farm.pickAt = now + 0.25
		target, targetDistance = farmCandidate(root, monsterPos, monsterLook)
		farm.pickTarget = target
		farm.pickDistance = targetDistance
	else
		target, targetDistance = farm.pickTarget, farm.pickDistance

		if target and (not target.Parent or farmSkipLoot(target)) then
			target = nil
			farm.pickTarget = nil
		end
	end

	local leaving = open and (not target or remaining <= FARM_EXIT_MARGIN)

	if not target then
		local door, doorDistance = farmExit(root)

		if not door then
			stopFarmMovement()
			return
		end

		if open and doorDistance <= FARM_EXIT_DISTANCE then
			stopFarmMovement()
			farmUseExit(door, now)
		elseif open or remaining <= 60 then
			farmGo(humanoid, root, door.Position, now, dt, sprint)
			farmCheckStuck(root, now)
		else
			local roam = farmRoamPoint(root, now, monsterPos, monsterLook)

			if roam then
				local moving = farmGo(humanoid, root, roam, now, dt, sprint * 0.75)

				if
					(roam - root.Position).Magnitude < 6
					or (not moving and (farm.pathFails or 0) >= 2)
					or farmProgress(root, roam, now) ~= "ok"
				then
					farm.roamGoal = nil
				end

				farmCheckStuck(root, now)
			else
				stopFarmMovement()
				farm.goal = nil
				farm.path = nil
			end
		end

		return
	end

	if leaving then
		local door, doorDistance = farmExit(root)

		if not door then
			stopFarmMovement()
			return
		end

		if doorDistance <= FARM_EXIT_DISTANCE then
			stopFarmMovement()
			farmUseExit(door, now)
		else
			farm.target = nil
			farmGo(humanoid, root, door.Position, now, dt, sprint)
			farmCheckStuck(root, now)
		end

		return
	end

	if farm.target ~= target then
		farm.target = target
		farm.targetAt = now
		farm.goal = nil
		farm.path = nil
		farm.roamGoal = nil
		farm.stuck = 0
	end

	if targetDistance <= FARM_PICKUP_DISTANCE then
		stopFarmMovement()

		if now >= farm.pickupAt then
			farm.pickupAt = now + 0.55
			farmPickup(target)
		end

		return
	end

	local moving = farmGo(humanoid, root, target.Position, now, dt, targetDistance > 12 and sprint or FARM_WALK_SPEED)

	local progress = farmProgress(root, target.Position, now)

	if progress == "giveup" then
		local spot = target:GetAttribute("SpotId")
		local key = spot or target
		local failures = (farm.failures[key] or 0) + 1

		farm.failures[key] = failures
		farm.blacklist[key] = now + math.min(8 * failures, 60)
		farm.target = nil
		farm.pickTarget = nil
		farm.goal = nil
		farm.path = nil
		farm.pathFails = 0
		return
	end

	if not moving and (farm.pathFails or 0) >= 3 then
		local spot = target:GetAttribute("SpotId")
		local key = spot or target

		farm.failures[key] = (farm.failures[key] or 0) + 1
		farm.blacklist[key] = now + math.min(8 * farm.failures[key], 60)
		farm.target = nil
		farm.pickTarget = nil
		farm.goal = nil
		farm.path = nil
		farm.pathFails = 0
		return
	end

	farmCheckStuck(root, now)
end

local syncAutoFarm

local function setAutoFarm(state)
	config.world.farm = state

	if state then
		restoreToken += 1
		farm.offset = nil
		farm.safe = nil
		farm.blockCount = 0
		farm.stuck = 0
		farm.doorAt = 0
		farm.doorMap = nil
		farm.doorScanAt = 0
		farm.scan = nil
		farm.pickAt = 0
		farm.pickTarget = nil
		farm.progressGoal = nil
		farm.progressDist = nil
		farm.progressFails = 0
		farm.progressAt = 0
	else
		stopFarmMovement()
		restoreDoors()
		farm.target = nil
		farm.goal = nil
		farm.path = nil
		farm.fleeUntil = 0
		farm.fleeGoal = nil
		farm.fleeFails = 0
		farm.fleeDist = nil
		farm.fleeCheckAt = 0
		farm.boltUntil = 0
		farm.roamGoal = nil
		farm.doorMap = nil
		farm.doorScanAt = 0
		farm.scan = nil
		farm.progressGoal = nil
		farm.progressDist = nil
		farm.progressFails = 0
		farm.progressAt = 0
	end

	if syncAutoFarm then
		syncAutoFarm(state, false)
	end
end

local farmAccumulator = 0

connect(RunService.Heartbeat, function(delta)
	if not config.world.farm then
		return
	end

	farmAccumulator += delta

	if farmAccumulator < 0.033 then
		return
	end

	local stepTime = farmAccumulator
	farmAccumulator = 0
	farmStep(os.clock(), stepTime)
end)

section("world", "world")
local toggleStamina = toggleRow("infinite stamina", config.world.stamina, setStamina)
local toggleInstant = toggleRow("instant interactions", config.world.instant, setInstant)
local toggleWeight = toggleRow("anti weight", config.world.weight, setAntiWeight)
toggleRow("remove darkness / fog", config.world.vision, setVision)
syncAutoKill = toggleRow("auto kill (monster)", config.world.autokill, setAutoKill)
syncAutoFarm = toggleRow("auto farm (loot + exit)", config.world.farm, setAutoFarm)

local function setChams(state)
	config.chams.enabled = state
end

section("chams", "vision")
local toggleChams = toggleRow("player/monster chams", config.chams.enabled, setChams)
sliderRow("fill", 0, 0.95, 0.05, config.chams.fill, function(value)
	return string.format("%d%%", math.floor((1 - value) * 100))
end, function(value)
	config.chams.fill = value
end)

local function setLootEsp(state)
	config.loot.enabled = state
	config.loot.highlight = state
	config.loot.labels = state
	config.loot.showName = state
	config.loot.showValue = state
	config.loot.tracers = state
end

section("loot esp", "vision")
local toggleLoot = toggleRow("loot esp", config.loot.enabled, setLootEsp)
sliderRow("minimum value", 0, 5000, 50, config.loot.minValue, function(value)
	return "$" .. shortNumber(value)
end, function(value)
	config.loot.minValue = value
end)
sliderRow("range", 0, 300, 10, config.loot.range, function(value)
	return value <= 0 and "any" or value .. "m"
end, function(value)
	config.loot.range = value
end)
sliderRow("fill", 0, 0.95, 0.05, config.loot.fill, function(value)
	return string.format("%d%%", math.floor((1 - value) * 100))
end, function(value)
	config.loot.fill = value
end)

task.delay(0.25, function()
	showTab("world", true)
end)

local dragging = false
local dragOrigin
local dragStart

connect(header.InputBegan, function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		finishMenuMotion()
		dragging = true
		dragStart = input.Position
		dragOrigin = Vector2.new(window.Position.X.Offset, window.Position.Y.Offset)
	end
end)

connect(UserInputService.InputChanged, function(input)
	if not dragging then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		local delta = input.Position - dragStart
		window.Position = UDim2.fromOffset(dragOrigin.X + delta.X, dragOrigin.Y + delta.Y)
	end
end)

connect(UserInputService.InputEnded, function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)

connect(UserInputService.InputBegan, function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.RightShift then
		toggleMenu()
	elseif window.Visible and input.KeyCode == Enum.KeyCode.One then
		showTab("world", false)
	elseif window.Visible and input.KeyCode == Enum.KeyCode.Two then
		showTab("vision", false)
	end
end)

local accumulator = 0

setStamina(config.world.stamina)
setInstant(config.world.instant)
setAntiWeight(config.world.weight)
setVision(config.world.vision)

connect(RunService.Heartbeat, function(delta)
	accumulator += delta
	if accumulator < 0.15 then
		return
	end
	accumulator = 0

	enforceInstant()
	enforceVision()

	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local origin = root and root.Position or workspace.CurrentCamera.CFrame.Position

	updatePlayers()
	scanLoot()
	refreshLoot(origin)
end)

local TRACER_BIND = "prism_tracers"

pcall(function()
	RunService:UnbindFromRenderStep(TRACER_BIND)
	RunService:BindToRenderStep(TRACER_BIND, Enum.RenderPriority.Camera.Value + 1, renderTracers)
end)

local function cleanup()
	pcall(function()
		RunService:UnbindFromRenderStep(TRACER_BIND)
	end)

	pcall(stopFarmMovement)
	pcall(restoreDoors)

	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)

	for model, record in pairs(chamByModel) do
		record.highlight:Destroy()
		record.label:Destroy()
		chamByModel[model] = nil
	end
	table.clear(chamByModel)

	for part, entry in pairs(lootEntries) do
		removeLootEntry(part, entry)
	end
	table.clear(lootEntries)

	for prompt, original in pairs(promptOriginals) do
		if prompt.Parent then
			prompt.HoldDuration = original
		end
	end
	table.clear(promptOriginals)
	table.clear(promptSet)

	LocalPlayer:SetAttribute("AdminInfStamina", staminaOriginal)

	removeWeightHook()
	setVision(false)

	for _, uiSoundName in ipairs({ "verschlafen_switch", "verschlafen_toggle" }) do
		local uiSound = game:GetService("SoundService"):FindFirstChild(uiSoundName)
		if uiSound then
			uiSound:Destroy()
		end
	end

	gui:Destroy()

	if env.verschlafenUnload == cleanup then
		env.verschlafenUnload = nil
	end

	if env.prismUnload == cleanup then
		env.prismUnload = nil
	end
end

env.verschlafenUnload = cleanup
env.prismUnload = cleanup
env.verschlafen = {
	setStamina = setStamina,
	setInstant = setInstant,
	setAntiWeight = setAntiWeight,
	setVision = setVision,
	setAutoKill = setAutoKill,
	autoKillTarget = killTarget,
	setAutoFarm = setAutoFarm,
	farm = farm,
	setLootEsp = setLootEsp,
	setChams = setChams,
	showTab = showTab,
	toggleMenu = toggleMenu,
}
env.prism = env.verschlafen
