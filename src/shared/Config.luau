--!strict
-- Configuración compartida entre servidor y cliente.
-- Cambia estos valores para ajustar el juego a tu gusto.

local Config = {}

-- Monedas
Config.COIN_VALUE = 1 -- valor de una moneda normal
Config.GOLD_COIN_VALUE = 5 -- valor de una moneda dorada
Config.GOLD_CHANCE = 0.05 -- probabilidad de moneda dorada en el suelo
Config.HIGH_ALTITUDE = 12 -- por encima de esta altura las monedas siempre son doradas
Config.MAX_COINS = 30 -- máximo de monedas en el mapa a la vez
Config.SPAWN_INTERVAL = 1 -- segundos entre cada aparición de moneda

-- Mapa
Config.ARENA_SIZE = 200 -- tamaño del suelo (studs)
Config.PLATFORM_COUNT = 14 -- número de plataformas flotantes

-- Guardado
Config.DATASTORE_NAME = "CazaMonedas_v1"
Config.AUTOSAVE_INTERVAL = 60 -- segundos

-- Valores base del personaje
Config.BASE_WALKSPEED = 16
Config.BASE_JUMPPOWER = 50

-- Mejoras de la tienda
export type Upgrade = {
	id: string,
	name: string,
	description: string,
	basePrice: number,
	maxLevel: number,
	perLevel: number,
}

Config.UPGRADE_ORDER = { "Speed", "Jump" }

Config.UPGRADES = {
	Speed = {
		id = "Speed",
		name = "Velocidad",
		description = "+4 de velocidad al caminar",
		basePrice = 10,
		maxLevel = 6,
		perLevel = 4,
	},
	Jump = {
		id = "Jump",
		name = "Salto",
		description = "+10 de potencia de salto",
		basePrice = 15,
		maxLevel = 6,
		perLevel = 10,
	},
} :: { [string]: Upgrade }

-- El precio sube con cada nivel comprado.
function Config.getPrice(upgrade: Upgrade, currentLevel: number): number
	return upgrade.basePrice * (currentLevel + 1)
end

return Config
