--!strict
-- 플레이어 프로필 (GDD 9.4, 9.5). m4-01은 **메모리 버전**이에요: 접속하면 ProfileSchema.new()로 바로 로드하고
-- 나가면 지워요 (저장 안 함). 진짜 DataStore 저장·세션 잠금은 m4-07이 이 파일에 붙여요 — 아래 API는 그대로.
--
--   DataService.get(player) -> Profile?                    로드 전·없으면 nil
--   DataService.waitForProfile(player, timeout?) -> Profile?  로드될 때까지 기다려요 (기본 10초)
--   DataService.update(player, mutate) -> boolean          로드 전이면 false. 바꾼 뒤 그 프레임 끝에 본인에게
--                                                         ProfileUpdated를 한 번 보내요 (한 프레임에 여러 번 바꿔도 한 번)
--   DataService.onLoaded(fn(player, profile)) -> 해제 함수   이미 로드된 사람에게도 바로 불러요
--   DataService.canPersist(player) -> boolean              이 프로필이 저장되는가 (메모리 버전은 항상 false)
-- 리모트: SaveSettings({ muteLevel }) — 표·정수 1~3·요청 간격(Config.Data.SettingsMinInterval)을 검증하고
-- 잘못된 값은 조용히 무시해요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ProfileSchema = require(ReplicatedStorage.Shared.ProfileSchema)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

export type Profile = ProfileSchema.Profile

local DataService = {}

local DEFAULT_WAIT = 10

local profiles: { [Player]: Profile } = {}
local dirtyView: { [Player]: boolean } = {} -- 이번 프레임 끝에 ProfileUpdated를 보낼 사람
local lastSettingsAt: { [Player]: number } = {}
local loadedListeners: { (player: Player, profile: Profile) -> () } = {}

local profileUpdatedEvent: RemoteEvent

local function sendView(player: Player)
	local profile = profiles[player]
	if profile == nil or player.Parent == nil then
		return
	end
	profileUpdatedEvent:FireClient(player, ProfileSchema.toView(profile, DataService.canPersist(player)))
end

local function scheduleView(player: Player)
	if dirtyView[player] then
		return
	end
	dirtyView[player] = true
	task.defer(function()
		dirtyView[player] = nil
		sendView(player)
	end)
end

local function callLoaded(fn: (Player, Profile) -> (), player: Player, profile: Profile)
	task.spawn(function()
		local ok, err = pcall(fn, player, profile)
		if not ok then
			warn(`[DataService] onLoaded handler failed: {err}`)
		end
	end)
end

local function load(player: Player)
	if profiles[player] then
		return
	end
	local profile = ProfileSchema.new()
	profiles[player] = profile
	scheduleView(player)
	for _, fn in table.clone(loadedListeners) do
		callLoaded(fn, player, profile)
	end
end

local function unload(player: Player)
	profiles[player] = nil
	dirtyView[player] = nil
	lastSettingsAt[player] = nil
end

function DataService.get(player: Player): Profile?
	return profiles[player]
end

function DataService.waitForProfile(player: Player, timeout: number?): Profile?
	local deadline = os.clock() + (timeout or DEFAULT_WAIT)
	while true do
		local profile = profiles[player]
		if profile or player.Parent == nil or os.clock() >= deadline then
			return profile
		end
		task.wait(0.1)
	end
end

function DataService.update(player: Player, mutate: (Profile) -> ()): boolean
	local profile = profiles[player]
	if profile == nil then
		return false
	end
	mutate(profile)
	scheduleView(player)
	return true
end

function DataService.onLoaded(fn: (player: Player, profile: Profile) -> ()): () -> ()
	table.insert(loadedListeners, fn)
	for player, profile in profiles do
		callLoaded(fn, player, profile)
	end
	return function()
		local index = table.find(loadedListeners, fn)
		if index then
			table.remove(loadedListeners, index)
		end
	end
end

function DataService.canPersist(_player: Player): boolean
	return false
end

local function onSaveSettings(player: Player, value: unknown)
	local now = os.clock()
	local last = lastSettingsAt[player]
	if last and now - last < Config.Data.SettingsMinInterval then
		return
	end
	lastSettingsAt[player] = now
	local settings = ProfileSchema.sanitizeSettings(value)
	if settings == nil then
		return
	end
	DataService.update(player, function(profile)
		profile.settings.muteLevel = settings.muteLevel
	end)
end

function DataService.init()
	profileUpdatedEvent = Remotes.event("ProfileUpdated")
	Remotes.event("SaveSettings").OnServerEvent:Connect(onSaveSettings)
	Players.PlayerAdded:Connect(load)
	Players.PlayerRemoving:Connect(unload)
	for _, player in Players:GetPlayers() do
		load(player)
	end
end

function DataService.start() end

return DataService
