-- Construye el modelo 3D de una criatura con piezas básicas.
-- Se usa para las criaturas salvajes, las monturas y los jefes.
-- Las partes cambian según los elementos:
--   Agua -> aletas · Tierra -> patas y orejas · Cielo -> alas · Legendaria -> corona y brillos

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local CreatureModel = {}

export type Options = {
	scale: number?,
	anchored: boolean?,
	color: Color3?,
	accent: Color3?,
	name: string?,
}

function CreatureModel.build(creatureId: string, options: Options?): Model
	local opts: Options = options or {}
	local creature = Config.CREATURES[creatureId]
	local s = opts.scale or Config.getCreatureSize(creatureId)
	local color = opts.color or creature.color
	local accent = opts.accent or creature.accent
	local legendary = creature.rarity == "Legendario"

	local model = Instance.new("Model")
	model.Name = opts.name or creatureId

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.one * s
	body.Color = color
	body.Material = Enum.Material.SmoothPlastic
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body.CanCollide = false
	body.CanTouch = false
	body.Massless = true
	body.Anchored = opts.anchored ~= false
	body.CFrame = CFrame.identity
	body.Parent = model
	model.PrimaryPart = body

	local function add(name: string, shape: string, size: Vector3, offset: CFrame, partColor: Color3, material: Enum.Material?)
		local part: BasePart
		if shape == "Wedge" then
			part = Instance.new("WedgePart")
		else
			local p = Instance.new("Part")
			p.Shape = (Enum.PartType :: any)[shape]
			part = p
		end
		part.Name = name
		part.Size = size
		part.CFrame = body.CFrame * offset
		part.Color = partColor
		part.Material = material or Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.Anchored = false
		part.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = part
		weld.Parent = part
		return part
	end

	-- Ojos
	for _, side in { -1, 1 } do
		add("Ojo", "Ball", Vector3.one * 0.22 * s, CFrame.new(side * 0.2 * s, 0.15 * s, -0.42 * s), Color3.fromRGB(20, 20, 25))
		add("Brillo", "Ball", Vector3.one * 0.07 * s, CFrame.new(side * 0.2 * s + 0.04 * s, 0.2 * s, -0.52 * s), Color3.new(1, 1, 1))
	end

	if Config.hasElement(creatureId, "Agua") then
		add("Aleta", "Wedge", Vector3.new(0.08 * s, 0.4 * s, 0.5 * s), CFrame.new(0, 0.55 * s, 0.1 * s), accent)
		add("Cola", "Wedge", Vector3.new(0.08 * s, 0.35 * s, 0.45 * s), CFrame.new(0, 0, 0.62 * s) * CFrame.Angles(math.rad(-90), 0, 0), accent)
	end

	if Config.hasElement(creatureId, "Tierra") then
		for _, x in { -1, 1 } do
			for _, z in { -1, 1 } do
				add("Pata", "Block", Vector3.new(0.22 * s, 0.35 * s, 0.22 * s), CFrame.new(x * 0.28 * s, -0.5 * s, z * 0.25 * s), accent)
			end
			add("Oreja", "Ball", Vector3.one * 0.25 * s, CFrame.new(x * 0.28 * s, 0.42 * s, 0.05 * s), accent)
		end
	end

	if Config.hasElement(creatureId, "Cielo") then
		for _, side in { -1, 1 } do
			add(
				"Ala",
				"Block",
				Vector3.new(0.75 * s, 0.08 * s, 0.45 * s),
				CFrame.new(side * 0.65 * s, 0.1 * s, 0.05 * s) * CFrame.Angles(0, 0, side * math.rad(20)),
				accent
			)
		end
	end

	if legendary then
		for i = -1, 1 do
			add("Corona", "Block", Vector3.new(0.1 * s, 0.25 * s, 0.1 * s), CFrame.new(i * 0.15 * s, 0.55 * s, -0.05 * s), accent, Enum.Material.Neon)
		end
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = accent
		sparkles.Parent = body
		local light = Instance.new("PointLight")
		light.Color = accent
		light.Range = s * 3
		light.Parent = body
	end

	return model
end

return CreatureModel
