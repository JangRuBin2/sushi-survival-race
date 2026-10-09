--!strict
-- 맵 장식 로컬 애니메이션 태그 (m5-20). Roblox API 없음 — 상수만 모아 둬요.
-- 한 플레이스 모드에서는 방마다 아레나가 다른 좌표에 뜨므로(Config.Arena), 클라이언트가 고정 workspace
-- 경로(로비의 workspace.Lobby 같은) 대신 CollectionService 태그로 애니메이션 대상 파츠를 찾아요.
-- 파츠 이름(Lantern, FaceEye 등)은 여러 맵이 재사용해서 겹칠 수 있어서, 태그로 구분해요.

local MapDecorTags = {}

MapDecorTags.EyeBlink = "MapDecorEyeBlink" -- rotating-belt 손님 얼굴 눈 (이따금 깜빡임)
MapDecorTags.Wobble = "MapDecorWobble" -- hot-plate 선반 간장병 (좌우로 천천히 흔들림)

return MapDecorTags
