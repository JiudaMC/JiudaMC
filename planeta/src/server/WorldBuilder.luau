-- Construye el planeta: océano, continentes, subsuelo, fosa, islas del cielo y templo.
-- También da puntos aleatorios de cada zona para criaturas y tesoros.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local WorldBuilder = {}

local terrain = workspace.Terrain
local CENTER = Config.PLANET_CENTER
local rng = Random.new()
local layoutRng = Random.new(2024) -- semilla fija: el mapa sale siempre igual

local terrainParams = RaycastParams.new()
terrainParams.FilterType = Enum.RaycastFilterType.Include
terrainParams.FilterDescendantsInstances = { terrain }

local state = {
	folder = nil :: Folder?,
	folders = {} :: { [string]: Folder },
	islands = {} :: { BasePart },
	temple = nil :: BasePart?,
	fosaCenter = Vector3.zero,
	returnCFrame = CFrame.new(0, 320, 0),
	bossSpots = {} :: { [string]: CFrame },
	returnPortal = nil :: BasePart?,
}
WorldBuilder.state = state

---------------------------------------------------------------------
-- Utilidades
---------------------------------------------------------------------
function WorldBuilder.part(props: { [string]: any }): BasePart
	local part = Instance.new(props.ClassName or "Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if props.Shape then
		part.Shape = props.Shape
	end
	for key, value in props do
		if key ~= "Parent" and key ~= "Shape" and key ~= "ClassName" then
			part[key] = value
		end
	end
	part.Parent = props.Parent
	return part
end
local part = WorldBuilder.part

-- CFrame para un cilindro "acostado" en el suelo (cara plana hacia arriba)
local function flatCylinder(position: Vector3, up: Vector3): CFrame
	return Config.uprightCFrame(position, up) * CFrame.Angles(0, 0, math.rad(90))
end

function WorldBuilder.randomTangent(up: Vector3): Vector3
	local ref = if math.abs(up.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis
	local t1 = up:Cross(ref).Unit
	local t2 = up:Cross(t1)
	local angle = rng:NextNumber(0, 2 * math.pi)
	return t1 * math.cos(angle) + t2 * math.sin(angle)
end

-- Dirección desplazada `distance` studs sobre una esfera de radio `radius`
local function offsetDirection(dir: Vector3, distance: number, radius: number, random: Random?): Vector3
	local r = random or rng
	local ref = if math.abs(dir.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis
	local t1 = dir:Cross(ref).Unit
	local t2 = dir:Cross(t1)
	local angle = r:NextNumber(0, 2 * math.pi)
	local tangent = t1 * math.cos(angle) + t2 * math.sin(angle)
	return (dir * radius + tangent * distance).Unit
end
WorldBuilder.offsetDirection = offsetDirection

-- Rayo desde el cielo hacia el centro: devuelve la primera superficie del terreno
function WorldBuilder.surfaceHit(dir: Vector3, ignoreWater: boolean): RaycastResult?
	terrainParams.IgnoreWater = ignoreWater
	return workspace:Raycast(CENTER + dir * (Config.WATER_RADIUS + 60), -dir * 220, terrainParams)
end

-- Rayo desde el techo de la cueva hacia su suelo
function WorldBuilder.caveFloor(dir: Vector3): RaycastResult?
	terrainParams.IgnoreWater = true
	return workspace:Raycast(CENTER + dir * (Config.CAVE_OUTER - 4), -dir * 45, terrainParams)
end

local function sign(parent: BasePart, text: string, offset: number?)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(280, 70)
	gui.StudsOffset = Vector3.new(0, offset or 6, 0)
	gui.MaxDistance = 150
	gui.Parent = parent
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = gui
end

---------------------------------------------------------------------
-- Puntos aleatorios por zona
---------------------------------------------------------------------
local function landPoint(): (Vector3?, Vector3?)
	for _ = 1, 30 do
		local continent = Config.CONTINENTS[rng:NextInteger(1, #Config.CONTINENTS)]
		local dir = offsetDirection(continent.direction, rng:NextNumber(0, continent.footprint * 0.9), Config.WATER_RADIUS)
		local hit = WorldBuilder.surfaceHit(dir, false)
		if hit and hit.Material ~= Enum.Material.Water and (hit.Position - CENTER).Magnitude > Config.WATER_RADIUS - 1 then
			return hit.Position, dir
		end
	end
	return nil, nil
end

local function seaPoint(onFloor: boolean): (Vector3?, Vector3?)
	for _ = 1, 40 do
		local dir = rng:NextUnitVector()
		local top = WorldBuilder.surfaceHit(dir, false)
		if top and top.Material == Enum.Material.Water then
			local floor = WorldBuilder.surfaceHit(dir, true)
			local floorRadius = floor and (floor.Position - CENTER).Magnitude
			if floor and floorRadius < Config.WATER_RADIUS - 6 then
				if onFloor then
					return floor.Position, dir
				end
				return CENTER + dir * rng:NextNumber(floorRadius + 4, Config.WATER_RADIUS - 3), dir
			end
		end
	end
	return nil, nil
end

local function cavePoint(): (Vector3?, Vector3?)
	for _ = 1, 20 do
		local dir = rng:NextUnitVector()
		local hit = WorldBuilder.caveFloor(dir)
		if hit then
			return hit.Position, dir
		end
	end
	return nil, nil
end

local function islandPoint(island: BasePart?, margin: number): (Vector3?, Vector3?)
	if not island then
		return nil, nil
	end
	local up = island:GetAttribute("Up") :: Vector3
	local radius = (island:GetAttribute("Diameter") :: number) / 2 - margin
	local top = island.Position + up * 3
	return top + WorldBuilder.randomTangent(up) * rng:NextNumber(0, math.max(radius, 1)), up
end

local function fosaPoint(onFloor: boolean): (Vector3?, Vector3?)
	local dir = Config.FOSA_DIRECTION
	local point = state.fosaCenter - dir * 6 + rng:NextUnitVector() * rng:NextNumber(0, 9)
	local up = (point - CENTER).Unit
	if not onFloor then
		return point, up
	end
	terrainParams.IgnoreWater = true
	local hit = workspace:Raycast(point, -up * 40, terrainParams)
	if hit then
		return hit.Position, up
	end
	return nil, nil
end

-- Devuelve (posición, arriba). Para zonas de suelo la posición es el suelo.
function WorldBuilder.randomPoint(kind: string): (Vector3?, Vector3?)
	if kind == "Pradera" then
		return landPoint()
	elseif kind == "Mar" then
		return seaPoint(false)
	elseif kind == "MarFondo" then
		return seaPoint(true)
	elseif kind == "Cueva" then
		return cavePoint()
	elseif kind == "Cielo" then
		local dir = rng:NextUnitVector()
		return CENTER + dir * rng:NextNumber(Config.SKY_MIN + 20, Config.ISLAND_MAX), dir
	elseif kind == "Islas" then
		return islandPoint(state.islands[rng:NextInteger(1, #state.islands)], 4)
	elseif kind == "Fosa" then
		return fosaPoint(false)
	elseif kind == "FosaFondo" then
		return fosaPoint(true)
	elseif kind == "Templo" then
		return islandPoint(state.temple, 18)
	end
	return nil, nil
end

---------------------------------------------------------------------
-- Construcción
---------------------------------------------------------------------
local function makeIsland(parent: Instance, dir: Vector3, distance: number, diameter: number, color: Color3): BasePart
	local position = CENTER + dir * distance
	local top = part({
		Name = "Isla",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(6, diameter, diameter),
		CFrame = flatCylinder(position, dir),
		Material = Enum.Material.Grass,
		Color = color,
		Parent = parent,
	})
	top:SetAttribute("Up", dir)
	top:SetAttribute("Diameter", diameter)
	part({
		Name = "BaseIsla",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(12, diameter * 0.7, diameter * 0.7),
		CFrame = flatCylinder(position - dir * 8, dir),
		Material = Enum.Material.Rock,
		Color = Color3.fromRGB(120, 105, 95),
		Parent = parent,
	})
	part({
		Name = "Punta",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * diameter * 0.45,
		CFrame = CFrame.new(position - dir * 15),
		Material = Enum.Material.Rock,
		Color = Color3.fromRGB(110, 95, 85),
		Parent = parent,
	})
	return top
end

local function makeTree(parent: Instance, ground: Vector3, up: Vector3)
	local height = layoutRng:NextNumber(6, 10)
	part({
		Name = "Tronco",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, 1.6, 1.6),
		CFrame = flatCylinder(ground + up * (height / 2 - 0.5), up),
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(110, 75, 45),
		Parent = parent,
	})
	part({
		Name = "Hojas",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * layoutRng:NextNumber(6, 9),
		CFrame = CFrame.new(ground + up * (height + 1.5)),
		Material = Enum.Material.Grass,
		Color = Color3.fromHSV(layoutRng:NextNumber(0.25, 0.38), 0.6, 0.7),
		CanCollide = false,
		Parent = parent,
	})
end

local function makeCrystal(parent: Instance, ground: Vector3, up: Vector3, withLight: boolean)
	local height = layoutRng:NextNumber(3, 7)
	local color = Color3.fromHSV(layoutRng:NextNumber(0.45, 0.85), 0.7, 1)
	local crystal = part({
		Name = "Cristal",
		Size = Vector3.new(1.5, height, 1.5),
		CFrame = Config.uprightCFrame(ground + up * (height / 2 - 0.5), up)
			* CFrame.Angles(layoutRng:NextNumber(-0.3, 0.3), layoutRng:NextNumber(0, 6), layoutRng:NextNumber(-0.3, 0.3)),
		Material = Enum.Material.Neon,
		Color = color,
		CanCollide = false,
		Parent = parent,
	})
	if withLight then
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 20
		light.Brightness = 1.5
		light.Parent = crystal
	end
end

function WorldBuilder.build()
	-- Limpiar lo que trae la plantilla Baseplate
	local old = workspace:FindFirstChild("Planeta")
	if old then
		old:Destroy()
	end
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
	for _, child in workspace:GetChildren() do
		if child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end

	workspace.Gravity = 0 -- la gravedad la ponemos nosotros, hacia el centro del planeta
	Lighting.ClockTime = 14
	Lighting.Brightness = 2
	Lighting.OutdoorAmbient = Color3.fromRGB(130, 130, 145)

	local folder = Instance.new("Folder")
	folder.Name = "Planeta"
	for _, name in { "Barreras", "Islas", "Criaturas", "Jefes", "Excavaciones", "Decoracion", "Portales" } do
		local sub = Instance.new("Folder")
		sub.Name = name
		sub.Parent = folder
		state.folders[name] = sub
	end
	state.folder = folder
	local decor = state.folders.Decoracion

	-------------------------------------------------------------- Terreno
	terrain:Clear()
	terrain.WaterColor = Color3.fromRGB(30, 120, 200)
	terrain.WaterTransparency = 0.6

	terrain:FillBall(CENTER, Config.WATER_RADIUS, Enum.Material.Water)
	task.wait()
	for _, continent in Config.CONTINENTS do
		terrain:FillBall(CENTER + continent.direction * continent.depth, continent.radius, Enum.Material.Grass)
		task.wait()
	end
	terrain:FillBall(CENTER, Config.SEABED_RADIUS, Enum.Material.Sand)
	task.wait()
	terrain:FillBall(CENTER, Config.ROCK_RADIUS, Enum.Material.Rock)
	task.wait()
	-- Subsuelo: una cueva con forma de cáscara alrededor del núcleo
	terrain:FillBall(CENTER, Config.CAVE_OUTER, Enum.Material.Air)
	task.wait()
	terrain:FillBall(CENTER, Config.CAVE_INNER, Enum.Material.Slate)
	task.wait()

	-- Colinas en los continentes
	for _, continent in Config.CONTINENTS do
		for _ = 1, 5 do
			local dir = offsetDirection(continent.direction, layoutRng:NextNumber(25, continent.footprint * 0.7), Config.WATER_RADIUS, layoutRng)
			if dir:Dot(Config.SHAFT_DIRECTION) < math.cos(40 / Config.WATER_RADIUS) then
				local hit = WorldBuilder.surfaceHit(dir, true)
				if hit then
					terrain:FillBall(hit.Position - dir * 5, layoutRng:NextNumber(9, 16), Enum.Material.Grass)
				end
			end
		end
	end

	-- Fosa abisal: un hoyo profundo en el fondo del mar
	state.fosaCenter = CENTER + Config.FOSA_DIRECTION * (Config.SEABED_RADIUS + 2)
	terrain:FillBall(state.fosaCenter, Config.FOSA_RADIUS, Enum.Material.Water)

	-- Pozo que baja del continente principal al subsuelo
	local shaftDir = Config.SHAFT_DIRECTION
	terrain:FillCylinder(Config.uprightCFrame(CENTER + shaftDir * 285, shaftDir), 70, 7, Enum.Material.Air)
	task.wait()

	-------------------------------------------------------------- Inicio
	local spawnHit = WorldBuilder.surfaceHit(Vector3.yAxis, true)
	local spawnPosition = if spawnHit then spawnHit.Position else Vector3.new(0, 310, 0)
	local spawnLocation = part({
		ClassName = "SpawnLocation",
		Name = "Inicio",
		Size = Vector3.new(14, 1, 14),
		CFrame = CFrame.new(spawnPosition + Vector3.new(0, 0.5, 0)),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(255, 255, 255),
		Parent = folder,
	});
	(spawnLocation :: SpawnLocation).Duration = 0
	sign(spawnLocation, "🌍 Planeta Criaturas\nDoma criaturas, móntalas y explora", 8)

	-- Árboles
	for _ = 1, 45 do
		local ground, up = landPoint()
		if ground and up and (ground - spawnPosition).Magnitude > 25 and up:Dot(shaftDir) < math.cos(25 / Config.WATER_RADIUS) then
			makeTree(decor, ground, up)
		end
	end

	-------------------------------------------------------------- Subsuelo
	local nearShaft = WorldBuilder.surfaceHit(offsetDirection(shaftDir, 14, Config.WATER_RADIUS, layoutRng), true)
	local groundRadius = if nearShaft then (nearShaft.Position - CENTER).Magnitude else 310
	local barrier = part({
		Name = "RocaSellada",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3, 26, 26),
		CFrame = flatCylinder(CENTER + shaftDir * (groundRadius + 0.5), shaftDir),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(80, 75, 70),
		Parent = state.folders.Barreras,
	})
	barrier:SetAttribute("Gate", "Subsuelo")
	sign(barrier, "🔒 Derrota al Guardián de Roca\npara bajar al Subsuelo")

	state.returnCFrame = Config.uprightCFrame(CENTER + offsetDirection(shaftDir, 20, 1, layoutRng) * (groundRadius + 6), shaftDir)

	local portalHit = WorldBuilder.caveFloor(offsetDirection(shaftDir, 16, Config.CAVE_INNER, layoutRng))
	if portalHit then
		local up = (portalHit.Position - CENTER).Unit
		local portal = part({
			Name = "PortalSubir",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.6, 10, 10),
			CFrame = flatCylinder(portalHit.Position + up * 0.3, up),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(120, 255, 180),
			CanCollide = false,
			Parent = state.folders.Portales,
		})
		state.returnPortal = portal
		sign(portal, "⬆️ Volver a la superficie", 5)
	end

	for i = 1, 45 do
		local ground, up = cavePoint()
		if ground and up then
			makeCrystal(decor, ground, up, i % 2 == 0)
		end
	end

	-------------------------------------------------------------- Fosa
	local fosaBarrier = part({
		Name = "SelloAbisal",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, Config.FOSA_RADIUS * 2 + 8, Config.FOSA_RADIUS * 2 + 8),
		CFrame = flatCylinder(CENTER + Config.FOSA_DIRECTION * (Config.SEABED_RADIUS + 0.5), Config.FOSA_DIRECTION),
		Material = Enum.Material.ForceField,
		Color = Color3.fromRGB(0, 200, 255),
		Transparency = 0.2,
		Parent = state.folders.Barreras,
	})
	fosaBarrier:SetAttribute("Gate", "Fosa")
	sign(fosaBarrier, "🔒 Derrota al Guardián Abisal\npara entrar a la Fosa")
	for i = 1, 10 do
		local ground, up = fosaPoint(true)
		if ground and up then
			makeCrystal(decor, ground, up, i % 2 == 0)
		end
	end

	-------------------------------------------------------------- Cielo
	local templeDir = Config.TEMPLE_DIRECTION
	state.temple = makeIsland(state.folders.Islas, templeDir, Config.TEMPLE_DISTANCE, 70, Color3.fromRGB(235, 225, 190))
	local temple = state.temple :: BasePart
	temple.Name = "Templo"
	local templeTop = temple.Position + templeDir * 3
	for _, angle in { 0, 90, 180, 270 } do
		local offset = Config.uprightCFrame(templeTop, templeDir) * CFrame.Angles(0, math.rad(angle), 0) * CFrame.new(0, 0, -22)
		part({
			Name = "Pilar",
			Size = Vector3.new(3, 16, 3),
			CFrame = offset * CFrame.new(0, 8, 0),
			Material = Enum.Material.Marble,
			Color = Color3.fromRGB(250, 245, 230),
			Parent = decor,
		})
	end
	local dome = part({
		Name = "CupulaCeleste",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 60,
		CFrame = CFrame.new(templeTop),
		Material = Enum.Material.ForceField,
		Color = Color3.fromRGB(150, 220, 255),
		Transparency = 0.2,
		Parent = state.folders.Barreras,
	})
	dome:SetAttribute("Gate", "Templo")
	sign(dome, "🔒 Derrota al Guardián Celeste\npara entrar al Templo", 34)

	local placed = 0
	for _ = 1, 60 do
		if placed >= 12 then
			break
		end
		local dir = layoutRng:NextUnitVector()
		if dir:Dot(templeDir) < math.cos(math.rad(25)) then
			local island = makeIsland(
				state.folders.Islas,
				dir,
				layoutRng:NextNumber(Config.ISLAND_MIN, Config.ISLAND_MAX),
				layoutRng:NextNumber(30, 55),
				Color3.fromHSV(layoutRng:NextNumber(0.2, 0.4), 0.5, 0.75)
			)
			table.insert(state.islands, island)
			placed += 1
		end
	end

	-------------------------------------------------------------- Lugares de los jefes
	local rocaDir = offsetDirection(shaftDir, 34, Config.WATER_RADIUS, layoutRng)
	local rocaHit = WorldBuilder.surfaceHit(rocaDir, true)
	local rocaGround = if rocaHit then rocaHit.Position else CENTER + rocaDir * 310
	state.bossSpots.Roca = Config.uprightCFrame(rocaGround + rocaDir * (Config.BOSSES.Roca.scale * 0.675), rocaDir, -shaftDir)

	local marinoDir = offsetDirection(Config.FOSA_DIRECTION, 40, Config.WATER_RADIUS, layoutRng)
	state.bossSpots.Marino = Config.uprightCFrame(CENTER + marinoDir * (Config.SEABED_RADIUS + 9), marinoDir)

	local celesteDir = offsetDirection(templeDir, 60, Config.TEMPLE_DISTANCE, layoutRng)
	state.bossSpots.Celeste = Config.uprightCFrame(CENTER + celesteDir * (Config.TEMPLE_DISTANCE + 5), celesteDir)

	folder.Parent = workspace
	return state
end

return WorldBuilder
