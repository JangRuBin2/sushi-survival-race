--!strict
-- m5-40 L2 QA (docs/qa/m5-40-l2.md): ramen-rapids · dessert-fridge 길이 늘리기 회귀 테스트 (개발 테스트 m5-40-l2에 없는 것).
--   1. 판정 파츠 하나하나 고정: c121dda(m5-40 전)의 판정 파츠 124개(이름·크기·origin 기준 위치·방향·충돌/터치/쿼리·태그·
--      속성·모양·재질·투명도·물성) 중 117개가 그대로, 결승 쪽 7개는 의도한 새 값. 파츠 수 라멘 86 · 디저트 68.
--      (m5-24-qa 판정 지문은 합계라 새 값으로 바꾸면 옛 파츠가 같이 바뀌어도 모를 수 있어요)
--   2. 길 약속을 실제 build 지오메트리로: 새 구간을 따라 수직선을 쏴서 밟는 면의 높이 단면을 만들고, 오르막·빈틈마다
--      점프(걷기 16, 점프 50)로 닿는지 봐요. 라멘은 젓가락 두 줄(왼쪽·오른쪽) 모두, 디저트는 냉동실 x 0 → 스쿱 4개 → 착지대.
--      냉동실 바닥 조각이 Layout 구멍과 정확히 같은지(이음매 빈틈 없음) 0.5 격자로 확인해요.
--   3. 새 밟는 면 바로 위(+0.1 ~ +6)에 머리를 박는 충돌 판정 파츠가 없어요.
--   4. G 젤리 = C 젤리: 착지대와의 높이 차·붙은 면·크기가 같고, 튕겨 오르는 기둥에 막는 파츠가 없어요.
--   5. Ice 태그: 옛 B·D 얼음 + FreezerFloor 7조각만, 스쿱 구역·결승·라멘에는 없음. IceController는 태그로만 얼음을 알아봐요.
--   6. 실제 start()를 가짜 Roblox 환경(m5-06-qa 하네스 복사, 돌린 origin)에서: 냉동 송풍구 주기·방향·면제 없음·소리 조건,
--      G 젤리 튕김·면제·소리·쿨다운, F·G·E 낙하선 경계, 라멘 두 번째 급류 밀기 = 첫 급류 밀기, 라멘 새 구간 낙하선·결승선.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")
local Shims = require("../tools/render/Shims")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local DLayout = RobloxRequire.require(Shared.maps.DessertFridgeLayout)
local DLogic = RobloxRequire.require(Shared.maps.DessertFridgeLogic)
local RLayout = RobloxRequire.require(Shared.maps.RamenRapidsLayout)
local RLogic = RobloxRequire.require(Shared.maps.RamenRapidsLogic)
local IceLogic = RobloxRequire.require(Shared.IceLogic)

local RShared = Shims.root("src/shared")
local RMaps = Shims.require(RShared.maps)

-- c121dda에서 같은 형식(rowsOf)으로 뽑은 판정 파츠 중 m5-40이 건드리지 않아야 하는 것 (117개)
local KEPT_ROWS = {
	"dessert-fridge|ColdFan1|1.00,6.00,16.00|-9.50,15.00,-158.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|ColdFan|FanIndex=1|Enum.PartType.Block|Enum.Material.DiamondPlate|0.00|nil",
	"dessert-fridge|ColdFan2|1.00,6.00,16.00|9.50,15.00,-194.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|ColdFan|FanIndex=2|Enum.PartType.Block|Enum.Material.DiamondPlate|0.00|nil",
	"dessert-fridge|CookieStep1|6.00,3.00,4.00|12.00,1.50,-114.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|ctrue ttrue qtrue|||Enum.PartType.Block|Enum.Material.Sand|0.00|0.7, 0.2, 0.5, 1, 1",
	"dessert-fridge|CookieStep2|6.00,6.00,4.00|12.00,3.00,-118.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|ctrue ttrue qtrue|||Enum.PartType.Block|Enum.Material.Sand|0.00|0.7, 0.2, 0.5, 1, 1",
	"dessert-fridge|CookieStep3|6.00,9.00,4.00|12.00,4.50,-122.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|ctrue ttrue qtrue|||Enum.PartType.Block|Enum.Material.Sand|0.00|0.7, 0.2, 0.5, 1, 1",
	"dessert-fridge|FanShelf|18.00,2.00,80.00|0.00,11.00,-176.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|ctrue ttrue qtrue|Ice||Enum.PartType.Block|Enum.Material.Ice|0.00|0.7, 0.2, 0.5, 1, 1",
	"dessert-fridge|IceCube1|4.00,4.00,4.00|-6.00,2.00,-24.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|ctrue ttrue qtrue|||Enum.PartType.Block|Enum.Material.Ice|0.15|0.7, 0.2, 0.5, 1, 1",
	"dessert-fridge|IceCube2|4.00,4.00,4.00|6.00,2.00,-32.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|ctrue ttrue qtrue|||Enum.PartType.Block|Enum.Material.Ice|0.15|0.7, 0.2, 0.5, 1, 1",
	"dessert-fridge|IceCube3|4.00,4.00,4.00|5.00,2.00,-46.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|ctrue ttrue qtrue|||Enum.PartType.Block|Enum.Material.Ice|0.15|0.7, 0.2, 0.5, 1, 1",
	"dessert-fridge|IceCube4|4.00,4.00,4.00|-6.00,2.00,-54.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|ctrue ttrue qtrue|||Enum.PartType.Block|Enum.Material.Ice|0.15|0.7, 0.2, 0.5, 1, 1",
	"dessert-fridge|IceCube5|4.00,4.00,4.00|6.00,2.00,-60.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|ctrue ttrue qtrue|||Enum.PartType.Block|Enum.Material.Ice|0.15|0.7, 0.2, 0.5, 1, 1",
	"dessert-fridge|IceCube6|4.00,4.00,4.00|-5.00,2.00,-76.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|ctrue ttrue qtrue|||Enum.PartType.Block|Enum.Material.Ice|0.15|0.7, 0.2, 0.5, 1, 1",
	"dessert-fridge|IceCube7|4.00,4.00,4.00|6.00,2.00,-84.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|ctrue ttrue qtrue|||Enum.PartType.Block|Enum.Material.Ice|0.15|0.7, 0.2, 0.5, 1, 1",
	"dessert-fridge|IceCube8|4.00,4.00,4.00|-6.00,2.00,-90.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|ctrue ttrue qtrue|||Enum.PartType.Block|Enum.Material.Ice|0.15|0.7, 0.2, 0.5, 1, 1",
	"dessert-fridge|IceTray01|22.00,2.00,21.00|0.00,-1.00,-26.50|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|ctrue ttrue qtrue|Ice||Enum.PartType.Block|Enum.Material.Ice|0.00|0.7, 0.2, 0.5, 1, 1",
	"dessert-fridge|IceTray02|3.00,2.00,6.00|-9.50,-1.00,-40.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|ctrue ttrue qtrue|Ice||Enum.PartType.Block|Enum.Material.Ice|0.00|0.7, 0.2, 0.5, 1, 1",
	"dessert-fridge|IceTray03|13.00,2.00,6.00|4.50,-1.00,-40.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|ctrue ttrue qtrue|Ice||Enum.PartType.Block|Enum.Material.Ice|0.00|0.7, 0.2, 0.5, 1, 1",
	"dessert-fridge|IceTray04|22.00,2.00,24.00|0.00,-1.00,-55.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|ctrue ttrue qtrue|Ice||Enum.PartType.Block|Enum.Material.Ice|0.00|0.7, 0.2, 0.5, 1, 1",
	"dessert-fridge|IceTray05|13.00,2.00,6.00|-4.50,-1.00,-70.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|ctrue ttrue qtrue|Ice||Enum.PartType.Block|Enum.Material.Ice|0.00|0.7, 0.2, 0.5, 1, 1",
	"dessert-fridge|IceTray06|3.00,2.00,6.00|9.50,-1.00,-70.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|ctrue ttrue qtrue|Ice||Enum.PartType.Block|Enum.Material.Ice|0.00|0.7, 0.2, 0.5, 1, 1",
	"dessert-fridge|IceTray07|22.00,2.00,23.00|0.00,-1.00,-84.50|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|ctrue ttrue qtrue|Ice||Enum.PartType.Block|Enum.Material.Ice|0.00|0.7, 0.2, 0.5, 1, 1",
	"dessert-fridge|Jelly1|8.00,1.00,8.00|-11.00,0.50,-120.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|ctrue ttrue qtrue|Jelly||Enum.PartType.Block|Enum.Material.Glass|0.10|0.7, 0.2, 0.5, 1, 1",
	"dessert-fridge|Jelly2|8.00,1.00,8.00|-3.00,0.50,-120.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|ctrue ttrue qtrue|Jelly||Enum.PartType.Block|Enum.Material.Glass|0.10|0.7, 0.2, 0.5, 1, 1",
	"dessert-fridge|Jelly3|8.00,1.00,8.00|5.00,0.50,-120.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|ctrue ttrue qtrue|Jelly||Enum.PartType.Block|Enum.Material.Glass|0.10|0.7, 0.2, 0.5, 1, 1",
	"dessert-fridge|JellyFloor|30.00,2.00,28.00|0.00,-1.00,-110.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|ctrue ttrue qtrue|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.00|nil",
	"dessert-fridge|Landing|30.00,14.00,12.00|0.00,5.00,-130.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|ctrue ttrue qtrue|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.00|nil",
	"dessert-fridge|Spawns.Spawn01|2.00,0.20,2.00|-8.75,0.10,-2.50|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.40|nil",
	"dessert-fridge|Spawns.Spawn02|2.00,0.20,2.00|-5.25,0.10,-2.50|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.40|nil",
	"dessert-fridge|Spawns.Spawn03|2.00,0.20,2.00|-1.75,0.10,-2.50|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.40|nil",
	"dessert-fridge|Spawns.Spawn04|2.00,0.20,2.00|1.75,0.10,-2.50|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.40|nil",
	"dessert-fridge|Spawns.Spawn05|2.00,0.20,2.00|5.25,0.10,-2.50|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.40|nil",
	"dessert-fridge|Spawns.Spawn06|2.00,0.20,2.00|8.75,0.10,-2.50|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.40|nil",
	"dessert-fridge|Spawns.Spawn07|2.00,0.20,2.00|-8.75,0.10,-6.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.40|nil",
	"dessert-fridge|Spawns.Spawn08|2.00,0.20,2.00|-5.25,0.10,-6.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.40|nil",
	"dessert-fridge|Spawns.Spawn09|2.00,0.20,2.00|-1.75,0.10,-6.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.40|nil",
	"dessert-fridge|Spawns.Spawn10|2.00,0.20,2.00|1.75,0.10,-6.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.40|nil",
	"dessert-fridge|Spawns.Spawn11|2.00,0.20,2.00|5.25,0.10,-6.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.40|nil",
	"dessert-fridge|Spawns.Spawn12|2.00,0.20,2.00|8.75,0.10,-6.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.40|nil",
	"dessert-fridge|Spawns.Spawn13|2.00,0.20,2.00|-8.75,0.10,-9.50|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.40|nil",
	"dessert-fridge|Spawns.Spawn14|2.00,0.20,2.00|-5.25,0.10,-9.50|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.40|nil",
	"dessert-fridge|Spawns.Spawn15|2.00,0.20,2.00|-1.75,0.10,-9.50|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.40|nil",
	"dessert-fridge|Spawns.Spawn16|2.00,0.20,2.00|1.75,0.10,-9.50|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.40|nil",
	"dessert-fridge|Spawns.Spawn17|2.00,0.20,2.00|5.25,0.10,-9.50|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.40|nil",
	"dessert-fridge|Spawns.Spawn18|2.00,0.20,2.00|8.75,0.10,-9.50|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.40|nil",
	"dessert-fridge|Spawns.Spawn19|2.00,0.20,2.00|-8.75,0.10,-13.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.40|nil",
	"dessert-fridge|Spawns.Spawn20|2.00,0.20,2.00|-5.25,0.10,-13.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.40|nil",
	"dessert-fridge|Spawns.Spawn21|2.00,0.20,2.00|-1.75,0.10,-13.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.40|nil",
	"dessert-fridge|Spawns.Spawn22|2.00,0.20,2.00|1.75,0.10,-13.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.40|nil",
	"dessert-fridge|Spawns.Spawn23|2.00,0.20,2.00|5.25,0.10,-13.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.40|nil",
	"dessert-fridge|Spawns.Spawn24|2.00,0.20,2.00|8.75,0.10,-13.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.40|nil",
	"dessert-fridge|StartFloor|24.00,2.00,16.00|0.00,-1.00,-8.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|ctrue ttrue qtrue|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.00|nil",
	"ramen-rapids|BrothSlide|20.00,2.00,112.46|0.00,-12.67,-70.79|L-0.000,-0.208,-0.978 U0.000,0.978,-0.208|ctrue ttrue qtrue|Broth||Enum.PartType.Block|Enum.Material.Glass|0.20|nil",
	"ramen-rapids|LandingRaft|24.00,2.00,16.00|0.00,-31.00,-134.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|ctrue ttrue qtrue|||Enum.PartType.Block|Enum.Material.Fabric|0.00|nil",
	"ramen-rapids|Noodle1|20.00,1.50,1.50|0.00,-1.82,-28.16|L-0.000,-0.208,-0.978 U0.000,0.978,-0.208|ctrue ttrue qtrue|||Enum.PartType.Cylinder|Enum.Material.SmoothPlastic|0.00|nil",
	"ramen-rapids|Noodle2|20.00,1.50,1.50|0.00,-7.98,-57.16|L-0.000,-0.208,-0.978 U0.000,0.978,-0.208|ctrue ttrue qtrue|||Enum.PartType.Cylinder|Enum.Material.SmoothPlastic|0.00|nil",
	"ramen-rapids|Noodle3|20.00,1.50,1.50|0.00,-14.15,-86.16|L-0.000,-0.208,-0.978 U0.000,0.978,-0.208|ctrue ttrue qtrue|||Enum.PartType.Cylinder|Enum.Material.SmoothPlastic|0.00|nil",
	"ramen-rapids|Noodle4|20.00,1.50,1.50|0.00,-20.10,-114.16|L-0.000,-0.208,-0.978 U0.000,0.978,-0.208|ctrue ttrue qtrue|||Enum.PartType.Cylinder|Enum.Material.SmoothPlastic|0.00|nil",
	"ramen-rapids|NoodleSweeper1|18.00,2.50,1.20|11.00,-28.50,-226.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|NoodleSweeper|SweeperIndex=1|Enum.PartType.Block|Enum.Material.Wood|0.00|nil",
	"ramen-rapids|NoodleSweeper2|18.00,2.50,1.20|-11.00,-28.50,-256.00|L0.000,-0.000,1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|NoodleSweeper|SweeperIndex=2|Enum.PartType.Block|Enum.Material.Wood|0.00|nil",
	"ramen-rapids|Spawns.Spawn01|3.00,0.20,3.00|-9.00,0.10,-2.50|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.40|nil",
	"ramen-rapids|Spawns.Spawn02|3.00,0.20,3.00|-5.40,0.10,-2.50|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.40|nil",
	"ramen-rapids|Spawns.Spawn03|3.00,0.20,3.00|-1.80,0.10,-2.50|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.40|nil",
	"ramen-rapids|Spawns.Spawn04|3.00,0.20,3.00|1.80,0.10,-2.50|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.40|nil",
	"ramen-rapids|Spawns.Spawn05|3.00,0.20,3.00|5.40,0.10,-2.50|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.40|nil",
	"ramen-rapids|Spawns.Spawn06|3.00,0.20,3.00|9.00,0.10,-2.50|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.40|nil",
	"ramen-rapids|Spawns.Spawn07|3.00,0.20,3.00|-9.00,0.10,-6.10|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.40|nil",
	"ramen-rapids|Spawns.Spawn08|3.00,0.20,3.00|-5.40,0.10,-6.10|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.40|nil",
	"ramen-rapids|Spawns.Spawn09|3.00,0.20,3.00|-1.80,0.10,-6.10|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.40|nil",
	"ramen-rapids|Spawns.Spawn10|3.00,0.20,3.00|1.80,0.10,-6.10|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.40|nil",
	"ramen-rapids|Spawns.Spawn11|3.00,0.20,3.00|5.40,0.10,-6.10|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.40|nil",
	"ramen-rapids|Spawns.Spawn12|3.00,0.20,3.00|9.00,0.10,-6.10|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.40|nil",
	"ramen-rapids|Spawns.Spawn13|3.00,0.20,3.00|-9.00,0.10,-9.70|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.40|nil",
	"ramen-rapids|Spawns.Spawn14|3.00,0.20,3.00|-5.40,0.10,-9.70|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.40|nil",
	"ramen-rapids|Spawns.Spawn15|3.00,0.20,3.00|-1.80,0.10,-9.70|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.40|nil",
	"ramen-rapids|Spawns.Spawn16|3.00,0.20,3.00|1.80,0.10,-9.70|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.40|nil",
	"ramen-rapids|Spawns.Spawn17|3.00,0.20,3.00|5.40,0.10,-9.70|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.40|nil",
	"ramen-rapids|Spawns.Spawn18|3.00,0.20,3.00|9.00,0.10,-9.70|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.40|nil",
	"ramen-rapids|Spawns.Spawn19|3.00,0.20,3.00|-9.00,0.10,-13.30|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.40|nil",
	"ramen-rapids|Spawns.Spawn20|3.00,0.20,3.00|-5.40,0.10,-13.30|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.40|nil",
	"ramen-rapids|Spawns.Spawn21|3.00,0.20,3.00|-1.80,0.10,-13.30|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.40|nil",
	"ramen-rapids|Spawns.Spawn22|3.00,0.20,3.00|1.80,0.10,-13.30|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.40|nil",
	"ramen-rapids|Spawns.Spawn23|3.00,0.20,3.00|5.40,0.10,-13.30|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.40|nil",
	"ramen-rapids|Spawns.Spawn24|3.00,0.20,3.00|9.00,0.10,-13.30|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.40|nil",
	"ramen-rapids|StartFloor|24.00,2.00,16.00|0.00,-1.00,-8.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|ctrue ttrue qtrue|||Enum.PartType.Block|Enum.Material.WoodPlanks|0.00|nil",
	"ramen-rapids|StartWall|25.00,14.00,0.50|0.00,7.00,0.25|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|ctrue ttrue qtrue|||Enum.PartType.Block|Enum.Material.Glass|0.60|nil",
	"ramen-rapids|SweeperHub1|8.00,4.00,4.00|0.00,-26.00,-226.00|L-0.000,-0.000,-1.000 U-1.000,0.000,0.000|ctrue ttrue qtrue|||Enum.PartType.Cylinder|Enum.Material.SmoothPlastic|0.00|nil",
	"ramen-rapids|SweeperHub2|8.00,4.00,4.00|0.00,-26.00,-256.00|L-0.000,-0.000,-1.000 U-1.000,0.000,0.000|ctrue ttrue qtrue|||Enum.PartType.Cylinder|Enum.Material.SmoothPlastic|0.00|nil",
	"ramen-rapids|SweeperPlatform1|2.00,40.00,40.00|0.00,-31.00,-226.00|L-0.000,-0.000,-1.000 U-1.000,0.000,0.000|ctrue ttrue qtrue|||Enum.PartType.Cylinder|Enum.Material.Marble|0.00|nil",
	"ramen-rapids|SweeperPlatform2|2.00,40.00,40.00|0.00,-31.00,-256.00|L-0.000,-0.000,-1.000 U-1.000,0.000,0.000|ctrue ttrue qtrue|||Enum.PartType.Cylinder|Enum.Material.Marble|0.00|nil",
	"ramen-rapids|Toppings.Chashu1|1.50,9.00,9.00|-6.00,-29.25,-147.00|L-0.000,-0.000,-1.000 U-1.000,0.000,0.000|ctrue ttrue qtrue|Chashu|ChashuIndex=1|Enum.PartType.Cylinder|Enum.Material.Slate|0.00|nil",
	"ramen-rapids|Toppings.Chashu2|1.50,9.00,9.00|6.00,-32.25,-147.00|L-0.000,-0.000,-1.000 U-1.000,0.000,0.000|ctrue ttrue qtrue|Chashu|ChashuIndex=2|Enum.PartType.Cylinder|Enum.Material.Slate|0.00|nil",
	"ramen-rapids|Toppings.Chashu3|1.50,9.00,9.00|-10.00,-29.87,-165.00|L-0.000,-0.000,-1.000 U-1.000,0.000,0.000|ctrue ttrue qtrue|Chashu|ChashuIndex=3|Enum.PartType.Cylinder|Enum.Material.Slate|0.00|nil",
	"ramen-rapids|Toppings.Chashu4|1.50,9.00,9.00|0.00,-32.24,-165.00|L-0.000,-0.000,-1.000 U-1.000,0.000,0.000|ctrue ttrue qtrue|Chashu|ChashuIndex=4|Enum.PartType.Cylinder|Enum.Material.Slate|0.00|nil",
	"ramen-rapids|Toppings.Chashu5|1.50,9.00,9.00|10.00,-30.20,-165.00|L-0.000,-0.000,-1.000 U-1.000,0.000,0.000|ctrue ttrue qtrue|Chashu|ChashuIndex=5|Enum.PartType.Cylinder|Enum.Material.Slate|0.00|nil",
	"ramen-rapids|Toppings.Chashu6|1.50,9.00,9.00|-6.00,-31.21,-183.00|L-0.000,-0.000,-1.000 U-1.000,0.000,0.000|ctrue ttrue qtrue|Chashu|ChashuIndex=6|Enum.PartType.Cylinder|Enum.Material.Slate|0.00|nil",
	"ramen-rapids|Toppings.Chashu7|1.50,9.00,9.00|6.00,-30.29,-183.00|L-0.000,-0.000,-1.000 U-1.000,0.000,0.000|ctrue ttrue qtrue|Chashu|ChashuIndex=7|Enum.PartType.Cylinder|Enum.Material.Slate|0.00|nil",
	"ramen-rapids|Toppings.Chashu8|1.50,9.00,9.00|-6.00,-31.96,-201.00|L-0.000,-0.000,-1.000 U-1.000,0.000,0.000|ctrue ttrue qtrue|Chashu|ChashuIndex=8|Enum.PartType.Cylinder|Enum.Material.Slate|0.00|nil",
	"ramen-rapids|Toppings.Chashu9|1.50,9.00,9.00|6.00,-29.54,-201.00|L-0.000,-0.000,-1.000 U-1.000,0.000,0.000|ctrue ttrue qtrue|Chashu|ChashuIndex=9|Enum.PartType.Cylinder|Enum.Material.Slate|0.00|nil",
	"ramen-rapids|Toppings.Naruto1|1.50,7.00,7.00|-17.00,-30.75,-147.00|L-0.000,-0.000,-1.000 U-1.000,0.000,0.000|ctrue ttrue qtrue|||Enum.PartType.Cylinder|Enum.Material.SmoothPlastic|0.00|nil",
	"ramen-rapids|Toppings.Naruto2|1.50,7.00,7.00|0.00,-30.75,-156.00|L-0.000,-0.000,-1.000 U-1.000,0.000,0.000|ctrue ttrue qtrue|||Enum.PartType.Cylinder|Enum.Material.SmoothPlastic|0.00|nil",
	"ramen-rapids|Toppings.Naruto3|1.50,7.00,7.00|0.00,-30.75,-174.00|L-0.000,-0.000,-1.000 U-1.000,0.000,0.000|ctrue ttrue qtrue|||Enum.PartType.Cylinder|Enum.Material.SmoothPlastic|0.00|nil",
	"ramen-rapids|Toppings.Naruto4|1.50,7.00,7.00|0.00,-30.75,-192.00|L-0.000,-0.000,-1.000 U-1.000,0.000,0.000|ctrue ttrue qtrue|||Enum.PartType.Cylinder|Enum.Material.SmoothPlastic|0.00|nil",
	"ramen-rapids|Toppings.NarutoSwirl1|4.90,0.06,0.80|-17.00,-29.96,-147.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse||SwirlOffset=0|Enum.PartType.Block|Enum.Material.SmoothPlastic|0.00|nil",
	"ramen-rapids|Toppings.NarutoSwirl1|4.90,0.06,0.80|-17.00,-29.96,-147.00|L-1.000,-0.000,-0.000 U0.000,1.000,0.000|cfalse tfalse qfalse||SwirlOffset=1.5707963267948966|Enum.PartType.Block|Enum.Material.SmoothPlastic|0.00|nil",
	"ramen-rapids|Toppings.NarutoSwirl2|4.90,0.06,0.80|0.00,-29.96,-156.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse||SwirlOffset=0|Enum.PartType.Block|Enum.Material.SmoothPlastic|0.00|nil",
	"ramen-rapids|Toppings.NarutoSwirl2|4.90,0.06,0.80|0.00,-29.96,-156.00|L-1.000,-0.000,-0.000 U0.000,1.000,0.000|cfalse tfalse qfalse||SwirlOffset=1.5707963267948966|Enum.PartType.Block|Enum.Material.SmoothPlastic|0.00|nil",
	"ramen-rapids|Toppings.NarutoSwirl3|4.90,0.06,0.80|0.00,-29.96,-174.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse||SwirlOffset=0|Enum.PartType.Block|Enum.Material.SmoothPlastic|0.00|nil",
	"ramen-rapids|Toppings.NarutoSwirl3|4.90,0.06,0.80|0.00,-29.96,-174.00|L-1.000,-0.000,-0.000 U0.000,1.000,0.000|cfalse tfalse qfalse||SwirlOffset=1.5707963267948966|Enum.PartType.Block|Enum.Material.SmoothPlastic|0.00|nil",
	"ramen-rapids|Toppings.NarutoSwirl4|4.90,0.06,0.80|0.00,-29.96,-192.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse||SwirlOffset=0|Enum.PartType.Block|Enum.Material.SmoothPlastic|0.00|nil",
	"ramen-rapids|Toppings.NarutoSwirl4|4.90,0.06,0.80|0.00,-29.96,-192.00|L-1.000,-0.000,-0.000 U0.000,1.000,0.000|cfalse tfalse qfalse||SwirlOffset=1.5707963267948966|Enum.PartType.Block|Enum.Material.SmoothPlastic|0.00|nil",
	"ramen-rapids|Wall|0.50,3.00,112.46|-10.25,-10.22,-71.31|L-0.000,-0.208,-0.978 U0.000,0.978,-0.208|ctrue ttrue qtrue|||Enum.PartType.Block|Enum.Material.Marble|0.00|nil",
	"ramen-rapids|Wall|0.50,3.00,112.46|10.25,-10.22,-71.31|L-0.000,-0.208,-0.978 U0.000,0.978,-0.208|ctrue ttrue qtrue|||Enum.PartType.Block|Enum.Material.Marble|0.00|nil",
	"ramen-rapids|Wall|0.50,3.00,16.00|-12.25,1.50,-8.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|ctrue ttrue qtrue|||Enum.PartType.Block|Enum.Material.Marble|0.00|nil",
	"ramen-rapids|Wall|0.50,3.00,16.00|12.25,1.50,-8.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|ctrue ttrue qtrue|||Enum.PartType.Block|Enum.Material.Marble|0.00|nil",
	"ramen-rapids|Whirlpool1|0.10,8.00,8.00|5.00,-5.47,-42.01|L-0.000,-0.208,-0.978 U-1.000,0.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Cylinder|Enum.Material.Glass|0.10|nil",
	"ramen-rapids|Whirlpool2|0.10,8.00,8.00|-5.00,-11.84,-72.01|L-0.000,-0.208,-0.978 U-1.000,0.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Cylinder|Enum.Material.Glass|0.10|nil",
	"ramen-rapids|Whirlpool3|0.10,8.00,8.00|5.00,-17.80,-100.01|L-0.000,-0.208,-0.978 U-1.000,0.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Cylinder|Enum.Material.Glass|0.10|nil",
}

-- m5-40이 의도해서 옮긴 옛 파츠 7개의 새 값 (결승 바닥·결승선, 라멘 결승 끝 벽·옆 벽 2)
local MOVED_ROWS = {
	"dessert-fridge|FinishFloor|24.00,2.00,44.00|0.00,23.00,-410.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|ctrue ttrue qtrue|||Enum.PartType.Block|Enum.Material.SmoothPlastic|0.00|nil",
	"dessert-fridge|FinishLine|24.00,0.40,1.00|0.00,24.20,-422.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.Neon|0.00|nil",
	"ramen-rapids|EndWall|25.00,14.00,0.50|0.00,-23.00,-446.25|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|ctrue ttrue qtrue|||Enum.PartType.Block|Enum.Material.Glass|0.60|nil",
	"ramen-rapids|FinishFloor|24.00,2.00,30.00|0.00,-31.00,-431.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|ctrue ttrue qtrue|||Enum.PartType.Block|Enum.Material.Marble|0.00|nil",
	"ramen-rapids|FinishLine|24.00,0.40,1.00|0.00,-29.80,-442.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|cfalse tfalse qfalse|||Enum.PartType.Block|Enum.Material.Neon|0.00|nil",
	"ramen-rapids|Wall|0.50,3.00,24.00|-12.25,-28.50,-434.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|ctrue ttrue qtrue|||Enum.PartType.Block|Enum.Material.Marble|0.00|nil",
	"ramen-rapids|Wall|0.50,3.00,24.00|12.25,-28.50,-434.00|L-0.000,-0.000,-1.000 U0.000,1.000,0.000|ctrue ttrue qtrue|||Enum.PartType.Block|Enum.Material.Marble|0.00|nil",
}

local RV3: any = roblox.Vector3
local RCF: any = roblox.CFrame

---------------------------------------------------------------- 가짜 Roblox

local function newSignal(): any
	local handlers: { any } = {}
	local signal = {}
	function signal:Connect(fn)
		local h = { fn = fn, connected = true }
		table.insert(handlers, h)
		return {
			Disconnect = function()
				h.connected = false
			end,
		}
	end
	function signal:Fire(...)
		for _, h in table.clone(handlers) do
			if h.connected then
				h.fn(...)
			end
		end
	end
	return signal
end

local BASE_PARTS = { Part = true }

local function newInstance(className: string): any
	local props: { [string]: any } = { ClassName = className, Name = className }
	local children: { any } = {}
	local attributes: { [string]: any } = {}
	local inst: any
	local methods: { [string]: any } = {}
	function methods.IsA(_, cls: string): boolean
		return cls == className or (cls == "BasePart" and BASE_PARTS[className] == true) or cls == "Instance"
	end
	function methods.GetChildren(_)
		return table.clone(children)
	end
	function methods.GetDescendants(_)
		local out = {}
		local function walk(list)
			for _, child in list do
				table.insert(out, child)
				walk(child.__children)
			end
		end
		walk(children)
		return out
	end
	function methods.FindFirstChild(_, name: string)
		for _, child in children do
			if child.Name == name then
				return child
			end
		end
		return nil
	end
	function methods.FindFirstChildOfClass(_, cls: string)
		for _, child in children do
			if child.ClassName == cls then
				return child
			end
		end
		return nil
	end
	function methods.IsAncestorOf(_, other: any): boolean
		local p = other.Parent
		while p do
			if p == inst then
				return true
			end
			p = p.Parent
		end
		return false
	end
	function methods.Destroy(_)
		props.__destroyed = true
		inst.Parent = nil
	end
	function methods.GetAttribute(_, name: string)
		return attributes[name]
	end
	function methods.SetAttribute(_, name: string, value: any)
		attributes[name] = value
	end
	inst = setmetatable({}, {
		__index = function(_, key: string)
			if key == "Position" and props.Position == nil and props.CFrame ~= nil then
				return props.CFrame.Position -- QA: 파츠 Position은 CFrame에서 (라멘 start가 FinishLine·소용돌이 위치를 읽어요)
			end
			if key == "__children" then
				return children
			end
			local m = methods[key]
			if m then
				return m
			end
			return props[key]
		end,
		__newindex = function(_, key: string, value: any)
			if key == "Parent" then
				local old = props.Parent
				if old then
					local index = table.find(old.__children, inst)
					if index then
						table.remove(old.__children, index)
					end
				end
				if value then
					table.insert(value.__children, inst)
				end
			end
			props[key] = value
		end,
	})
	return inst
end

local enumStub = setmetatable({}, {
	__index = function(_, enumName: string)
		return setmetatable({}, {
			__index = function(_, item: string)
				return `{enumName}.{item}`
			end,
		})
	end,
})

local function newCollection(): any
	local tags: { [string]: { any } } = {}
	local service = {}
	function service:AddTag(inst: any, tag: string)
		tags[tag] = tags[tag] or {}
		table.insert(tags[tag], inst)
	end
	function service:GetTagged(tag: string)
		return table.clone(tags[tag] or {})
	end
	function service:HasTag(inst: any, tag: string)
		return table.find(tags[tag] or {}, inst) ~= nil
	end
	return service
end

local function ctor(): any
	return {
		new = function(...)
			return { ... }
		end,
	}
end

type Env = {
	map: any,
	heartbeat: any,
	collection: any,
	setClock: (number) -> (),
	exempt: { any },
	delays: { { seconds: number, fn: () -> () } },
	sounds: { string },
}

local function loadMap(file: string?): Env
	local heartbeat = newSignal()
	local collection = newCollection()
	local clock = 0
	local exempt: { any } = {}
	local delays: { { seconds: number, fn: () -> () } } = {}
	local sounds: { string } = {}
	local stubs: { [string]: any } = {
		MapKit = {
			buildDecor = function()
				return {}
			end,
			decorFolder = function(model)
				return model
			end,
			introCamera = function() end,
			attachStudioArt = function() end,
			applyDecorRules = function() end,
		},
		MapSfx = {
			play = function(part: any, cue: string)
				table.insert(sounds, `{cue}@{if part then part.Name else "nil"}`)
			end,
		},
		MapTypes = {},
		MoveExempt = {
			mark = function(character, seconds)
				table.insert(exempt, { character = character, seconds = seconds })
			end,
		},
	}
	local function token(name: string): any
		return { __mod = name }
	end
	local parent = setmetatable({
		Parent = setmetatable({}, {
			__index = function(_, name: string)
				return token("@" .. name)
			end,
		}),
	}, {
		__index = function(_, name: string)
			return token(name)
		end,
	})
	local map = luau.load(fs.readFile(`src/shared/maps/{file or "DessertFridge"}.luau`), {
		debugName = file or "DessertFridge",
		environment = {
			script = { Parent = parent },
			require = function(target: any): any
				local name = target.__mod
				local shared = string.sub(name, 1, 1) == "@"
				if shared then
					name = string.sub(name, 2)
				end
				if stubs[name] ~= nil then
					return stubs[name]
				end
				if shared then
					return RobloxRequire.require((Shared :: any)[name])
				end
				return RobloxRequire.require((Shared :: any).maps[name])
			end,
			Instance = { new = newInstance },
			Vector3 = RV3,
			Vector2 = ctor(),
			CFrame = RCF,
			Color3 = roblox.Color3,
			ColorSequence = ctor(),
			NumberSequence = ctor(),
			NumberSequenceKeypoint = ctor(),
			NumberRange = ctor(),
			PhysicalProperties = ctor(),
			Enum = enumStub,
			game = {
				GetService = function(_, name: string)
					if name == "RunService" then
						return { Heartbeat = heartbeat }
					elseif name == "CollectionService" then
						return collection
					end
					error(`unexpected service {name}`)
				end,
			},
			os = {
				clock = function()
					return clock
				end,
			},
			task = {
				delay = function(seconds: number, fn: () -> ())
					local entry = { seconds = seconds, fn = fn }
					table.insert(delays, entry)
					return entry
				end,
			},
		},
	})()
	return {
		map = map,
		heartbeat = heartbeat,
		collection = collection,
		setClock = function(v: number)
			clock = v
		end,
		exempt = exempt,
		delays = delays,
		sounds = sounds,
	}
end

-- 실제 아레나처럼 띄우고, 더 엄격하게 돌려 놓은 origin
local ORIGIN = RCF.new(2000, 300, 4000) * RCF.Angles(0, math.rad(90), 0)

local function world(x: number, y: number, z: number): any
	return ORIGIN * RV3.new(x, y, z)
end

local function localOf(part: any): any
	return ORIGIN:ToObjectSpace(part.CFrame)
end

local function newRacer(name: string, x: number, y: number, z: number, velocity: any?): (any, any)
	local character = newInstance("Model")
	local root = newInstance("Part")
	root.Name = "HumanoidRootPart"
	root.Position = world(x, y, z)
	root.AssemblyLinearVelocity = velocity or RV3.new(0, 0, 0)
	root.Parent = character
	local attachment = newInstance("Attachment")
	attachment.Name = "RootAttachment"
	attachment.Parent = root
	return { Character = character, Name = name }, root
end

type Run = {
	env: Env,
	model: any,
	ctx: any,
	cleanup: { any },
	racers: { any },
	passed: { any },
	eliminated: { any },
	active: { value: boolean },
}

local function startRun(racers: { any }, envOverride: Env?, modelOverride: any?, startClock: number?): Run
	local env = envOverride or loadMap()
	local model = modelOverride or env.map.build(ORIGIN)
	local cleanup: { any } = {}
	local passed: { any } = {}
	local eliminated: { any } = {}
	local active = { value = true }
	local live = table.clone(racers)
	local function drop(player)
		local i = table.find(live, player)
		if i then
			table.remove(live, i)
		end
	end
	local ctx = {
		model = model,
		origin = ORIGIN,
		cleanup = {
			add = function(_, item)
				table.insert(cleanup, item)
				return item
			end,
		},
		isActive = function()
			return active.value
		end,
		getRacers = function()
			return table.clone(live)
		end,
		pass = function(player)
			table.insert(passed, player)
			drop(player)
		end,
		eliminate = function(player)
			table.insert(eliminated, player)
			drop(player)
		end,
	}
	env.setClock(startClock or 0)
	env.map.start(ctx)
	return {
		env = env,
		model = model,
		ctx = ctx,
		cleanup = cleanup,
		racers = live,
		passed = passed,
		eliminated = eliminated,
		active = active,
	}
end

local function tick(run: Run, clock: number, dt: number?)
	run.env.setClock(clock)
	run.env.heartbeat:Fire(dt or 1 / 60)
end

-- build가 만든 충돌 파츠의 로컬 상자
type Box = { name: string, minX: number, maxX: number, minY: number, maxY: number, minZ: number, maxZ: number }

local function collidableBoxes(model: any): { Box }
	local boxes: { Box } = {}
	for _, part in model:GetDescendants() do
		if part.ClassName == "Part" and part.CanCollide ~= false and part.Size then
			local rel = localOf(part).Position
			local half = part.Size / 2
			table.insert(boxes, {
				name = part.Name,
				minX = rel.X - half.X,
				maxX = rel.X + half.X,
				minY = rel.Y - half.Y,
				maxY = rel.Y + half.Y,
				minZ = rel.Z - half.Z,
				maxZ = rel.Z + half.Z,
			})
		end
	end
	return boxes
end

-- (x, z)를 덮는 충돌 파츠 중 윗면이 topY(±0.01)인 것이 있는지
local function floorAt(boxes: { Box }, x: number, z: number, topY: number): Box?
	for _, b in boxes do
		if x > b.minX and x < b.maxX and z > b.minZ and z < b.maxZ and math.abs(b.maxY - topY) < 0.01 then
			return b
		end
	end
	return nil
end

local function near(a: number, b: number, eps: number?): boolean
	return math.abs(a - b) <= (eps or 1e-4)
end

---------------------------------------------------------------- 실제 build (렌더러 가짜 Roblox 환경)

local GRAVITY = 196.2
local WALK = Config.Character.WalkSpeed
local JUMP = Config.Character.JumpPower
local MAX_RISE = JUMP ^ 2 / (2 * GRAVITY) - 2 -- 개발 테스트와 같은 여유 (약 4.37)
local STEP = 0.25 -- 단면 샘플 간격
local MAX_STEP = 0.6 -- 이 이하 높이 변화는 걸어서 (경사·이음매)

local function reachWithRise(rise: number): number
	local disc = JUMP * JUMP - 2 * GRAVITY * rise
	if disc < 0 then
		return 0
	end
	return WALK * (JUMP + math.sqrt(disc)) / GRAVITY
end

local SHIM_ORIGIN = roblox.CFrame.new(Config.Arena.SlotSpacing, Config.Arena.BaseHeight, 0)
local shimBuilt: { [string]: any } = {}
local function shimBuild(id: string): any
	if shimBuilt[id] == nil then
		shimBuilt[id] = RMaps.get(id).build(SHIM_ORIGIN)
	end
	return shimBuilt[id]
end

local function under(inst: any, root: any, name: string): boolean
	local node = inst.Parent
	while node and node ~= root do
		if node.Name == name then
			return true
		end
		node = node.Parent
	end
	return false
end

local function judgmentParts(id: string): { any }
	local model = shimBuild(id)
	local list = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and not under(d, model, "Decor") and not under(d, model, "IntroCamera") then
			table.insert(list, d)
		end
	end
	return list
end

-- 판정 파츠 한 줄 (리포트 "판정 파츠 비교"와 같은 형식)
local function rowsOf(id: string): { [string]: boolean }
	local rows: { [string]: boolean } = {}
	for _, d in judgmentParts(id) do
		local cf = SHIM_ORIGIN:ToObjectSpace(d.CFrame)
		local p, lv, uv = cf.Position, cf.LookVector, cf.UpVector
		local tags = d:GetTags()
		table.sort(tags)
		local attrs = {}
		for k, v in d:GetAttributes() do
			table.insert(attrs, k .. "=" .. tostring(v))
		end
		table.sort(attrs)
		local row = string.format(
			"%s|%s|%.2f,%.2f,%.2f|%.2f,%.2f,%.2f|L%.3f,%.3f,%.3f U%.3f,%.3f,%.3f|c%s t%s q%s|%s|%s|%s|%s|%.2f|%s",
			id,
			(string.gsub(d:GetFullName(), "^.-%.", "")),
			d.Size.X,
			d.Size.Y,
			d.Size.Z,
			p.X,
			p.Y,
			p.Z,
			lv.X,
			lv.Y,
			lv.Z,
			uv.X,
			uv.Y,
			uv.Z,
			tostring(d.CanCollide),
			tostring(d.CanTouch),
			tostring(d.CanQuery),
			table.concat(tags, ","),
			table.concat(attrs, ";"),
			tostring(d.Shape),
			tostring(d.Material),
			d.Transparency,
			tostring(d.CustomPhysicalProperties)
		)
		rows[row] = true
	end
	return rows
end

type Solid = { name: string, cf: any, half: any }

local function solidsOf(id: string): { Solid }
	local list: { Solid } = {}
	for _, d in judgmentParts(id) do
		if d.CanCollide then
			table.insert(list, { name = d.Name, cf = SHIM_ORIGIN:ToObjectSpace(d.CFrame), half = d.Size / 2 })
		end
	end
	return list
end

local function axes(v: any): { number }
	return { v.X, v.Y, v.Z }
end

-- 로컬 (x, fromY, z)에서 아래로 쏜 선이 solid에 처음 닿는 높이. 원기둥은 상자로 근사해요 — 세운 스쿱은 윗면이 같지만
-- 대각선 길에서 스쿱 사이 빈틈이 실제(2.43)보다 작게 잡혀요. 원 사이 빈틈은 m5-40-l2 scoopClimb가 따로 봐요.
local function hitDown(s: Solid, x: number, z: number, fromY: number): number?
	local o = axes(s.cf:PointToObjectSpace(roblox.Vector3.new(x, fromY, z)))
	local d = axes(s.cf:VectorToObjectSpace(roblox.Vector3.new(0, -1, 0)))
	local h = axes(s.half)
	local tmin, tmax = -math.huge, math.huge
	for i = 1, 3 do
		if math.abs(d[i]) < 1e-9 then
			if math.abs(o[i]) > h[i] then
				return nil
			end
		else
			local t1, t2 = (-h[i] - o[i]) / d[i], (h[i] - o[i]) / d[i]
			if t1 > t2 then
				t1, t2 = t2, t1
			end
			tmin, tmax = math.max(tmin, t1), math.min(tmax, t2)
		end
	end
	if tmin <= tmax and tmin >= 0 then
		return fromY - tmin
	end
	return nil
end

local function surfaceAt(solids: { Solid }, x: number, z: number): (number?, string?)
	local best, name = nil, nil
	for _, s in solids do
		local y = hitDown(s, x, z, 200)
		if y and (best == nil or y > best) then
			best, name = y, s.name
		end
	end
	return best, name
end

local function inside(s: Solid, p: any): boolean
	local o = s.cf:PointToObjectSpace(p)
	return math.abs(o.X) < s.half.X - 1e-6 and math.abs(o.Y) < s.half.Y - 1e-6 and math.abs(o.Z) < s.half.Z - 1e-6
end

type Seg = { s0: number, s1: number, h0: number, h1: number, z0: number, z1: number, names: { [string]: boolean } }

-- 꺾은선 길을 STEP마다 샘플해 밟는 면(낙하선 + 1보다 위)의 연속 구간으로 나눠요
local function profile(solids: { Solid }, path: { { number } }, fallLineAt: (number) -> number): { Seg }
	local segs: { Seg } = {}
	local current: Seg? = nil
	local previous = 0
	local s = 0
	for i = 1, #path - 1 do
		local a, b = path[i], path[i + 1]
		local length = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
		local n = math.max(1, math.ceil(length / STEP))
		for k = (if i == 1 then 0 else 1), n do
			local f = k / n
			local x, z = a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f
			local here = s + length * f
			local y, name = surfaceAt(solids, x, z)
			if y ~= nil and y < fallLineAt(z) + 1 then
				y = nil
			end
			if y == nil then
				current = nil
			elseif current and math.abs(y - previous) <= MAX_STEP then
				current.s1, current.h1, current.z1 = here, y, z
				current.names[name :: string] = true
			else
				local seg: Seg =
					{ s0 = here, s1 = here, h0 = y, h1 = y, z0 = z, z1 = z, names = { [name :: string] = true } }
				table.insert(segs, seg)
				current = seg
			end
			if y then
				previous = y
			end
		end
		s += length
	end
	return segs
end

-- 이어지는 두 면 사이: 걸어서(내려가기·경사) 또는 앞선 면에서 점프로 닿아야 해요
local function checkProfile(t: Test.Test, label: string, segs: { Seg })
	for i = 2, #segs do
		local b, a = segs[i], segs[i - 1]
		local contiguous = b.s0 - a.s1 <= STEP * 1.5
		if not (contiguous and b.h0 <= a.h1 + MAX_STEP) then
			local ok, detail = false, "no take-off within MAX_RISE"
			for j = i - 1, 1, -1 do
				local from = segs[j]
				local rise = b.h0 - from.h1
				if rise <= MAX_RISE then
					local gap = math.max(0, b.s0 - from.s1 - STEP)
					local reach = reachWithRise(math.max(rise, 0))
					ok = gap + 1 <= reach
					detail = string.format("gap %.2f rise %.2f reach %.2f", gap, rise, reach)
					break
				end
			end
			t.ok(ok, `{label}: z {a.z1} → {b.z0} ({detail})`)
		end
	end
end

local function namesOf(segs: { Seg }): { [string]: boolean }
	local all: { [string]: boolean } = {}
	for _, seg in segs do
		for name in seg.names do
			all[name] = true
		end
	end
	return all
end

-- 파츠 하나의 로컬 AABB (샘플 범위용)
local function aabb(s: Solid): (number, number, number, number)
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local p = s.cf * roblox.Vector3.new(sx * s.half.X, sy * s.half.Y, sz * s.half.Z)
				minX, maxX = math.min(minX, p.X), math.max(maxX, p.X)
				minZ, maxZ = math.min(minZ, p.Z), math.max(maxZ, p.Z)
			end
		end
	end
	return minX, maxX, minZ, maxZ
end

-- 이름이 name인 면 위 +0.1 ~ +6에 다른 충돌 판정 파츠가 있는지 (allow는 일부러 올린 장애물)
local function headroomHits(solids: { Solid }, name: string, allow: (string) -> boolean): { string }
	local hits: { [string]: boolean } = {}
	local found = 0
	for _, s in solids do
		if s.name == name then
			found += 1
			local minX, maxX, minZ, maxZ = aabb(s)
			local x = minX + 0.3
			while x <= maxX - 0.3 do
				local z = minZ + 0.3
				while z <= maxZ - 0.3 do
					local top = hitDown(s, x, z, 200)
					if top then
						for dy = 0.1, 6, 0.5 do
							local p = roblox.Vector3.new(x, top + dy, z)
							for _, other in solids do
								if other ~= s and not allow(other.name) and inside(other, p) then
									hits[`{name} <- {other.name}`] = true
								end
							end
						end
					end
					z += 0.5
				end
				x += 0.5
			end
		end
	end
	local list = {}
	for key in hits do
		table.insert(list, key)
	end
	table.sort(list)
	if found == 0 then
		table.insert(list, `{name} missing`)
	end
	return list
end

local function partNamed(id: string, name: string): any
	for _, d in judgmentParts(id) do
		if d.Name == name then
			return d
		end
	end
	return nil
end

local function topOf(part: any): number
	return SHIM_ORIGIN:PointToObjectSpace(part.CFrame.Position).Y + part.Size.Y / 2
end

local function zRange(part: any): (number, number)
	local z = SHIM_ORIGIN:PointToObjectSpace(part.CFrame.Position).Z
	return z - part.Size.Z / 2, z + part.Size.Z / 2
end

local function xRange(part: any): (number, number)
	local x = SHIM_ORIGIN:PointToObjectSpace(part.CFrame.Position).X
	return x - part.Size.X / 2, x + part.Size.X / 2
end

local function count(list: { string }, value: string): number
	local n = 0
	for _, v in list do
		if v == value then
			n += 1
		end
	end
	return n
end

local function countPrefix(list: { string }, prefix: string): number
	local n = 0
	for _, v in list do
		if string.sub(v, 1, #prefix) == prefix then
			n += 1
		end
	end
	return n
end

local function modelPart(run: Run, tag: string): any
	for _, part in run.env.collection:GetTagged(tag) do
		if run.model:IsAncestorOf(part) then
			return part
		end
	end
	return nil
end

return function(t: Test.Test)
	---------------------------------------------------------------- 1. 판정 파츠 고정

	t.test("L2 QA: c121dda 판정 파츠 117개가 그대로, 옮긴 7개(결승 쪽)는 의도한 새 값", function()
		local rows = { ["ramen-rapids"] = rowsOf("ramen-rapids"), ["dessert-fridge"] = rowsOf("dessert-fridge") }
		t.eq(#KEPT_ROWS, 117)
		t.eq(#MOVED_ROWS, 7)
		for _, list in { KEPT_ROWS, MOVED_ROWS } do
			for _, row in list do
				local id = string.match(row, "^([^|]+)") :: string
				t.ok(rows[id][row] == true, `missing or changed: {row}`)
			end
		end
		-- 라멘 71 → 86 (뗏목·젓가락 4·받침·렌게 4·급류 판·벽 2·면발 2), 디저트 53 → 68 (얼음 7·송풍구·스쿱 4·바닥·착지대·젤리)
		local counts = { ["ramen-rapids"] = 0, ["dessert-fridge"] = 0 }
		for id, set in rows do
			for _ in set do
				counts[id] += 1
			end
		end
		t.eq(counts["ramen-rapids"], 86)
		t.eq(counts["dessert-fridge"], 68)
	end)

	---------------------------------------------------------------- 2. 길 약속 (build 지오메트리 단면)

	t.test(
		"L2 QA 라멘: 젓가락 두 줄 길 모두 원판 → 뗏목 → 젓가락 → 받침 → X자 → 렌게 4 → 급류 → 결승",
		function()
			local solids = solidsOf("ramen-rapids")
			local tail = { { 0, -341.5 }, { -3, -350.5 }, { 3, -359.5 }, { 0, -368.5 }, { 0, -372 }, { 0, -443 } }
			local lanes = {
				left = {
					{ 0, -262 },
					{ 0, -280 },
					{ -3, -284 },
					{ -3, -308 },
					{ 0, -311 },
					{ -4.5, -314 },
					{ 4.5, -336 },
				},
				right = {
					{ 0, -262 },
					{ 0, -280 },
					{ 3, -284 },
					{ 3, -308 },
					{ 0, -311 },
					{ 4.5, -314 },
					{ -4.5, -336 },
				},
			}
			for lane, head in lanes do
				local path = table.clone(head)
				for _, p in tail do
					table.insert(path, p)
				end
				local segs = profile(solids, path, RLogic.fallLineAt)
				t.ok(#segs >= 6, `{lane}: segments {#segs}`)
				t.ok(segs[1].s0 < 1e-6, `{lane}: starts on the disc`)
				t.ok(segs[#segs].z1 <= RLayout.finishLineZ(), `{lane}: reaches past the finish line`)
				checkProfile(t, `ramen {lane}`, segs)
				local names = namesOf(segs)
				local stick = if lane == "left" then { "Chopstick1", "Chopstick3" } else { "Chopstick2", "Chopstick4" }
				for _, name in
					{
						"ChopRaft",
						stick[1],
						"ChopRest",
						stick[2],
						"RengeStep1",
						"RengeStep4",
						"BrothSlide2",
						"FinishFloor",
					}
				do
					t.ok(names[name], `{lane}: walks over {name}`)
				end
			end
		end
	)

	t.test(
		"L2 QA 디저트: D 선반 → 냉동실 x 0 → 스쿱 바닥 → 스쿱 4개 → 착지대 → 결승 (단면)",
		function()
			local solids = solidsOf("dessert-fridge")
			local path = {
				{ 0, -210 },
				{ 0, -337 },
				{ 8, -339 },
				{ 8, -344 },
				{ 3, -352 },
				{ 8, -360 },
				{ 3, -368 },
				{ 3, -380 },
				{ 0, -382 },
				{ 0, -425 },
			}
			local segs = profile(solids, path, DLogic.fallLineAt)
			t.ok(segs[1].s0 < 1e-6, "starts on the fan shelf")
			t.ok(segs[#segs].z1 <= DLayout.FINISH_LINE_Z, "reaches past the finish line")
			checkProfile(t, "dessert", segs)
			local names = namesOf(segs)
			for _, name in
				{
					"FanShelf",
					"FreezerFloor01",
					"FreezerFloor07",
					"ScoopFloor",
					"Scoop1",
					"Scoop4",
					"ScoopLanding",
					"FinishFloor",
				}
			do
				t.ok(names[name], `walks over {name}`)
			end
			-- 스쿱 바닥에서 착지대(12 높이)로 바로는 못 올라요: 스쿱이나 젤리가 필요
			t.ok(DLayout.TOP_Y - DLayout.HIGH_Y > MAX_RISE + 2, "landing needs scoops or the jelly")
		end
	)

	t.test(
		"L2 QA 디저트: 냉동실 바닥 조각 = Layout 구멍 3개를 뺀 모양 (0.5 격자, 이음매 빈틈 없음)",
		function()
			local solids = solidsOf("dessert-fridge")
			local half = DLayout.FREEZER_WIDTH / 2
			local mismatch = 0
			local samples = 0
			local x = -half + 0.25
			while x < half do
				local z = DLayout.FREEZER.front - 0.25
				while z > DLayout.FREEZER.back do
					local y, name = surfaceAt(solids, x, z)
					local walkable = DLogic.freezerWalkable(x, z)
					local built = y ~= nil
						and math.abs(y - DLayout.HIGH_Y) < 1e-3
						and string.match(name or "", "^FreezerFloor") ~= nil
					local fallsThrough = y == nil or y < DLogic.fallLineAt(z)
					samples += 1
					if walkable ~= built or (not walkable and not fallsThrough) then
						mismatch += 1
					end
					z -= 0.5
				end
				x += 0.5
			end
			t.eq(samples, 7680)
			t.eq(mismatch, 0, "freezer floor vs layout holes")
		end
	)

	---------------------------------------------------------------- 3. 머리 위 공간

	t.test("L2 QA: 새 밟는 면 위 +0.1 ~ +6에 머리를 박는 충돌 판정 파츠가 없어요", function()
		local ramen = solidsOf("ramen-rapids")
		local none = function(_: string): boolean
			return false
		end
		for _, name in
			{
				"ChopRaft",
				"Chopstick1",
				"Chopstick2",
				"Chopstick3",
				"Chopstick4",
				"ChopRest",
				"RengeStep1",
				"RengeStep2",
				"RengeStep3",
				"RengeStep4",
			}
		do
			t.eq(headroomHits(ramen, name, none), {}, name)
		end
		-- 두 번째 급류 판 위에는 면발 줄기(일부러 넘는 장애물)만
		t.eq(
			headroomHits(ramen, "BrothSlide2", function(other: string): boolean
				return string.match(other, "^Noodle2_") ~= nil
			end),
			{}
		)
		local dessert = solidsOf("dessert-fridge")
		for _, name in
			{
				"FreezerFloor01",
				"FreezerFloor03",
				"FreezerFloor05",
				"FreezerFloor07",
				"Scoop1",
				"Scoop2",
				"Scoop3",
				"Scoop4",
				"ScoopLanding",
				"ScoopJelly",
			}
		do
			t.eq(headroomHits(dessert, name, none), {}, name)
		end
	end)

	---------------------------------------------------------------- 4. G 젤리 = C 젤리

	t.test(
		"L2 QA 디저트: G 젤리는 C 젤리와 같은 크기·높이 차·붙은 면, 튕겨 오르는 기둥이 비어 있어요",
		function()
			local cJelly, gJelly = partNamed("dessert-fridge", "Jelly2"), partNamed("dessert-fridge", "ScoopJelly")
			local cLanding, gLanding =
				partNamed("dessert-fridge", "Landing"), partNamed("dessert-fridge", "ScoopLanding")
			t.ok(cJelly and gJelly and cLanding and gLanding, "parts")
			t.ok((cJelly.Size - gJelly.Size).Magnitude < 1e-6, "same jelly size")
			t.ok(
				math.abs((topOf(cLanding) - topOf(cJelly)) - (topOf(gLanding) - topOf(gJelly))) < 1e-6,
				"same height to climb (11)"
			)
			local cMin = zRange(cJelly)
			local _, cLandFront = zRange(cLanding)
			local gMin = zRange(gJelly)
			local _, gLandFront = zRange(gLanding)
			t.ok(math.abs(cMin - cLandFront) < 1e-6 and math.abs(gMin - gLandFront) < 1e-6, "jelly flush with the face")
			local gLandMin, gLandMax = zRange(gLanding)
			local cLandMin, cLandMax = zRange(cLanding)
			t.ok(gLandMax - gLandMin >= cLandMax - cLandMin - 1e-6, "G landing at least as deep as C")
			local jx0, jx1 = xRange(gJelly)
			local lx0, lx1 = xRange(gLanding)
			t.ok(jx0 >= lx0 and jx1 <= lx1, "landing covers the jelly width")
			-- 젤리 위 기둥(+0.1 ~ +32)과 착지대 앞 4 studs 위(+0.1 ~ +20)가 비어 있어요
			local solids = solidsOf("dessert-fridge")
			local blocked: { [string]: boolean } = {}
			local function probe(x: number, y: number, z: number)
				for _, s in solids do
					if inside(s, roblox.Vector3.new(x, y, z)) then
						blocked[s.name] = true
					end
				end
			end
			local x = jx0 + 0.3
			while x <= jx1 - 0.3 do
				for z = gMin + 0.3, gMin + 7.7, 0.5 do
					for y = topOf(gJelly) + 0.1, topOf(gJelly) + 32, 0.5 do
						probe(x, y, z)
					end
				end
				for z = gMin - 4, gMin - 0.3, 0.5 do
					for y = topOf(gLanding) + 0.1, topOf(gLanding) + 20, 0.5 do
						probe(x, y, z)
					end
				end
				x += 0.5
			end
			t.eq(next(blocked), nil, "jelly launch column blocked")
		end
	)

	---------------------------------------------------------------- 5. Ice 태그

	t.test(
		"L2 QA: Ice 태그는 옛 B·D 얼음 8조각 + FreezerFloor 7조각만, 스쿱 구역·결승·라멘에는 없어요",
		function()
			local iced = {}
			for _, d in judgmentParts("dessert-fridge") do
				if table.find(d:GetTags(), IceLogic.TAG) then
					table.insert(iced, d.Name)
				end
			end
			table.sort(iced)
			t.eq(iced, {
				"FanShelf",
				"FreezerFloor01",
				"FreezerFloor02",
				"FreezerFloor03",
				"FreezerFloor04",
				"FreezerFloor05",
				"FreezerFloor06",
				"FreezerFloor07",
				"IceTray01",
				"IceTray02",
				"IceTray03",
				"IceTray04",
				"IceTray05",
				"IceTray06",
				"IceTray07",
			})
			for _, d in judgmentParts("ramen-rapids") do
				t.eq(table.find(d:GetTags(), IceLogic.TAG), nil, d.Name)
			end
			-- IceController는 발밑 레이캐스트가 맞은 파츠의 태그(IceLogic.TAG)로만 얼음을 알아봐요 (이름·맵 id 분기 없음)
			local controller = fs.readFile("src/client/input/IceController.luau")
			t.ok(string.find(controller, "CollectionService:HasTag(hit.Instance, IceLogic.TAG)", 1, true) ~= nil)
			t.eq(string.find(controller, "dessert", 1, true), nil)
			t.eq(string.find(controller, "IceTray", 1, true), nil)
			t.eq(IceLogic.TAG, "Ice")
			-- 냉동 송풍구 하우징은 충돌·쿼리 없음 (발밑 레이캐스트를 가로채지 않아요)
			local vent = partNamed("dessert-fridge", "FreezerFan1")
			t.eq(vent.CanQuery, false)
			t.eq(vent.CanCollide, false)
		end
	)

	---------------------------------------------------------------- 6. start() 시뮬레이션 — 디저트

	t.test(
		"L2 QA 냉동 송풍구: 쉼 → 경고(서리) → 불기(+X 40/s) → 쉼, 면제 없음, 소리는 불기 시작 한 번",
		function()
			local racer, root = newRacer("r", 0, 15, -286)
			local run = startRun({ racer })
			local right = ORIGIN.RightVector
			local vent = modelPart(run, "FreezerFan")
			t.ok(vent ~= nil, "FreezerFan in this model")
			tick(run, 0.2, 0.1) -- 위상 3.2 = 쉼
			t.ok(root.AssemblyLinearVelocity.Magnitude < 1e-6, "no push while resting")
			t.eq(vent:FindFirstChild("Frost").Enabled, false)
			tick(run, 1.2, 0.1) -- 위상 0.2 = 경고
			t.ok(root.AssemblyLinearVelocity.Magnitude < 1e-6, "no push while warning")
			t.eq(vent:FindFirstChild("Frost").Enabled, true)
			tick(run, 2.0, 0.1) -- 위상 1.0 = 불기
			t.ok(near(root.AssemblyLinearVelocity:Dot(right), 4, 1e-4), "push +4 after 0.1s")
			t.ok(
				near(root.AssemblyLinearVelocity.Y, 0) and near(root.AssemblyLinearVelocity:Dot(ORIGIN.LookVector), 0),
				"only sideways"
			)
			tick(run, 4.0, 0.1) -- 위상 3.0 = 쉼
			t.ok(near(root.AssemblyLinearVelocity:Dot(right), 4, 1e-4), "no push while resting again")
			t.eq(vent:FindFirstChild("Frost").Enabled, false)
			t.eq(#run.env.exempt, 0, "continuous push must not mark MoveExempt")
			t.eq(count(run.env.sounds, "FanGust@FreezerFan1"), 1)
			t.eq(#run.eliminated, 0)
		end
	)

	t.test(
		"L2 QA 냉동 송풍구: 냉동실에 아무도 없으면 소리 없음(서리는 켜요), 구역 밖·높이·폭 밖은 안 밀어요",
		function()
			local outside = newRacer("far", 0, 3, -5)
			local run = startRun({ outside })
			tick(run, 1.2, 0.1)
			tick(run, 2.0, 0.1)
			t.eq(count(run.env.sounds, "FanGust@FreezerFan1"), 0)
			t.ok(countPrefix(run.env.sounds, "FanGust@ColdFan") >= 1, "D fans still play (unchanged)")
			local vent = modelPart(run, "FreezerFan")
			t.eq(vent:FindFirstChild("Frost").Enabled, true, "frost is visual, independent of the sound gate")
			for _, p in { { 0, 15, -270 }, { 0, 21.1, -286 }, { 8.5, 15, -286 }, { 0, 15, -300 } } do
				local r, root = newRacer("r", p[1], p[2], p[3])
				local run2 = startRun({ r })
				tick(run2, 2.0, 0.1)
				t.ok(root.AssemblyLinearVelocity.Magnitude < 1e-6, `({p[1]},{p[2]},{p[3]}) not pushed`)
			end
		end
	)

	t.test(
		"L2 QA G 젤리: C 젤리와 같은 튕김·면제 1.5초·0.15초 뒤 제거, 소리는 ScoopJelly에서, 쿨다운 0.6",
		function()
			local racer, root = newRacer("jumper", -6, 16, -372)
			local run = startRun({ racer })
			tick(run, 0.1)
			local launch = root:FindFirstChild("JellyLaunch")
			t.ok(launch ~= nil, "JellyLaunch")
			local expected = RV3.new(0, DLayout.JELLY_UP, 0) + ORIGIN.LookVector * DLayout.JELLY_FORWARD
			t.ok((launch.VectorVelocity - expected).Magnitude < 1e-4, "launch velocity = C jelly")
			t.eq(#run.env.exempt, 1)
			t.eq(run.env.exempt[1].seconds, DLayout.JELLY_EXEMPT)
			t.ok(table.find(run.cleanup, launch) ~= nil, "launch in cleanup")
			local hold = nil
			for _, d in run.env.delays do
				if near(d.seconds, DLayout.JELLY_HOLD) then
					hold = d
				end
			end
			t.ok(hold ~= nil and table.find(run.cleanup, hold) ~= nil, "removal scheduled in cleanup")
			t.eq(count(run.env.sounds, "JellyBoing@ScoopJelly"), 1)
			tick(run, 0.69)
			t.eq(#run.env.exempt, 1, "cooldown")
			tick(run, 0.7)
			t.eq(#run.env.exempt, 2, "again after 0.6s")
			-- C 젤리 소리는 여전히 C 패드에서
			local c = newRacer("c", -3, 4, -120)
			local run2 = startRun({ c })
			tick(run2, 0.1)
			t.eq(countPrefix(run2.env.sounds, "JellyBoing@Jelly"), 1)
		end
	)

	t.test(
		"L2 QA G 젤리: 옆 바닥·착지대 위·젤리 위 높이 떠 있음·폭 밖에서는 안 튕겨요",
		function()
			for _, p in { { 0, 15, -372 }, { -6, 27, -380 }, { -6, 18.6, -372 }, { -11, 15, -372 }, { -6, 15, -366 } } do
				local racer = newRacer("r", p[1], p[2], p[3])
				local run = startRun({ racer })
				tick(run, 0.1)
				t.eq(#run.env.exempt, 0, `({p[1]},{p[2]},{p[3]})`)
			end
		end
	)

	t.test("L2 QA 디저트 낙하선: F 구멍·G -13, G 착지대 아래도 -13, E -1", function()
		local cases = {
			{ x = -5, z = -238, y = -13.1, out = true }, -- 냉동실 구멍 1로 떨어짐
			{ x = 5, z = -264, y = -12.9, out = false },
			{ x = 0, z = -300, y = -13.1, out = true },
			{ x = 0, z = -360, y = -13.1, out = true },
			{ x = 0, z = -382, y = -12.9, out = false }, -- G 착지대 (C 착지대와 같은 규칙)
			{ x = 0, z = -400, y = -1.1, out = true },
			{ x = 0, z = -400, y = -0.9, out = false },
			{ x = 0, z = -421, y = -1.1, out = true }, -- 결승선 바로 앞
		}
		for _, case in cases do
			local racer = newRacer("r", case.x, case.y, case.z)
			local run = startRun({ racer })
			tick(run, 0.1)
			t.eq(#run.eliminated, if case.out then 1 else 0, `({case.x},{case.y},{case.z})`)
			t.eq(#run.passed, 0)
		end
	end)

	---------------------------------------------------------------- 6. start() 시뮬레이션 — 라멘

	t.test(
		"L2 QA 라멘: 두 번째 급류 밀기 = 첫 급류 밀기 (앞 40/s 가속, 옆 0), 소리 SoySlow, 면제 없음",
		function()
			local env = loadMap("RamenRapids")
			local r1, root1 = newRacer("r1", 0, RLayout.rapidsHeightAt(-60) + 3, -60)
			local r2, root2 = newRacer("r2", 0, RLayout.rapids2HeightAt(-397) + 3, -397)
			local run = startRun({ r1, r2 }, env)
			tick(run, 0.1, 0.1)
			local forward, right = ORIGIN.LookVector, ORIGIN.RightVector
			t.ok(near(root1.AssemblyLinearVelocity:Dot(forward), 4, 1e-4), "first rapids +4")
			t.ok(near(root2.AssemblyLinearVelocity:Dot(forward), 4, 1e-4), "second rapids +4")
			t.ok(near(root2.AssemblyLinearVelocity:Dot(right), 0, 1e-6), "no side push (no whirlpool)")
			t.ok((root1.AssemblyLinearVelocity - root2.AssemblyLinearVelocity).Magnitude < 1e-6, "same push")
			t.eq(count(run.env.sounds, "SoySlow@BrothSlide"), 1)
			t.eq(count(run.env.sounds, "SoySlow@BrothSlide2"), 1)
			tick(run, 0.2, 0.1)
			t.eq(count(run.env.sounds, "SoySlow@BrothSlide2"), 1, "sound once per entry")
			t.ok(near(root2.AssemblyLinearVelocity:Dot(forward), 8, 1e-4), "+8 after 0.2s")
			t.eq(#run.env.exempt, 0)
			t.eq(#run.eliminated, 0)
		end
	)

	t.test(
		"L2 QA 라멘: 렌게·젓가락·받침 위에서는 안 밀어요, 새 구간 낙하선 -55, 결승선 -442",
		function()
			for _, p in
				{
					{ 0, RLayout.rengeStepTop(4) + 3, -368.5 },
					{ -3, -27, -296 },
					{ 0, -27, -311 },
					{ 0, RLayout.rengeStepTop(1) + 3, -341.5 },
				}
			do
				local env = loadMap("RamenRapids")
				local r, root = newRacer("r", p[1], p[2], p[3])
				local run = startRun({ r }, env)
				tick(run, 0.1, 0.1)
				t.ok(root.AssemblyLinearVelocity.Magnitude < 1e-6, `({p[1]},{p[2]},{p[3]}) not pushed`)
				t.eq(#run.eliminated, 0)
			end
			local cases = {
				{ z = -296, y = -55.1, out = true }, -- 젓가락 사이로 떨어짐
				{ z = -296, y = -54.9, out = false },
				{ z = -360, y = -55.1, out = true },
				{ z = -400, y = -55.1, out = true },
			}
			for _, case in cases do
				local env = loadMap("RamenRapids")
				local r = newRacer("r", 0, case.y, case.z)
				local run = startRun({ r }, env)
				tick(run, 0.1)
				t.eq(#run.eliminated, if case.out then 1 else 0, `z {case.z} y {case.y}`)
			end
			local env = loadMap("RamenRapids")
			local near1 = newRacer("near", 0, -27, -441.9)
			local over = newRacer("over", 6, -27, -442)
			local run = startRun({ near1, over }, env)
			tick(run, 0.1)
			t.eq(run.passed, { over })
		end
	)
end
