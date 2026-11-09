-- Script principal del servidor:
--   datos y guardado · monturas · criaturas salvajes y domar · excavaciones
--   jefes y zonas cerradas · oxígeno · tienda

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- No aparecer hasta que el planeta exista (si no, caerías al centro)
Players.CharacterAutoLoads = false

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local CreatureModel = require(Shared:WaitForChild("CreatureModel"))
local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))

local CENTER = Config.PLANET_CENTER
local rng = Random.new()

---------------------------------------------------------------------
-- Remotes
---------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local function remote(className: string, name: string): any
	local r = Instance.new(className)
	r.Name = name
	r.Parent = remotes
	return r
end
local equipRemote = remote("RemoteFunction", "Montar") :: RemoteFunction
local buyRemote = remote("RemoteFunction", "Comprar") :: RemoteFunction
local inventoryRemote = remote("RemoteFunction", "PedirInventario") :: RemoteFunction
local inventoryEvent = remote("RemoteEvent", "Inventario") :: RemoteEvent
local notifyEvent = remote("RemoteEvent", "Aviso") :: RemoteEvent
local attackEvent = remote("RemoteEvent", "Atacar") :: RemoteEvent
remotes.Parent = ReplicatedStorage

---------------------------------------------------------------------
-- Construir el planeta
---------------------------------------------------------------------
local world = WorldBuilder.build()

---------------------------------------------------------------------
-- Datos de jugadores
---------------------------------------------------------------------
local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DATASTORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[Planeta] DataStore no disponible, el progreso no se guardará:", result)
	end
end

local sessions: { [Player]: any } = {}
local canSave: { [Player]: boolean } = {}

local function defaultData()
	return {
		Coins = Config.START.Coins,
		Golosinas = Config.START.Golosinas,
		Pala = 1,
		Radar = false,
		Tanque = 0,
		Owned = {},
		Equipped = "",
		Unlocks = {},
	}
end

local function sanitize(raw: any)
	local data = defaultData()
	if typeof(raw) ~= "table" then
		return data
	end
	if typeof(raw.Coins) == "number" then
		data.Coins = math.max(0, math.floor(raw.Coins))
	end
	if typeof(raw.Golosinas) == "number" then
		data.Golosinas = math.max(0, math.floor(raw.Golosinas))
	end
	if typeof(raw.Pala) == "number" then
		data.Pala = math.clamp(math.floor(raw.Pala), 1, #Config.PALAS)
	end
	data.Radar = raw.Radar == true
	if typeof(raw.Tanque) == "number" then
		data.Tanque = math.clamp(math.floor(raw.Tanque), 0, #Config.TANQUES)
	end
	if typeof(raw.Owned) == "table" then
		for id, count in raw.Owned do
			if Config.CREATURES[id] and typeof(count) == "number" and count > 0 then
				data.Owned[id] = math.floor(count)
			end
		end
	end
	if typeof(raw.Equipped) == "string" and data.Owned[raw.Equipped] then
		data.Equipped = raw.Equipped
	end
	if typeof(raw.Unlocks) == "table" then
		for gate in Config.GATES do
			if raw.Unlocks[gate] == true then
				data.Unlocks[gate] = true
			end
		end
	end
	return data
end

local function key(player: Player): string
	return "player_" .. player.UserId
end

local function loadData(player: Player)
	if not store then
		return true, defaultData()
	end
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return (store :: DataStore):GetAsync(key(player))
		end)
		if ok then
			return true, sanitize(result)
		end
		warn(("[Planeta] Error al cargar a %s (intento %d): %s"):format(player.Name, attempt, tostring(result)))
		task.wait(attempt)
	end
	return false, defaultData()
end

local function saveData(player: Player)
	local data = sessions[player]
	if not store or not data or not canSave[player] then
		return
	end
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			(store :: DataStore):SetAsync(key(player), data)
		end)
		if ok then
			return
		end
		warn(("[Planeta] Error al guardar a %s (intento %d): %s"):format(player.Name, attempt, tostring(err)))
		task.wait(attempt)
	end
end

-- Copia los datos a atributos del jugador para que el cliente los vea
local function sync(player: Player)
	local data = sessions[player]
	if not data then
		return
	end
	player:SetAttribute("Coins", data.Coins)
	player:SetAttribute("Golosinas", data.Golosinas)
	player:SetAttribute("Pala", data.Pala)
	player:SetAttribute("Radar", data.Radar)
	player:SetAttribute("Tanque", data.Tanque)
	player:SetAttribute("Equipped", data.Equipped)
	for gate in Config.GATES do
		player:SetAttribute("Unlock_" .. gate, data.Unlocks[gate] == true)
	end
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Monedas")
	if coins then
		(coins :: IntValue).Value = data.Coins
	end
end

local function notify(player: Player, text: string, kind: string?)
	notifyEvent:FireClient(player, text, kind or "info")
end

local function sendInventory(player: Player)
	local data = sessions[player]
	if data then
		inventoryEvent:FireClient(player, data.Owned)
	end
end

local function addCoins(player: Player, amount: number)
	local data = sessions[player]
	if data then
		data.Coins += amount
		sync(player)
	end
end

local function getRoot(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and humanoid and humanoid.Health > 0 then
		return root :: BasePart
	end
	return nil
end

---------------------------------------------------------------------
-- Monturas: la criatura equipada va debajo del jugador
---------------------------------------------------------------------
local function attachMount(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not root then
		return
	end
	local old = character:FindFirstChild("Montura")
	if old then
		old:Destroy()
	end
	local data = sessions[player]
	if not data or data.Equipped == "" then
		return
	end
	local geometry = Config.getMountGeometry(data.Equipped)
	local model = CreatureModel.build(data.Equipped, { anchored = false, name = "Montura" })
	local body = model.PrimaryPart :: BasePart
	model:PivotTo(root.CFrame * CFrame.new(0, -geometry.bodyDrop, 0))
	local weld = Instance.new("Weld")
	weld.Part0 = root
	weld.Part1 = body
	weld.C0 = CFrame.new(0, -geometry.bodyDrop, 0)
	weld.Parent = body
	model.Parent = character
end

---------------------------------------------------------------------
-- Jugadores entrando y saliendo
---------------------------------------------------------------------
local function onPlayerAdded(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Monedas"
	coins.Parent = leaderstats
	leaderstats.Parent = player

	player.CharacterAdded:Connect(function(character)
		player:SetAttribute("Oxygen", nil) -- al reaparecer tienes el aire lleno
		character:WaitForChild("HumanoidRootPart")
		task.wait(0.1)
		attachMount(player)
	end)

	local ok, data = loadData(player)
	if not player.Parent then
		return
	end
	sessions[player] = data
	canSave[player] = ok
	if not ok then
		notify(player, "No se pudo cargar tu progreso; esta partida no se guardará.", "error")
	end
	sync(player)
	sendInventory(player)
	attachMount(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	saveData(player)
	sessions[player] = nil
	canSave[player] = nil
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

-- El planeta ya está listo: ahora sí aparecen los personajes
Players.CharacterAutoLoads = true
for _, player in Players:GetPlayers() do
	if not player.Character then
		task.spawn(function()
			player:LoadCharacter()
		end)
	end
end

---------------------------------------------------------------------
-- Criaturas salvajes
---------------------------------------------------------------------
type Wild = {
	id: string,
	habitat: string,
	model: Model,
	up: Vector3,
	heading: Vector3,
	radius: number,
	lift: number,
	alive: boolean,
	phase: number,
}

local wilds: { Wild } = {}

local function pickWeighted(weights: { [string]: number }): string
	local total = 0
	for _, w in weights do
		total += w
	end
	local roll = rng:NextNumber(0, total)
	local last = ""
	for id, w in weights do
		last = id
		roll -= w
		if roll <= 0 then
			return id
		end
	end
	return last
end

local function placeWild(wild: Wild)
	local bob = if wild.habitat == "Pradera" or wild.habitat == "Cueva" then 0 else math.sin(os.clock() * 2 + wild.phase) * 0.8
	local position = CENTER + wild.up * (wild.radius + wild.lift + bob)
	wild.model:PivotTo(Config.uprightCFrame(position, wild.up, wild.heading))
end

local function relocateWild(wild: Wild): boolean
	local habitat = Config.HABITATS[wild.habitat]
	local point, up = WorldBuilder.randomPoint(habitat.spawn)
	if not point or not up then
		return false
	end
	wild.up = (point - CENTER).Unit
	wild.radius = (point - CENTER).Magnitude
	wild.heading = WorldBuilder.randomTangent(wild.up)
	placeWild(wild)
	return true
end

local onTame -- se define más abajo

local function spawnWild(habitatId: string)
	local habitat = Config.HABITATS[habitatId]
	local id = pickWeighted(habitat.creatures)
	local creature = Config.CREATURES[id]
	local rarity = Config.RARITIES[creature.rarity]
	local taming = Config.TAMING[creature.rarity]

	local model = CreatureModel.build(id, { anchored = true })
	local isGround = habitat.kind == "suelo" or habitat.kind == "cueva" or habitatId == "Templo"
	local wild: Wild = {
		id = id,
		habitat = habitatId,
		model = model,
		up = Vector3.yAxis,
		heading = Vector3.xAxis,
		radius = 0,
		lift = if isGround then Config.getCreatureLift(id) else 0,
		alive = true,
		phase = rng:NextNumber(0, 6),
	}
	if not relocateWild(wild) then
		model:Destroy()
		return
	end

	model:SetAttribute("CreatureId", id)
	model:SetAttribute("Habitat", habitatId)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = ("Domar (%d 🍬)"):format(taming.golosinas)
	prompt.ObjectText = ("%s · %s"):format(creature.name, rarity.name)
	prompt.HoldDuration = taming.hold
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart
	prompt.Triggered:Connect(function(player)
		onTame(player, wild)
	end)

	model.Parent = world.folders.Criaturas
	table.insert(wilds, wild)
end

local function removeWild(wild: Wild)
	wild.alive = false
	wild.model:Destroy()
	local index = table.find(wilds, wild)
	if index then
		table.remove(wilds, index)
	end
end

onTame = function(player: Player, wild: Wild)
	local data = sessions[player]
	if not data or not wild.alive then
		return
	end
	local creature = Config.CREATURES[wild.id]
	local taming = Config.TAMING[creature.rarity]
	if data.Golosinas < taming.golosinas then
		notify(player, ("Necesitas %d 🍬 para domar a %s"):format(taming.golosinas, creature.name), "error")
		return
	end
	data.Golosinas -= taming.golosinas

	if rng:NextNumber() <= taming.chance then
		data.Owned[wild.id] = (data.Owned[wild.id] or 0) + 1
		local first = data.Equipped == ""
		if first then
			data.Equipped = wild.id
		end
		removeWild(wild)
		sync(player)
		sendInventory(player)
		if first then
			attachMount(player)
		end
		notify(player, ("¡Domaste a %s! (%s)"):format(creature.name, Config.RARITIES[creature.rarity].name), "exito")
	else
		sync(player)
		relocateWild(wild)
		notify(player, ("¡%s se escapó!"):format(creature.name), "error")
	end
end

-- Movimiento de las criaturas salvajes
local function stepWild(wild: Wild, dt: number)
	local habitat = Config.HABITATS[wild.habitat]
	if habitat.kind == "fijo" or habitat.speed <= 0 then
		placeWild(wild)
		return
	end

	local angle = habitat.speed * dt / math.max(wild.radius, 1)
	local axis = wild.up:Cross(wild.heading)
	if axis.Magnitude < 1e-4 then
		wild.heading = WorldBuilder.randomTangent(wild.up)
		return
	end
	local rotation = CFrame.fromAxisAngle(axis.Unit, angle)
	local newUp = (rotation * wild.up).Unit
	local newHeading = rotation * wild.heading
	newHeading = (CFrame.fromAxisAngle(newUp, rng:NextNumber(-0.6, 0.6) * dt) * newHeading)
	newHeading = (newHeading - newUp * newHeading:Dot(newUp)).Unit

	local newRadius = wild.radius
	local valid = true
	if habitat.kind == "suelo" then
		local hit = WorldBuilder.surfaceHit(newUp, false)
		valid = hit ~= nil
			and hit.Material ~= Enum.Material.Water
			and (hit.Position - CENTER).Magnitude > Config.WATER_RADIUS - 1
		if valid and hit then
			newRadius = (hit.Position - CENTER).Magnitude
		end
	elseif habitat.kind == "cueva" then
		local hit = WorldBuilder.caveFloor(newUp)
		valid = hit ~= nil
		if valid and hit then
			newRadius = (hit.Position - CENTER).Magnitude
		end
	elseif habitat.kind == "agua" then
		valid = Config.isWater(CENTER + newUp * newRadius)
	end

	if valid then
		wild.up = newUp
		wild.heading = newHeading
		wild.radius = newRadius
	else
		wild.heading = -wild.heading -- da la vuelta
	end
	placeWild(wild)
end

task.spawn(function()
	local last = os.clock()
	while true do
		task.wait(0.1)
		local now = os.clock()
		local dt = now - last
		last = now
		for _, wild in table.clone(wilds) do
			if wild.alive and wild.model.Parent then
				stepWild(wild, dt)
			end
		end
	end
end)

task.spawn(function()
	while true do
		for _, habitatId in Config.HABITAT_ORDER do
			local count = 0
			for _, wild in wilds do
				if wild.habitat == habitatId then
					count += 1
				end
			end
			if count < Config.HABITATS[habitatId].max then
				spawnWild(habitatId)
			end
		end
		task.wait(Config.WILD_RESPAWN_INTERVAL)
	end
end)

---------------------------------------------------------------------
-- Excavaciones
---------------------------------------------------------------------
local digCounts: { [string]: number } = {}

local function spawnDig(zoneId: string)
	local zone = Config.DIG_ZONES[zoneId]
	local point, up = WorldBuilder.randomPoint(zone.spawn)
	if not point or not up then
		return
	end
	local mound = WorldBuilder.part({
		Name = "Tesoro",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.8, 5, 5),
		CFrame = Config.uprightCFrame(point + up * 0.2, up) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Ground,
		Color = Color3.fromRGB(120, 85, 50),
		CanCollide = false,
	})
	mound:SetAttribute("Zone", zoneId)
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = Color3.fromRGB(255, 230, 120)
	sparkles.Parent = mound

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Excavar"
	prompt.ObjectText = "Tesoro · " .. zone.name
	prompt.HoldDuration = 1.2
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = mound

	local dug = false
	prompt.Triggered:Connect(function(player)
		local data = sessions[player]
		if dug or not data then
			return
		end
		dug = true
		local multiplier = Config.PALAS[data.Pala].multiplier
		if Config.hasElement(data.Equipped, "Tierra") then
			multiplier *= Config.DIG_EARTH_BONUS
		end
		local amount = math.floor(zone.value * multiplier + 0.5)
		data.Coins += amount
		local text = ("+%d 🪙"):format(amount)
		if rng:NextNumber() < Config.DIG_GOLOSINA_CHANCE then
			data.Golosinas += 1
			text ..= "  +1 🍬"
		end
		sync(player)
		notify(player, text, "exito")
		digCounts[zoneId] -= 1
		mound:Destroy()
	end)

	digCounts[zoneId] = (digCounts[zoneId] or 0) + 1
	mound.Parent = world.folders.Excavaciones
end

task.spawn(function()
	while true do
		for _, zoneId in Config.DIG_ORDER do
			if (digCounts[zoneId] or 0) < Config.DIG_ZONES[zoneId].max then
				spawnDig(zoneId)
			end
		end
		task.wait(Config.DIG_RESPAWN_INTERVAL)
	end
end)

---------------------------------------------------------------------
-- Portal para salir del subsuelo
---------------------------------------------------------------------
if world.returnPortal then
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Subir"
	prompt.ObjectText = "Volver a la superficie"
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = world.returnPortal
	prompt.Triggered:Connect(function(player)
		local character = player.Character
		if character then
			character:PivotTo(world.returnCFrame)
		end
	end)
end

---------------------------------------------------------------------
-- Jefes
---------------------------------------------------------------------
type Boss = {
	id: string,
	model: Model,
	body: BasePart,
	health: number,
	alive: boolean,
	contributors: { [Player]: boolean },
	lastAttack: number,
	lastActive: number,
	bar: Frame,
	label: TextLabel,
}

local bosses: { [string]: Boss } = {}

local function updateBossBar(boss: Boss)
	local config = Config.BOSSES[boss.id]
	boss.bar.Size = UDim2.fromScale(math.clamp(boss.health / config.health, 0, 1), 1)
	boss.label.Text = ("%s  %d/%d"):format(config.name, math.max(0, math.ceil(boss.health)), config.health)
	boss.model:SetAttribute("Health", boss.health)
end

local function createBoss(bossId: string)
	local config = Config.BOSSES[bossId]
	local model = CreatureModel.build(config.look, {
		anchored = true,
		scale = config.scale,
		color = config.color,
		accent = config.accent,
		name = config.name,
	})
	local body = model.PrimaryPart :: BasePart
	model:PivotTo(world.bossSpots[bossId])
	model:SetAttribute("BossId", bossId)
	model:SetAttribute("MaxHealth", config.health)

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(260, 46)
	gui.StudsOffset = Vector3.new(0, config.scale * 0.8, 0)
	gui.MaxDistance = 200
	gui.Parent = body
	local back = Instance.new("Frame")
	back.Size = UDim2.new(1, 0, 0, 18)
	back.Position = UDim2.fromOffset(0, 26)
	back.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
	back.Parent = gui
	local bar = Instance.new("Frame")
	bar.BackgroundColor3 = Color3.fromRGB(230, 60, 60)
	bar.BorderSizePixel = 0
	bar.Parent = back
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 24)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Parent = gui

	local boss: Boss = {
		id = bossId,
		model = model,
		body = body,
		health = config.health,
		alive = true,
		contributors = {},
		lastAttack = os.clock(),
		lastActive = os.clock(),
		bar = bar,
		label = label,
	}
	updateBossBar(boss)
	model.Parent = world.folders.Jefes
	bosses[bossId] = boss
end

local function defeatBoss(boss: Boss)
	local config = Config.BOSSES[boss.id]
	boss.alive = false
	boss.model.Parent = nil
	for player in boss.contributors do
		local data = sessions[player]
		if data and player.Parent then
			data.Coins += config.reward
			local newUnlock = not data.Unlocks[config.gate]
			data.Unlocks[config.gate] = true
			sync(player)
			if newUnlock then
				notify(player, ("¡Derrotaste al %s! Ya puedes entrar a: %s"):format(config.name, Config.GATES[config.gate].name), "exito")
			else
				notify(player, ("¡Derrotaste al %s! +%d 🪙"):format(config.name, config.reward), "exito")
			end
			task.spawn(saveData, player)
		end
	end
	boss.contributors = {}
	task.delay(Config.BOSS_RESPAWN_TIME, function()
		boss.health = config.health
		boss.alive = true
		updateBossBar(boss)
		boss.model.Parent = world.folders.Jefes
	end)
end

local function bossAttack(boss: Boss)
	local config = Config.BOSSES[boss.id]
	local targets = {}
	for _, player in Players:GetPlayers() do
		local root = getRoot(player)
		if root and (root.Position - boss.body.Position).Magnitude < Config.BOSS_AGGRO_RANGE then
			table.insert(targets, root)
		end
	end
	if #targets == 0 then
		return false
	end
	local target = targets[rng:NextInteger(1, #targets)]
	local center = target.Position
	local warning = WorldBuilder.part({
		Name = "Ataque",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * Config.BOSS_ATTACK_RADIUS * 2,
		CFrame = CFrame.new(center),
		Material = Enum.Material.Neon,
		Color = config.accent,
		Transparency = 0.75,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = workspace,
	})
	task.delay(1.2, function()
		warning:Destroy()
		if not boss.alive then
			return
		end
		for _, player in Players:GetPlayers() do
			local root = getRoot(player)
			if root and (root.Position - center).Magnitude <= Config.BOSS_ATTACK_RADIUS then
				local humanoid = (root.Parent :: Model):FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid:TakeDamage(config.damage)
				end
			end
		end
	end)
	return true
end

for bossId in Config.BOSSES do
	createBoss(bossId)
end

task.spawn(function()
	while true do
		task.wait(0.5)
		local now = os.clock()
		for _, boss in bosses do
			if boss.alive then
				if now - boss.lastAttack >= Config.BOSS_ATTACK_INTERVAL then
					boss.lastAttack = now
					if bossAttack(boss) then
						boss.lastActive = now
					end
				end
				-- Si nadie pelea, se cura
				if now - boss.lastActive > 15 and boss.health < Config.BOSSES[boss.id].health then
					boss.health = Config.BOSSES[boss.id].health
					boss.contributors = {}
					updateBossBar(boss)
				end
			end
		end
	end
end)

local lastHit: { [Player]: number } = {}
attackEvent.OnServerEvent:Connect(function(player, bossId)
	if typeof(bossId) ~= "string" then
		return
	end
	local boss = bosses[bossId]
	local data = sessions[player]
	local root = getRoot(player)
	if not boss or not boss.alive or not data or not root then
		return
	end
	local now = os.clock()
	if lastHit[player] and now - lastHit[player] < Config.ATTACK.cooldown then
		return
	end
	local config = Config.BOSSES[bossId]
	if (root.Position - boss.body.Position).Magnitude > config.scale / 2 + Config.ATTACK.range then
		return
	end
	lastHit[player] = now

	local damage = Config.ATTACK.unmountedDamage
	local creature = Config.CREATURES[data.Equipped]
	if creature then
		damage = Config.RARITIES[creature.rarity].damage
	end
	boss.health -= damage
	boss.contributors[player] = true
	boss.lastActive = now
	updateBossBar(boss)
	if boss.health <= 0 then
		defeatBoss(boss)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastHit[player] = nil
	for _, boss in bosses do
		boss.contributors[player] = nil
	end
end)

---------------------------------------------------------------------
-- Oxígeno (bajo el agua y en el subsuelo)
---------------------------------------------------------------------
task.spawn(function()
	while true do
		task.wait(Config.OXYGEN_TICK)
		for _, player in Players:GetPlayers() do
			local data = sessions[player]
			local character = player.Character
			local head = character and character:FindFirstChild("Head") :: BasePart?
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if data and head and humanoid and humanoid.Health > 0 then
				local tank = if data.Tanque > 0 then Config.TANQUES[data.Tanque].multiplier else 1
				local maxOxygen = Config.MAX_OXYGEN * tank
				local oxygen = player:GetAttribute("Oxygen") or maxOxygen
				local element, depthFactor = Config.getOxygenEnvironment(head.Position)
				if element then
					local air = Config.getAirMultiplier(data.Equipped, element)
					oxygen -= Config.OXYGEN_DRAIN * depthFactor / air
					if oxygen <= 0 then
						oxygen = 0
						humanoid:TakeDamage(Config.DROWN_DAMAGE)
					end
				else
					oxygen += Config.OXYGEN_REGEN
				end
				player:SetAttribute("Oxygen", math.clamp(oxygen, 0, maxOxygen))
				player:SetAttribute("MaxOxygen", maxOxygen)
			end
		end
	end
end)

---------------------------------------------------------------------
-- Montar / tienda / inventario
---------------------------------------------------------------------
equipRemote.OnServerInvoke = function(player, creatureId)
	local data = sessions[player]
	if not data then
		return false, "Cargando..."
	end
	if creatureId == "" or creatureId == nil then
		data.Equipped = ""
	elseif typeof(creatureId) == "string" and data.Owned[creatureId] then
		data.Equipped = creatureId
	else
		return false, "No tienes esa criatura"
	end
	sync(player)
	attachMount(player)
	if data.Equipped == "" then
		return true, "Te bajaste de tu criatura"
	end
	return true, "Montando a " .. Config.CREATURES[data.Equipped].name
end

buyRemote.OnServerInvoke = function(player, itemId)
	local data = sessions[player]
	if not data then
		return false, "Cargando..."
	end
	local item
	for _, entry in Config.SHOP do
		if entry.id == itemId then
			item = entry
		end
	end
	if not item then
		return false, "Objeto inválido"
	end
	if item.kind == "pala" and data.Pala >= item.tier then
		return false, "Ya tienes una pala igual o mejor"
	elseif item.kind == "radar" and data.Radar then
		return false, "Ya tienes el radar"
	elseif item.kind == "tanque" and data.Tanque >= item.tier then
		return false, "Ya tienes un tanque igual o mejor"
	end
	if data.Coins < item.price then
		return false, ("Te faltan %d 🪙"):format(item.price - data.Coins)
	end

	data.Coins -= item.price
	if item.kind == "golosina" then
		data.Golosinas += item.amount
	elseif item.kind == "pala" then
		data.Pala = item.tier
	elseif item.kind == "radar" then
		data.Radar = true
	elseif item.kind == "tanque" then
		data.Tanque = item.tier
	end
	sync(player)
	return true, "¡Compraste " .. item.name .. "!"
end

inventoryRemote.OnServerInvoke = function(player)
	local data = sessions[player]
	return if data then data.Owned else nil
end
