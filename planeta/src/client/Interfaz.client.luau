-- Interfaz del jugador:
--   monedas, golosinas, zona y oxígeno · colección de criaturas (montar)
--   tienda · avisos · radar · botón de ataque contra jefes

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local equipRemote = remotes:WaitForChild("Montar") :: RemoteFunction
local buyRemote = remotes:WaitForChild("Comprar") :: RemoteFunction
local inventoryRemote = remotes:WaitForChild("PedirInventario") :: RemoteFunction
local inventoryEvent = remotes:WaitForChild("Inventario") :: RemoteEvent
local notifyEvent = remotes:WaitForChild("Aviso") :: RemoteEvent
local attackEvent = remotes:WaitForChild("Atacar") :: RemoteEvent

local player = Players.LocalPlayer
local planeta = workspace:WaitForChild("Planeta")

---------------------------------------------------------------------
-- Utilidades de UI
---------------------------------------------------------------------
local function create(className: string, props: { [string]: any }): any
	local instance = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	instance.Parent = props.Parent
	return instance
end

local function round(parent: Instance, radius: number?)
	create("UICorner", { CornerRadius = UDim.new(0, radius or 12), Parent = parent })
end

local DARK = Color3.fromRGB(28, 30, 40)
local PANEL = Color3.fromRGB(45, 48, 62)
local WHITE = Color3.new(1, 1, 1)

local gui = create("ScreenGui", {
	Name = "PlanetaHUD",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

local function label(props: { [string]: any }): TextLabel
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or Enum.Font.FredokaOne
	props.TextColor3 = props.TextColor3 or WHITE
	props.TextSize = props.TextSize or 20
	return create("TextLabel", props)
end

local function textButton(props: { [string]: any }): TextButton
	props.Font = props.Font or Enum.Font.FredokaOne
	props.TextColor3 = props.TextColor3 or WHITE
	props.TextSize = props.TextSize or 20
	props.AutoButtonColor = true
	local b = create("TextButton", props)
	round(b, 10)
	return b
end

---------------------------------------------------------------------
-- Barra superior
---------------------------------------------------------------------
local top = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 10),
	Size = UDim2.fromOffset(360, 44),
	BackgroundColor3 = DARK,
	BackgroundTransparency = 0.15,
	Parent = gui,
})
round(top)
local statsLabel = label({ Size = UDim2.fromScale(1, 1), TextSize = 22, Parent = top })

local zoneLabel = label({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 58),
	Size = UDim2.fromOffset(360, 24),
	TextSize = 18,
	TextStrokeTransparency = 0.4,
	Parent = gui,
})

local function refreshStats()
	local pala = Config.PALAS[player:GetAttribute("Pala") or 1]
	statsLabel.Text = ("🪙 %d    🍬 %d    ⛏️ %s"):format(
		player:GetAttribute("Coins") or 0,
		player:GetAttribute("Golosinas") or 0,
		if pala then pala.name else "-"
	)
end
for _, attribute in { "Coins", "Golosinas", "Pala" } do
	player:GetAttributeChangedSignal(attribute):Connect(refreshStats)
end
refreshStats()

-- Oxígeno
local oxygenBack = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 86),
	Size = UDim2.fromOffset(260, 22),
	BackgroundColor3 = DARK,
	Visible = false,
	Parent = gui,
})
round(oxygenBack, 8)
local oxygenBar = create("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(80, 200, 255),
	Parent = oxygenBack,
})
round(oxygenBar, 8)
local oxygenText = label({ Size = UDim2.fromScale(1, 1), TextSize = 16, Text = "💨 Oxígeno", Parent = oxygenBack })

local function refreshOxygen()
	local oxygen = player:GetAttribute("Oxygen")
	local maxOxygen = player:GetAttribute("MaxOxygen") or Config.MAX_OXYGEN
	if typeof(oxygen) ~= "number" or oxygen >= maxOxygen then
		oxygenBack.Visible = false
		return
	end
	oxygenBack.Visible = true
	local ratio = oxygen / maxOxygen
	oxygenBar.Size = UDim2.fromScale(ratio, 1)
	oxygenBar.BackgroundColor3 = if ratio < 0.25 then Color3.fromRGB(255, 80, 80) else Color3.fromRGB(80, 200, 255)
	oxygenText.Text = if ratio <= 0 then "💨 ¡Sin aire!" else "💨 Oxígeno"
end
player:GetAttributeChangedSignal("Oxygen"):Connect(refreshOxygen)
player:GetAttributeChangedSignal("MaxOxygen"):Connect(refreshOxygen)

---------------------------------------------------------------------
-- Avisos
---------------------------------------------------------------------
local toastHolder = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 116),
	Size = UDim2.fromOffset(420, 200),
	BackgroundTransparency = 1,
	Parent = gui,
})
create("UIListLayout", {
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 6),
	Parent = toastHolder,
})

local KIND_COLORS = {
	exito = Color3.fromRGB(60, 170, 90),
	error = Color3.fromRGB(190, 60, 60),
	info = Color3.fromRGB(60, 90, 170),
}

local function toast(text: string, kind: string?)
	local frame = create("Frame", {
		Size = UDim2.fromOffset(400, 38),
		BackgroundColor3 = KIND_COLORS[kind or "info"] or KIND_COLORS.info,
		Parent = toastHolder,
	})
	round(frame, 10)
	local textLabel = label({ Size = UDim2.new(1, -12, 1, 0), Position = UDim2.fromOffset(6, 0), TextSize = 18, TextWrapped = true, Text = text, Parent = frame })
	task.delay(2.5, function()
		local info = TweenInfo.new(0.4)
		TweenService:Create(frame, info, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(textLabel, info, { TextTransparency = 1 }):Play()
		task.wait(0.4)
		frame:Destroy()
	end)
end
notifyEvent.OnClientEvent:Connect(toast)

---------------------------------------------------------------------
-- Ventanas (Criaturas y Tienda)
---------------------------------------------------------------------
local function window(title: string): (Frame, ScrollingFrame)
	local frame = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.new(0.9, 0, 0.7, 0),
		BackgroundColor3 = DARK,
		Visible = false,
		Parent = gui,
	})
	create("UISizeConstraint", { MaxSize = Vector2.new(640, 460), Parent = frame })
	round(frame, 16)
	label({ Size = UDim2.new(1, 0, 0, 44), TextSize = 26, Text = title, Parent = frame })
	local close = textButton({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(32, 32),
		BackgroundColor3 = Color3.fromRGB(200, 60, 60),
		Text = "X",
		Parent = frame,
	})
	close.Activated:Connect(function()
		frame.Visible = false
	end)
	local list = create("ScrollingFrame", {
		Position = UDim2.fromOffset(10, 50),
		Size = UDim2.new(1, -20, 1, -60),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = frame,
	})
	return frame, list
end

local creaturesWindow, creaturesList = window("🐾 Mis criaturas")
local shopWindow, shopList = window("🛒 Tienda")

create("UIGridLayout", {
	CellSize = UDim2.fromOffset(180, 190),
	CellPadding = UDim2.fromOffset(10, 10),
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = creaturesList,
})
create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = shopList })

local function sideButton(text: string, y: number, color: Color3, target: Frame)
	local b = textButton({
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, y),
		Size = UDim2.fromOffset(130, 48),
		BackgroundColor3 = color,
		Text = text,
		Parent = gui,
	})
	b.Activated:Connect(function()
		local show = not target.Visible
		creaturesWindow.Visible = false
		shopWindow.Visible = false
		target.Visible = show
	end)
end
sideButton("🐾 Criaturas", -30, Color3.fromRGB(230, 140, 50), creaturesWindow)
sideButton("🛒 Tienda", 30, Color3.fromRGB(70, 130, 255), shopWindow)

---------------------------------------------------------------------
-- Colección de criaturas
---------------------------------------------------------------------
local owned: { [string]: number } = {}

local function habitatsOf(creatureId: string): string
	local names = {}
	for _, habitatId in Config.HABITAT_ORDER do
		local habitat = Config.HABITATS[habitatId]
		if habitat.creatures[creatureId] then
			table.insert(names, habitat.name)
		end
	end
	return table.concat(names, ", ")
end

local function elementsText(creatureId: string): string
	local parts = {}
	for _, element in Config.CREATURES[creatureId].elements do
		table.insert(parts, Config.ELEMENTS[element].emoji)
	end
	return table.concat(parts, " ")
end

local function busyCall(fn: () -> (boolean, string?))
	local ok, success, message = pcall(fn)
	if ok then
		toast(message or "", if success then "exito" else "error")
	else
		toast("Error de conexión", "error")
	end
end

local function refreshCreatures()
	for _, child in creaturesList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local equipped = player:GetAttribute("Equipped")

	for index, creatureId in Config.CREATURE_ORDER do
		local creature = Config.CREATURES[creatureId]
		local rarity = Config.RARITIES[creature.rarity]
		local count = owned[creatureId] or 0
		local card = create("Frame", { LayoutOrder = index, BackgroundColor3 = PANEL, Parent = creaturesList })
		round(card, 12)
		create("UIStroke", { Color = rarity.color, Thickness = 2, Parent = card })

		local circle = create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 10),
			Size = UDim2.fromOffset(54, 54),
			BackgroundColor3 = if count > 0 then creature.color else Color3.fromRGB(25, 25, 30),
			Parent = card,
		})
		round(circle, 27)

		if count > 0 then
			label({ Position = UDim2.fromOffset(0, 68), Size = UDim2.new(1, 0, 0, 24), Text = creature.name, Parent = card })
			label({
				Position = UDim2.fromOffset(0, 92),
				Size = UDim2.new(1, 0, 0, 20),
				TextSize = 16,
				TextColor3 = rarity.color,
				Text = ("%s  %s  x%d"):format(rarity.name, elementsText(creatureId), count),
				Parent = card,
			})
			local isEquipped = equipped == creatureId
			local b = textButton({
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -10),
				Size = UDim2.new(1, -20, 0, 40),
				BackgroundColor3 = if isEquipped then Color3.fromRGB(200, 90, 60) else Color3.fromRGB(60, 170, 90),
				Text = if isEquipped then "Bajarse" else "Montar",
				Parent = card,
			})
			b.Activated:Connect(function()
				busyCall(function()
					return equipRemote:InvokeServer(if isEquipped then "" else creatureId)
				end)
			end)
		else
			label({ Position = UDim2.fromOffset(0, 68), Size = UDim2.new(1, 0, 0, 24), Text = "???", Parent = card })
			label({
				Position = UDim2.fromOffset(8, 96),
				Size = UDim2.new(1, -16, 0, 80),
				TextSize = 15,
				TextWrapped = true,
				Font = Enum.Font.Gotham,
				TextColor3 = Color3.fromRGB(170, 170, 185),
				Text = ("%s %s\nVive en: %s"):format(rarity.name, elementsText(creatureId), habitatsOf(creatureId)),
				Parent = card,
			})
		end
	end
end

inventoryEvent.OnClientEvent:Connect(function(data)
	owned = data or {}
	refreshCreatures()
end)
player:GetAttributeChangedSignal("Equipped"):Connect(refreshCreatures)
task.spawn(function()
	local ok, data = pcall(function()
		return inventoryRemote:InvokeServer()
	end)
	if ok and data then
		owned = data
	end
	refreshCreatures()
end)

---------------------------------------------------------------------
-- Tienda
---------------------------------------------------------------------
local shopRefreshers = {}

for index, item in Config.SHOP do
	local row = create("Frame", {
		LayoutOrder = index,
		Size = UDim2.new(1, -8, 0, 70),
		BackgroundColor3 = PANEL,
		Parent = shopList,
	})
	round(row, 10)
	label({
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -150, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 22,
		Text = item.name,
		Parent = row,
	})
	label({
		Position = UDim2.fromOffset(12, 36),
		Size = UDim2.new(1, -150, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.Gotham,
		TextSize = 15,
		TextColor3 = Color3.fromRGB(190, 190, 205),
		Text = item.description,
		Parent = row,
	})
	local buy = textButton({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(120, 46),
		BackgroundColor3 = Color3.fromRGB(60, 170, 90),
		Parent = row,
	})
	buy.Activated:Connect(function()
		busyCall(function()
			return buyRemote:InvokeServer(item.id)
		end)
	end)

	table.insert(shopRefreshers, function()
		local have = false
		if item.kind == "pala" then
			have = (player:GetAttribute("Pala") or 1) >= item.tier
		elseif item.kind == "radar" then
			have = player:GetAttribute("Radar") == true
		elseif item.kind == "tanque" then
			have = (player:GetAttribute("Tanque") or 0) >= item.tier
		end
		if have then
			buy.Text = "✅ Tienes"
			buy.BackgroundColor3 = Color3.fromRGB(100, 100, 110)
		else
			buy.Text = "🪙 " .. item.price
			buy.BackgroundColor3 = if (player:GetAttribute("Coins") or 0) >= item.price
				then Color3.fromRGB(60, 170, 90)
				else Color3.fromRGB(150, 70, 70)
		end
	end)
end

local function refreshShop()
	for _, refresh in shopRefreshers do
		refresh()
	end
end
for _, attribute in { "Coins", "Pala", "Radar", "Tanque" } do
	player:GetAttributeChangedSignal(attribute):Connect(refreshShop)
end
refreshShop()

---------------------------------------------------------------------
-- Montura actual y habilidades
---------------------------------------------------------------------
local mountLabel = label({
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 12, 1, -12),
	Size = UDim2.fromOffset(380, 70),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Bottom,
	TextSize = 16,
	TextWrapped = true,
	TextStrokeTransparency = 0.4,
	Parent = gui,
})

local function refreshMount()
	local id = player:GetAttribute("Equipped")
	local creature = typeof(id) == "string" and Config.CREATURES[id]
	if not creature then
		mountLabel.Text = "🚶 A pie · Doma una criatura con 🍬 para montarla"
		return
	end
	local lines = { ("🐾 Montando: %s (%s)"):format(creature.name, Config.RARITIES[creature.rarity].name) }
	for _, element in creature.elements do
		local info = Config.ELEMENTS[element]
		table.insert(lines, info.emoji .. " " .. info.ability)
	end
	mountLabel.Text = table.concat(lines, "\n")
end
player:GetAttributeChangedSignal("Equipped"):Connect(refreshMount)
refreshMount()

---------------------------------------------------------------------
-- Radar: marca la criatura y el tesoro más cercanos (se ven a través de paredes)
---------------------------------------------------------------------
local creatureHighlight = create("Highlight", {
	FillColor = Color3.fromRGB(255, 200, 60),
	OutlineColor = Color3.fromRGB(255, 255, 255),
	FillTransparency = 0.5,
	DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
	Enabled = false,
	Parent = workspace.CurrentCamera,
})
local treasureHighlight = create("Highlight", {
	FillColor = Color3.fromRGB(120, 255, 140),
	OutlineColor = Color3.fromRGB(255, 255, 255),
	FillTransparency = 0.4,
	DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
	Enabled = false,
	Parent = workspace.CurrentCamera,
})
local radarLabel = label({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 10),
	Size = UDim2.fromOffset(260, 50),
	TextXAlignment = Enum.TextXAlignment.Right,
	TextSize = 16,
	TextStrokeTransparency = 0.4,
	Visible = false,
	Parent = gui,
})

local function nearest(folder: Instance, from: Vector3): (Instance?, number)
	local best, bestDistance = nil, math.huge
	for _, child in folder:GetChildren() do
		local p: BasePart? = nil
		if child:IsA("Model") then
			p = child.PrimaryPart
		elseif child:IsA("BasePart") then
			p = child
		end
		if p then
			local d = (p.Position - from).Magnitude
			if d < bestDistance then
				best, bestDistance = child, d
			end
		end
	end
	return best, bestDistance
end

task.spawn(function()
	local creaturesFolder = planeta:WaitForChild("Criaturas")
	local treasureFolder = planeta:WaitForChild("Excavaciones")
	while true do
		task.wait(0.5)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if player:GetAttribute("Radar") == true and root then
			local creature, creatureDistance = nearest(creaturesFolder, root.Position)
			local treasure, treasureDistance = nearest(treasureFolder, root.Position)
			creatureHighlight.Adornee = creature
			creatureHighlight.Enabled = creature ~= nil
			treasureHighlight.Adornee = treasure
			treasureHighlight.Enabled = treasure ~= nil
			local lines = {}
			if creature then
				local id = creature:GetAttribute("CreatureId")
				local info = typeof(id) == "string" and Config.CREATURES[id]
				table.insert(lines, ("📡 %s a %d m"):format(if info then info.name else "Criatura", creatureDistance))
			end
			if treasure then
				table.insert(lines, ("💎 Tesoro a %d m"):format(treasureDistance))
			end
			radarLabel.Text = table.concat(lines, "\n")
			radarLabel.Visible = #lines > 0
		else
			creatureHighlight.Enabled = false
			treasureHighlight.Enabled = false
			radarLabel.Visible = false
		end
	end
end)

---------------------------------------------------------------------
-- Atacar jefes
---------------------------------------------------------------------
local bossesFolder = planeta:WaitForChild("Jefes")
local attackButton = textButton({
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -16, 1, -270),
	Size = UDim2.fromOffset(150, 64),
	BackgroundColor3 = Color3.fromRGB(210, 60, 60),
	TextSize = 24,
	Text = "⚔️ Atacar",
	Visible = false,
	Parent = gui,
})

local targetBoss: string? = nil

local function attack()
	if targetBoss then
		attackEvent:FireServer(targetBoss)
	end
end
attackButton.Activated:Connect(attack)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.UserInputType == Enum.UserInputType.MouseButton1 then
		attack()
	end
end)

---------------------------------------------------------------------
-- Zona actual y jefe cercano
---------------------------------------------------------------------
RunService.Heartbeat:Connect(function()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	zoneLabel.Text = "📍 " .. Config.getZone(root.Position)

	targetBoss = nil
	for _, boss in bossesFolder:GetChildren() do
		local id = boss:GetAttribute("BossId")
		local body = boss:IsA("Model") and boss.PrimaryPart
		if typeof(id) == "string" and body then
			local config = Config.BOSSES[id]
			if (body.Position - root.Position).Magnitude <= config.scale / 2 + Config.ATTACK.range then
				targetBoss = id
			end
		end
	end
	attackButton.Visible = targetBoss ~= nil
end)
