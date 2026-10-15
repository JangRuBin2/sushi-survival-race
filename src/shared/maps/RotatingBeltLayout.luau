--!strict
-- 회전 벨트 m5-40 길이 늘리기: 옛 결승 자리부터 새로 끼운 구간 표 (순수 데이터, Roblox API 없음 → lune 테스트).
-- 옛 네 구간(출발·벨트 A·병목·벨트 B)과 결승 치수는 RotatingBelt.luau의 local 상수 그대로예요 (m4-02 QA가 소스를 읽어요).
-- RotatingBelt.build가 벨트 B 다음에 이 표의 구간을 차례로 쌓고, 그 뒤에 결승을 둬요. RotatingBeltArt.SECTIONS도
-- 이 표를 이어 붙여요. 좌표는 origin 기준 로컬: x 좌우, y 위(바닥 윗면 0), z 0이 출발선이고 -Z로 갈수록 결승.
--
--   ① Landing1   쉼터 (나무 바닥, 노렌 문 — 손님 홀 → 주방 쪽)
--   ② SideBelts  지그재그 옆 벨트 4장: 좌우로 번갈아 밀고, 각 벨트 끝 칸막이의 틈은 미는 쪽 반대편 → 대각선으로 달려요
--   ③ Landing2   쉼터
--   ④ Slalom     접시 탑 슬라롬: 쌓인 색 접시 탑(고정, 충돌) 사이 좁은 길을 S자로
--   ⑤ BeltC      벨트 C + 젓가락 3개 (벨트 B의 강화판 — 젓가락 대기 시간이 짧은 쪽)

export type NewSection = {
	name: string,
	kind: "Floor" | "SideBelts" | "Slalom" | "Belt",
	depth: number,
	half: number, -- 벽 안쪽 폭의 절반
}

export type SideBelt = { depth: number, push: number } -- push: +1이면 +x 쪽으로, -1이면 -x 쪽으로 밀어요
export type Tower = { x: number, z: number, d: number, h: number }
export type Chopsticks = { offsets: { number }, cooldownMin: number, cooldownMax: number }

local Layout = {}

Layout.NEW_SECTIONS = {
	{ name = "Landing1", kind = "Floor", depth = 14, half = 10 },
	{ name = "SideBelts", kind = "SideBelts", depth = 88, half = 8 },
	{ name = "Landing2", kind = "Floor", depth = 14, half = 10 },
	{ name = "Slalom", kind = "Slalom", depth = 100, half = 10 },
	{ name = "BeltC", kind = "Belt", depth = 54, half = 8 },
} :: { NewSection }

-- 새 구간이 시작하는 z (= 벨트 B 끝: 14 + 34 + 24 + 34)
Layout.NEW_FRONT = -106

-- ② 옆 벨트 (구간 안에서 앞 → 뒤 순서). 미는 속도는 옛 벨트와 같은 PUSH_SPEED(10)·PUSH_ACCEL(24).
Layout.SIDE_BELTS = {
	{ depth = 22, push = 1 },
	{ depth = 22, push = -1 },
	{ depth = 22, push = 1 },
	{ depth = 22, push = -1 },
} :: { SideBelt }
-- 각 옆 벨트 끝 칸막이: 미는 쪽 반대편에 폭 GATE_WIDTH 틈 (벽에 붙어서)
Layout.GATE_WIDTH = 6
Layout.PARTITION_HEIGHT = 8 -- 점프(최고 약 6.4)로 못 넘어요
Layout.PARTITION_THICKNESS = 1

-- ④ 접시 탑 (구간 안 로컬 z — 구간 앞 끝에서 뒤로 잰 거리). 지름 d·높이 h. 줄마다 길이 가운데↔양옆으로 번갈아요.
Layout.PLATE_THICKNESS = 1.5 -- 탑을 이루는 접시 한 장 두께 (판정 파츠 한 장)
Layout.TOWERS = {
	{ x = -6.5, z = 10, d = 6, h = 12 },
	{ x = 6.5, z = 10, d = 6, h = 13.5 },
	{ x = 0, z = 22, d = 7, h = 12 },
	{ x = -5, z = 34, d = 6, h = 13.5 },
	{ x = 7, z = 34, d = 5, h = 12 },
	{ x = 2, z = 46, d = 7, h = 13.5 },
	{ x = -6, z = 58, d = 7, h = 12 },
	{ x = 6, z = 58, d = 7, h = 12 },
	{ x = -1, z = 70, d = 6, h = 13.5 },
	{ x = -7, z = 82, d = 6, h = 12 },
	{ x = 5, z = 82, d = 6, h = 13.5 },
	{ x = 0, z = 92, d = 6, h = 12 },
} :: { Tower }

-- ⑤ 벨트 C 젓가락: 좌우 번갈아 3개, 대기 시간은 옛 범위(2.5~4.5) 안에서 짧은 쪽
Layout.BELT_C_CHOPSTICKS = { offsets = { -3, 3, -3 }, cooldownMin = 2.5, cooldownMax = 3.5 } :: Chopsticks

-- 길이 추정 (빠른 사람, 초) — 걷기 16, 뒤로 미는 벨트는 순 6(16 - 10)으로 걸어요
Layout.WALK_SPEED = 16 -- Config.Character.WalkSpeed와 같아요
Layout.BELT_PUSH_SPEED = 10 -- RotatingBelt.luau PUSH_SPEED와 같아요
Layout.SECTION_DELAY = {
	Narrow = 1, -- 한 줄로 좁아지는 병목에서 부딪힘
	SideBelts = 3, -- 칸막이 틈 4번을 밀기 거슬러 대각선으로
	Slalom = 2.5, -- S자로 돌아가는 거리
	Chopsticks = 4, -- 젓가락 5개 (벨트 B 2 + 벨트 C 3) × 평균 0.8초
} :: { [string]: number }

-- 구간 i 앞 끝 z
function Layout.sectionFront(index: number): number
	local z = Layout.NEW_FRONT
	for i = 1, index - 1 do
		z -= Layout.NEW_SECTIONS[i].depth
	end
	return z
end

function Layout.sectionByName(name: string): (NewSection?, number)
	for i, section in Layout.NEW_SECTIONS do
		if section.name == name then
			return section, Layout.sectionFront(i)
		end
	end
	return nil, 0
end

-- 새 구간이 끝나는 z (= 결승 구간 앞 끝)
function Layout.newBack(): number
	return Layout.sectionFront(#Layout.NEW_SECTIONS + 1)
end

-- 옆 벨트 i의 앞 끝 z와 밀기 방향
function Layout.sideBeltFront(index: number): number
	local _, front = Layout.sectionByName("SideBelts")
	for i = 1, index - 1 do
		front -= Layout.SIDE_BELTS[i].depth
	end
	return front
end

-- 옆 벨트 i 끝 칸막이의 막힌 부분 x 범위 (틈은 미는 반대쪽 벽에 붙어 있어요)
function Layout.partitionSolid(index: number): (number, number)
	local section = Layout.sectionByName("SideBelts") :: NewSection
	local half = section.half
	local push = Layout.SIDE_BELTS[index].push
	if push > 0 then
		return -half + Layout.GATE_WIDTH, half -- 틈은 -x 쪽
	end
	return -half, half - Layout.GATE_WIDTH -- 틈은 +x 쪽
end

-- 접시 탑 i의 월드(로컬) 중심 z
function Layout.towerZ(tower: Tower): number
	local _, front = Layout.sectionByName("Slalom")
	return front - tower.z
end

return Layout
