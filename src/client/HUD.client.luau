-- Script del cliente:
--   * muestra el contador de monedas
--   * dibuja la tienda de mejoras
--   * hace girar las monedas (solo visual, en el cliente)
--   * muestra un "+1" al recoger una moneda

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local buyUpgrade = remotes:WaitForChild("BuyUpgrade") :: RemoteFunction
local coinCollected = remotes:WaitForChild("CoinCollected") :: RemoteEvent

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

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

local function round(parent: Instance, radius: number)
	create("UICorner", { CornerRadius = UDim.new(0, radius), Parent = parent })
end

local gui = create("ScreenGui", {
	Name = "CazaMonedasHUD",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = playerGui,
})

---------------------------------------------------------------------
-- Contador de monedas
---------------------------------------------------------------------
local coinFrame = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 12),
	Size = UDim2.fromOffset(200, 50),
	BackgroundColor3 = Color3.fromRGB(30, 30, 40),
	BackgroundTransparency = 0.2,
	Parent = gui,
})
round(coinFrame, 12)

local coinLabel = create("TextLabel", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Font = Enum.Font.FredokaOne,
	TextSize = 28,
	TextColor3 = Color3.fromRGB(255, 220, 60),
	Text = "🪙 0",
	Parent = coinFrame,
})

local function refreshCoins()
	coinLabel.Text = "🪙 " .. tostring(player:GetAttribute("Coins") or 0)
end
player:GetAttributeChangedSignal("Coins"):Connect(refreshCoins)
refreshCoins()

---------------------------------------------------------------------
-- Tienda
---------------------------------------------------------------------
local shopButton = create("TextButton", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 12, 0.5, 0),
	Size = UDim2.fromOffset(120, 50),
	BackgroundColor3 = Color3.fromRGB(70, 130, 255),
	Font = Enum.Font.FredokaOne,
	TextSize = 24,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "🛒 Tienda",
	Parent = gui,
})
round(shopButton, 12)

local shopFrame = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(340, 80 + #Config.UPGRADE_ORDER * 80),
	BackgroundColor3 = Color3.fromRGB(30, 30, 40),
	Visible = false,
	Parent = gui,
})
round(shopFrame, 16)

create("TextLabel", {
	Size = UDim2.new(1, 0, 0, 44),
	BackgroundTransparency = 1,
	Font = Enum.Font.FredokaOne,
	TextSize = 28,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "Mejoras",
	Parent = shopFrame,
})

local closeButton = create("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -8, 0, 8),
	Size = UDim2.fromOffset(30, 30),
	BackgroundColor3 = Color3.fromRGB(220, 60, 60),
	Font = Enum.Font.FredokaOne,
	TextSize = 20,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "X",
	Parent = shopFrame,
})
round(closeButton, 8)

local statusLabel = create("TextLabel", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 0, 1, -6),
	Size = UDim2.new(1, 0, 0, 24),
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	TextSize = 16,
	TextColor3 = Color3.fromRGB(200, 200, 200),
	Text = "",
	Parent = shopFrame,
})

shopButton.Activated:Connect(function()
	shopFrame.Visible = not shopFrame.Visible
end)
closeButton.Activated:Connect(function()
	shopFrame.Visible = false
end)

local busy = false

for index, upgradeId in Config.UPGRADE_ORDER do
	local upgrade = Config.UPGRADES[upgradeId]

	local row = create("Frame", {
		Position = UDim2.new(0, 12, 0, 48 + (index - 1) * 80),
		Size = UDim2.new(1, -24, 0, 70),
		BackgroundColor3 = Color3.fromRGB(50, 50, 65),
		Parent = shopFrame,
	})
	round(row, 10)

	local title = create("TextLabel", {
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -140, 0, 30),
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.new(1, 1, 1),
		Parent = row,
	})

	create("TextLabel", {
		Position = UDim2.fromOffset(12, 36),
		Size = UDim2.new(1, -140, 0, 24),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(190, 190, 200),
		Text = upgrade.description,
		Parent = row,
	})

	local buy = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(110, 46),
		BackgroundColor3 = Color3.fromRGB(60, 180, 90),
		Font = Enum.Font.FredokaOne,
		TextSize = 20,
		TextColor3 = Color3.new(1, 1, 1),
		Parent = row,
	})
	round(buy, 10)

	local function refresh()
		local level = player:GetAttribute(upgrade.id) or 0
		title.Text = ("%s  (nv. %d/%d)"):format(upgrade.name, level, upgrade.maxLevel)
		if level >= upgrade.maxLevel then
			buy.Text = "MÁX"
			buy.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
		else
			local price = Config.getPrice(upgrade, level)
			local coins = player:GetAttribute("Coins") or 0
			buy.Text = "🪙 " .. price
			buy.BackgroundColor3 = if coins >= price then Color3.fromRGB(60, 180, 90) else Color3.fromRGB(150, 70, 70)
		end
	end

	player:GetAttributeChangedSignal(upgrade.id):Connect(refresh)
	player:GetAttributeChangedSignal("Coins"):Connect(refresh)
	refresh()

	buy.Activated:Connect(function()
		if busy then
			return
		end
		busy = true
		local ok, success, message = pcall(function()
			return buyUpgrade:InvokeServer(upgrade.id)
		end)
		if ok then
			statusLabel.Text = message or ""
			statusLabel.TextColor3 = if success then Color3.fromRGB(120, 255, 140) else Color3.fromRGB(255, 120, 120)
		else
			statusLabel.Text = "Error de conexión"
		end
		busy = false
	end)
end

---------------------------------------------------------------------
-- Monedas girando (efecto visual local)
---------------------------------------------------------------------
local coinsFolder = workspace:WaitForChild("Coins")
local SPIN_SPEED = math.rad(180) -- grados por segundo

RunService.RenderStepped:Connect(function(dt)
	local spin = CFrame.Angles(0, SPIN_SPEED * dt, 0)
	for _, coin in coinsFolder:GetChildren() do
		if coin:IsA("BasePart") then
			coin.CFrame = CFrame.new(coin.Position) * spin * coin.CFrame.Rotation
		end
	end
end)

---------------------------------------------------------------------
-- Texto flotante "+N" al recoger
---------------------------------------------------------------------
coinCollected.OnClientEvent:Connect(function(value: number)
	local popup = create("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 66),
		Size = UDim2.fromOffset(120, 40),
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		TextSize = if value > Config.COIN_VALUE then 36 else 28,
		TextColor3 = if value > Config.COIN_VALUE then Color3.fromRGB(255, 170, 0) else Color3.fromRGB(255, 230, 60),
		TextStrokeTransparency = 0.5,
		Text = "+" .. value,
		Parent = gui,
	})
	local tween = TweenService:Create(popup, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 110),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	tween:Play()
	tween.Completed:Once(function()
		popup:Destroy()
	end)
end)
