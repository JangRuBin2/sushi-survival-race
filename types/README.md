# Roblox 타입 정의 (luau-lsp 타입 검사용)

`globalTypes.None.d.luau` — luau-lsp 저장소 태그 `1.70.1`의 `scripts/globalTypes.None.d.luau`를 그대로 받은 파일이에요
(`rokit.toml`의 luau-lsp 버전과 같은 태그). 네트워크 없이도 같은 결과가 나오게 저장소에 커밋해 둬요.

검증 5번째 단계 (PowerShell·bash 공통):
```
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --platform roblox --sourcemap sourcemap.json --definitions "@roblox=types/globalTypes.None.d.luau" --flag:LuauSolverV2=true src
```
- 새 타입 검사기(`LuauSolverV2`)를 써요. 옛 검사기는 이 버전에서 `pcall` 반환값·Instance와 nil 비교 같은
  올바른 코드에도 에러를 많이 내서(140건) 쓰지 않기로 했어요 (m4-12 결정 기록).
- 끝 코드 0 = 에러 없음. 에러가 있으면 1.

갱신: luau-lsp 버전을 올리면 같은 태그의 파일로 바꿔요.
```
curl -sSL -o types/globalTypes.None.d.luau https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/<태그>/scripts/globalTypes.None.d.luau
```
