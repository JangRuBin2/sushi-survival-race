--!strict
-- 이 서버가 어떤 플레이스 역할인지 정해요 (GDD 11.2, m4-11). 순수 로직.
--   "Single"  한 플레이스 모드: 로비와 매치가 같은 서버 (Studio, 또는 PlaceId를 아직 안 넣음)
--   "Lobby"   로비 플레이스 (방 만들기·대기, 매치 시작 때 텔레포트)
--   "Match"   매치 플레이스 (도착한 방 멤버로 바로 매치)

export type Role = "Single" | "Lobby" | "Match"

export type Places = {
	LobbyPlaceId: number?,
	MatchPlaceId: number?,
}

local PlaceRole = {}

function PlaceRole.resolve(placeId: number, places: Places, isStudio: boolean): Role
	if isStudio or places.LobbyPlaceId == nil or places.MatchPlaceId == nil then
		return "Single"
	end
	if placeId == places.MatchPlaceId then
		return "Match"
	end
	return "Lobby"
end

return PlaceRole
