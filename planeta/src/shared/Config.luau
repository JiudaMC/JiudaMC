-- Configuración compartida entre servidor y cliente.
-- Aquí puedes cambiar criaturas, jefes, objetos, precios y el tamaño del planeta.

local Config = {}

---------------------------------------------------------------------
-- Planeta (todas las distancias se miden desde el centro)
---------------------------------------------------------------------
Config.PLANET_CENTER = Vector3.zero
Config.WATER_RADIUS = 300 -- nivel del mar
Config.SEABED_RADIUS = 282 -- fondo del océano
Config.ROCK_RADIUS = 276 -- roca entre el fondo del mar y la cueva
Config.CAVE_OUTER = 255 -- techo del subsuelo
Config.CAVE_INNER = 225 -- suelo del subsuelo (núcleo)
Config.SKY_MIN = 340 -- por encima de esto estás "en el cielo"
Config.ISLAND_MIN = 370 -- altura mínima de las islas flotantes
Config.ISLAND_MAX = 430 -- altura máxima de las islas flotantes
Config.MAX_ALTITUDE = 650 -- no se puede volar más lejos que esto

Config.GRAVITY = 120 -- fuerza de gravedad hacia el centro del planeta
Config.JUMP_SPEED = 45

-- Continentes: bolas de tierra que salen del océano
Config.CONTINENTS = {
	{ direction = Vector3.new(0, 1, 0), radius = 200, depth = 110, footprint = 95 }, -- continente principal (inicio)
	{ direction = Vector3.new(1, -0.15, 0.25).Unit, radius = 150, depth = 160, footprint = 68 },
	{ direction = Vector3.new(-0.55, -0.5, -0.65).Unit, radius = 150, depth = 160, footprint = 68 },
	{ direction = Vector3.new(-0.3, -0.85, 0.45).Unit, radius = 130, depth = 180, footprint = 58 },
}

Config.SHAFT_DIRECTION = Vector3.new(0.15, 1, 0.1).Unit -- agujero al subsuelo (cerca del inicio)
Config.FOSA_DIRECTION = Vector3.new(0, 0.3, 1).Unit -- fosa abisal (en el océano)
Config.FOSA_RADIUS = 22
Config.TEMPLE_DIRECTION = Vector3.new(0.7, 0.7, 0).Unit -- templo celeste (isla flotante)
Config.TEMPLE_DISTANCE = 410

---------------------------------------------------------------------
-- Guardado y valores iniciales
---------------------------------------------------------------------
Config.DATASTORE_NAME = "PlanetaCriaturas_v1"
Config.AUTOSAVE_INTERVAL = 60
Config.START = { Coins = 30, Golosinas = 3 }

---------------------------------------------------------------------
-- Oxígeno
---------------------------------------------------------------------
-- Se gasta bajo el agua y en el subsuelo; entre más profundo, más rápido.
Config.MAX_OXYGEN = 100
Config.OXYGEN_TICK = 0.5
Config.OXYGEN_DRAIN = 4 -- ~12 s de aire en la superficie del mar sin criatura
Config.OXYGEN_DEPTH_STEP = 20 -- cada 20 studs de profundidad se gasta +100% más rápido
Config.OXYGEN_REGEN = 10
Config.DROWN_DAMAGE = 10

---------------------------------------------------------------------
-- Elementos
---------------------------------------------------------------------
Config.ELEMENT_ORDER = { "Agua", "Tierra", "Cielo" }

Config.ELEMENTS = {
	Agua = { name = "Agua", emoji = "🌊", ability = "Más aire bajo el agua y nadas rápido" },
	Tierra = { name = "Tierra", emoji = "⛰️", ability = "Más aire en el subsuelo, corres más y excavas mejor" },
	Cielo = { name = "Cielo", emoji = "☁️", ability = "Puedes volar (F o botón Volar)" },
}

---------------------------------------------------------------------
-- Rarezas
---------------------------------------------------------------------
Config.MOUNT_SCALE = 2.2

-- air: cuánto multiplica tu aire una criatura del elemento correcto (agua bajo el mar, tierra en el subsuelo)
-- flyCeiling: altura máxima (desde el centro) a la que vuela una criatura de cielo
Config.RARITIES = {
	Comun = {
		name = "Común",
		color = Color3.fromRGB(190, 190, 190),
		scale = 1.6,
		speed = 1,
		damage = 10,
		air = 2.5,
		flyCeiling = 395,
	},
	Raro = {
		name = "Raro",
		color = Color3.fromRGB(80, 170, 255),
		scale = 2.0,
		speed = 1.15,
		damage = 18,
		air = 6,
		flyCeiling = 470,
	},
	Legendario = {
		name = "Legendario",
		color = Color3.fromRGB(255, 190, 40),
		scale = 2.6,
		speed = 1.3,
		damage = 30,
		air = math.huge,
		flyCeiling = 650,
	},
}

---------------------------------------------------------------------
-- Criaturas
--   Comunes: 1 elemento · Raras: 2 elementos · Legendarias: los 3
---------------------------------------------------------------------
Config.CREATURE_ORDER = {
	"Burbuja",
	"Medusin",
	"Topito",
	"Piedron",
	"Plumin",
	"Nubecita",
	"Delfalado",
	"Grifito",
	"Cangrejon",
	"Dracolux",
	"TitanEsmeralda",
}

Config.CREATURES = {
	Burbuja = {
		name = "Burbuja",
		rarity = "Comun",
		elements = { "Agua" },
		color = Color3.fromRGB(90, 170, 255),
		accent = Color3.fromRGB(200, 235, 255),
	},
	Medusin = {
		name = "Medusín",
		rarity = "Comun",
		elements = { "Agua" },
		color = Color3.fromRGB(200, 120, 255),
		accent = Color3.fromRGB(255, 200, 255),
	},
	Topito = {
		name = "Topito",
		rarity = "Comun",
		elements = { "Tierra" },
		color = Color3.fromRGB(140, 95, 60),
		accent = Color3.fromRGB(230, 190, 150),
	},
	Piedron = {
		name = "Piedrón",
		rarity = "Comun",
		elements = { "Tierra" },
		color = Color3.fromRGB(130, 130, 140),
		accent = Color3.fromRGB(90, 90, 100),
	},
	Plumin = {
		name = "Plumín",
		rarity = "Comun",
		elements = { "Cielo" },
		color = Color3.fromRGB(255, 235, 120),
		accent = Color3.fromRGB(255, 170, 60),
	},
	Nubecita = {
		name = "Nubecita",
		rarity = "Comun",
		elements = { "Cielo" },
		color = Color3.fromRGB(240, 245, 255),
		accent = Color3.fromRGB(170, 200, 255),
	},
	Delfalado = {
		name = "Delfalado",
		rarity = "Raro",
		elements = { "Agua", "Cielo" },
		color = Color3.fromRGB(70, 200, 220),
		accent = Color3.fromRGB(255, 255, 255),
	},
	Grifito = {
		name = "Grifito",
		rarity = "Raro",
		elements = { "Tierra", "Cielo" },
		color = Color3.fromRGB(220, 160, 60),
		accent = Color3.fromRGB(255, 240, 200),
	},
	Cangrejon = {
		name = "Cangrejón",
		rarity = "Raro",
		elements = { "Agua", "Tierra" },
		color = Color3.fromRGB(230, 80, 60),
		accent = Color3.fromRGB(255, 200, 150),
	},
	Dracolux = {
		name = "Dracolux",
		rarity = "Legendario",
		elements = { "Agua", "Tierra", "Cielo" },
		color = Color3.fromRGB(120, 60, 255),
		accent = Color3.fromRGB(255, 215, 0),
	},
	TitanEsmeralda = {
		name = "Titán Esmeralda",
		rarity = "Legendario",
		elements = { "Agua", "Tierra", "Cielo" },
		color = Color3.fromRGB(40, 200, 120),
		accent = Color3.fromRGB(200, 255, 220),
	},
}

function Config.hasElement(creatureId: string?, element: string): boolean
	local creature = creatureId and Config.CREATURES[creatureId]
	if not creature then
		return false
	end
	return table.find(creature.elements, element) ~= nil
end

function Config.getCreatureSize(creatureId: string): number
	local creature = Config.CREATURES[creatureId]
	return Config.RARITIES[creature.rarity].scale * Config.MOUNT_SCALE
end

-- Altura del centro del cuerpo de la criatura sobre el suelo
function Config.getCreatureLift(creatureId: string, size: number?): number
	local s = size or Config.getCreatureSize(creatureId)
	return if Config.hasElement(creatureId, "Tierra") then 0.675 * s else 0.5 * s
end

-- Posición de la montura respecto al jugador
function Config.getMountGeometry(creatureId: string)
	local s = Config.getCreatureSize(creatureId)
	local bodyDrop = 1 + 0.35 * s -- distancia del torso del jugador al centro de la criatura
	return {
		bodyDrop = bodyDrop,
		rideHeight = bodyDrop + Config.getCreatureLift(creatureId, s), -- torso del jugador sobre el suelo
	}
end

-- Velocidades según la criatura montada (nil = a pie)
function Config.getSpeeds(creatureId: string?)
	local creature = creatureId and Config.CREATURES[creatureId]
	if not creature then
		return { walk = 16, swim = 14, fly = nil }
	end
	local bonus = Config.RARITIES[creature.rarity].speed
	return {
		walk = (22 + (if Config.hasElement(creatureId, "Tierra") then 10 else 0)) * bonus,
		swim = (if Config.hasElement(creatureId, "Agua") then 32 else 14) * bonus,
		fly = if Config.hasElement(creatureId, "Cielo") then 50 * bonus else nil,
	}
end

-- Altura máxima de vuelo (distancia al centro). nil = no puede volar.
function Config.getFlyCeiling(creatureId: string?): number?
	if not Config.hasElement(creatureId, "Cielo") then
		return nil
	end
	local creature = Config.CREATURES[creatureId :: string]
	return math.min(Config.RARITIES[creature.rarity].flyCeiling, Config.MAX_ALTITUDE)
end

-- ¿Dónde se gasta oxígeno? Devuelve el elemento que protege ("Agua"/"Tierra")
-- y cuánto más rápido se gasta por la profundidad. nil = respiras normal.
function Config.getOxygenEnvironment(position: Vector3): (string?, number)
	local r = (position - Config.PLANET_CENTER).Magnitude
	if Config.isWater(position) then
		return "Agua", 1 + math.max(0, Config.WATER_RADIUS - r) / Config.OXYGEN_DEPTH_STEP
	end
	if r < Config.CAVE_OUTER + 2 then
		return "Tierra", 1.5 + math.max(0, Config.CAVE_OUTER - r) / Config.OXYGEN_DEPTH_STEP
	end
	return nil, 1
end

-- Cuánto multiplica tu aire la criatura montada en ese entorno
function Config.getAirMultiplier(creatureId: string?, element: string): number
	if not Config.hasElement(creatureId, element) then
		return 1
	end
	local creature = Config.CREATURES[creatureId :: string]
	return Config.RARITIES[creature.rarity].air
end

---------------------------------------------------------------------
-- Hábitats: dónde aparecen las criaturas salvajes
--   kind: "suelo" camina por los continentes, "agua" nada en el océano,
--   "aire" vuela en el cielo, "cueva" camina por el subsuelo, "fijo" flota en su sitio
---------------------------------------------------------------------
Config.HABITAT_ORDER = { "Pradera", "Mar", "Cielo", "Cueva", "Fosa", "Templo" }

Config.HABITATS = {
	Pradera = {
		name = "Pradera",
		kind = "suelo",
		spawn = "Pradera",
		max = 10,
		speed = 5,
		creatures = { Topito = 35, Piedron = 25, Plumin = 25, Nubecita = 15 },
	},
	Mar = {
		name = "Océano",
		kind = "agua",
		spawn = "Mar",
		max = 8,
		speed = 6,
		creatures = { Burbuja = 40, Medusin = 38, Delfalado = 12, Cangrejon = 10 },
	},
	Cielo = {
		name = "Cielo",
		kind = "aire",
		spawn = "Cielo",
		max = 6,
		speed = 8,
		creatures = { Nubecita = 30, Plumin = 20, Grifito = 35, Delfalado = 15 },
	},
	Cueva = {
		name = "Subsuelo",
		kind = "cueva",
		spawn = "Cueva",
		max = 6,
		speed = 4,
		creatures = { Piedron = 30, Topito = 20, Cangrejon = 35, Grifito = 15 },
	},
	Fosa = {
		name = "Fosa Abisal",
		kind = "fijo",
		spawn = "Fosa",
		max = 2,
		speed = 0,
		creatures = { Medusin = 45, Delfalado = 35, TitanEsmeralda = 20 },
	},
	Templo = {
		name = "Templo Celeste",
		kind = "fijo",
		spawn = "Templo",
		max = 2,
		speed = 0,
		creatures = { Nubecita = 40, Grifito = 40, Dracolux = 20 },
	},
}
Config.WILD_RESPAWN_INTERVAL = 3

---------------------------------------------------------------------
-- Domar criaturas
---------------------------------------------------------------------
Config.TAMING = {
	Comun = { golosinas = 1, chance = 0.8, hold = 1.5 },
	Raro = { golosinas = 3, chance = 0.5, hold = 3 },
	Legendario = { golosinas = 8, chance = 0.3, hold = 5 },
}

---------------------------------------------------------------------
-- Excavaciones (tesoros enterrados)
---------------------------------------------------------------------
Config.DIG_ORDER = { "Pradera", "Mar", "Cueva", "Islas", "Fosa", "Templo" }

Config.DIG_ZONES = {
	Pradera = { name = "Pradera", spawn = "Pradera", value = 3, max = 12 },
	Mar = { name = "Océano", spawn = "MarFondo", value = 8, max = 8 },
	Cueva = { name = "Subsuelo", spawn = "Cueva", value = 12, max = 8 },
	Islas = { name = "Islas del cielo", spawn = "Islas", value = 15, max = 8 },
	Fosa = { name = "Fosa Abisal", spawn = "FosaFondo", value = 30, max = 3 },
	Templo = { name = "Templo Celeste", spawn = "Templo", value = 30, max = 3 },
}
Config.DIG_RESPAWN_INTERVAL = 2
Config.DIG_GOLOSINA_CHANCE = 0.2
Config.DIG_EARTH_BONUS = 1.5 -- montando una criatura de Tierra

---------------------------------------------------------------------
-- Tienda
---------------------------------------------------------------------
Config.PALAS = {
	{ name = "Pala de madera", multiplier = 1 },
	{ name = "Pala de hierro", multiplier = 2 },
	{ name = "Pala de diamante", multiplier = 4 },
}

Config.TANQUES = {
	{ name = "Tanque de oxígeno", multiplier = 2 },
	{ name = "Tanque de oxígeno II", multiplier = 3 },
}

Config.SHOP = {
	{ id = "Golosina1", name = "Golosina", description = "Sirve para domar criaturas", price = 10, kind = "golosina", amount = 1 },
	{ id = "Golosina5", name = "5 Golosinas", description = "Paquete con descuento", price = 45, kind = "golosina", amount = 5 },
	{ id = "PalaHierro", name = "Pala de hierro", description = "x2 monedas al excavar", price = 200, kind = "pala", tier = 2 },
	{ id = "PalaDiamante", name = "Pala de diamante", description = "x4 monedas al excavar", price = 1000, kind = "pala", tier = 3 },
	{ id = "Radar", name = "Radar", description = "Marca la criatura y el tesoro más cercanos", price = 150, kind = "radar" },
	{ id = "Tanque1", name = "Tanque de oxígeno", description = "Aguantas el doble bajo el agua", price = 120, kind = "tanque", tier = 1 },
	{ id = "Tanque2", name = "Tanque de oxígeno II", description = "Aguantas el triple bajo el agua", price = 400, kind = "tanque", tier = 2 },
}

---------------------------------------------------------------------
-- Jefes: cada uno cierra el paso a una zona
---------------------------------------------------------------------
Config.GATE_ORDER = { "Subsuelo", "Fosa", "Templo" }

Config.GATES = {
	Subsuelo = { name = "Subsuelo", boss = "Roca" },
	Fosa = { name = "Fosa Abisal", boss = "Marino" },
	Templo = { name = "Templo Celeste", boss = "Celeste" },
}

Config.BOSSES = {
	Roca = {
		name = "Guardián de Roca",
		look = "Piedron",
		color = Color3.fromRGB(90, 80, 75),
		accent = Color3.fromRGB(255, 120, 40),
		scale = 11,
		health = 400,
		damage = 15,
		gate = "Subsuelo",
		reward = 100,
	},
	Marino = {
		name = "Guardián Abisal",
		look = "Medusin",
		color = Color3.fromRGB(30, 60, 140),
		accent = Color3.fromRGB(0, 255, 200),
		scale = 11,
		health = 900,
		damage = 20,
		gate = "Fosa",
		reward = 250,
	},
	Celeste = {
		name = "Guardián Celeste",
		look = "Grifito",
		color = Color3.fromRGB(240, 240, 255),
		accent = Color3.fromRGB(120, 200, 255),
		scale = 11,
		health = 1500,
		damage = 25,
		gate = "Templo",
		reward = 500,
	},
}

Config.ATTACK = {
	unmountedDamage = 5,
	cooldown = 0.5,
	range = 30, -- distancia extra a la superficie del jefe
}
Config.BOSS_ATTACK_INTERVAL = 3
Config.BOSS_ATTACK_RADIUS = 12
Config.BOSS_AGGRO_RANGE = 80
Config.BOSS_RESPAWN_TIME = 30

---------------------------------------------------------------------
-- Utilidades
---------------------------------------------------------------------

-- CFrame en `position` cuyo "arriba" es `up`, mirando hacia `look` (opcional)
function Config.uprightCFrame(position: Vector3, up: Vector3, look: Vector3?): CFrame
	local ref = look or (if math.abs(up.Y) < 0.95 then Vector3.yAxis else Vector3.xAxis)
	local forward = ref - up * ref:Dot(up)
	if forward.Magnitude < 1e-3 then
		local alt = if math.abs(up.X) < 0.95 then Vector3.xAxis else Vector3.zAxis
		forward = alt - up * alt:Dot(up)
	end
	return CFrame.lookAt(position, position + forward.Unit, up)
end

-- ¿Hay agua del terreno en esta posición?
function Config.isWater(position: Vector3): boolean
	local min = Vector3.new(math.floor(position.X / 4) * 4, math.floor(position.Y / 4) * 4, math.floor(position.Z / 4) * 4)
	local ok, materials = pcall(function()
		return workspace.Terrain:ReadVoxels(Region3.new(min, min + Vector3.new(4, 4, 4)), 4)
	end)
	return ok and materials[1][1][1] == Enum.Material.Water
end

function Config.getZone(position: Vector3): string
	local r = (position - Config.PLANET_CENTER).Magnitude
	if r > Config.SKY_MIN then
		return "Cielo"
	end
	if r < Config.CAVE_OUTER + 2 then
		return "Subsuelo"
	end
	if Config.isWater(position) then
		return "Océano"
	end
	return "Superficie"
end

return Config
