--!strict
-- 터치 조작 버튼 아이콘 이미지 id (m6-14 C2). Roblox는 SVG·로컬 PNG를 바로 못 써서, 사용자가 Studio에서
-- assets/icons/png/*.png를 올린 뒤(Asset Manager → Bulk Import) 받은 id를 아래 IDS에 적어요 (docs/DEV-SETUP.md 3-22).
-- "rbxassetid://123456" 또는 숫자만 "123456" 둘 다 돼요. 비어 있는 동안 버튼은 지금처럼 글씨(🤸 다이브 …)로 나와요.
--   IconAssets.image(name, ids?) -> string?   쓸 수 있는 "rbxassetid://<숫자>" 또는 nil(글씨 폴백)
--   IconAssets.attackIcon(dynamite) -> Name   공격 버튼에 쓸 아이콘 이름 (다이너마이트를 들면 점화)
-- 순수 모듈 (Roblox API 없음).

local IconAssets = {}

export type Name = "dive" | "grab" | "attack" | "dynamite"

-- 원본: assets/icons/<이름>.svg → PNG: assets/icons/png/<이름>.png (tools/icons/export-icons.js)
IconAssets.IDS = {
	dive = "",
	grab = "",
	attack = "",
	dynamite = "",
} :: { [Name]: string }

IconAssets.NAMES = { "dive", "grab", "attack", "dynamite" } :: { Name }

-- id 문자열을 Image 값으로. 모양이 틀리면 nil (잘못 붙여 넣은 값으로 빈 그림이 나오지 않게 글씨로 폴백)
function IconAssets.normalize(raw: any): string?
	if type(raw) ~= "string" then
		return nil
	end
	local text = string.match(raw, "^%s*(.-)%s*$") or ""
	local idText = string.match(text, "^rbxassetid://(%d+)$") or string.match(text, "^(%d+)$")
	local value = if idText then tonumber(idText) else nil
	if idText == nil or value == nil or value <= 0 then
		return nil
	end
	return "rbxassetid://" .. idText
end

function IconAssets.image(name: Name, ids: { [string]: string }?): string?
	local source: { [string]: string } = ids or IconAssets.IDS :: any
	return IconAssets.normalize(source[name])
end

function IconAssets.attackIcon(dynamite: boolean): Name
	return if dynamite then "dynamite" else "attack"
end

return IconAssets
