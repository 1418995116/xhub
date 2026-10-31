# XHub

Roblox 通用 Hub（单文件 Luau）：飞行 / ESP / 实体绘制 / 自瞄 / 穿墙 / 自动交互 / 自动躲避 / 寻路。

## 加载

```lua
loadstring(game:HttpGet("https://ghproxy.net/https://raw.githubusercontent.com/1418995116/xhub/main/xhub.lua?t=" .. math.floor(tick())))()
```

jsDelivr 的 `@main` 有约 12 小时缓存，急用时改用 40 位 commit sha：
`https://cdn.jsdelivr.net/gh/1418995116/xhub@<full-sha>/xhub.lua`

## 当前版本

v5.2 / build 2026-11-01 02:15 / 100758 bytes

## 快捷键

RightShift / Insert / F2 开关菜单 · F 开关飞行 · 左键（开火）触发自瞄 · Q 备用瞄准键

## 服务器档位（自动识别）

| 档位 | 特征 | 位移策略 |
|---|---|---|
| DOORS | RemotesFolder + CurrentRooms | 服务端约 16-20 studs/s，用 Noclip + 自动开门 |
| San Aurie | ReplicatedFirst.AntiCheat | 会封号，建议只开 ESP / Noclip |
| 通用 | 其它 | 先 35，被拉回就降 5 档 |

## 更新流程

1. 修改 `xhub.lua` 后 Commit
2. 需要 `@main` 立刻生效时，浏览器打开一次
   `https://purge.jsdelivr.net/gh/1418995116/xhub@main/xhub.lua`
   （purge 有速率限制，重复点击会返回 `throttled: true`，等约 13 分钟）
3. 或者直接用 commit sha 加载，完全不受缓存影响