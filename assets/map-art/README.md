# assets/map-art

Studio에서 만든 **장식 전용** 맵 아트를 넣는 곳이에요 (m4-01). Rojo가 이 폴더를 `ServerStorage.MapArt`로 싣어요.

- 파일 이름 = 맵 id: `rotating-belt.rbxm` → `ServerStorage.MapArt["rotating-belt"]` (Model 하나)
- 맵의 `build`가 `MapKit.attachStudioArt(model, id, origin)`를 부르면 복제해서 맵 `Decor/StudioArt`로 붙여요.
- 안의 파츠는 전부 충돌·쿼리·터치 없음 + Anchored로 강제돼요 (게임 판정에 영향 없음). 밟고 서는 바닥·벽은 계속 코드가 만들어요.
- Model의 피벗(Pivot)을 맵 origin 자리(출발선 가운데, 앞쪽 = -Z)에 맞춰 두면 그대로 겹쳐져요.
- 로비 장식은 `lobby.rbxm` (m4-06).
