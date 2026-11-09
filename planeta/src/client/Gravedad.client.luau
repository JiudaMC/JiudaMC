-- Control del personaje en un planeta redondo:
--   * gravedad hacia el centro del planeta
--   * caminar, saltar, nadar y volar en cualquier punto de la esfera
--   * cámara que gira con el planeta
--   * barreras de los jefes (se vuelven atravesables al desbloquear la zona)
--
-- Roblox no tiene gravedad esférica, así que el movimiento lo calculamos nosotros
-- con un LinearVelocity (velocidad) y un AlignOrientation (rotación).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local controls = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()

local CENTER = Config.PLANET_CENTER

---------------------------------------------------------------------
-- Estado
---------------------------------------------------------------------
local ctl = nil -- datos del personaje actual
local flying = false
local jumpQueued = false
local upHeld, downHeld = false, false

local cam = {
	up = Vector3.yAxis,
	forward = Vector3.new(0, 0, -1),
	pitch = math.rad(-15),
	zoom = 20,
	rotating = false,
	gamepad = Vector2.zero,
	pinchStart = 20,
}

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.IgnoreWater = true
groundParams.RespectCanCollide = true

local cameraParams = RaycastParams.new()
cameraParams.FilterType = Enum.RaycastFilterType.Exclude
cameraParams.IgnoreWater = true
cameraParams.RespectCanCollide = true

local function getEquipped(): string?
	local id = player:GetAttribute("Equipped")
	if typeof(id) == "string" and id ~= "" and Config.CREATURES[id] then
		return id
	end
	return nil
end

local function getRideHeight(): number
	local equipped = getEquipped()
	if equipped then
		return Config.getMountGeometry(equipped).rideHeight
	end
	local humanoid = ctl.humanoid :: Humanoid
	local hip = if humanoid.RigType == Enum.HumanoidRigType.R15 then humanoid.HipHeight else 2
	return hip + ctl.root.Size.Y / 2
end

---------------------------------------------------------------------
-- Animaciones (usamos las del script Animate de Roblox)
---------------------------------------------------------------------
local function playTrack(name: string)
	if ctl.trackName == name then
		return
	end
	if ctl.track then
		ctl.track:Stop(0.2)
	end
	ctl.trackName = name
	ctl.track = ctl.tracks[name]
	if ctl.track then
		ctl.track:Play(0.2)
	end
end

---------------------------------------------------------------------
-- Preparar / limpiar personaje
---------------------------------------------------------------------
local function cleanup()
	if not ctl then
		return
	end
	for _, instance in ctl.instances do
		instance:Destroy()
	end
	if ctl.track then
		ctl.track:Stop()
	end
	ctl = nil
	flying = false
end

local function setupCharacter(character: Model)
	cleanup()
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	local animator = humanoid:WaitForChild("Animator") :: Animator

	local tracks = {}
	local animate = character:WaitForChild("Animate", 3)
	if animate then
		local function load(key: string, folderName: string, animName: string)
			local folder = animate:FindFirstChild(folderName)
			local animation = folder and folder:FindFirstChild(animName)
			if animation and animation:IsA("Animation") then
				tracks[key] = animator:LoadAnimation(animation)
			end
		end
		load("idle", "idle", "Animation1")
		load("walk", "walk", "WalkAnim")
		load("run", "run", "RunAnim")
		load("jump", "jump", "JumpAnim")
		load("fall", "fall", "FallAnim")
		load("swim", "swim", "Swim")
		load("swimidle", "swimidle", "SwimIdle")
		load("sit", "sit", "SitAnim")
		local animateScript: any = animate
		animateScript.Enabled = false -- apagamos el Animate normal; las animaciones las ponemos nosotros
	end
	for _, track in animator:GetPlayingAnimationTracks() do
		track:Stop(0)
	end

	-- El Humanoid deja de moverse solo; lo movemos nosotros
	humanoid.PlatformStand = true
	humanoid.AutoRotate = false

	local attachment = Instance.new("Attachment")
	attachment.Name = "PlanetaControl"
	attachment.Parent = root

	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.MaxForce = 60000
	velocity.VectorVelocity = Vector3.zero
	velocity.Parent = root

	local align = Instance.new("AlignOrientation")
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.MaxTorque = 1e7
	align.Responsiveness = 30
	align.CFrame = root.CFrame.Rotation
	align.Parent = root

	groundParams.FilterDescendantsInstances = { character }
	cameraParams.FilterDescendantsInstances = { character }

	local up = (root.Position - CENTER).Unit
	local facing = root.CFrame.LookVector
	facing = facing - up * facing:Dot(up)
	if facing.Magnitude < 1e-3 then
		facing = cam.forward
	end

	ctl = {
		character = character,
		humanoid = humanoid,
		root = root,
		velocity = velocity,
		align = align,
		tracks = tracks,
		track = nil,
		trackName = "",
		facing = facing.Unit,
		lastJump = 0,
		instances = { attachment, velocity, align },
	}

	humanoid.Died:Connect(function()
		if ctl and ctl.character == character then
			cleanup()
		end
	end)
end

player.CharacterAdded:Connect(setupCharacter)
if player.Character then
	task.spawn(setupCharacter, player.Character)
end

---------------------------------------------------------------------
-- Entrada
---------------------------------------------------------------------
local function toggleFlight()
	if flying then
		flying = false
	elseif Config.getFlyCeiling(getEquipped()) then
		flying = true
	end
end

UserInputService.JumpRequest:Connect(function()
	jumpQueued = true
end)

local function rotateCamera(dx: number, dy: number)
	cam.forward = CFrame.fromAxisAngle(cam.up, -dx) * cam.forward
	cam.pitch = math.clamp(cam.pitch - dy, math.rad(-75), math.rad(60))
end

UserInputService.InputBegan:Connect(function(input, processed)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		cam.rotating = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
	end
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonY then
		toggleFlight()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		cam.rotating = false
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
		cam.gamepad = Vector2.zero
	end
end)

UserInputService.InputChanged:Connect(function(input, processed)
	if input.UserInputType == Enum.UserInputType.MouseMovement and cam.rotating then
		rotateCamera(input.Delta.X * 0.006, input.Delta.Y * 0.006)
	elseif input.UserInputType == Enum.UserInputType.MouseWheel and not processed then
		cam.zoom = math.clamp(cam.zoom - input.Position.Z * 3, 6, 70)
	elseif input.UserInputType == Enum.UserInputType.Touch and not processed then
		rotateCamera(input.Delta.X * 0.008, input.Delta.Y * 0.008)
	elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
		cam.gamepad = Vector2.new(input.Position.X, input.Position.Y)
	end
end)

UserInputService.TouchPinch:Connect(function(_, scale, _, state, processed)
	if processed then
		return
	end
	if state == Enum.UserInputState.Begin then
		cam.pinchStart = cam.zoom
	else
		cam.zoom = math.clamp(cam.pinchStart / math.max(scale, 0.1), 6, 70)
	end
end)

-- Dirección de movimiento: tangente (caminar) y 3D (nadar/volar)
local function getMoveInput(up: Vector3): (Vector3, Vector3)
	local move = controls:GetMoveVector()
	local forward = cam.forward - up * cam.forward:Dot(up)
	if forward.Magnitude < 1e-3 then
		forward = ctl.facing
	end
	forward = forward.Unit
	local right = forward:Cross(up)
	local tangent = right * move.X + forward * -move.Z
	local look = camera.CFrame.LookVector
	local full = camera.CFrame.RightVector * move.X + look * -move.Z
	return tangent, full
end

---------------------------------------------------------------------
-- Física del personaje
---------------------------------------------------------------------
local function step(dt: number)
	if not ctl then
		return
	end
	local humanoid: Humanoid = ctl.humanoid
	local root: BasePart = ctl.root
	if humanoid.Health <= 0 or not root.Parent then
		cleanup()
		return
	end

	local position = root.Position
	local offset = position - CENTER
	local distance = offset.Magnitude
	local up = offset / distance
	local equipped = getEquipped()
	local speeds = Config.getSpeeds(equipped)
	local ceiling = Config.getFlyCeiling(equipped)
	if flying and not ceiling then
		flying = false
	end

	local rideHeight = getRideHeight()
	local tangentInput, fullInput = getMoveInput(up)
	local current = root.AssemblyLinearVelocity
	local radial = current:Dot(up)
	local tangential = current - up * radial
	local keyUp = upHeld or UserInputService:IsKeyDown(Enum.KeyCode.Space) or UserInputService:IsKeyDown(Enum.KeyCode.E)
	local keyDown = downHeld or UserInputService:IsKeyDown(Enum.KeyCode.Q) or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
	local vertical = (if keyUp then 1 else 0) - (if keyDown then 1 else 0)
	local now = os.clock()
	local mode: string
	local newVelocity: Vector3

	if flying then
		mode = "fly"
		local dir = fullInput + up * vertical
		if dir.Magnitude > 1 then
			dir = dir.Unit
		end
		local target = dir * (speeds.fly or 50)
		-- Techo de vuelo según la rareza de la criatura
		if ceiling and distance >= ceiling and target:Dot(up) > 0 then
			target -= up * target:Dot(up)
		end
		if ceiling and distance > ceiling + 2 then
			target -= up * 15
		end
		newVelocity = current:Lerp(target, math.min(1, dt * 4))
	elseif Config.isWater(position) then
		mode = "swim"
		local dir = fullInput + up * vertical
		if dir.Magnitude > 1 then
			dir = dir.Unit
		end
		local target = dir * speeds.swim
		if dir.Magnitude < 0.1 then
			target = -up * 2 -- se hunde despacio
		end
		newVelocity = current:Lerp(target, math.min(1, dt * 4))
	else
		local result = workspace:Raycast(position, -up * (rideHeight + 2), groundParams)
		local height = if result then (position - result.Position):Dot(up) else math.huge
		local grounded = result ~= nil and now - ctl.lastJump > 0.25 and height <= rideHeight + 0.7
		if grounded then
			mode = "ground"
			radial = math.clamp((rideHeight - height) * 15, -40, 40)
			if jumpQueued then
				radial = Config.JUMP_SPEED
				ctl.lastJump = now
				mode = "air"
			end
			tangential = tangential:Lerp(tangentInput * speeds.walk, math.min(1, dt * 12))
		else
			mode = "air"
			radial = math.max(radial - Config.GRAVITY * dt, -150)
			tangential = tangential:Lerp(tangentInput * speeds.walk, math.min(1, dt * 3))
		end
		newVelocity = tangential + up * radial
	end
	jumpQueued = false

	-- No salir del planeta
	if distance > Config.MAX_ALTITUDE and newVelocity:Dot(up) > 0 then
		newVelocity -= up * newVelocity:Dot(up)
	end
	ctl.velocity.VectorVelocity = newVelocity

	-- Hacia dónde mira el personaje (siempre "de pie" sobre el planeta)
	local moveDir = if mode == "fly" or mode == "swim" then fullInput else tangentInput
	moveDir -= up * moveDir:Dot(up)
	if moveDir.Magnitude > 0.05 then
		ctl.facing = moveDir.Unit
	end
	local facing = ctl.facing - up * ctl.facing:Dot(up)
	if facing.Magnitude < 1e-3 then
		facing = cam.forward
	end
	ctl.facing = facing.Unit
	ctl.align.CFrame = CFrame.lookAt(Vector3.zero, ctl.facing, up)

	-- Animación
	local moving = tangentInput.Magnitude > 0.1 or (mode ~= "ground" and fullInput.Magnitude > 0.1)
	if equipped then
		playTrack("sit")
	elseif mode == "swim" then
		playTrack(if moving then "swim" else "swimidle")
	elseif mode == "air" then
		playTrack(if radial > 0 then "jump" else "fall")
	elseif moving then
		playTrack("walk")
	else
		playTrack("idle")
	end
end

---------------------------------------------------------------------
-- Cámara
---------------------------------------------------------------------
local function updateCamera(dt: number)
	camera.CameraType = Enum.CameraType.Scriptable
	local root = ctl and ctl.root
	if not root then
		return
	end
	if cam.gamepad.Magnitude > 0.15 then
		rotateCamera(cam.gamepad.X * dt * 2.5, -cam.gamepad.Y * dt * 2)
	end

	local targetUp = (root.Position - CENTER).Unit
	local up = cam.up:Lerp(targetUp, math.min(1, dt * 6))
	if up.Magnitude < 1e-3 then
		up = targetUp
	end
	up = up.Unit
	local forward = cam.forward - up * cam.forward:Dot(up)
	if forward.Magnitude < 1e-3 then
		forward = ctl.facing
	end
	forward = forward.Unit
	cam.up = up
	cam.forward = forward

	local right = forward:Cross(up)
	local look = (CFrame.fromAxisAngle(right, cam.pitch) * forward).Unit
	local equipped = getEquipped()
	local extra = if equipped then Config.getCreatureSize(equipped) * 0.6 else 0
	local zoom = cam.zoom + extra
	local focus = root.Position + up * 2.5
	local desired = focus - look * zoom
	local hit = workspace:Raycast(focus, desired - focus, cameraParams)
	local position = if hit then hit.Position + look * 0.6 else desired
	camera.CFrame = CFrame.lookAt(position, focus, up)
	camera.Focus = CFrame.new(focus)
end

RunService:BindToRenderStep("CamaraPlaneta", Enum.RenderPriority.Camera.Value + 1, updateCamera)
RunService.Heartbeat:Connect(step)

---------------------------------------------------------------------
-- Botones de vuelo (útiles en celular)
---------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "ControlesVuelo"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function button(text: string, position: UDim2, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(1, 1)
	b.Position = position
	b.Size = UDim2.fromOffset(84, 56)
	b.BackgroundColor3 = color
	b.Font = Enum.Font.FredokaOne
	b.TextSize = 22
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = text
	b.Visible = false
	b.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = b
	return b
end

local flyButton = button("🕊️ Volar", UDim2.new(1, -16, 1, -200), Color3.fromRGB(90, 160, 255))
local upButton = button("▲", UDim2.new(1, -110, 1, -200), Color3.fromRGB(70, 70, 90))
local downButton = button("▼", UDim2.new(1, -110, 1, -140), Color3.fromRGB(70, 70, 90))

flyButton.Activated:Connect(toggleFlight)
upButton.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		upHeld = true
	end
end)
upButton.InputEnded:Connect(function()
	upHeld = false
end)
downButton.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		downHeld = true
	end
end)
downButton.InputEnded:Connect(function()
	downHeld = false
end)

RunService.RenderStepped:Connect(function()
	local canFly = Config.getFlyCeiling(getEquipped()) ~= nil
	local inWater = ctl ~= nil and Config.isWater(ctl.root.Position)
	flyButton.Visible = canFly
	flyButton.Text = if flying then "🛬 Bajar" else "🕊️ Volar"
	local showArrows = (flying or inWater) and UserInputService.TouchEnabled
	upButton.Visible = showArrows
	downButton.Visible = showArrows
	if not showArrows then
		upHeld, downHeld = false, false
	end
end)

---------------------------------------------------------------------
-- Barreras de los jefes
---------------------------------------------------------------------
local planeta = workspace:WaitForChild("Planeta")
local barriers = planeta:WaitForChild("Barreras")

local function refreshBarrier(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local gate = part:GetAttribute("Gate")
	if typeof(gate) ~= "string" then
		return
	end
	if part:GetAttribute("BaseTransparency") == nil then
		part:SetAttribute("BaseTransparency", part.Transparency)
	end
	local unlocked = player:GetAttribute("Unlock_" .. gate) == true
	part.CanCollide = not unlocked
	part.Transparency = if unlocked then 0.85 else part:GetAttribute("BaseTransparency") :: number
end

local function refreshAllBarriers()
	for _, part in barriers:GetDescendants() do
		refreshBarrier(part)
	end
end

barriers.DescendantAdded:Connect(refreshBarrier)
for _, gate in Config.GATE_ORDER do
	player:GetAttributeChangedSignal("Unlock_" .. gate):Connect(refreshAllBarriers)
end
refreshAllBarriers()
