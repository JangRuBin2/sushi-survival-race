--!strict
-- m5-06 AC6: 얼음 위 관성 이동 순수 계산 (IceLogic.step)

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local IceLogic = RobloxRequire.require(Shared.IceLogic)

local DT = 1 / 60
local WALK = 16

local function size(v: { x: number, z: number }): number
	return math.sqrt(v.x * v.x + v.z * v.z)
end

-- seconds 동안 DT씩 step
local function run(current, target, seconds: number, walk: number?)
	local v = current
	local frames = math.floor(seconds / DT + 0.5)
	for _ = 1, frames do
		v = IceLogic.step(v, target, DT, walk or WALK)
	end
	return v
end

return function(t: Test.Test)
	t.test("AC6: 상수가 스펙 기본값 (ACCEL 2.5, DRAG 1.0, 레이 4.5, 태그 Ice)", function()
		t.eq(IceLogic.ACCEL, 2.5)
		t.eq(IceLogic.DRAG, 1.0)
		t.eq(IceLogic.RAY_LENGTH, 4.5)
		t.eq(IceLogic.TAG, "Ice")
	end)

	t.test("AC6: 정지에서 입력 방향 목표로 0.9초 뒤 90% (±3%)", function()
		local v = run({ x = 0, z = 0 }, { x = 0, z = -WALK }, 0.9)
		local ratio = -v.z / WALK
		t.ok(ratio >= 0.87 and ratio <= 0.93, `ratio {ratio}`)
		t.ok(math.abs(v.x) < 1e-9, "no sideways drift")
		-- 프레임 크기와 무관(지수식): 한 번에 0.9초도 같아요
		local once = IceLogic.step({ x = 0, z = 0 }, { x = 0, z = -WALK }, 0.9, WALK)
		t.ok(math.abs(once.z - v.z) < 1e-6, `once {once.z} vs frames {v.z}`)
	end)

	t.test("AC6: 입력이 없으면 속도 16이 1초 뒤 약 5.9 (16·e^-1)", function()
		local v = run({ x = 16, z = 0 }, { x = 0, z = 0 }, 1)
		t.ok(math.abs(v.x - 16 * math.exp(-1)) < 0.01, `v {v.x}`)
		-- 미끄러지는 거리 ≈ 16 / DRAG = 16 studs
		local distance = 0
		local cur = { x = 16, z = 0 }
		for _ = 1, 60 * 10 do
			distance += cur.x * DT
			cur = IceLogic.step(cur, { x = 0, z = 0 }, DT, WALK)
		end
		t.ok(distance > 15 and distance < 16.5, `slide {distance}`)
	end)

	t.test("AC6: 반대 입력으로 0.35초 안에 방향이 바뀌어요 (0.3초 안팎에 멈춤)", function()
		local v = run({ x = 0, z = -WALK }, { x = 0, z = WALK }, 0.35)
		t.ok(v.z > 0, `still moving forward {v.z}`)
		local stopAt = nil
		local cur = { x = 0, z = -WALK }
		for frame = 1, 60 do
			cur = IceLogic.step(cur, { x = 0, z = WALK }, DT, WALK)
			if cur.z >= 0 then
				stopAt = frame * DT
				break
			end
		end
		t.ok(stopAt ~= nil and stopAt <= 0.3, `stopped at {stopAt}`)
	end)

	t.test("AC6: 방향을 꺾으면 둥글게 돌아요 (중간에 두 성분이 섞여요)", function()
		local v = run({ x = 0, z = -WALK }, { x = WALK, z = 0 }, 0.3)
		t.ok(v.x > 1 and v.z < -1, `turning {v.x},{v.z}`)
	end)

	t.test(
		"AC6: 결과 크기가 max(|current|, walkSpeed)를 넘지 않아요 (얼음은 속도를 안 늘려요)",
		function()
			local seed = 6
			local rng = {
				NextNumber = function(_, lo: number, hi: number): number
					seed = (seed * 1103515245 + 12345) % 2147483648
					return lo + (hi - lo) * seed / 2147483648
				end,
			}
			for _ = 1, 2000 do
				local current = { x = rng:NextNumber(-40, 40), z = rng:NextNumber(-40, 40) }
				local walk = rng:NextNumber(0, 24)
				local dir = rng:NextNumber(0, 2 * math.pi)
				local scale = rng:NextNumber(0, 1.5) -- 목표가 walk보다 커도(비정상) 잘라요
				local target = { x = math.cos(dir) * walk * scale, z = math.sin(dir) * walk * scale }
				local dt = rng:NextNumber(0, 0.5)
				local out = IceLogic.step(current, target, dt, walk)
				local limit = math.max(size(current), walk)
				t.ok(size(out) <= limit + 1e-9, `out {size(out)} > limit {limit}`)
			end
			-- 서버 밀기·다이브로 빠른 속도는 줄어들기만 해요
			local fast = IceLogic.step({ x = 30, z = 0 }, { x = WALK, z = 0 }, DT, WALK)
			t.ok(fast.x < 30 and fast.x > WALK, `fast {fast.x}`)
		end
	)

	t.test("AC6: dt = 0이면 그대로", function()
		local v = IceLogic.step({ x = 3, z = -7 }, { x = 16, z = 0 }, 0, WALK)
		t.eq(v.x, 3)
		t.eq(v.z, -7)
		local still = IceLogic.step({ x = 3, z = -7 }, { x = 0, z = 0 }, 0, WALK)
		t.eq(still.x, 3)
		t.eq(still.z, -7)
	end)

	t.test("isIceMode: 땅에 닿아 있고 발밑이 Ice일 때만", function()
		t.eq(IceLogic.isIceMode(true, true), true)
		t.eq(IceLogic.isIceMode(false, true), false)
		t.eq(IceLogic.isIceMode(true, false), false)
		t.eq(IceLogic.isIceMode(false, false), false)
	end)
end
