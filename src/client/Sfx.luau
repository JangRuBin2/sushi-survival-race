--!strict
-- 효과음·배경음 (m3-08). 소리 id·볼륨은 Shared.SfxLibrary가 정해요.
--   Sfx.play(cue, at?)    효과음. at이 BasePart면 그 파트에서, Vector3면 그 위치에서 3D로, 없으면 2D로.
--   Sfx.setMusic(name?)   배경음 바꾸기 (nil이면 끄기). 0.5초 동안 이전 곡을 줄이며 새 곡을 키워요.
--   Sfx.start(gui)        init.client.luau가 다른 컨트롤러와 함께 불러요.
-- start 전에 불려도 에러 없이 무시해요. 모르는 이름은 이름당 한 번만 경고하고, id가 없는 cue는 조용히 넘어가요.
-- start가 하는 일: SoundGroup(Sfx 0.7, Music 0.3, Config.Fx), 방/매치 단계에 맞춘 배경음, GuiButton 클릭음(조작 버튼 제외),
-- 장애물 소리(서버 MapSfx 방송 → 3D 재생),
-- 내가 통과하면 Qualified, Roblox 위쪽 바 오른쪽 끝 음소거 버튼(소리 켬 → 음악 끔 → 모두 끔).
-- 음소거 저장 (m4-07): 누르면 마지막 누름 0.5초 뒤 SaveSettings를 한 번 보내요. 첫 ProfileView가 오면 저장된 단계로
-- 맞춰요 (그 전에 사용자가 이미 눌렀으면 사용자 값 우선).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SfxCues = require(ReplicatedStorage.Shared.SfxCues)
local SfxLibrary = require(ReplicatedStorage.Shared.SfxLibrary)
local Types = require(ReplicatedStorage.Shared.Types)

local ProfileStore = require(script.Parent.ProfileStore)

local Sfx = {}

local SFX_GROUP_VOLUME = Config.Fx.SfxVolume
local MUSIC_GROUP_VOLUME = Config.Fx.MusicVolume
local ROLLOFF_MAX_DISTANCE = Config.Fx.SfxMaxDistance
local SAME_CUE_GAP = 0.05 -- 같은 cue는 이 시간 안에 다시 울리지 않아요
local MAX_ACTIVE_SFX = Config.Fx.SfxMaxActive
local SFX_MAX_LIFETIME = 10 -- Ended가 오지 않아도(로드 실패 등) 이 시간 뒤 지워요. 아직 울리는 긴 소리는 길이만큼 더 기다려요
local MUSIC_FADE = 0.5

-- 음소거 단계: 1 소리 켬, 2 음악 끔, 3 모두 끔
local MUTE_LABELS = { "🔊 소리 켬", "🎵 음악 끔", "🔇 모두 끔" }
local MUTE_ICONS = { "🔊", "🎵", "🔇" } -- 좁은 화면에서는 아이콘만

local started = false
local sfxGroup: SoundGroup? = nil
local musicGroup: SoundGroup? = nil
local muteLevel = 1
local refreshMuteButton: (() -> ())? = nil

local warned: { [string]: boolean } = {}
local lastPlayed: { [string]: number } = {}
local activeSfx = 0

local currentMusicName: string? = nil
local currentMusic: Sound? = nil

local fadeInfo = TweenInfo.new(MUSIC_FADE, Enum.EasingStyle.Linear)

local function warnOnce(kind: string, name: string)
	local key = `{kind}:{name}`
	if warned[key] then
		return
	end
	warned[key] = true
	warn(`[Sfx] unknown {kind} "{name}" (see Shared.SfxCues)`)
end

local function applyMute()
	if sfxGroup then
		sfxGroup.Volume = if muteLevel >= 3 then 0 else SFX_GROUP_VOLUME
	end
	if musicGroup then
		musicGroup.Volume = if muteLevel >= 2 then 0 else MUSIC_GROUP_VOLUME
	end
end

local function makeGroup(name: string, volume: number): SoundGroup
	local group = Instance.new("SoundGroup")
	group.Name = name
	group.Volume = volume
	group.Parent = SoundService
	return group
end

function Sfx.play(cue: string, at: (BasePart | Vector3)?)
	if not SfxCues.isEffect(cue) then
		warnOnce("cue", cue)
		return
	end
	if not started then
		return
	end
	local entry = SfxLibrary.get(cue)
	if entry == nil or entry.id == nil then
		return
	end
	local now = os.clock()
	local last = lastPlayed[cue]
	if last ~= nil and now - last < SAME_CUE_GAP then
		return
	end
	if activeSfx >= MAX_ACTIVE_SFX then
		return
	end
	lastPlayed[cue] = now

	local sound = Instance.new("Sound")
	sound.Name = cue
	sound.SoundId = entry.id :: string
	sound.Volume = entry.volume
	local jitter = entry.pitchJitter or 0
	sound.PlaybackSpeed = (entry.pitch or 1) * (1 + (math.random() * 2 - 1) * jitter)
	sound.SoundGroup = sfxGroup
	sound.RollOffMaxDistance = ROLLOFF_MAX_DISTANCE

	-- 소리가 붙을 곳: 파트, 임시 Attachment(위치), SoundService(2D)
	local holder: Instance? = nil
	if typeof(at) == "Instance" then
		if not (at :: Instance):IsA("BasePart") then
			sound:Destroy()
			return
		end
		sound.Parent = at
	elseif typeof(at) == "Vector3" then
		local attachment = Instance.new("Attachment")
		attachment.Name = "SfxAt"
		attachment.WorldPosition = at :: Vector3
		attachment.Parent = workspace.Terrain
		holder = attachment
		sound.Parent = attachment
	else
		sound.Parent = SoundService
	end

	activeSfx += 1
	local done = false
	local function finish()
		if done then
			return
		end
		done = true
		activeSfx -= 1
		sound:Destroy()
		if holder then
			holder:Destroy()
		end
	end
	sound.Ended:Once(finish)
	sound.Destroying:Once(finish) -- 붙은 파트가 먼저 사라져도 개수를 맞춰요
	-- 수명: 기본 SFX_MAX_LIFETIME. 그때 아직 울리는 긴 소리면 남은 길이만큼 더 기다려요 (m3-08 QA B5)
	local function expire()
		if done then
			return
		end
		local length = sound.TimeLength
		if sound.IsPlaying and type(length) == "number" and length > 0 then
			local speed = math.max(sound.PlaybackSpeed, 0.01)
			local left = (length - sound.TimePosition) / speed
			if left > 0 then
				task.delay(left + 0.5, finish)
				return
			end
		end
		finish()
	end
	task.delay(SFX_MAX_LIFETIME, expire)
	sound:Play()
end

function Sfx.setMusic(name: string?)
	if name ~= nil and not SfxCues.isMusic(name) then
		warnOnce("music", name)
		return
	end
	if not started or name == currentMusicName then
		return
	end
	currentMusicName = name

	local old = currentMusic
	currentMusic = nil
	if old then
		local tween = TweenService:Create(old, fadeInfo, { Volume = 0 })
		tween.Completed:Once(function()
			old:Destroy()
		end)
		tween:Play()
	end

	if name == nil then
		return
	end
	local entry = SfxLibrary.get(name)
	if entry == nil or entry.id == nil then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = `Music_{name}`
	sound.SoundId = entry.id :: string
	sound.Looped = true
	sound.Volume = 0
	sound.SoundGroup = musicGroup
	sound.Parent = SoundService
	sound:Play()
	TweenService:Create(sound, fadeInfo, { Volume = entry.volume }):Play()
	currentMusic = sound
end

-- 배경음: 방/매치 상태를 기억해 두고 바뀔 때마다 musicFor로 골라요
local inMatch = false
local phaseInfo: Types.MatchPhaseInfo? = nil

local function refreshMusic()
	local info = if inMatch then phaseInfo else nil
	Sfx.setMusic(
		SfxLibrary.musicFor(
			inMatch,
			if info then info.phase else nil,
			if info then info.roundIndex else nil,
			if info then info.roundCount else nil
		)
	)
end

-- 클릭음을 내지 않는 버튼 (m3-08 QA B1): Roblox 기본 터치 조작(TouchGui)·ContextActionService 버튼,
-- 그리고 자신이나 조상에 NoClickSfx = true가 달린 조작 버튼(다이브·잡기). 누를 때마다 확인해요(나중에 단 속성도 반영).
local SILENT_GUIS = { TouchGui = true, ContextActionGui = true }

local function isSilentButton(button: Instance): boolean
	local current: Instance? = button
	while current ~= nil do
		if SILENT_GUIS[current.Name] or current:GetAttribute(Attributes.NoClickSfx) == true then
			return true
		end
		current = current.Parent
	end
	return false
end

-- 이미 연결한 버튼 (다시 붙여도 연결이 늘지 않게, m3-08 QA B3). 버튼이 사라지면 키도 사라져요.
local hookedButtons: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function hookButton(instance: Instance)
	if instance:IsA("GuiButton") and not hookedButtons[instance] then
		hookedButtons[instance] = true
		instance.Activated:Connect(function()
			if not isSilentButton(instance) then
				Sfx.play("ButtonClick")
			end
		end)
	end
end

-- 음소거 버튼 자리 (사용자 수정 지시, m3-09): Roblox 위쪽 바(topbar) 줄의 오른쪽 끝.
--   자기 ScreenGui에 ScreenInsets = TopbarSafeInsets를 주면 그 영역은 위쪽 바에서 Roblox 메뉴·채팅 같은
--   기본 버튼과 기기 노치를 뺀 칸이에요. 게임 화면(LobbyGui — 로비·방·HUD·관전·소개가 모두 그 안)은
--   IgnoreGuiInset이 꺼져 있어 위쪽 바 "아래"에만 그려지므로 우리 UI와도 겹치지 않아요.
--   (예전 자리 y 60은 폭 900~980px에서 로비 패널 제목 줄과 닿았어요, m3-09 QA B5)
--   IgnoreGuiInset은 ScreenInsets를 덮어쓰는 옛 단축 속성이라 설정하지 않아요.
local MUTE_MARGIN = 4 -- 위쪽 바 안 위아래·오른쪽 여백
local MUTE_MAX_HEIGHT = 36 -- 바가 높아도(새 상단 바 58px) 버튼은 이 높이까지만
local MUTE_WIDE_WIDTH = 110
local MUTE_COMPACT_WIDTH = 36

-- 음소거 저장·복원 (m4-07)
local MUTE_SAVE_DELAY = 0.5 -- 마지막 누름 뒤 이만큼 지나서 한 번 보내요
local MUTE_SEND_GAP = 1 -- 보내는 간격 최소값 (서버 SettingsMinInterval에 걸려 마지막 값이 버려지지 않게)
local userChangedMute = false -- 첫 프로필이 오기 전에 사용자가 눌렀는가
local muteRestored = false
local muteSaveToken = 0
local lastMuteSentAt = -math.huge
local lastMuteSent: number? = nil -- 서버에 있는(보낸) 값

local function sendMuteLevel(token: number)
	if token ~= muteSaveToken then
		return
	end
	local wait = MUTE_SEND_GAP - (os.clock() - lastMuteSentAt)
	if wait > 0 then
		task.delay(wait, sendMuteLevel, token)
		return
	end
	if muteLevel == lastMuteSent then
		return
	end
	lastMuteSentAt = os.clock()
	lastMuteSent = muteLevel
	Remotes.event("SaveSettings"):FireServer({ muteLevel = muteLevel })
end

local function scheduleMuteSave()
	muteSaveToken += 1
	task.delay(MUTE_SAVE_DELAY, sendMuteLevel, muteSaveToken)
end

local function restoreMute(view: Types.ProfileView)
	if muteRestored then
		return
	end
	muteRestored = true
	local saved = if type(view.settings) == "table" then view.settings.muteLevel else nil
	if type(saved) ~= "number" or saved % 1 ~= 0 or saved < 1 or saved > #MUTE_LABELS then
		return
	end
	if userChangedMute then
		return -- 사용자 값 우선 (누른 값은 곧 저장돼요)
	end
	lastMuteSent = saved
	muteLevel = saved
	applyMute()
	if refreshMuteButton then
		refreshMuteButton()
	end
end

local function buildMuteButton(playerGui: Instance)
	local screen = Instance.new("ScreenGui")
	screen.Name = "SoundGui"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 5
	screen.ScreenInsets = Enum.ScreenInsets.TopbarSafeInsets

	local button = Instance.new("TextButton")
	button.Name = "MuteButton"
	-- 위쪽 바 높이에 맞춰 세로 가운데, 오른쪽 끝
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -MUTE_MARGIN, 0.5, 0)
	button.Size = UDim2.new(0, MUTE_WIDE_WIDTH, 1, -MUTE_MARGIN * 2)
	button.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	button.BackgroundTransparency = 0.35
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 14
	button.AutoButtonColor = true

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button

	local heightCap = Instance.new("UISizeConstraint")
	heightCap.MaxSize = Vector2.new(MUTE_WIDE_WIDTH, MUTE_MAX_HEIGHT)
	heightCap.Parent = button

	-- 좁은 화면(휴대폰 가로)에서는 아이콘만 (m3-08 QA B2): 위쪽 바 왼쪽의 Roblox 버튼과 멀리 떨어지게 폭을 줄여요
	local compact = false
	local function refresh()
		button.Text = if compact then MUTE_ICONS[muteLevel] else MUTE_LABELS[muteLevel]
		local width = if compact then MUTE_COMPACT_WIDTH else MUTE_WIDE_WIDTH
		button.Size = UDim2.new(0, width, 1, -MUTE_MARGIN * 2)
	end
	local function watchViewport()
		local camera = workspace.CurrentCamera
		if camera == nil then
			return
		end
		local function update()
			local narrow = camera.ViewportSize.X < Config.Fx.NarrowScreenWidth
			if narrow ~= compact then
				compact = narrow
				refresh()
			end
		end
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
		update()
	end
	refreshMuteButton = refresh
	refresh()
	watchViewport()

	button.Activated:Connect(function()
		muteLevel = muteLevel % #MUTE_LABELS + 1
		userChangedMute = true
		refresh()
		applyMute()
		scheduleMuteSave()
	end)

	button.Parent = screen
	screen.Parent = playerGui
end

-- 장애물 소리 (m3-09): 서버 MapSfx가 cue와 파트(·위치)를 보내면 여기서 3D로 내요.
-- 클라이언트가 내야 pitch·음소거("모두 끔")·동시 재생 한도가 다른 효과음과 같아요. 멀리 있는(다른 방) 소리는 무시해요.
local function playMapSfx(cue: unknown, part: unknown, position: unknown)
	if type(cue) ~= "string" or typeof(position) ~= "Vector3" then
		return
	end
	local at = position :: Vector3
	local camera = workspace.CurrentCamera
	if camera and (camera.CFrame.Position - at).Magnitude > ROLLOFF_MAX_DISTANCE then
		return
	end
	if typeof(part) == "Instance" and (part :: Instance):IsA("BasePart") and (part :: Instance).Parent ~= nil then
		Sfx.play(cue, part :: BasePart)
	else
		Sfx.play(cue, at)
	end
end

function Sfx.start(_gui: Instance)
	if started then
		return
	end
	started = true

	sfxGroup = makeGroup("Sfx", SFX_GROUP_VOLUME)
	musicGroup = makeGroup("Music", MUSIC_GROUP_VOLUME)
	applyMute()

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	-- 버튼 클릭음: 지금 있는 버튼 + 나중에 생기는 버튼 (다른 UI 파일을 고치지 않아요)
	for _, descendant in playerGui:GetDescendants() do
		hookButton(descendant)
	end
	playerGui.DescendantAdded:Connect(hookButton)

	buildMuteButton(playerGui)

	-- 저장된 음소거 단계: 이미 받은 프로필이 있으면 바로, 아니면 처음 올 때
	local current = ProfileStore.get()
	if current then
		restoreMute(current)
	else
		local connection: ProfileStore.Connection
		connection = ProfileStore.changed(function(view)
			connection:Disconnect()
			restoreMute(view)
		end)
	end

	Remotes.event("RoomUpdated").OnClientEvent:Connect(function(room: Types.RoomSnapshot?)
		inMatch = room ~= nil and room.state == "InMatch"
		if not inMatch then
			phaseInfo = nil
		end
		refreshMusic()
	end)

	Remotes.event("MatchPhase").OnClientEvent:Connect(function(info: Types.MatchPhaseInfo)
		phaseInfo = info
		refreshMusic()
	end)

	Remotes.event("PlayerResult").OnClientEvent:Connect(function(result: Types.PlayerResult)
		if result.userId == player.UserId and result.result == "Passed" then
			Sfx.play("Qualified")
		end
	end)

	Remotes.event("MapSfx").OnClientEvent:Connect(playMapSfx)

	refreshMusic()
end

return Sfx
