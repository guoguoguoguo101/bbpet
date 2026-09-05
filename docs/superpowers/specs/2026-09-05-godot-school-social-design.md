# BbPet Godot 学校社交核

在现有 Godot 客户端上补点同学加好友、枢纽好友列表、教室黑板。校长协议不改。关学校窗只藏窗口、不断 WebSocket，人仍留在学校（对齐 Electron）。

## 背景

第一刀（`2026-09-05-godot-client-vertical-slice-design.md`）已经能透明桌宠、连校长、操场/教室走动。学校里不能点人、没有黑板、没有好友列表；关学校窗会 `disconnect_room`。

Electron 学校窗可以点人立刻加好友、教室写黑板、枢纽打开好友列表；打开好友就会 `ensureRoom`，关掉世界窗也不掉线。Godot 要对齐这三件事，才能和 Electron 同事在同一间教室真正同校。

家、串门、动作、五子棋、操场近距泡、LLM 仍不在范围里。

## 目标

Godot 客户端能够：

1. 在学校点同学弹出菜单，发 `friendRequest`，双方立刻成为好友（校长现有逻辑，不用点同意）。
2. 枢纽「好友」看到名单和在不在线；未连校长时点「好友」会先连上，不自动打开学校窗。
3. 教室黑板发/看字，同一教室（含 Electron）约 1 秒内看到；隔壁班看不到。进房带最近约 80 条，画面显示最近 7 条。
4. 关掉学校窗后 WebSocket 保持到退出程序或修改学校地址；人仍留在学校，再点「去上学」回到刚才的地图。

## 范围

做：

- 扩展 `godot/`：`RoomMessages`、`RoomClient`、`WindowHub`、`WorldWindow`、`PanelWindow`。
- 增发 `chat`、`friendRequest`；增收 `chat`、`friends`。`welcome.home.friends` 写入同一份列表。
- 枢纽第三入口「好友」。面板种 `friends`。
- 教室黑板 UI + 底栏输入。操场无输入、无头顶泡。
- 点人菜单：加好友 / 已是好友 / 取消。
- 改第一刀：`close_world` 不再断线，只隐藏学校窗（不发 `enterPlace("away")`）。校长把 `away` 当成「回自己家」，人已在自己家时会静默丢弃，并不能用来离校。

不做：

- 改 `server/`、`shared/` 报文形状、Electron 客户端（README 可补一句 Godot 好友/黑板）。
- `friendAccept` / `friendDecline` UI、incoming 申请条。
- 「去他家」「进他家」「五子棋」、家地图、动作、操场泡。
- LLM、天气、照片生成、Godot 当校长。

## 架构

三窗不变。连接变成进程内长连。

```
枢纽「去上学」/「好友」
        │ 已连则复用；未连则 connect + hello
        ▼
RoomClient  ──WS──► 现有校长
  发: hello, enterPlace, move, chat, friendRequest
  收: welcome, snapshot, join, leave, move, poses,
      chat, friends, error, notice
  丢: pose, dress, emote, gameState, …

关学校窗: 隐藏 WorldWindow（不断线、不离校）
退出 / 改学校地址: discard_world() + disconnect_room()
```

家的 snapshot（`home:`）和 `away` **不得**打开学校窗。只有 `placeId` 以 `school:` 开头的 snapshot 才 `show_world`。

## 组件

| 单元 | 职责 | 依赖 |
| --- | --- | --- |
| `RoomMessages` | `HANDLED` 含 `chat`、`friends` | 无 |
| `RoomClient` | 长连；`send_chat(text)`、`request_friend(id)`；缓存 `friends`、`board`；信号 `chat_received`、`friends_changed` | AppState |
| `WindowHub` | 枢纽三钮；`open_panel("friends")` 可先连校长；`close_world` 只藏窗；学校 snapshot 才开学校窗 | RoomClient、Panel、World |
| `WorldWindow` | 点人菜单、教室黑板与输入、输入聚焦时不走路 | RoomClient、SchoolLogic |
| `PanelWindow` | `friends` 列表；枢纽加「好友」 | RoomClient |
| `school_social.gd`（可选纯函数） | 菜单分支、board 截 80、可见 7 条、`sanitize_chat` | 无 |

`sanitize_chat` 对齐 `shared/world.ts`：空白压成单空格、trim、最长 80。

## 数据与协议

发：

- `{ "type": "chat", "text": "<sanitized>", "placeId": "<当前教室 id>" }` 仅当前在教室时发。`placeId` 必须带，且必须是当前 `snapshot.you` 所在教室，对齐 Electron `WorldApp`。
- `{ "type": "friendRequest", "targetId": "<id>" }`

收：

- `chat`：`line` 含 `id, clientId, name, text, ts, kind, placeId`。仅当 `placeId` 等于当前学校 `placeId` 且该地为 classroom 时追加黑板。
- `friends`：`friends` 数组（`FriendCard`：`clientId, name, species, colors, online, placeId, homeId, schoolPlaceId, inGame`）。`incoming` 收下但不渲染。
- `welcome`：把 `home.friends` 写入列表；不要用 `home` 打开学校窗。
- `snapshot`：学校图更新 people/you/board；`board` 只在 classroom 使用。

`BOARD_LIMIT = 80`。画面 `visible_board = board.slice(-7)`。

## 界面

### 点人

点非自己的同学。菜单贴在其屏幕坐标旁。

- 未好友：「加好友」「取消」。
- 已好友（`friends` 里有该 id）：「已是好友」（不可再发请求）、「取消」。
- 没有五子棋、去他家。
- 点地图空白或「取消」关闭菜单。

### 黑板

仅 `place.kind == classroom`：

- 黑板区在教室上方 `k` 砖附近，深底浅字，空时文案：`黑板还是空的，回车写一句。`
- 行格式：`{name}：{text}`
- 底栏 placeholder：`点这里或按 Enter 写黑板`；按钮「发送」。
- 教室 hint 可用：`黑板只有本班听得见`。
- 操场：无黑板、无输入。顶栏 hint 不要再写「走近才看得到气泡」（这一刀没有泡）。

输入框聚焦时不处理 WASD；点地图让输入失焦并重新走路。

### 好友面板

尺寸约 300×480。枢纽按钮文案「好友」。

每行：16×16 预览（`pixel_size=2`）、名字、状态一行：

- 离线 → `离线`
- `schoolPlaceId` 有值 → `在学校`
- 否则在线 → `在线`

空列表 hint：`去学校点别的同学，点「加好友」就会出现在这里。`
未连上时先出现连接中/失败文案，成功后再画列表。
没有进他家、五子棋。

### 枢纽

三个按钮，顺序：去上学、好友、设置。

## 数据流

**去上学：** 未连则 `connect` + `hello` + `pending_enter=school:campus`。已连且当前不在学校则 `enterPlace("school:campus")`。已连且学校窗开着且 `connected` 则前置窗口。

**好友：** 未连则 `connect` + `hello`（`pending_enter` 为空）。`friends_changed` 或 welcome 后 `open_panel("friends")`。不要 `begin_school_flow`。

**关学校窗 / 踩操场 `x`：** 保存尺寸、隐藏学校窗，不 `queue_free`、不发 `away`。`connected` 保持 true。人仍在学校。再点「去上学」显示同一扇窗。

**设置改地址或种类/名字：** 若已连接则 `discard_world()` 并断开；需用户再点上学或好友。改种类后刷新桌宠穿透。

## 错误处理

- 连不上：「连不上学校」，桌宠不崩，不自动重连。
- 中途断开：「已断开」；好友面板可保留最后名单但标断开；再点入口才重连。
- 好友：校长原文 notice/error（`已添加 …`、`你们已经是好友了`、`不能加自己`、`没选到同学`）写入 `RoomClient.last_notice`（截断到 80 字）。学校窗开着时由 `status` 画进顶栏 `_alert`；进下一张地图或关窗后顶栏恢复人数。好友面板开着时画在面板顶部一行。
- 黑板：空字不发；输入框 max 80。校长限流时本地不乐观插入。
- 隔壁班 `chat.placeId` 不匹配则丢弃。

## 测试

Headless：

- `chat`/`friends` 被 parse，`gameState` 仍 ignored。
- `sanitize_chat` 与 80 字截断。
- board 最多 80，可见 7。
- 未好友 / 已好友菜单谓词。
- 关学校窗只隐藏、不断线、不发 `away`。
- 家 snapshot 不触发「应打开学校窗」的标志。

手工：

1. 甲乙同班：甲写黑板，乙约 1 秒内看到 `名字：正文`；丙在隔壁班看不到。
2. 进教室能看到进房前已有黑板（最近 7 条上屏）。
3. 操场无输入；点同学能加好友；再点为「已是好友」。
4. 枢纽好友显示对方在线/在学校；关学校窗后列表仍在、连接还在；再点去上学会回到刚才的地图。
5. 校长没开时点好友：有错误提示，桌宠还在。
6. Electron 同学同班：黑板与加好友互通。

## 明确的选择

- 教室黑板 only，不做操场泡。
- 点人小菜单，不直接点加。
- 进程内长连，关窗只藏窗口，人仍在学校。
- incoming 申请不画。
- 不把好友做成第四扇系统窗。
