# m5-24 그룹 D 작업 기록 (bouncy-castle-maze · lantern-bridge · cat-cafe-shelves)

## 2026-10-13 인계 (wip, 사용자 요청으로 중단)
- 브랜치: `m5-24-art-d` (worktree `agent-adb9fe3b08e5b5131`), `origin/main` 591d84e(키트 수정 e07e08d 포함)까지 머지함. 스펙 상태 `in-dev`.
- **검증 5단계 아직 안 돌림** (wip 커밋). 기존 테스트 중 예산 단언(`<= DECOR_PART_BUDGET` 600)은 깨질 것 — D2대로 `checkBudget(..., "Extended")`로 바꿔야 함:
  `tests/map-bouncy-castle-maze.spec.luau` AC7(208줄 근처), `tests/map-lantern-bridge.spec.luau` AC10(195줄; `Lantern` 이름 12개 단언은 유지됨), `tests/map-cat-cafe-shelves.spec.luau` AC10(241줄).

### 끝난 것
- before 렌더: `docs/renders/<mapId>/before-*.png` 3맵 (렌더러 lookAt 고친 뒤 다시 찍은 것).
- **bouncy-castle-maze** (반복 3회): 잔디밭(GROUND = 낙하선 -40 −16 = -56), 성 받침 + 바깥 공기 기둥(빨강/노랑), 흰 파이핑(벽·칸막이 위), 탑 6개(원뿔 지붕·깃발 Sway), 입구 아치, 결승 아치(그림자 SpotLight 1·Confetti·Sparkle), 송풍기 2(팬 Spin·호스 Pulse), 풍선 다발 3(Bob), 산울타리, 간식 수레, 바람개비, 매표소 + 비눗방울(Bubbles), 대관람차(허브 Spin)·회전목마·서커스 텐트·옆 초밥집·나무·먼 언덕. 램프 기둥을 레인 안 → 성 바깥(x ±28)으로 옮김(이름·개수 그대로). `lighting = Art.LIGHTING`(13시 맑음), `Art.BUDGET = "Extended"`. 소개 점 4개 새로(판정 경계 +40 안).
  - stats: decor 1418/1500, lights 7, shadowed 1, particles 3, anim 47, void 전부 ≤4%. eye/mobile은 렌더러 카메라가 출발 벽 뒤(z +9.5)라 공기 기둥만 보임 — 실제 Roblox 카메라는 벽 앞으로 당겨짐(QA 참고).
  - 주의: m5-maps-fix-a가 z −110(x −20~10)에 출구 벽을 추가 — 그 자리에 장식 없음(확인 필요).
- **lantern-bridge** (반복 1회): 강(WATER_Y = -40, 불투명 반사), 계곡 절벽 바위, 절벽 위 축제 거리 + 노점 10(빛 10), 등불 줄 4(강 위 y 22), 떠내려가는 등롱 14(Bob), 쉼터·출발·결승 바위 받침, 다리 끝 고정 기둥, 석등 불씨(Embers)·쉼터2 그림자 SpotLight, 반딧불, 먼 신사·불꽃·산·달, 도리이 보강. `lighting = Art.LIGHTING`(21시 밤). 판자 위·하위 장식/anim 없음.
  - stats: decor 884, lights 23/24, shadowed 1, particles 9, anim 69, void 0%. **렌더 PNG 아직 안 봄(비평 반복 남음).**

### 남은 것
1. lantern-bridge: `build/renders/lantern-bridge/*.png` 보고 비평 → 고침 2회 이상.
2. cat-cafe-shelves: 아직 손 안 댐. 계획: 방 키우기(바닥 y -30 = 탈락선 -11 −19, 벽 ±170), 캣타워 받침 기둥(사이잘 Fabric 띠), 거대 치즈냥(경고 주황 255,150,60과 다른 갈색 톤), 꼬리 Sway, 잠자는 고양이 Pulse, 창 + 햇살 Spot(그림자), 카운터·케이크 진열장, 천장 팬 Spin, `Art.LIGHTING`(16시). 기존 소개 1번 점이 벽 밖이라 고쳐야 함. (fix-b가 CatCafeShelves.luau 277~346 판정부를 고침 — 아트 부분만.)
3. 새 테스트 `tests/m5-24-group-d.spec.luau`: 3맵 checkBudget Extended, lighting == Art.LIGHTING + MapLighting.validate + 로비와 다름, 소개 경로가 장식 속 안 지남(m4-12 방식), lantern-bridge 판자 구간(|x| ≤ halfWidth+1, y -3~5) 안에 anim 장식 없음.
4. 기존 테스트 예산 단언 3곳 수정(위), 검증 5단계, after PNG 복사(`docs/renders/<mapId>/after-*.png`), 스펙 개발 메모 그룹 D 절, `in-qa`.

### 다음에 할 첫 단계
`git fetch origin && git merge origin/main` → `lune run tools/render-map lantern-bridge --view all` → PNG 비평.

### 막힌 점
- 없음. 렌더러 lookAt 버그는 main(e07e08d)에서 고쳐짐(내 임시 수정은 되돌림).
