--!strict
-- m4-01 기반 작업: PlaceRole, ProfileSchema, MapKitLogic, MoveExempt, 결승 같은 묶음 리셋(m2-07 I1),
-- 새 맵 stub 2개, Config 기본값, 공용 파일·훅 계약 (docs/specs/m4-01-foundation.md)

local fs = require("@lune/fs")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local PlaceRole = RobloxRequire.require(Shared.PlaceRole)
local ProfileSchema = RobloxRequire.require(Shared.ProfileSchema)
local MoveExempt = RobloxRequire.require(Shared.MoveExempt)
local RoundLogic = RobloxRequire.require(Shared.RoundLogic)
local Rules = RobloxRequire.require(Shared.Rules)
local Maps = RobloxRequire.require(Shared.maps)
local MapTypes = RobloxRequire.require(Shared.maps.MapTypes)
local MapKitLogic = RobloxRequire.require(Shared.maps.MapKitLogic)

local function fakeRng(seed: number)
	local state = seed
	return {
		NextInteger = function(_, min: number, max: number): number
			state = (state * 1103515245 + 12345) % 2147483648
			return min + state % (max - min + 1)
		end,
	}
end

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

local function noScore(): number
	return 0
end

local function summary(outcomes: { any }): { [number]: string }
	local out = {}
	for _, o in outcomes do
		out[o.userId] = `{o.result}:{o.place}`
	end
	return out
end

local function spec(overrides: { [string]: any }?): { [string]: any }
	local s: { [string]: any } = {
		name = "Lantern",
		shape = "Block",
		size = { x = 2, y = 4, z = 2 },
		color = { r = 170, g = 30, b = 36 },
		material = "Wood",
		offset = { x = 0, y = 0, z = 0 },
	}
	for k, v in overrides or {} do
		s[k] = v
	end
	return s
end

local function source(path: string): string
	return fs.readFile(path)
end

local function has(path: string, text: string): boolean
	return string.find(source(path), text, 1, true) ~= nil
end

return function(t: Test.Test)
	-- AC1 ---------------------------------------------------------------------------------
	t.test("AC1: PlaceRole.resolve", function()
		local both = { LobbyPlaceId = 100, MatchPlaceId = 200 }
		t.eq(PlaceRole.resolve(200, both, true), "Single", "Studio")
		t.eq(PlaceRole.resolve(200, {}, false), "Single", "no ids")
		t.eq(PlaceRole.resolve(100, { LobbyPlaceId = 100 }, false), "Single", "lobby only")
		t.eq(PlaceRole.resolve(200, { MatchPlaceId = 200 }, false), "Single", "match only")
		t.eq(PlaceRole.resolve(200, both, false), "Match")
		t.eq(PlaceRole.resolve(100, both, false), "Lobby")
		t.eq(PlaceRole.resolve(999, both, false), "Lobby", "other place")
	end)

	-- AC2 ---------------------------------------------------------------------------------
	t.test("AC2: ProfileSchema.new 기본값, 부를 때마다 다른 표", function()
		local a = ProfileSchema.new()
		-- m5-03이 v2로 올렸어요 (redeemedCodes·eventTokens·ownedFx·equippedFx·boughtOffers)
		t.eq(a.version, 2)
		t.eq(ProfileSchema.VERSION, 2)
		t.eq(a.coins, 0)
		t.eq(a.wins, 0)
		t.eq(a.matchesPlayed, 0)
		t.eq(a.lastDailyBonusDay, nil)
		t.eq(a.ownedSkins, { tamago = true })
		t.eq(a.equippedSkin, "tamago")
		t.eq(a.equippedSkin, Config.Appearance.Default)
		t.eq(a.settings.muteLevel, 1)

		local b = ProfileSchema.new()
		t.ok(a ~= b and a.ownedSkins ~= b.ownedSkins and a.settings ~= b.settings, "fresh tables")
		a.coins = 50
		a.ownedSkins.salmon = true
		a.settings.muteLevel = 3
		t.eq(b.coins, 0)
		t.eq(b.ownedSkins, { tamago = true })
		t.eq(b.settings.muteLevel, 1)
		t.eq(ProfileSchema.new().coins, 0)
	end)

	-- AC3 ---------------------------------------------------------------------------------
	t.test("AC3: titleFor 경계값", function()
		t.eq(ProfileSchema.titleFor(0), nil)
		t.eq(ProfileSchema.titleFor(1), "탈출 초밥")
		t.eq(ProfileSchema.titleFor(9), "탈출 초밥")
		t.eq(ProfileSchema.titleFor(10), "전설의 참치")
		t.eq(ProfileSchema.titleFor(99), "전설의 참치")
		t.eq(ProfileSchema.titleFor(100), "바다의 왕")
		t.eq(ProfileSchema.titleFor(250), "바다의 왕")
	end)

	t.test("AC3: toView는 ownedSkins 이름순 목록, title = titleFor(wins), 설정 복사", function()
		local p = ProfileSchema.new()
		p.ownedSkins = { tuna = true, ebi = true, tamago = true, salmon = false }
		p.wins = 12
		p.coins = 340
		p.settings.muteLevel = 2
		local view = ProfileSchema.toView(p, false)
		t.eq(view.ownedSkins, { "ebi", "tamago", "tuna" })
		t.eq(view.title, "전설의 참치")
		t.eq(view.coins, 340)
		t.eq(view.wins, 12)
		t.eq(view.equippedSkin, "tamago")
		t.eq(view.settings, { muteLevel = 2 })
		t.eq(view.persistent, false)
		t.ok(view.settings ~= p.settings, "settings copied")
		t.eq(ProfileSchema.toView(ProfileSchema.new(), true).persistent, true)
		t.eq(ProfileSchema.toView(ProfileSchema.new(), true).title, nil)
	end)

	t.test("SaveSettings 검증: 표 + 정수 1~3만", function()
		t.eq(ProfileSchema.sanitizeSettings({ muteLevel = 1 }), { muteLevel = 1 })
		t.eq(ProfileSchema.sanitizeSettings({ muteLevel = 3 }), { muteLevel = 3 })
		for _, bad in
			{
				nil,
				2,
				"2",
				{},
				{ muteLevel = 0 },
				{ muteLevel = 4 },
				{ muteLevel = 1.5 },
				{ muteLevel = "1" },
				{ muteLevel = 0 / 0 },
			} :: { any }
		do
			t.eq(ProfileSchema.sanitizeSettings(bad), nil, `rejects {tostring(bad)}`)
		end
		t.eq(ProfileSchema.sanitizeSettings({ muteLevel = 2, extra = true }), { muteLevel = 2 }, "drops extra keys")
	end)

	-- AC4 ---------------------------------------------------------------------------------
	t.test("AC4: MapKitLogic.validate가 크기 0·색 300·모르는 재질을 거부", function()
		t.eq(MapKitLogic.validate({ spec(), spec({ name = "Ball", shape = "Ball" }) }), nil)
		t.eq(MapKitLogic.validate({}), nil)
		t.ok(MapKitLogic.validate({ spec({ size = { x = 0, y = 1, z = 1 } }) }) ~= nil, "size 0")
		t.ok(MapKitLogic.validate({ spec({ color = { r = 300, g = 0, b = 0 } }) }) ~= nil, "color 300")
		t.ok(MapKitLogic.validate({ spec({ material = "Unobtanium" }) }) ~= nil, "material")
		t.ok(MapKitLogic.validate({ spec({ shape = "Torus" }) }) ~= nil, "shape")
		t.ok(MapKitLogic.validate({ spec({ name = "" }) }) ~= nil, "name")
		t.ok(MapKitLogic.validate({ spec({ transparency = 2 }) }) ~= nil, "transparency")
		t.ok(MapKitLogic.validate({ spec({ offset = { x = 1 } }) }) ~= nil, "offset")
		-- 몇 번째가 틀렸는지 알려줘요
		local problem = MapKitLogic.validate({ spec(), spec({ name = "Bad", material = "Nope" }) }) :: string
		t.ok(string.find(problem, "#2 Bad", 1, true) ~= nil, problem)
	end)

	t.test("AC4: count·bounds가 손 계산과 같아요 (회전 포함)", function()
		local specs = {
			spec({ size = { x = 2, y = 4, z = 2 }, offset = { x = 0, y = 2, z = 0 } }),
			spec({ size = { x = 10, y = 1, z = 6 }, offset = { x = 5, y = 0, z = -20 } }),
		}
		t.eq(MapKitLogic.count(specs), 2)
		local b = MapKitLogic.bounds(specs) :: any
		t.eq(b.min, { x = -1, y = -0.5, z = -23 })
		t.eq(b.max, { x = 10, y = 4, z = 1 })
		t.eq(MapKitLogic.bounds({}), nil)

		-- Y축 90도: 10×1×2 상자가 x폭 2, z폭 10이 돼요
		local rotated = MapKitLogic.bounds({
			spec({ size = { x = 10, y = 1, z = 2 }, rotation = { x = 0, y = 90, z = 0 } }),
		}) :: any
		t.ok(near(rotated.min.x, -1) and near(rotated.max.x, 1), "x span 2")
		t.ok(near(rotated.min.z, -5) and near(rotated.max.z, 5), "z span 10")
		t.ok(near(rotated.min.y, -0.5) and near(rotated.max.y, 0.5), "y span 1")
	end)

	t.test("MapKitLogic: 예산·팔레트", function()
		t.eq(MapKitLogic.DECOR_PART_BUDGET, 600)
		t.eq(MapKitLogic.PARTICLE_BUDGET, 8)
		t.eq(MapKitLogic.LIGHT_BUDGET, 12)
		local names = 0
		for name, c in MapKitLogic.PALETTE do
			names += 1
			t.eq(MapKitLogic.validate({ spec({ name = name, color = c }) }), nil, `palette {name} is a valid color`)
		end
		t.ok(names >= 12, "palette entries")
		for _, key in
			{
				"Rice",
				"Nori",
				"Soy",
				"Wasabi",
				"Salmon",
				"Tuna",
				"Egg",
				"Wood",
				"Porcelain",
				"PorcelainRim",
				"Iron",
				"Lacquer",
				"Noren",
			}
		do
			t.ok(MapKitLogic.PALETTE[key] ~= nil, `PALETTE.{key}`)
		end
	end)

	-- AC5 ---------------------------------------------------------------------------------
	t.test("AC5: 결승 같은 묶음 Fall(10) + Reset(50) → 우승 Fall, Reset은 2등", function()
		local standings = RoundLogic.newStandings({
			{ userId = 1, name = "A" },
			{ userId = 2, name = "B" },
		})
		local round = RoundLogic.newRound("Final", { 1, 2 })
		RoundLogic.activate(round, 1)
		local out = RoundLogic.applyOutcomes(
			standings,
			RoundLogic.eliminate(round, {
				{ userId = 1, score = 10, cause = "Fall" },
				{ userId = 2, score = 50, cause = "Reset" },
			}, noScore)
		)
		t.eq(summary(out), { [1] = "Won:1", [2] = "Eliminated:2" })
		t.ok(round.ended)
		t.eq(RoundLogic.winnerOf(standings), 1)
	end)

	t.test("AC5: 결승 같은 묶음 둘 다 Reset → 우승자 없이 끝나요", function()
		local standings = RoundLogic.newStandings({
			{ userId = 1, name = "A" },
			{ userId = 2, name = "B" },
		})
		local round = RoundLogic.newRound("Final", { 1, 2 })
		RoundLogic.activate(round, 1)
		local out = RoundLogic.applyOutcomes(
			standings,
			RoundLogic.eliminate(round, {
				{ userId = 1, score = 10, cause = "Reset" },
				{ userId = 2, score = 50, cause = "Reset" },
			}, noScore)
		)
		for _, o in out do
			t.eq(o.result, "Eliminated")
		end
		t.eq(#out, 2)
		t.ok(round.ended, "round ends (no waiting for the time limit)")
		t.eq(RoundLogic.winnerOf(standings), nil)
		local winner, needsWon = RoundLogic.decideWinner(standings, {})
		t.eq(winner, nil)
		t.eq(needsWon, false)
	end)

	t.test("결승 묶음 순서: 리셋 무리가 먼저(점수 순), 그다음 낙하 무리(점수 순)", function()
		local order = RoundLogic.finalBatchOrder({
			{ userId = 1, score = 30, cause = "Fall" },
			{ userId = 2, score = 90, cause = "Reset" },
			{ userId = 3, score = 5 }, -- cause 없음 = Fall
			{ userId = 4, score = 10, cause = "Reset" },
		})
		local ids = {}
		for _, f in order do
			table.insert(ids, f.userId)
		end
		t.eq(ids, { 4, 2, 3, 1 })
	end)

	t.test(
		"결승 3명 중 2명 같은 묶음(리셋 높이 99 + 낙하 1): 남은 1명 우승, 리셋이 더 나쁜 등수",
		function()
			local standings = RoundLogic.newStandings({
				{ userId = 1, name = "A" },
				{ userId = 2, name = "B" },
				{ userId = 3, name = "C" },
			})
			local round = RoundLogic.newRound("Final", { 1, 2, 3 })
			RoundLogic.activate(round, 1)
			local out = RoundLogic.applyOutcomes(
				standings,
				RoundLogic.eliminate(round, {
					{ userId = 1, score = 99, cause = "Reset" },
					{ userId = 2, score = 1, cause = "Fall" },
				}, noScore)
			)
			t.eq(summary(out), { [1] = "Eliminated:3", [2] = "Eliminated:2", [3] = "Won:1" })
		end
	)

	t.test("결승 3명 같은 묶음 전원(리셋 1 + 낙하 2): 낙하자 중 높은 사람 우승", function()
		local round = RoundLogic.newRound("Final", { 1, 2, 3 })
		RoundLogic.activate(round, 1)
		local out = RoundLogic.eliminate(round, {
			{ userId = 1, score = 99, cause = "Reset" },
			{ userId = 2, score = 20, cause = "Fall" },
			{ userId = 3, score = 40, cause = "Fall" },
		}, noScore)
		t.eq(out[#out].userId, 3)
		t.eq(out[#out].result, "Won")
		t.eq(out[1].userId, 1, "reset is eliminated first (worst place)")
	end)

	-- AC6 ---------------------------------------------------------------------------------
	t.test(
		"AC6: 맵 풀 Race 4(m5-15 lantern-bridge 포함) · Survival 2 · Final 1, 새 stub 2개가 validate 통과",
		function()
			local byKind: { [string]: { string } } = { Race = {}, Survival = {}, Final = {} }
			for _, info in Maps.infos() do
				table.insert(byKind[info.kind], info.id)
			end
			for _, list in byKind do
				table.sort(list)
			end
			t.eq(byKind.Race, { "lantern-bridge", "ramen-rapids", "rotating-belt", "soy-swamp" })
			t.eq(byKind.Survival, { "chef-board", "hot-plate" })
			t.eq(byKind.Final, { "skewer-showdown" })

			local ramen = Maps.get("ramen-rapids")
			t.eq(MapTypes.validate(ramen), nil)
			t.eq(ramen.kind, "Race")
			t.eq(ramen.displayName, "라멘 국물 급류")
			t.eq(ramen.rule, "국물 급류를 타고 차슈·나루토를 밟아 건너, 결승선까지!")
			local chef = Maps.get("chef-board")
			t.eq(MapTypes.validate(chef), nil)
			t.eq(chef.kind, "Survival")
			t.eq(chef.displayName, "셰프의 도마")
			t.eq(
				chef.rule,
				"칼이 내려치는 줄을 피하고, 잘려 나가는 도마 위에서 끝까지 버티세요!"
			)
		end
	)

	t.test("AC6: 4라운드 구성 시드 1~500 — 중복 0, Survival 1~2번", function()
		for seed = 1, 500 do
			local plan = Rules.buildRoundPlan(4, Maps.infos(), fakeRng(seed))
			t.eq(#plan, 4)
			local seen: { [string]: boolean } = {}
			local survival = 0
			for _, map in plan do
				t.ok(not seen[map.id], `seed {seed}: duplicate {map.id}`)
				seen[map.id] = true
				if map.kind == "Survival" then
					survival += 1
				end
			end
			t.ok(survival >= 1 and survival <= 2, `seed {seed}: {survival} Survival rounds`)
		end
	end)

	t.test("AC6: m4-01 Studio 절차의 forceMapPlan이 풀려요", function()
		local plan, problem =
			Rules.resolveForcedPlan({ "ramen-rapids", "chef-board", "soy-swamp", "skewer-showdown" }, Maps.infos())
		t.eq(problem, nil)
		t.eq(#(plan :: { any }), 4)
	end)

	-- AC7 ---------------------------------------------------------------------------------
	t.test(
		"AC7: Config 기본값 (Places nil, forceMapPlan nil, persistDataInStudio false, Titles 오름차순)",
		function()
			t.eq(Config.Places.LobbyPlaceId, nil)
			t.eq(Config.Places.MatchPlaceId, nil)
			t.eq(Config.DEBUG.forceMapPlan, nil)
			t.eq(Config.DEBUG.persistDataInStudio, false)
			for i = 2, #Config.Titles do
				t.ok(Config.Titles[i - 1].wins < Config.Titles[i].wins, `Titles[{i}] ascending`)
			end
			t.eq(Config.Rewards, { RoundPass = 10, FinalQualify = 30, Win = 100, DailyFirstMatch = 50 })
			t.eq(Config.Data.StoreName, "PlayerData_v1")
			t.eq(Config.Data.SettingsMinInterval, 0.5)
			t.eq(Config.Teleport.ArrivalTimeout, 20)
			t.eq(Config.Ui.BaseShortSide, 720)
			t.eq(Config.MovementGuard.ExemptAfterServerMove, 1.0)
			t.eq(Config.MovementGuard.MaxHorizontalSpeed, 80)
		end
	)

	-- MoveExempt ---------------------------------------------------------------------------
	t.test("MoveExempt.untilTime: 기본 1초, 더 늦은 값은 줄이지 않아요", function()
		t.eq(MoveExempt.untilTime(nil, 100), 100 + Config.MovementGuard.ExemptAfterServerMove)
		t.eq(MoveExempt.untilTime(nil, 100, 3), 103)
		t.eq(MoveExempt.untilTime(105, 100), 105, "keeps later value")
		t.eq(MoveExempt.untilTime(100.5, 100), 101, "extends earlier value")
		t.eq(MoveExempt.untilTime(nil, 100, 0), 100)
	end)

	-- 공용 파일·훅 계약 (다른 m4 스펙이 기대하는 것) -------------------------------------------
	t.test("Remotes: ProfileUpdated·RewardGranted·SaveSettings가 RemoteEvent, 리모트 21개", function()
		local src = source("src/shared/Remotes.luau")
		local events = string.match(src, "local EVENTS = (%b{})") :: string
		local functions = string.match(src, "local FUNCTIONS = (%b{})") :: string
		for _, name in { "ProfileUpdated", "RewardGranted", "SaveSettings" } do
			t.ok(string.find(events, `"{name}"`, 1, true) ~= nil, `{name} in EVENTS`)
		end
		local _, eventCount = string.gsub(events, '"%w+"', "")
		local _, functionCount = string.gsub(functions, '"%w+"', "")
		-- m4-11이 Notice(텔레포트 실패·서버 이동 안내)를 더해 17개
		-- m4-13이 EquipSkin·BuyWithCoins를 더해 19개
		-- m4-14가 RequestRobuxPurchase를 더해 20개
		-- m5-02가 AdminPreviewSkin을 더해 21개
		-- m5-03이 BuyWithTokens·RequestOfferPurchase·EquipFx·RedeemCode·AdminCommand를 더해 26개
		t.eq(eventCount + functionCount, 26)
	end)

	t.test("Types: Settings·ProfileView·RewardReason·RewardGrant", function()
		local src = source("src/shared/Types.luau")
		for _, name in { "Settings", "ProfileView", "RewardReason", "RewardGrant" } do
			t.ok(string.find(src, `export type {name} =`, 1, true) ~= nil, name)
		end
		t.ok(string.find(src, '"RoundPass" | "FinalQualify" | "Win" | "DailyFirstMatch"', 1, true) ~= nil)
	end)

	t.test("서버 init: DataService 맨 앞, PlaceService 다음, 새 서비스 등록", function()
		local src = source("src/server/init.server.luau")
		local list = string.match(src, "local SERVICES = (%b{})") :: string
		local function at(name: string): number
			return string.find(list, `require(script.{name})`, 1, true) or math.huge
		end
		t.ok(at("DataService") < at("PlaceService"), "DataService first")
		t.ok(at("PlaceService") < at("RoomService"), "PlaceService before existing")
		for _, name in { "LobbyService", "RewardService", "MovementGuardService" } do
			t.ok(at(name) < math.huge, `registers {name}`)
			t.ok(at("GrabService") < at(name), `{name} after existing services`)
			local s = source(`src/server/{name}.luau`)
			t.ok(string.find(s, "%.init%(%)") ~= nil and string.find(s, "%.start%(%)") ~= nil, `{name} init/start`)
		end
	end)

	t.test("클라이언트 init: ProfileStore → Sfx → 기존 → 새 컨트롤러", function()
		local src = source("src/client/init.client.luau")
		local list = string.match(src, "local CONTROLLERS = (%b{})") :: string
		local function at(name: string): number
			return string.find(list, `require(script.{name})`, 1, true) or math.huge
		end
		t.ok(at("ProfileStore") < at("Sfx"), "ProfileStore first")
		t.ok(at("Sfx") < at("ui.HudController"), "Sfx before existing")
		for _, name in { "ui.UiScaleController", "ui.CoinController", "fx.LobbyFxController" } do
			t.ok(at(name) < math.huge, `registers {name}`)
			t.ok(at("input.GrabController") < at(name), `{name} after existing`)
		end
		t.ok(has("src/client/ui/UiScaleController.luau", "function UiScaleController.attach("), "attach")
	end)

	t.test("훅: MatchEvents API, 부르는 곳", function()
		local events = source("src/server/MatchEvents.luau")
		for _, name in { "MatchStart", "RoundStart", "Result", "MatchEnd", "WinnerShowcase" } do
			t.ok(string.find(events, `function MatchEvents.on{name}(`, 1, true) ~= nil, `on{name}`)
			t.ok(string.find(events, `function MatchEvents.fire{name}(`, 1, true) ~= nil, `fire{name}`)
		end
		t.ok(string.find(events, "pcall(fn", 1, true) ~= nil, "handlers isolated with pcall")
		t.ok(string.find(events, "task.spawn", 1, true) ~= nil, "handlers run in their own thread")

		local match = source("src/server/MatchService.luau")
		t.ok(string.find(match, "MatchEvents.fireMatchStart(", 1, true) ~= nil)
		t.ok(string.find(match, "MatchEvents.fireRoundStart(", 1, true) ~= nil)
		t.ok(string.find(match, "MatchEvents.fireMatchEnd(", 1, true) ~= nil)
		t.ok(string.find(match, "MatchEvents.fireWinnerShowcase(", 1, true) ~= nil)
		-- roundStart는 prepared.run 바로 앞
		local roundStartAt = string.find(match, "MatchEvents.fireRoundStart(", 1, true) :: number
		local runAt = string.find(match, "prepared.run(targetCount)", 1, true) :: number
		t.ok(roundStartAt < runAt, "roundStart before run")
		-- matchEnd(우승자 있음)는 Victory 방송 뒤, 대기 전
		local victoryAt = string.find(match, 'phase = "Victory"', 1, true) :: number
		local endAt = string.find(match, "fireMatchEnd(ctx, winnerUserId, standings)", 1, true) :: number
		local waitAt = string.find(match, "task.wait(Config.Match.VictoryDuration)", 1, true) :: number
		local showcaseAt = string.find(match, "fireWinnerShowcase(ctx, winnerUserId)", 1, true) :: number
		t.ok(victoryAt < endAt and endAt < waitAt and waitAt < showcaseAt, "Victory → matchEnd → wait → showcase")

		t.ok(has("src/server/EliminationService.luau", "MatchEvents.fireResult(roomId, result)"), "fireResult")
	end)

	t.test(
		"RoundService: setPassValidator·activeRoomOf, 배치 때 MoveExempt, 낙하 위치 = 마지막 땅",
		function()
			local round = source("src/server/RoundService.luau")
			t.ok(string.find(round, "function RoundService.setPassValidator(", 1, true) ~= nil)
			t.ok(string.find(round, "function RoundService.activeRoomOf(", 1, true) ~= nil)
			t.ok(string.find(round, "if not passAllowed(player) then", 1, true) ~= nil)
			t.ok(string.find(round, "MoveExempt.mark(character)", 1, true) ~= nil)
			t.ok(string.find(round, "humanoid.FloorMaterial ~= Enum.Material.Air", 1, true) ~= nil)
			t.ok(string.find(round, "position = lastGroundOf[userId]", 1, true) ~= nil)
			t.ok(has("src/server/CharacterUtil.luau", "MoveExempt.mark(character)"), "toLobby marks")
		end
	)

	t.test("DataService API (m4-07·m4-08·m4-14가 쓰는 것)", function()
		local data = source("src/server/DataService.luau")
		for _, fn in { "get", "waitForProfile", "update", "onLoaded", "canPersist" } do
			t.ok(string.find(data, `function DataService.{fn}(`, 1, true) ~= nil, fn)
		end
		local store = source("src/client/ProfileStore.luau")
		for _, fn in { "get", "changed", "start" } do
			t.ok(string.find(store, `function ProfileStore.{fn}(`, 1, true) ~= nil, fn)
		end
		-- m4-11: 4번째 인자로 Studio 흉내 모드(Config.DEBUG.simulateMatchServer)를 넘겨요
		t.ok(
			has("src/server/PlaceService.luau", "PlaceRole.resolve(game.PlaceId, Config.Places, RunService:IsStudio()")
		)
	end)

	t.test("default.project.json: ServerStorage.MapArt, 가로 고정", function()
		local project = source("default.project.json")
		t.ok(string.find(project, '"$path": "assets/map-art"', 1, true) ~= nil, "MapArt path")
		t.ok(string.find(project, '"ScreenOrientation": "LandscapeSensor"', 1, true) ~= nil, "orientation")
		t.ok(fs.isDir("assets/map-art"), "assets/map-art exists")
	end)
end
