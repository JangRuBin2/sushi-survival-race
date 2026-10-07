--!strict
-- 맵 모듈 공통 인터페이스 (GDD 11.4, CLAUDE.md)
--
-- 맵 하나 = 이 폴더의 모듈 하나. MapModule 모양의 테이블을 돌려주고 maps/init.luau의 ALL에 추가해요.
--
-- 흐름 (RoundService가 호출)
--   build(origin)  회색 박스 Model을 지어서 돌려줘요. 아직 Workspace에 넣지 않아요.
--   start(ctx)     라운드 시작. 장애물을 가동하고 결승선/낙하 판정을 연결해서
--                  ctx.pass / ctx.eliminate를 불러요. 판정은 모두 서버에서 해요.
--   cleanup(ctx)   라운드가 끝난 뒤. ctx.cleanup에 넣은 것은 RoundService가 따로 정리하니까
--                  그 밖에 따로 치울 게 있을 때만 써요. 상태는 모듈이 아니라 ctx에 둬요
--                  (한 서버에서 여러 방이 같은 맵을 동시에 돌릴 수 있어요).
--
-- build()가 돌려주는 Model 안의 약속
--   Spawns (Folder)  시작 위치 BasePart들. 이름순으로 플레이어를 배치해요. 최대 인원(24)만큼 있어야 해요.
--   코스는 origin의 앞쪽(LookVector, 로컬 -Z)으로 뻗어요. 시간 종료 때 "가장 멀리 간" 순위도 이 축으로 재요.
-- 장애물은 CollectionService 태그(Chopstick, Wasabi, SoySauce, HotTile)를 파츠에 달아서 동작시켜요.

local Cleanup = require(script.Parent.Parent.Cleanup)
local Rules = require(script.Parent.Parent.Rules)

export type MapKind = Rules.MapKind

export type RoundContext = {
	model: Model,
	origin: CFrame,
	rng: Random,
	targetCount: number, -- 이번 라운드 통과(Survival은 생존) 목표 인원
	cleanup: Cleanup.Cleanup, -- 라운드가 끝나면 RoundService가 run() 해요
	isActive: () -> boolean,
	getRacers: () -> { Player }, -- 아직 통과/탈락하지 않은 플레이어
	pass: (player: Player) -> (), -- 결승선 통과 (Race/Final)
	eliminate: (player: Player) -> (), -- 탈락 (낙하 등)
}

export type MapModule = {
	id: string,
	kind: MapKind,
	displayName: string,
	rule: string, -- 라운드 소개 때 보여줄 한 줄 규칙
	timeLimit: number?, -- 없으면 Config.TimeLimit[kind]
	build: (origin: CFrame) -> Model,
	start: (ctx: RoundContext) -> (),
	cleanup: ((ctx: RoundContext) -> ())?,
}

local KINDS = { Race = true, Survival = true, Final = true }

local MapTypes = {}

-- 맵 모듈 모양 검사. 문제가 있으면 이유를, 괜찮으면 nil을 돌려줘요.
function MapTypes.validate(map: any): string?
	if type(map) ~= "table" then
		return "map module must return a table"
	end
	local id = map.id
	if type(id) ~= "string" or id == "" then
		return "id must be a non-empty string"
	end
	if not KINDS[map.kind] then
		return `{id}: kind must be Race, Survival or Final`
	end
	for _, field in { "displayName", "rule" } do
		if type(map[field]) ~= "string" then
			return `{id}: {field} must be a string`
		end
	end
	if map.timeLimit ~= nil and (type(map.timeLimit) ~= "number" or map.timeLimit <= 0) then
		return `{id}: timeLimit must be a positive number`
	end
	for _, field in { "build", "start" } do
		if type(map[field]) ~= "function" then
			return `{id}: {field} must be a function`
		end
	end
	if map.cleanup ~= nil and type(map.cleanup) ~= "function" then
		return `{id}: cleanup must be a function`
	end
	return nil
end

return MapTypes
