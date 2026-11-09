-- Configuración compartida entre servidor y cliente.
-- Aquí puedes cambiar criaturas, huevos, precios, tamaños del mundo, etc.

local Config = {}

---------------------------------------------------------------------
-- Mundo
---------------------------------------------------------------------
Config.WORLD_SIZE = 1024 -- el mundo da la vuelta: al pasar el borde apareces del otro lado
Config.SEA_LEVEL = 0
Config.LAND_RADIUS = 190 -- radio del continente central
Config.GRASS_TOP = 7 -- altura aproximada del suelo del continente
Config.SKY_HEIGHT = 80 -- por encima de esto estás "en el cielo"

-- Cueva del subsuelo (debajo del continente)
Config.CAVE_TOP = -23
Config.CAVE_BOTTOM = -47
Config.CAVE_HALF = 100 -- la cueva mide 200 x 200
Config.SHAFT_POSITION = Vector3.new(80, 0, 80) -- agujero que baja a la cueva

---------------------------------------------------------------------
-- Guardado
---------------------------------------------------------------------
Config.DATASTORE_NAME = "PlanetaCriaturas_v1"
Config.AUTOSAVE_INTERVAL = 60

---------------------------------------------------------------------
-- Habilidades
---------------------------------------------------------------------
Config.BASE_WALKSPEED = 16
Config.EARTH_SPEED_BONUS = 8 -- criaturas de Tierra: corres más
Config.FLY_SPEED = 60 -- criaturas de Cielo: velocidad de vuelo

Config.MAX_OXYGEN = 100
Config.OXYGEN_TICK = 0.5 -- segundos entre comprobaciones
Config.OXYGEN_DRAIN = 4 -- oxígeno perdido por comprobación bajo el agua (~12 s de aire)
Config.OXYGEN_REGEN = 10
Config.DROWN_DAMAGE = 10

---------------------------------------------------------------------
-- Elementos
---------------------------------------------------------------------
Config.ELEMENT_ORDER = { "Agua", "Tierra", "Cielo" }

Config.ELEMENTS = {
	Agua = {
		name = "Agua",
		emoji = "🌊",
		color = Color3.fromRGB(60, 150, 255),
		ability = "Respiras bajo el agua",
	},
	Tierra = {
		name = "Tierra",
		emoji = "⛰️",
		color = Color3.fromRGB(150, 105, 60),
		ability = "Excavas rocas y corres más rápido",
	},
	Cielo = {
		name = "Cielo",
		emoji = "☁️",
		color = Color3.fromRGB(200, 230, 255),
		ability = "Pulsa F para volar",
	},
}

---------------------------------------------------------------------
-- Rarezas
---------------------------------------------------------------------
Config.RARITIES = {
	Comun = { name = "Común", color = Color3.fromRGB(190, 190, 190), multiplier = 1, scale = 1.6 },
	Raro = { name = "Raro", color = Color3.fromRGB(80, 170, 255), multiplier = 1.5, scale = 2.0 },
	Legendario = { name = "Legendario", color = Color3.fromRGB(255, 190, 40), multiplier = 2, scale = 2.6 },
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

function Config.getMultiplier(creatureId: string?): number
	local creature = creatureId and Config.CREATURES[creatureId]
	if not creature then
		return 1
	end
	return Config.RARITIES[creature.rarity].multiplier
end

---------------------------------------------------------------------
-- Huevos (cada uno está en una zona distinta del mundo)
---------------------------------------------------------------------
Config.EGG_ORDER = { "Basico", "Abisal", "Mistico", "Celestial" }

Config.EGGS = {
	Basico = {
		name = "Huevo Básico",
		price = 25,
		color = Color3.fromRGB(245, 240, 220),
		requires = nil, -- está junto al punto de inicio
		pool = {
			{ id = "Burbuja", weight = 15 },
			{ id = "Medusin", weight = 15 },
			{ id = "Topito", weight = 15 },
			{ id = "Piedron", weight = 15 },
			{ id = "Plumin", weight = 15 },
			{ id = "Nubecita", weight = 15 },
			{ id = "Delfalado", weight = 3 },
			{ id = "Grifito", weight = 3 },
			{ id = "Cangrejon", weight = 3 },
			{ id = "Dracolux", weight = 0.7 },
			{ id = "TitanEsmeralda", weight = 0.3 },
		},
	},
	Abisal = {
		name = "Huevo Abisal",
		price = 150,
		color = Color3.fromRGB(40, 110, 200),
		requires = "Agua", -- en el fondo del océano
		pool = {
			{ id = "Burbuja", weight = 30 },
			{ id = "Medusin", weight = 30 },
			{ id = "Delfalado", weight = 15 },
			{ id = "Cangrejon", weight = 20 },
			{ id = "Dracolux", weight = 3 },
			{ id = "TitanEsmeralda", weight = 2 },
		},
	},
	Mistico = {
		name = "Huevo Místico",
		price = 150,
		color = Color3.fromRGB(150, 70, 200),
		requires = "Tierra", -- en la cueva del subsuelo
		pool = {
			{ id = "Topito", weight = 30 },
			{ id = "Piedron", weight = 30 },
			{ id = "Grifito", weight = 15 },
			{ id = "Cangrejon", weight = 20 },
			{ id = "Dracolux", weight = 3 },
			{ id = "TitanEsmeralda", weight = 2 },
		},
	},
	Celestial = {
		name = "Huevo Celestial",
		price = 300,
		color = Color3.fromRGB(255, 230, 140),
		requires = "Cielo", -- en el templo de la isla flotante
		pool = {
			{ id = "Plumin", weight = 25 },
			{ id = "Nubecita", weight = 25 },
			{ id = "Grifito", weight = 20 },
			{ id = "Delfalado", weight = 20 },
			{ id = "Dracolux", weight = 6 },
			{ id = "TitanEsmeralda", weight = 4 },
		},
	},
}

---------------------------------------------------------------------
-- Zonas y tesoros
---------------------------------------------------------------------
Config.ZONE_ORDER = { "Superficie", "Oceano", "Subsuelo", "Cielo" }

Config.ZONES = {
	Superficie = { name = "Superficie", value = 1, max = 25, color = Color3.fromRGB(255, 220, 60) },
	Oceano = { name = "Océano", value = 4, max = 15, color = Color3.fromRGB(240, 250, 255) },
	Subsuelo = { name = "Subsuelo", value = 6, max = 15, color = Color3.fromRGB(80, 255, 230) },
	Cielo = { name = "Cielo", value = 8, max = 15, color = Color3.fromRGB(255, 150, 255) },
}

Config.TREASURE_SPAWN_INTERVAL = 0.5

function Config.getZone(position: Vector3): string
	if position.Y > Config.SKY_HEIGHT then
		return "Cielo"
	end
	if
		position.Y < Config.CAVE_TOP + 2
		and math.abs(position.X) <= Config.CAVE_HALF
		and math.abs(position.Z) <= Config.CAVE_HALF
	then
		return "Subsuelo"
	end
	local flatDistance = Vector2.new(position.X, position.Z).Magnitude
	if flatDistance > Config.LAND_RADIUS + 10 and position.Y < Config.SEA_LEVEL + 10 then
		return "Oceano"
	end
	return "Superficie"
end

return Config
