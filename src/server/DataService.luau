--!strict
-- 플레이어 프로필 (GDD 9.4, 9.5). m4-07: DataStore 저장 + 세션 잠금 (직접 구현, 외부 라이브러리 없음).
--
--   DataService.get(player) -> Profile?                    로드 전·없으면 nil
--   DataService.waitForProfile(player, timeout?) -> Profile?  로드될 때까지 기다려요 (기본 10초)
--   DataService.update(player, mutate) -> boolean          로드 전이면 false. 바꾼 뒤 그 프레임 끝에 본인에게
--                                                         ProfileUpdated를 한 번 보내요 (한 프레임에 여러 번 바꿔도 한 번)
--   DataService.onLoaded(fn(player, profile)) -> 해제 함수   이미 로드된 사람에게도 바로 불러요
--   DataService.canPersist(player) -> boolean              이 프로필이 저장되는가
--   DataService.saveNow(player) -> boolean                 지금 저장하고 성공 여부 (m4-14 결제). 같은 사람 저장은
--                                                         한 번에 하나씩, 겹치면 앞 저장이 끝난 뒤 한 번 더 (yield)
-- 리모트: SaveSettings({ muteLevel }) — 표·정수 1~3·요청 간격(Config.Data.SettingsMinInterval)을 검증하고
-- 잘못된 값은 조용히 무시해요.
--
-- 저장: 저장소 Config.Data.StoreName, 키 u_<UserId>, 값 { profile, lock = { jobId, at }? } (ProfileLogic).
--   로드(PlayerAdded): UpdateAsync로 읽으며 잠금을 걸어요. 남의 잠금이 만료 전이면 RetryDelay초 뒤 다시
--   (LoadRetries번), 그래도 잠겨 있으면 가져와요(경고). 요청 에러는 MAX_RETRIES번 다시, 그래도 실패하면
--   임시 프로필(저장 안 함 — 진짜 데이터를 빈 값으로 덮어쓰지 않게).
--   저장: 바뀐 프로필을 AutosaveInterval마다, 나갈 때(잠금 해제), BindToClose(최대 25초)에서. 저장소 잠금이
--   내 것이 아니면 쓰지 않고 그 사람은 임시 프로필로 바꿔요.
--   Studio: Config.DEBUG.persistDataInStudio가 false면 메모리만. true인데 API 접근이 꺼져 있으면 경고 한 줄 + 메모리.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local ProfileLogic = require(ReplicatedStorage.Shared.ProfileLogic)
local ProfileSchema = require(ReplicatedStorage.Shared.ProfileSchema)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

export type Profile = ProfileSchema.Profile

type Session = {
	player: Player,
	key: string,
	profile: Profile,
	persist: boolean, -- false면 임시 프로필 (저장 안 함)
	dirty: boolean,
	released: boolean, -- 잠금을 풀었음 (더 저장하지 않음)
	saving: boolean,
	wantGen: number, -- 요청된 저장 번호
	doneGen: number, -- 처리된 저장 번호
	okGen: number, -- 성공한 저장 번호
	wantRelease: boolean,
	lastWriteAt: number, -- os.clock()
}

type Request = () -> ()
type Transform = (old: unknown) -> { [string]: any }?

local DataService = {}

local DEFAULT_WAIT = 10
local MAX_RETRIES = 3 -- DataStore 요청 에러 때 다시 시도하는 횟수
local CLOSE_TIMEOUT = 25 -- BindToClose에서 저장을 기다리는 최대 시간(초)
local BUDGET_MAX_WAIT = 10 -- 요청 예산이 0일 때 기다리는 최대 시간(초)
local LOCK_REFRESH = Config.Data.SessionLockExpiry / 3 -- 바뀐 게 없어도 이 간격마다 잠금 시간을 갱신해요

local store: DataStore? = nil
local jobId = ""
local studio = false
local closing = false

local sessions: { [Player]: Session } = {}
local saving: { [Session]: boolean } = {} -- 나간 사람 포함, 저장 중인 세션 (BindToClose가 기다려요)
local dirtyView: { [Player]: boolean } = {} -- 이번 프레임 끝에 ProfileUpdated를 보낼 사람
local lastSettingsAt: { [Player]: number } = {}
local loadedListeners: { (player: Player, profile: Profile) -> () } = {}

local profileUpdatedEvent: RemoteEvent

local function keyFor(player: Player): string
	return `u_{player.UserId}`
end

local function sendView(player: Player)
	local session = sessions[player]
	if session == nil or player.Parent == nil then
		return
	end
	profileUpdatedEvent:FireClient(player, ProfileSchema.toView(session.profile, session.persist))
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

-- Studio에서 API 접근이 꺼져 있으면(또는 퍼블리시 전) 요청마다 에러가 나요. 경고 한 줄 남기고 메모리로 바꿔요.
local function disableStore(reason: string)
	if store == nil then
		return
	end
	store = nil
	warn(`[DataService] DataStore unavailable in Studio, using memory only: {reason}`)
end

local function waitForBudget(requestType: Enum.DataStoreRequestType)
	local waited = 0
	while waited < BUDGET_MAX_WAIT do
		local ok, budget = pcall(function()
			return DataStoreService:GetRequestBudgetForRequestType(requestType)
		end)
		if not ok or budget > 0 then
			return
		end
		task.wait(0.5)
		waited += 0.5
	end
end

-- DataStore 요청 하나를 에러 때 MAX_RETRIES번까지 다시 해요. 성공하면 true.
local function request(what: string, fn: Request): boolean
	for attempt = 1, MAX_RETRIES + 1 do
		if store == nil then
			return false
		end
		waitForBudget(Enum.DataStoreRequestType.UpdateAsync)
		local ok, err = pcall(fn)
		if ok then
			return true
		end
		if studio then
			disableStore(tostring(err))
			return false
		end
		warn(`[DataService] {what} failed (attempt {attempt}/{MAX_RETRIES + 1}): {err}`)
		if attempt <= MAX_RETRIES and not closing then
			task.wait(Config.Data.RetryDelay)
		end
	end
	return false
end

local function updateAsync(key: string, userId: number, transform: Transform)
	local dataStore = store :: DataStore
	dataStore:UpdateAsync(key, function(old: unknown)
		local new = transform(old)
		if new == nil then
			return nil
		end
		return new, { userId }
	end)
end

-- 잠금을 걸고 프로필을 읽어요. 돌려주는 값: (프로필, 저장 가능)
local function loadFromStore(player: Player): (Profile, boolean)
	if store == nil then
		return ProfileSchema.new(), false
	end
	local key = keyFor(player)
	local userId = player.UserId
	local expiry = Config.Data.SessionLockExpiry
	for attempt = 1, Config.Data.LoadRetries + 1 do
		local allowSteal = attempt > Config.Data.LoadRetries
		local raw: unknown = nil
		local decision = "take"
		local ok = request(`load {key}`, function()
			updateAsync(key, userId, function(old)
				local new, result = ProfileLogic.claim(old, jobId, os.time(), expiry, allowSteal)
				decision = result
				raw = if type(old) == "table" then (old :: any).profile else nil
				return new
			end)
		end)
		if not ok then
			if store ~= nil then
				warn(`[DataService] could not load {key}, using a temporary profile (not saved)`)
			end
			return ProfileSchema.new(), false
		end
		if decision == "wait" then
			if player.Parent == nil then
				return ProfileSchema.new(), false
			end
			task.wait(Config.Data.RetryDelay)
			continue
		end
		if decision == "steal" then
			warn(`[DataService] {key} was locked by another server, taking the lock (previous server presumed dead)`)
		end
		local profile, info = ProfileLogic.migrate(raw)
		if not info.persistable then
			warn(`[DataService] {key}: {table.concat(info.notes, "; ")}`)
			-- 저장하지 않으니 잠금을 바로 풀어 둬요 (다른 서버가 기다리지 않게)
			task.spawn(request, `release {key}`, function()
				updateAsync(key, userId, function(old)
					return ProfileLogic.release(old, jobId)
				end)
			end)
			return profile, false
		end
		return profile, true
	end
	return ProfileSchema.new(), false -- 도달하지 않아요 (마지막 시도는 allowSteal)
end

-- 저장 한 번. 성공하면 true.
local function writeOnce(session: Session, release: boolean): boolean
	if session.released then
		return true
	end
	if not session.persist or store == nil then
		return false
	end
	local snapshot = ProfileLogic.deepCopy(session.profile)
	local wasDirty = session.dirty
	session.dirty = false
	local written = false
	local ok = request(`save {session.key}`, function()
		updateAsync(session.key, session.player.UserId, function(old)
			local new, canWrite = ProfileLogic.commit(old, snapshot, jobId, os.time(), release)
			written = canWrite
			return new
		end)
	end)
	if not ok then
		session.dirty = session.dirty or wasDirty
		return false
	end
	if not written then
		warn(`[DataService] {session.key}: session lock lost to another server, switching to a temporary profile`)
		session.persist = false
		scheduleView(session.player)
		return false
	end
	session.lastWriteAt = os.clock()
	if release then
		session.released = true
	end
	return true
end

local function runSaves(session: Session)
	if session.saving then
		return
	end
	session.saving = true
	saving[session] = true
	while session.doneGen < session.wantGen do
		local gen = session.wantGen
		local release = session.wantRelease
		local ok = writeOnce(session, release)
		session.doneGen = gen
		if ok then
			session.okGen = gen
		end
	end
	session.saving = false
	saving[session] = nil
end

-- 저장을 요청하고 끝날 때까지 기다려요 (yield). 겹치면 앞 저장이 끝난 뒤 한 번 더 써요.
local function save(session: Session, release: boolean): boolean
	session.wantGen += 1
	session.wantRelease = session.wantRelease or release
	local myGen = session.wantGen
	if not session.saving then
		task.spawn(runSaves, session)
	end
	while session.doneGen < myGen do
		task.wait()
	end
	return session.okGen >= myGen
end

local function load(player: Player)
	if sessions[player] then
		return
	end
	local profile, persist = loadFromStore(player)
	local session: Session = {
		player = player,
		key = keyFor(player),
		profile = profile,
		persist = persist,
		dirty = false,
		released = false,
		saving = false,
		wantGen = 0,
		doneGen = 0,
		okGen = 0,
		wantRelease = false,
		lastWriteAt = os.clock(),
	}
	if player.Parent == nil or closing then
		-- 로드하는 동안 나갔어요: 건 잠금만 풀어요
		if persist then
			save(session, true)
		end
		return
	end
	sessions[player] = session
	scheduleView(player)
	for _, fn in table.clone(loadedListeners) do
		callLoaded(fn, player, profile)
	end
end

local function unload(player: Player)
	local session = sessions[player]
	sessions[player] = nil
	dirtyView[player] = nil
	lastSettingsAt[player] = nil
	if session and session.persist then
		save(session, true)
	end
end

function DataService.get(player: Player): Profile?
	local session = sessions[player]
	return if session then session.profile else nil
end

function DataService.waitForProfile(player: Player, timeout: number?): Profile?
	local deadline = os.clock() + (timeout or DEFAULT_WAIT)
	while true do
		local profile = DataService.get(player)
		if profile or player.Parent == nil or os.clock() >= deadline then
			return profile
		end
		task.wait(0.1)
	end
end

function DataService.update(player: Player, mutate: (Profile) -> ()): boolean
	local session = sessions[player]
	if session == nil then
		return false
	end
	mutate(session.profile)
	session.dirty = true
	scheduleView(player)
	return true
end

function DataService.onLoaded(fn: (player: Player, profile: Profile) -> ()): () -> ()
	table.insert(loadedListeners, fn)
	for player, session in sessions do
		callLoaded(fn, player, session.profile)
	end
	return function()
		local index = table.find(loadedListeners, fn)
		if index then
			table.remove(loadedListeners, index)
		end
	end
end

function DataService.canPersist(player: Player): boolean
	local session = sessions[player]
	return session ~= nil and session.persist and store ~= nil
end

function DataService.saveNow(player: Player): boolean
	local session = sessions[player]
	if session == nil or not session.persist then
		return false
	end
	return save(session, false)
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

local function autosave()
	while not closing do
		task.wait(Config.Data.AutosaveInterval)
		if closing or store == nil then
			continue
		end
		local now = os.clock()
		for _, session in sessions do
			if session.persist and (session.dirty or now - session.lastWriteAt >= LOCK_REFRESH) then
				task.spawn(save, session, false)
			end
		end
	end
end

local function onClose()
	closing = true
	if store == nil then
		return
	end
	for _, session in sessions do
		if session.persist then
			task.spawn(save, session, true)
		end
	end
	local deadline = os.clock() + CLOSE_TIMEOUT
	while next(saving) ~= nil and os.clock() < deadline do
		task.wait(0.1)
	end
end

local function openStore()
	studio = RunService:IsStudio()
	if studio and not Config.DEBUG.persistDataInStudio then
		return -- Studio 기본: 메모리만
	end
	jobId = if game.JobId ~= "" then game.JobId else `studio-{HttpService:GenerateGUID(false)}`
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.Data.StoreName)
	end)
	if ok then
		store = result
	elseif studio then
		warn(`[DataService] DataStore unavailable in Studio, using memory only: {result}`)
	else
		warn(`[DataService] could not open DataStore, profiles will not be saved: {result}`)
	end
end

function DataService.init()
	openStore()
	profileUpdatedEvent = Remotes.event("ProfileUpdated")
	Remotes.event("SaveSettings").OnServerEvent:Connect(onSaveSettings)
	Players.PlayerAdded:Connect(load)
	Players.PlayerRemoving:Connect(unload)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	game:BindToClose(onClose)
end

function DataService.start()
	task.spawn(autosave)
end

return DataService
