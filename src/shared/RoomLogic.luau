--!strict
-- 방 규칙 (GDD 3.2): 설정 검증, 이름 정리, 방 코드, 참가/퇴장/방장 승계, 시작 조건, 빠른 참가.
-- Roblox API를 쓰지 않는 순수 로직이에요. RoomService(서버)와 로비 UI(클라이언트)가 같이 쓰고,
-- tests/room.spec.luau에서 Lune으로 돌려요. 방 하나는 평범한 테이블이고 여기 함수들이 고쳐요.

local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local RoomLogic = {}

export type Room = {
	id: string,
	name: string,
	maxPlayers: number,
	isPrivate: boolean,
	code: string?, -- 비공개 방만
	hostUserId: number,
	members: { Types.MemberInfo }, -- 들어온 순서. 방장이 나가면 맨 앞 사람이 이어받아요.
	state: Types.RoomState,
	autoStartAt: number?, -- 정원이 다 찼을 때 자동 시작 시각
	slot: number, -- 아레나 슬롯 (Config.Arena.SlotSpacing 간격으로 맵을 띄우는 번호, 1부터)
	-- 서버를 넘어 같은 방을 알아보는 키 (m4-11). 로비↔매치 텔레포트 동안 그대로 따라가요.
	key: string?,
}

export type NewRoomParams = {
	id: string,
	name: string,
	maxPlayers: number,
	isPrivate: boolean,
	code: string?,
	slot: number,
	key: string?,
}

-- Random과 같은 모양 (Rules.Rng)
export type Rng = {
	NextInteger: (self: any, min: number, max: number) -> number,
}

-- 방장 시작 버튼에 필요한 최소 인원. 스튜디오에서는 혼자 테스트할 수 있게 DEBUG 값을 써요.
function RoomLogic.minPlayersToStart(isStudio: boolean): number
	if isStudio then
		return Config.DEBUG.minPlayersToStart
	end
	return Config.Room.MinPlayersToStart
end

-- 방 이름 정리: 제어 문자 제거, 공백 정리, 최대 길이(글자 수)로 자르기. 남는 게 없으면 nil.
-- 텍스트 필터는 서버에서 따로 적용해요.
function RoomLogic.cleanName(raw: any): string?
	if type(raw) ~= "string" or utf8.len(raw) == nil then
		return nil
	end
	local name = string.gsub(raw, "%c", " ")
	name = string.gsub(name, "%s+", " ")
	name = string.match(name, "^%s*(.-)%s*$") :: string
	if name == "" then
		return nil
	end
	local cut = utf8.offset(name, Config.Room.NameMaxLength + 1)
	if cut then
		name = string.match(string.sub(name, 1, cut - 1), "^(.-)%s*$") :: string
	end
	return name
end

function RoomLogic.defaultName(displayName: string): string
	return RoomLogic.cleanName(`{displayName}의 초밥집`) or "초밥집"
end

-- 클라이언트가 보낸 방 만들기 설정 검증. name은 정리한 결과라 nil일 수 있어요 (그러면 기본 이름).
function RoomLogic.validateSettings(raw: any): (Types.RoomSettings?, string?)
	if type(raw) ~= "table" then
		return nil, "잘못된 방 설정이에요"
	end
	local maxPlayers = raw.maxPlayers
	if type(maxPlayers) ~= "number" or not table.find(Config.Room.MaxPlayerOptions, maxPlayers) then
		return nil, "최대 인원을 다시 골라 주세요"
	end
	if type(raw.isPrivate) ~= "boolean" then
		return nil, "공개 여부를 다시 골라 주세요"
	end
	if raw.name ~= nil and type(raw.name) ~= "string" then
		return nil, "방 이름이 올바르지 않아요"
	end
	return {
		maxPlayers = maxPlayers,
		isPrivate = raw.isPrivate,
		name = RoomLogic.cleanName(raw.name),
	}, nil
end

local function codePattern(): string
	return "^" .. string.rep("%d", Config.Room.CodeLength) .. "$"
end

function RoomLogic.isValidCode(code: any): boolean
	return type(code) == "string" and string.match(code, codePattern()) ~= nil
end

-- 겹치지 않는 비공개 방 코드 ("0000"~"9999"). 빈 코드를 못 찾으면 nil.
function RoomLogic.generateCode(rng: Rng, isTaken: (code: string) -> boolean): string?
	local length = Config.Room.CodeLength
	local max = 10 ^ length - 1
	local format = "%0" .. length .. "d"
	for _ = 1, 200 do
		local code = string.format(format, rng:NextInteger(0, max))
		if not isTaken(code) then
			return code
		end
	end
	return nil
end

-- 비어 있는 가장 작은 아레나 슬롯 번호 (1부터)
function RoomLogic.nextFreeSlot(used: { [number]: boolean }): number
	local slot = 1
	while used[slot] do
		slot += 1
	end
	return slot
end

function RoomLogic.newRoom(params: NewRoomParams, host: Types.MemberInfo): Room
	return {
		id = params.id,
		name = params.name,
		maxPlayers = params.maxPlayers,
		isPrivate = params.isPrivate,
		code = if params.isPrivate then params.code else nil,
		hostUserId = host.userId,
		members = { { userId = host.userId, name = host.name } },
		state = "Waiting",
		autoStartAt = nil,
		slot = params.slot,
		key = params.key,
	}
end

function RoomLogic.isMember(room: Room, userId: number): boolean
	for _, member in room.members do
		if member.userId == userId then
			return true
		end
	end
	return false
end

function RoomLogic.isFull(room: Room): boolean
	return #room.members >= room.maxPlayers
end

-- 참가 가능 여부 (실패하면 화면에 보여줄 이유)
function RoomLogic.canJoin(room: Room, userId: number): (boolean, string?)
	if RoomLogic.isMember(room, userId) then
		return false, "이미 이 방에 있어요"
	end
	if room.state ~= "Waiting" then
		return false, "이미 게임 중인 방이에요"
	end
	if RoomLogic.isFull(room) then
		return false, "방이 꽉 찼어요"
	end
	return true, nil
end

function RoomLogic.addMember(room: Room, member: Types.MemberInfo): (boolean, string?)
	local ok, err = RoomLogic.canJoin(room, member.userId)
	if not ok then
		return false, err
	end
	table.insert(room.members, { userId = member.userId, name = member.name })
	return true, nil
end

-- 매치가 이미 시작된 방에 늦게 온 멤버를 넣어요 (m4-11 매치 서버: 관전자). 이미 멤버거나 꽉 찼으면 false.
function RoomLogic.addLateMember(room: Room, member: Types.MemberInfo): boolean
	if RoomLogic.isMember(room, member.userId) or RoomLogic.isFull(room) then
		return false
	end
	table.insert(room.members, { userId = member.userId, name = member.name })
	return true
end

-- 멤버를 빼고, 방장이 나갔으면 가장 먼저 들어온 사람에게 넘겨요. 뺐으면 true.
function RoomLogic.removeMember(room: Room, userId: number): boolean
	for i, member in room.members do
		if member.userId == userId then
			table.remove(room.members, i)
			if room.hostUserId == userId and room.members[1] then
				room.hostUserId = room.members[1].userId
			end
			return true
		end
	end
	return false
end

-- 방장의 시작 요청 검증
function RoomLogic.canStart(room: Room, userId: number, minPlayers: number): (boolean, string?)
	if room.hostUserId ~= userId then
		return false, "방장만 시작할 수 있어요"
	end
	if room.state ~= "Waiting" then
		return false, "이미 게임 중이에요"
	end
	if #room.members < minPlayers then
		return false, `최소 {minPlayers}명이 모여야 시작할 수 있어요`
	end
	return true, nil
end

-- 정원이 다 찬 대기 중인 방은 자동 시작 카운트다운을 돌려요.
function RoomLogic.shouldAutoStart(room: Room): boolean
	return room.state == "Waiting" and RoomLogic.isFull(room)
end

local function byId(a: Room, b: Room): boolean
	local na, nb = tonumber(a.id), tonumber(b.id)
	if na and nb then
		return na < nb
	end
	return a.id < b.id
end

-- 빠른 참가: 자리가 남은 공개 대기 방 중 시작이 가장 임박한 곳.
-- 자동 시작 카운트다운이 도는 방(빠른 순) → 사람이 많은 방 → 먼저 만든 방 순서예요.
-- (정원이 찬 방만 카운트다운이 돌아서 지금은 첫 조건에 걸리는 방이 없지만, 시작 조건이 바뀌어도 맞게 둬요.)
function RoomLogic.pickQuickJoin(rooms: { Room }): Room?
	local best: Room? = nil
	for _, room in rooms do
		if room.isPrivate or room.state ~= "Waiting" or RoomLogic.isFull(room) then
			continue
		end
		if best == nil then
			best = room
			continue
		end
		local current = best :: Room
		local a, b = room.autoStartAt or math.huge, current.autoStartAt or math.huge
		if a ~= b then
			if a < b then
				best = room
			end
		elseif #room.members ~= #current.members then
			if #room.members > #current.members then
				best = room
			end
		elseif byId(room, current) then
			best = room
		end
	end
	return best
end

-- 방 멤버에게 보내는 상세 정보
function RoomLogic.snapshot(room: Room): Types.RoomSnapshot
	local members = table.create(#room.members) :: { Types.MemberInfo }
	for i, member in room.members do
		members[i] = { userId = member.userId, name = member.name }
	end
	return {
		id = room.id,
		name = room.name,
		maxPlayers = room.maxPlayers,
		isPrivate = room.isPrivate,
		code = room.code,
		hostUserId = room.hostUserId,
		members = members,
		state = room.state,
		autoStartAt = room.autoStartAt,
	}
end

-- 로비 방 목록: 공개 방만. 대기 중인 방 → 사람 많은 방 → 먼저 만든 방 순서.
function RoomLogic.listPublic(rooms: { Room }): { Types.RoomListing }
	local visible: { Room } = {}
	for _, room in rooms do
		if not room.isPrivate then
			table.insert(visible, room)
		end
	end
	table.sort(visible, function(a: Room, b: Room): boolean
		if a.state ~= b.state then
			return a.state == "Waiting"
		end
		if #a.members ~= #b.members then
			return #a.members > #b.members
		end
		return byId(a, b)
	end)
	local listings = table.create(#visible) :: { Types.RoomListing }
	for i, room in visible do
		listings[i] = {
			id = room.id,
			name = room.name,
			maxPlayers = room.maxPlayers,
			memberCount = #room.members,
			state = room.state,
		}
	end
	return listings
end

return RoomLogic
