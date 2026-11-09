-- Script principal del servidor:
--   * construye el mapa si no existe
--   * crea las estadísticas (leaderstats) de cada jugador
--   * guarda y carga el progreso con DataStore
--   * hace aparecer monedas y gestiona su recogida
--   * procesa las compras de la tienda

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

---------------------------------------------------------------------
-- Remotes (comunicación servidor <-> cliente)
---------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"

local buyUpgrade = Instance.new("RemoteFunction")
buyUpgrade.Name = "BuyUpgrade"
buyUpgrade.Parent = remotes

local coinCollected = Instance.new("RemoteEvent")
coinCollected.Name = "CoinCollected"
coinCollected.Parent = remotes

remotes.Parent = ReplicatedStorage

---------------------------------------------------------------------
-- Mapa
---------------------------------------------------------------------
local function makePart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if props.Shape then
		part.Shape = props.Shape -- la forma primero, para que no altere el tamaño
	end
	for key, value in props do
		if key ~= "Parent" and key ~= "Shape" then
			(part :: any)[key] = value
		end
	end
	part.Parent = props.Parent
	return part
end

local function buildArena(): Instance
	local existing = workspace:FindFirstChild("Arena")
	if existing then
		return existing
	end

	local arena = Instance.new("Folder")
	arena.Name = "Arena"

	local size = Config.ARENA_SIZE

	makePart({
		Name = "Floor",
		Size = Vector3.new(size, 4, size),
		Position = Vector3.new(0, -2, 0),
		Material = Enum.Material.Grass,
		Color = Color3.fromRGB(86, 171, 86),
		Parent = arena,
	})

	-- Muros invisibles para no caerse del mapa
	local wallHeight = 60
	for _, data in
		{
			{ Vector3.new(size / 2 + 1, wallHeight / 2, 0), Vector3.new(2, wallHeight, size) },
			{ Vector3.new(-size / 2 - 1, wallHeight / 2, 0), Vector3.new(2, wallHeight, size) },
			{ Vector3.new(0, wallHeight / 2, size / 2 + 1), Vector3.new(size, wallHeight, 2) },
			{ Vector3.new(0, wallHeight / 2, -size / 2 - 1), Vector3.new(size, wallHeight, 2) },
		}
	do
		makePart({
			Name = "Wall",
			Position = data[1],
			Size = data[2],
			Transparency = 1,
			Parent = arena,
		})
	end

	-- Plataformas flotantes: cuanto más altas, más mejoras de salto necesitas
	local rng = Random.new(2024)
	local spread = size * 0.4
	for i = 1, Config.PLATFORM_COUNT do
		local width = rng:NextNumber(12, 22)
		local height = 4 + (i / Config.PLATFORM_COUNT) * 26
		makePart({
			Name = "Platform" .. i,
			Size = Vector3.new(width, 2, width),
			Position = Vector3.new(rng:NextNumber(-spread, spread), height, rng:NextNumber(-spread, spread)),
			Material = Enum.Material.SmoothPlastic,
			Color = Color3.fromHSV(i / Config.PLATFORM_COUNT, 0.6, 0.95),
			Parent = arena,
		})
	end

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Anchored = true
	spawnLocation.Size = Vector3.new(12, 1, 12)
	spawnLocation.Position = Vector3.new(0, 0.5, 0)
	spawnLocation.Color = Color3.fromRGB(255, 255, 255)
	spawnLocation.Material = Enum.Material.Neon
	spawnLocation.Duration = 0
	spawnLocation.Parent = arena

	arena.Parent = workspace
	return arena
end

local arena = buildArena()

local coinsFolder = Instance.new("Folder")
coinsFolder.Name = "Coins"
coinsFolder.Parent = workspace

---------------------------------------------------------------------
-- Datos de jugadores
---------------------------------------------------------------------
type PlayerData = { Coins: number, Speed: number, Jump: number }

local DEFAULT_DATA: PlayerData = { Coins = 0, Speed = 0, Jump = 0 }

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DATASTORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[CazaMonedas] DataStore no disponible, el progreso no se guardará:", result)
	end
end

-- Solo se guardan los jugadores cuyos datos se cargaron bien,
-- para no sobrescribir su progreso con ceros.
local loaded: { [Player]: boolean } = {}

local function getKey(player: Player): string
	return "player_" .. player.UserId
end

local function loadData(player: Player): (boolean, PlayerData)
	local data = table.clone(DEFAULT_DATA)
	if not store then
		return true, data
	end
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return (store :: DataStore):GetAsync(getKey(player))
		end)
		if ok then
			if typeof(result) == "table" then
				for key in DEFAULT_DATA do
					if typeof(result[key]) == "number" then
						(data :: any)[key] = result[key]
					end
				end
			end
			return true, data
		end
		warn(("[CazaMonedas] Error al cargar datos de %s (intento %d): %s"):format(player.Name, attempt, tostring(result)))
		task.wait(attempt)
	end
	return false, data
end

local function saveData(player: Player)
	if not store or not loaded[player] then
		return
	end
	local data: PlayerData = {
		Coins = player:GetAttribute("Coins") or 0,
		Speed = player:GetAttribute("Speed") or 0,
		Jump = player:GetAttribute("Jump") or 0,
	}
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			(store :: DataStore):SetAsync(getKey(player), data)
		end)
		if ok then
			return
		end
		warn(("[CazaMonedas] Error al guardar datos de %s (intento %d): %s"):format(player.Name, attempt, tostring(err)))
		task.wait(attempt)
	end
end

local function applyUpgrades(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local speedLevel = player:GetAttribute("Speed") or 0
	local jumpLevel = player:GetAttribute("Jump") or 0
	humanoid.WalkSpeed = Config.BASE_WALKSPEED + speedLevel * Config.UPGRADES.Speed.perLevel
	humanoid.UseJumpPower = true
	humanoid.JumpPower = Config.BASE_JUMPPOWER + jumpLevel * Config.UPGRADES.Jump.perLevel
end

local function setCoins(player: Player, amount: number)
	player:SetAttribute("Coins", amount)
	local leaderstats = player:FindFirstChild("leaderstats")
	local coinsValue = leaderstats and leaderstats:FindFirstChild("Monedas")
	if coinsValue then
		(coinsValue :: IntValue).Value = amount
	end
end

local function onPlayerAdded(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local coinsValue = Instance.new("IntValue")
	coinsValue.Name = "Monedas"
	coinsValue.Parent = leaderstats
	leaderstats.Parent = player

	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid")
		applyUpgrades(player)
	end)

	local ok, data = loadData(player)
	if not player.Parent then
		return -- el jugador se fue mientras cargaba
	end
	loaded[player] = ok
	if not ok then
		warn("[CazaMonedas] No se pudieron cargar los datos de " .. player.Name .. "; esta sesión no se guardará.")
	end

	player:SetAttribute("Speed", data.Speed)
	player:SetAttribute("Jump", data.Jump)
	setCoins(player, data.Coins)
	applyUpgrades(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	saveData(player)
	loaded[player] = nil
end)

game:BindToClose(function()
	local pending = 0
	for _, player in Players:GetPlayers() do
		pending += 1
		task.spawn(function()
			saveData(player)
			pending -= 1
		end)
	end
	local start = os.clock()
	while pending > 0 and os.clock() - start < 25 do
		task.wait()
	end
end)

task.spawn(function()
	while true do
		task.wait(Config.AUTOSAVE_INTERVAL)
		for _, player in Players:GetPlayers() do
			task.spawn(saveData, player)
		end
	end
end)

---------------------------------------------------------------------
-- Monedas
---------------------------------------------------------------------
local rng = Random.new()
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { arena }

local function findSpawnPosition(): Vector3?
	local half = Config.ARENA_SIZE / 2 - 6
	for _ = 1, 10 do
		local origin = Vector3.new(rng:NextNumber(-half, half), 200, rng:NextNumber(-half, half))
		local result = workspace:Raycast(origin, Vector3.new(0, -400, 0), rayParams)
		if result and result.Instance:IsA("BasePart") and result.Instance.Transparency < 1 then
			return result.Position + Vector3.new(0, 3, 0)
		end
	end
	return nil
end

local function spawnCoin()
	local position = findSpawnPosition()
	if not position then
		return
	end

	local isGold = position.Y > Config.HIGH_ALTITUDE or rng:NextNumber() < Config.GOLD_CHANCE
	local value = if isGold then Config.GOLD_COIN_VALUE else Config.COIN_VALUE

	local coin = makePart({
		Name = if isGold then "GoldCoin" else "Coin",
		Shape = Enum.PartType.Cylinder,
		Size = if isGold then Vector3.new(0.6, 4, 4) else Vector3.new(0.4, 3, 3),
		CFrame = CFrame.new(position),
		Material = Enum.Material.Neon,
		Color = if isGold then Color3.fromRGB(255, 170, 0) else Color3.fromRGB(255, 230, 60),
		CanCollide = false,
		CastShadow = false,
	})
	coin:SetAttribute("Value", value)

	local collected = false
	coin.Touched:Connect(function(hit)
		if collected then
			return
		end
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return
		end
		collected = true
		setCoins(player, (player:GetAttribute("Coins") or 0) + value)
		coinCollected:FireClient(player, value, coin.Position)
		coin:Destroy()
	end)

	coin.Parent = coinsFolder
end

task.spawn(function()
	while true do
		if #coinsFolder:GetChildren() < Config.MAX_COINS then
			spawnCoin()
		end
		task.wait(Config.SPAWN_INTERVAL)
	end
end)

---------------------------------------------------------------------
-- Tienda
---------------------------------------------------------------------
buyUpgrade.OnServerInvoke = function(player: Player, upgradeId: any)
	if typeof(upgradeId) ~= "string" then
		return false, "Mejora inválida"
	end
	local upgrade = Config.UPGRADES[upgradeId]
	if not upgrade then
		return false, "Mejora inválida"
	end

	local level = player:GetAttribute(upgrade.id) or 0
	if level >= upgrade.maxLevel then
		return false, "¡Nivel máximo!"
	end

	local price = Config.getPrice(upgrade, level)
	local coins = player:GetAttribute("Coins") or 0
	if coins < price then
		return false, ("Te faltan %d monedas"):format(price - coins)
	end

	setCoins(player, coins - price)
	player:SetAttribute(upgrade.id, level + 1)
	applyUpgrades(player)
	return true, ("¡%s nivel %d!"):format(upgrade.name, level + 1)
end
