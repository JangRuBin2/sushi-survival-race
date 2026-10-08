--!strict
-- 탈락 연출 "먹혔다!" (m3-03, GDD 1.1·7). 서버 판정은 건드리지 않고 각 클라이언트가 로컬로 재생해요.
--   PlayerResult가 Eliminated + cause Fall/Reset이면 방의 모든 클라이언트가 탈락 위치에서 같은 연출을 봐요.
--     진짜 캐릭터는 서버가 고정해 두고, 여기서는 로컬로 숨긴 뒤(LocalTransparencyModifier) 그 자리에
--     SushiBody 인형을 만들어 움직여요. 끝나면 인형·소품을 지우고 숨김을 풀어요.
--   연출 종류(EliminationCutsceneLogic.variantFor): 결승 = 셰프 손, Survival 낙하 = 손님 입, 그 밖 = 젓가락.
--   탈락한 본인만 카메라(CameraDirector "Elimination")와 "먹혔다!" 스탬프를 받아요. 카메라를 놓으면
--     SpectateController의 자동 관전이 이어져요.
--   월드 연출은 동시에 MAX_CONCURRENT개까지. 넘으면 캐릭터만 숨겼다가 풀어요 (본인 연출은 한도와 무관).
--   cause가 Left·nil(시간 종료·정원 마감)이면 연출 없음. 위치가 없으면 본인은 스탬프만, 남은 아무것도 안 봐요.
--   매치가 끝나거나(RoomUpdated) Victory가 시작되면 재생 중인 연출을 모두 지워요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Cleanup = require(ReplicatedStorage.Shared.Cleanup)
local Config = require(ReplicatedStorage.Shared.Config)
local Logic = require(ReplicatedStorage.Shared.EliminationCutsceneLogic)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SushiBody = require(ReplicatedStorage.Shared.SushiBody)
local Types = require(ReplicatedStorage.Shared.Types)
local CameraDirector = require(script.Parent.Parent.CameraDirector)
local Sfx = require(script.Parent.Parent.Sfx)
local Props = require(script.Parent.CutsceneProps)
local Screen = require(script.Parent.EliminationCutsceneScreen)

local OWNER = "Elimination"
local FOLDER_NAME = "EliminationCutscenes"
-- 진짜 캐릭터가 탈락 위치에서 이만큼 안에 있을 때만 숨겨요 (리셋 뒤 다른 곳에 새로 생긴 캐릭터는 그대로)
local HIDE_RADIUS = 40
-- 본인 카메라: 인형을 비스듬히 위에서 크게
local CAMERA_OFFSET = Vector3.new(9, 9, 13)
local CAMERA_FOLLOW = 8 -- 초당 따라가는 정도

local UP = Vector3.new(0, 1, 0)

-- 연출 하나의 움직임. update(t)는 카메라가 볼 곳을 돌려줘요. speaker = 말풍선을 달 파트.
type Animation = {
	update: (t: number) -> Vector3,
	speaker: BasePart,
}

type Playing = {
	isWorld: boolean,
	stop: () -> (),
}

local EliminationCutsceneController = {}

local function lerp(a: Vector3, b: Vector3, alpha: number): Vector3
	return a:Lerp(b, alpha)
end

-- 같은 위치에서 회전만 바꿔 인형을 놓아요
local function placeDoll(doll: Model, at: Vector3, rotation: CFrame?)
	doll:PivotTo(CFrame.new(at) * (rotation or CFrame.identity))
end

-- 젓가락이 집어 → 버둥 → 간장 퐁당 → 손님 입 "냠!" (0~2.4초, 3초 기준)
local function chopsticks(model: Model, doll: Model, origin: Vector3, s: (number) -> number, rng: Random): Animation
	local sticks = Props.chopsticks()
	sticks.Parent = model
	local dishTop = origin + Vector3.new(6, 0, 0)
	Props.soyDish(dishTop).Parent = model
	local mouthAt = origin + Vector3.new(-7, 7, 0)
	local mouthCFrame = CFrame.lookAt(mouthAt, mouthAt + Vector3.new(1, 0, 0))
	local mouth = Props.mouth()
	mouth.Parent = model
	local speaker = Props.anchor(mouthAt + Vector3.new(0, 4, 0))
	speaker.Parent = model

	local lifted = origin + Vector3.new(0, 6, 0)
	local overDish = dishTop + Vector3.new(0, 4, 0)
	local dipped = dishTop + Vector3.new(0, 1.4, 0)
	local mouthFront = mouthAt + Vector3.new(4, 0, 0)
	local swallowed = mouthAt + Vector3.new(-1, 0, 0)
	local stickHigh = origin + Vector3.new(0, 14, 0)
	local splashed = false
	local eaten = false

	local function update(t: number): Vector3
		local a = Logic.alpha
		local ease = Logic.smooth
		local dollAt = origin
		local rotation = CFrame.identity
		local open = 1
		local tip: Vector3

		if t < s(0.3) then
			-- 젓가락이 벌린 채 내려와요
			tip = lerp(stickHigh, origin, ease(a(t, 0, s(0.3))))
			open = 1
		elseif t < s(0.6) then
			tip = origin
			open = 1 - a(t, s(0.3), s(0.4))
		else
			open = 0
			if t < s(1.2) then
				-- 들어 올려 버둥
				dollAt = lerp(origin, lifted, ease(a(t, s(0.6), s(0.9))))
				rotation = CFrame.Angles(math.sin(t * 34) * 0.25, 0, math.sin(t * 27) * 0.55)
			elseif t < s(1.8) then
				-- 종지 위로 → 퐁당 → 다시 위로
				if t < s(1.4) then
					dollAt = lerp(lifted, overDish, ease(a(t, s(1.2), s(1.4))))
				elseif t < s(1.55) then
					dollAt = lerp(overDish, dipped, ease(a(t, s(1.4), s(1.5))))
				else
					dollAt = lerp(dipped, overDish, ease(a(t, s(1.55), s(1.8))))
				end
				if not splashed and t >= s(1.5) then
					splashed = true
					Props.splash(model, dishTop, rng)
				end
				rotation = CFrame.Angles(0, 0, math.sin(t * 20) * 0.15)
			else
				-- 손님 입으로
				dollAt = if t < s(2.1)
					then lerp(overDish, mouthFront, ease(a(t, s(1.8), s(2.1))))
					else lerp(mouthFront, swallowed, ease(a(t, s(2.1), s(2.2))))
				rotation = CFrame.Angles(0, 0, math.rad(90))
			end
			tip = dollAt
			if t >= s(2.2) then
				-- 다 먹이고 젓가락은 위로 빠져요
				tip = lerp(mouthFront, mouthFront + Vector3.new(4, 12, 0), ease(a(t, s(2.2), s(2.6))))
				open = 0.6
			end
		end

		if not eaten and t >= s(2.2) then
			eaten = true
			doll.Parent = nil
		end
		if not eaten then
			placeDoll(doll, dollAt, rotation)
		end
		Props.poseChopsticks(sticks, tip, open)

		-- 입: 기다리는 동안 조금 벌림 → 1.8초부터 크게 → 2.2초에 앙
		local mouthOpen = 0.35 + math.sin(t * 6) * 0.08
		if t >= s(1.8) then
			mouthOpen = if t < s(2.2) then 1 else 1 - a(t, s(2.2), s(2.3))
		end
		Props.poseMouth(mouth, mouthCFrame, mouthOpen)

		return if t < s(1.8) then dollAt else lerp(dollAt, mouthAt, a(t, s(1.8), s(2.3)))
	end

	return { update = update, speaker = speaker }
end

-- 아래에서 입 벌린 손님 입으로 떨어져 "냠!" (Survival 낙하)
local function mouthFall(model: Model, doll: Model, origin: Vector3, s: (number) -> number): Animation
	local mouthAt = origin - Vector3.new(0, 10, 0)
	local mouthCFrame = CFrame.new(mouthAt) * CFrame.Angles(math.rad(90), 0, 0) -- 위를 향해 벌어져요
	local mouth = Props.mouth()
	mouth.Parent = model
	local speaker = Props.anchor(mouthAt + Vector3.new(0, 5, 0))
	speaker.Parent = model
	local eaten = false

	local function update(t: number): Vector3
		local fall = Logic.alpha(t, 0, s(1.2))
		local dollAt = lerp(origin, mouthAt + Vector3.new(0, 1, 0), fall * fall)
		if not eaten and t >= s(1.25) then
			eaten = true
			doll.Parent = nil
		end
		if not eaten then
			placeDoll(doll, dollAt, CFrame.Angles(t * 7, t * 4, 0))
		end
		local open = if t < s(1.2) then 1 else 1 - Logic.alpha(t, s(1.2), s(1.35))
		-- 다 먹은 뒤 오물오물
		if t >= s(1.5) then
			open = 0.15 + math.abs(math.sin(t * 10)) * 0.2
		end
		Props.poseMouth(mouth, mouthCFrame, open)
		return lerp(origin, mouthAt, math.min(1, fall * 1.2))
	end

	return { update = update, speaker = speaker }
end

-- 셰프의 거대한 손이 내려와 움켜쥐고 위로 사라져요 (결승)
local function chefHand(model: Model, doll: Model, origin: Vector3, s: (number) -> number): Animation
	local hand = Props.chefHand()
	hand.Parent = model
	local speaker = Props.anchor(origin + Vector3.new(0, 9, 0))
	speaker.Parent = model

	local gripAt = origin + Vector3.new(0, 3, 2.2) -- 손바닥 가운데 (손가락 끝이 인형 앞을 감싸요)
	local high = gripAt + Vector3.new(0, 34, 0)
	local gone = gripAt + Vector3.new(0, 60, 0)
	local dollOffset = origin - gripAt

	local function update(t: number): Vector3
		local a = Logic.alpha
		local ease = Logic.smooth
		local palm: Vector3
		local grip = 0
		if t < s(0.8) then
			palm = lerp(high, gripAt, ease(a(t, 0, s(0.8))))
		elseif t < s(1.2) then
			palm = gripAt
			grip = ease(a(t, s(0.8), s(1.1)))
		else
			local lift = a(t, s(1.2), s(2.2))
			palm = lerp(gripAt, gone, lift * lift)
			grip = 1
		end
		local wobble = if t >= s(0.8) then CFrame.Angles(0, 0, math.sin(t * 30) * 0.3) else CFrame.identity
		Props.poseChefHand(hand, CFrame.new(palm), grip)
		local dollAt = if t < s(1.2) then origin else palm + dollOffset
		placeDoll(doll, dollAt, wobble)
		return lerp(origin, dollAt, 0.45)
	end

	return { update = update, speaker = speaker }
end

-- 진짜 캐릭터를 로컬로 숨겨요. apply는 매 프레임 불러서 기본 스크립트가 되돌린 걸 다시 숨겨요.
local function characterHider(character: Model?, position: Vector3?): { apply: () -> (), restore: () -> () }
	local target: Model? = nil
	if character and character.Parent then
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if position == nil or root == nil or (root.Position - position).Magnitude <= HIDE_RADIUS then
			target = character
		end
	end

	local function set(value: number)
		if target == nil or target.Parent == nil then
			return
		end
		for _, item in target:GetDescendants() do
			if item:IsA("BasePart") or item:IsA("Decal") then
				(item :: any).LocalTransparencyModifier = value
			end
		end
	end

	return {
		apply = function()
			set(1)
		end,
		restore = function()
			set(0)
			target = nil
		end,
	}
end

function EliminationCutsceneController.start(gui: Instance)
	local me = Players.LocalPlayer
	local rng = Random.new()
	local duration = Config.Match.EliminationCutscene

	local phase: Types.MatchPhaseInfo? = nil
	local playing: { [Playing]: boolean } = {}
	local worldCount = 0

	local function folder(): Folder
		local existing = workspace:FindFirstChild(FOLDER_NAME)
		if existing and existing:IsA("Folder") then
			return existing
		end
		local created = Instance.new("Folder")
		created.Name = FOLDER_NAME
		created.Parent = workspace
		return created
	end

	local function stopAll()
		local list = {}
		for entry in playing do
			table.insert(list, entry)
		end
		for _, entry in list do
			entry.stop()
		end
	end

	local function play(result: Types.PlayerResult)
		local isMe = result.userId == me.UserId
		local position = result.position
		if not isMe and position == nil then
			return -- 보여 줄 자리가 없어요
		end

		local subject = Players:GetPlayerByUserId(result.userId)
		local character = subject and subject.Character
		local appearance = character and character:GetAttribute(Attributes.AppearanceId)
		local appearanceId = if type(appearance) == "string" then appearance else Config.Appearance.Default

		local info = phase
		local isFinal = info ~= nil and Logic.isFinalRound(info.roundIndex, info.roundCount)
		local variant = Logic.variantFor(info and info.mapKind, isFinal, result.cause)
		local world = position ~= nil and (isMe or Logic.canStartWorld(worldCount))

		local cleanup = Cleanup.new()
		local entry: Playing = { isWorld = world and not isMe, stop = function() end }
		local stopped = false
		entry.stop = function()
			if stopped then
				return
			end
			stopped = true
			playing[entry] = nil
			if entry.isWorld then
				worldCount -= 1
			end
			cleanup:run()
		end
		playing[entry] = true
		if entry.isWorld then
			worldCount += 1
		end

		local hider = characterHider(character, position)
		cleanup:add(hider.restore)
		hider.apply()

		if isMe then
			cleanup:add(Screen.showStamp(gui, result.place, duration))
			Sfx.play("Eliminated")
		end

		local animation: Animation? = nil
		local beats = Logic.timeline(variant, duration)
		local nextBeat = 1
		local line = Logic.pickLine(appearanceId, variant, rng)
		if world and position then
			local model = cleanup:add(Instance.new("Model"))
			model.Name = `EliminationCutscene_{result.userId}`
			local doll = cleanup:add(SushiBody.build(appearanceId))
			doll.Parent = model
			local function s(x: number): number
				return Logic.scaled(x, duration)
			end
			if variant == "ChefHand" then
				animation = chefHand(model, doll, position, s)
			elseif variant == "Mouth" then
				animation = mouthFall(model, doll, position, s)
			else
				animation = chopsticks(model, doll, position, s, rng)
			end
			if animation then
				animation.update(0)
			end
			model.Parent = folder()
		end

		local focus: Vector3? = position
		local cameraAt: Vector3? = position

		local function cameraCFrame(): CFrame?
			local look = cameraAt
			if look == nil then
				return nil
			end
			return CFrame.lookAt(look + CAMERA_OFFSET, look, UP)
		end

		local startedAt = os.clock()
		cleanup:add(RunService.RenderStepped:Connect(function(dt: number)
			local t = os.clock() - startedAt
			if t >= duration then
				entry.stop()
				return
			end
			hider.apply()
			local anim = animation
			if anim then
				focus = anim.update(t)
				while beats[nextBeat] and t >= beats[nextBeat].at do
					local cue = beats[nextBeat].cue
					nextBeat += 1
					Sfx.play(cue, anim.speaker.Position)
					if cue == "SpeechPop" then
						Screen.speechBubble(anim.speaker, line)
					end
				end
			end
			if isMe and focus and cameraAt then
				cameraAt = cameraAt:Lerp(focus, math.min(1, dt * CAMERA_FOLLOW))
				local camera = workspace.CurrentCamera
				local cf = cameraCFrame()
				if camera and cf and CameraDirector.isActive(OWNER) then
					camera.CFrame = cf
				end
			end
		end))

		if isMe and position then
			cleanup:add(function()
				CameraDirector.release(OWNER)
			end)
			CameraDirector.request(OWNER, CameraDirector.Priority.Elimination, function(camera: Camera)
				camera.CameraType = Enum.CameraType.Scriptable
				local cf = cameraCFrame()
				if cf then
					camera.CFrame = cf
				end
			end)
		end
	end

	Remotes.event("RoomUpdated").OnClientEvent:Connect(function(room: Types.RoomSnapshot?)
		if room == nil or room.state ~= "InMatch" then
			phase = nil
			stopAll()
		end
	end)

	Remotes.event("MatchPhase").OnClientEvent:Connect(function(info: Types.MatchPhaseInfo)
		phase = info
		if info.phase == "Victory" then
			stopAll()
		end
	end)

	Remotes.event("PlayerResult").OnClientEvent:Connect(function(result: Types.PlayerResult)
		if result.result ~= "Eliminated" or not Logic.shouldPlay(result.cause) then
			return
		end
		if phase ~= nil and phase.phase == "Victory" then
			return
		end
		play(result)
	end)
end

return EliminationCutsceneController
