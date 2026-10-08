--!strict
-- 우승 연출 "탈출 성공!" (m3-05, GDD 8): 우승한 초밥이 가게 문을 박차고 나와 부두를 달려 바다로 다이빙,
-- 물고기들이 박수. MatchPhase = Victory(우승자 있음)를 받으면 방의 모든 클라이언트가 재생해요.
--   - 장면은 클라이언트 로컬 (VictoryCutsceneLogic.SCENE_ORIGIN에 VictoryProps를 짓고 끝나면 지움). 서버는 모름.
--   - 길이 Config.Match.VictoryCutscene. 박자·효과음·인형/카메라 위치는 Shared.VictoryCutsceneLogic.
--   - 카메라는 CameraDirector "VictoryCutscene"(우선순위 50)로 잡고, 끝나면 release →
--     SpectateController의 Victory(로비의 우승자 비추기)로 돌아가요.
--   - 끝나거나, 방이 대기실로 돌아오거나(RoomUpdated state ≠ InMatch), 새 Starting이 오면 모두 정리해요.
-- 순위표·"🏆 우승!" 배너는 HudScreen이 연출 길이만큼 기다렸다 띄워요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Cleanup = require(ReplicatedStorage.Shared.Cleanup)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SushiBody = require(ReplicatedStorage.Shared.SushiBody)
local Types = require(ReplicatedStorage.Shared.Types)
local VictoryCutsceneLogic = require(ReplicatedStorage.Shared.VictoryCutsceneLogic)
local CameraDirector = require(script.Parent.Parent.CameraDirector)
local Sfx = require(script.Parent.Parent.Sfx)
local VictoryCutsceneScreen = require(script.Parent.VictoryCutsceneScreen)
local VictoryProps = require(script.Parent.VictoryProps)

local OWNER = "VictoryCutscene"
-- m3-02가 SushiBody.GROUND_OFFSET(발바닥 → Body 중심)을 정해요. 없으면 이 값.
local DEFAULT_GROUND_OFFSET = 2.3
local GRAVITY = 60
local CAMERA_FOV = 60

type Debris = { part: BasePart, velocity: Vector3, born: number, life: number }

local VictoryCutsceneController = {}

local function toVector(v: VictoryCutsceneLogic.Vec): Vector3
	return Vector3.new(v[1], v[2], v[3])
end

local function groundOffset(): number
	local value = (SushiBody :: any).GROUND_OFFSET
	return if type(value) == "number" then value else DEFAULT_GROUND_OFFSET
end

-- 우승자 캐릭터의 스킨 id (나갔거나 없으면 기본 계란초밥)
local function appearanceOf(winnerUserId: number): string
	local winner = Players:GetPlayerByUserId(winnerUserId)
	local character = winner and winner.Character
	local id = character and character:GetAttribute(Attributes.AppearanceId)
	return if type(id) == "string" and id ~= "" then id else Config.Appearance.Default
end

-- 인형: SushiBody.build로 만들고 모든 파츠를 고정·충돌 없음으로
local function buildDoll(appearanceId: string): Model?
	local ok, result = pcall(SushiBody.build, appearanceId)
	if not ok then
		warn(`[VictoryCutscene] SushiBody.build failed: {result}`)
		ok, result = pcall(SushiBody.build, Config.Appearance.Default)
		if not ok then
			return nil
		end
	end
	local doll = result :: Model
	doll.Name = "VictoryDoll"
	for _, item in doll:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
		end
	end
	return doll
end

local function nameOf(userId: number): string
	local other = Players:GetPlayerByUserId(userId)
	return if other then other.DisplayName else `#{userId}`
end

function VictoryCutsceneController.start(gui: Instance)
	local player = Players.LocalPlayer
	local playerGui = gui.Parent or player:WaitForChild("PlayerGui")
	local screen = VictoryCutsceneScreen.new(playerGui)

	local session: Cleanup.Cleanup? = nil

	local function stop()
		local current = session
		if current then
			session = nil
			current:run()
		end
	end

	local function play(info: Types.MatchPhaseInfo)
		stop()
		local winnerUserId = info.winnerUserId :: number
		local duration = Config.Match.VictoryCutscene
		local cleanup = Cleanup.new()
		session = cleanup

		local timeline = VictoryCutsceneLogic.timeline(duration)
		local cues = VictoryCutsceneLogic.cues(duration)
		local splashAt = VictoryCutsceneLogic.splashTime(duration)
		local title = VictoryCutsceneLogic.titleText(
			VictoryCutsceneLogic.winnerName(info.standings, winnerUserId, nameOf(winnerUserId)),
			winnerUserId == player.UserId
		)

		local o = VictoryCutsceneLogic.SCENE_ORIGIN
		local origin = CFrame.new(o[1], o[2], o[3])
		local props = VictoryProps.build(origin)
		cleanup:add(props.model)
		local doll = buildDoll(appearanceOf(winnerUserId))
		if doll then
			doll.Parent = props.model
		end
		local fishRing = VictoryCutsceneLogic.fishRing(#props.fish, VictoryCutsceneLogic.Layout.FishRadius)
		local lift = groundOffset()

		local debris: { Debris } = {}
		local function burst(at: Vector3, color: Color3, count: number, speed: number, up: number)
			local now = os.clock()
			for _ = 1, count do
				local p = Instance.new("Part")
				p.Name = "Debris"
				p.Size = Vector3.one * (0.4 + math.random() * 0.5)
				p.Color = color
				p.Anchored = true
				p.CanCollide = false
				p.CanQuery = false
				p.CanTouch = false
				p.CastShadow = false
				p.CFrame = CFrame.new(at)
				p.Parent = props.model
				local angle = math.random() * 2 * math.pi
				local velocity =
					Vector3.new(math.cos(angle) * speed, up * (0.6 + math.random() * 0.6), math.sin(angle) * speed)
				table.insert(debris, { part = p, velocity = velocity, born = now, life = 0.9 })
			end
		end

		local function updateDebris(dt: number)
			local now = os.clock()
			for i = #debris, 1, -1 do
				local d = debris[i]
				if now - d.born > d.life then
					d.part:Destroy()
					table.remove(debris, i)
				else
					d.velocity -= Vector3.new(0, GRAVITY * dt, 0)
					d.part.CFrame = d.part.CFrame + d.velocity * dt
					d.part.Transparency = (now - d.born) / d.life
				end
			end
		end

		local function cameraCFrame(t: number): CFrame
			local pose = VictoryCutsceneLogic.cameraPose(t, duration)
			local eye = origin:PointToWorldSpace(toVector(pose.eye))
			local target = origin:PointToWorldSpace(toVector(pose.target))
			return CFrame.lookAt(eye, target)
		end

		local function applyCamera(camera: Camera)
			camera.CameraType = Enum.CameraType.Scriptable
			camera.FieldOfView = CAMERA_FOV
			camera.CFrame = cameraCFrame(0)
		end

		local function render(t: number)
			VictoryProps.setDoorsOpen(props, VictoryCutsceneLogic.doorOpen(t, duration))

			local pose = VictoryCutsceneLogic.dollPose(t, duration)
			local dollPosition = toVector(pose.position)
			if doll then
				-- 발바닥 위치에서 Body 중심만큼 올린 곳을 기준으로 돌려요 (yaw 먼저, 그다음 앞으로 숙이기)
				local center = origin * CFrame.new(dollPosition + Vector3.new(0, lift, 0))
				doll:PivotTo(center * CFrame.Angles(0, pose.yaw, 0) * CFrame.Angles(-pose.pitch, 0, 0))
			end

			local dollWorld = origin:PointToWorldSpace(dollPosition + Vector3.new(0, lift, 0))
			local water = VictoryCutsceneLogic.Layout.WaterY
			for index, fish in props.fish do
				local rise, clap = VictoryCutsceneLogic.fishState(t, duration, index)
				local offset = fishRing[index]
				local fishLocal =
					Vector3.new(offset[1], water - 3 + rise * 3.6, VictoryCutsceneLogic.Layout.DiveLandZ + offset[2])
				local at = origin:PointToWorldSpace(fishLocal)
				local lookAt = Vector3.new(dollWorld.X, at.Y, dollWorld.Z)
				local bob = if rise > 0 then math.abs(clap) * 0.3 else 0
				VictoryProps.poseFish(fish, CFrame.lookAt(at, lookAt) + Vector3.new(0, bob, 0), clap)
			end

			local camera = workspace.CurrentCamera
			if camera and CameraDirector.isActive(OWNER) then
				if camera.CameraType ~= Enum.CameraType.Scriptable then
					camera.CameraType = Enum.CameraType.Scriptable
				end
				camera.CFrame = cameraCFrame(t)
			end
		end

		props.model.Parent = workspace
		render(0)
		CameraDirector.request(OWNER, CameraDirector.Priority.VictoryCutscene, applyCamera)
		cleanup:add(function()
			CameraDirector.release(OWNER)
			screen:hide()
		end)

		local startedAt = os.clock()
		local nextCue = 1
		local lastBeat: string? = nil
		local splashed = false

		cleanup:add(RunService.RenderStepped:Connect(function(dt: number)
			if session ~= cleanup then
				return
			end
			local t = os.clock() - startedAt
			if t >= duration then
				stop()
				return
			end

			while cues[nextCue] and cues[nextCue].at <= t do
				Sfx.play(cues[nextCue].name)
				nextCue += 1
			end

			local beat = VictoryCutsceneLogic.beatAt(timeline, t)
			if beat ~= lastBeat then
				lastBeat = beat
				if beat == "DoorBurst" then
					burst(origin:PointToWorldSpace(Vector3.new(0, 1, -1)), Color3.fromRGB(200, 190, 170), 10, 10, 8)
				elseif beat == "Clap" then
					screen:show(title)
				end
			end
			if not splashed and t >= splashAt then
				splashed = true
				local landing =
					Vector3.new(0, VictoryCutsceneLogic.Layout.WaterY, VictoryCutsceneLogic.Layout.DiveLandZ)
				burst(origin:PointToWorldSpace(landing), Color3.fromRGB(200, 235, 255), 18, 8, 26)
			end

			render(t)
			updateDebris(dt)
		end))
	end

	Remotes.event("MatchPhase").OnClientEvent:Connect(function(info: Types.MatchPhaseInfo)
		if info.phase == "Victory" then
			if info.winnerUserId then
				play(info)
			else
				stop() -- 우승자 없이 끝난 매치는 연출 없음
			end
		elseif info.phase == "Starting" then
			stop()
		end
	end)

	Remotes.event("RoomUpdated").OnClientEvent:Connect(function(room: Types.RoomSnapshot?)
		if room == nil or room.state ~= "InMatch" then
			stop()
		end
	end)
end

return VictoryCutsceneController
