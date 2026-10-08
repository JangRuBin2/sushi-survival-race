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
--   overtime(ctx, info)  결승 연장전 (m5-01). 결승(마지막 라운드)에서 시간 제한이 되면 한 번 불러요.
--                  **kind == "Final" 맵은 필수**. 불리면 info.collapseDuration초 안에 어떤 레이서도 안전하게
--                  서 있을 수 없게 만들어야 해요(바닥 제거·치명 구역 등). 매달리기·높은 곳 버티기 같은
--                  "안전한 자리"가 남으면 안 돼요 (Fall Guys Jump Showdown infinite hang). 낙하 판정은 start에서
--                  하던 대로 ctx.eliminate. 상태는 ctx/지역 변수에 둬요. 결승이 아닌 라운드에서는 부르지 않아요.
--                  끝까지 안 끝나면 RoundService가 안전 상한(Config.Final.HardCapMargin 뒤)에 높이 순으로 판정해요.
--                  훅 안에서 오래 기다리지 마세요(task.wait 등): 일정은 task.delay/task.spawn 스레드를 ctx.cleanup에
--                  넣어 돌리고 바로 돌아와요. RoundService는 훅을 따로 스레드로 부르지만, 판정 일정은 훅을 기다리지 않아요.
--                  (훅이 없는 맵이 디버그 강제 플랜으로 결승이 되면 연장전 없이 시간 제한에 높이 순으로 끝나요.)
--
-- build()가 돌려주는 Model 안의 약속
--   Spawns (Folder)  시작 위치 BasePart들. 이름순으로 플레이어를 배치해요. 최대 인원(24)만큼 있어야 해요.
--   코스는 origin의 앞쪽(LookVector, 로컬 -Z)으로 뻗어요. 시간 종료 때 "가장 멀리 간" 순위도 이 축으로 재요.
-- 장애물은 CollectionService 태그를 파츠에 달아서 동작시켜요 (전체 목록은 CLAUDE.md "맵 모듈 공통 인터페이스":
-- Conveyor·Chopstick, SoySauce·Wasabi, Broth·Chashu·NoodleSweeper, HotTile, ChefBoardCell·ChefKnife, SkewerShowdown*).

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

-- 결승 연장전 정보 (m5-01)
export type OvertimeInfo = {
	collapseDuration: number, -- 이 시간(초) 안에 설 곳을 전부 없애야 해요
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
	overtime: ((ctx: RoundContext, info: OvertimeInfo) -> ())?, -- Final 맵은 필수 (m5-01)
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
	if map.kind == "Final" and type(map.overtime) ~= "function" then
		return `{id}: Final maps must have an overtime function`
	end
	if map.overtime ~= nil and type(map.overtime) ~= "function" then
		return `{id}: overtime must be a function`
	end
	return nil
end

return MapTypes
