# BbPet Godot 客户端竖切

用 Godot 4 重做整个桌宠客户端的第一刀：透明桌宠能当主程序用，并能连上现有校长进学校走动。校长、协议、Electron 客户端这一刀都不改。

## 背景

当前客户端是 Electron + React：透明置顶宠物、枢纽面板、学校世界窗、家/动作/五子棋。校长是独立 Node WebSocket 进程（`npm run room`，默认 `ws://127.0.0.1:18765`）。

目标架构是「Godot 做整个客户端，校长继续用 Node」。整仓一次迁完太大。这一刀只验证三件难事叠在一起：Windows 透明置顶窗、现有 16×16 模板宠、现有 JSON 协议。

Electron 代码留在仓库对照。同事改发 Godot 导出的 EXE；还在用 Electron 的人进同一所学校时，两边要能看见对方。

## 目标

Godot 4.4+ / GDScript 导出的 Windows 程序能够：

1. 当角落桌宠：透明置顶、按不透明像素点击穿透、拖拽、左键枢纽、托盘或右键显示/隐藏/退出。
2. 首次选种类、起名；设置里改名字、种类、学校地址。
3. 连现有校长，进操场和四间教室，WASD 走动，镜头跟随，看见同学（含 Electron 客户端）。

成功标准见文末验收清单。

## 范围

做：

- 仓库新增 `godot/` 工程；`server/`、`shared/`、Electron 客户端原样保留。
- 三窗：桌宠（引擎主窗）、枢纽/设置/引导（额外 `Window`）、学校（额外 `Window`）。
- 运行时按现有模板串和瓷砖串画像素，不新做精灵表、不改 TileMap 关卡。
- `WebSocketPeer` 对接现有校长。这一刀只发 `hello` / `enterPlace` / `move`，只处理 `welcome` / `snapshot` / `join` / `leave` / `move` / `poses` / `error` / `notice`。

不做：

- 改校长进程或 WebSocket 报文形状。
- 抽一份给 TS 和 GDScript 共用的 JSON 协议/地图文件（允许双份逻辑，文件头注明源路径）。
- LLM、天气/新闻气泡、照片生成像素宠、右键天气菜单。
- 黑板、点人菜单、加好友、好友列表、家、串门、动作、五子棋。
- Godot 当校长、`hostRoom`、读 Electron 的 userData。
- 用 Electron/PowerShell 维持置顶或点击穿透。

## 架构

引擎主窗就是桌宠窗（64×86、无边框、透明、置顶），避免再藏一个空根窗。枢纽和学校是额外 `Window`。

```
Windows 桌面
  ├─ 主窗 PetWindow      透明置顶 64×86
  ├─ PanelWindow         枢纽 / 设置 / 首次引导（同时只开一种）
  └─ WorldWindow         不透明学校窗，默认 820×560，最小 520×380
         │
         ▼
Autoload
  ├─ AppState            档案
  ├─ RoomClient          WebSocket JSON
  └─ WindowHub           开/关窗、托盘、置顶
         │
         ▼
现有校长  ws://…:18765     npm run room，零改动
```

窗口之间不互相拿节点，只通过 Autoload 信号通信。

Godot 工程放在 `godot/`。应用名 `bbpet`，档案写 `user://bbpet-state.json`（Windows 下为 Godot `app_userdata/bbpet/`，与 Electron userData 分开）。本机对照必须两份档案、两个 `clientId`。

## 组件

| 单元 | 职责 | 依赖 |
| --- | --- | --- |
| `AppState` | 读/写 `user://bbpet-state.json`：`clientId`、`onboarded`、`pet`、`settings.roomUrl`、`settings.worldWidth/Height` | 无 |
| `RoomClient` | 连接；发 `hello` / `enterPlace` / `move`；收白名单报文，其余丢弃 | AppState |
| `WindowHub` | 显示宠物；开/关面板与学校；托盘；面板贴在宠物旁；退出时断 WS、关窗 | AppState、TrayIcon |
| `PixelPet` | 模板串 → `ImageTexture`（种类、配色、pose、左右翻、最近邻缩放） | `templates.gd` |
| `school_logic.gd` | 从 `shared/world.ts` 搬：`PLACES`、门、出生点、`TILE`/`PET_SIZE`/`MOVE_SPEED`、`clampMove`、`triggerAt`、`spawnAfterEnter`、`tileColor`/`tileAccent` | 无 |
| `sync.gd` | 从 `shared/sync.ts` 搬：`interpolatePose`、`keepVisualPeople`、`applyPoseItems`、`roundPose` | school_logic 常量 |
| `paint.gd` | 从 `src/world/paint.ts` 搬：按瓷砖画地图和教室/操场标签 | school_logic |
| `PetWindow` | 穿透多边形、拖拽、左键开关枢纽、右键菜单、本地 idle/blink | PixelPet、WindowHub |
| `PanelWindow` | 同时只显示引导 / 枢纽 / 设置 | AppState、WindowHub、RoomClient |
| `WorldWindow` | 地图、镜头、WASD、门切场景、画自己和同学 | PixelPet、paint、school_logic、sync、RoomClient |
| `TrayIcon` | Windows 托盘：显示/隐藏宠物、退出 | 系统 API；失败则右键菜单顶上 |

`templates.gd` 从 `src/pet/templates.ts` 与 `src/pet/colors.ts` / `DEFAULT_COLORS` 搬。`SPECIES_LABELS` 用于引导和设置。

每个纯逻辑文件头部注释源路径，例如 `# 源：shared/world.ts`。数值必须与源文件一致：`TILE = 32`、学校里宠物占位 `PET_SIZE = 32`、`MOVE_SPEED = 110`、`MOVE_SEND_MS = 100`、`POSE_TICK_MS = 100`、`SCHOOL_CROWD_CAP = 100`。桌宠窗尺寸是另一套：64×86（16×16 模板放大），不要和学校里的 32 混用。

## 数据与协议

### 档案

JSON 字段对齐现有 store 的子集：

```json
{
  "onboarded": false,
  "clientId": "<uuid>",
  "pet": {
    "name": "豆豆",
    "species": "blob",
    "colors": { "outline": "...", "body": "...", "shadow": "...", "light": "...", "accent": "...", "eye": "...", "pupil": "...", "blush": "..." }
  },
  "settings": {
    "roomUrl": "ws://127.0.0.1:18765",
    "worldWidth": 820,
    "worldHeight": 560
  }
}
```

- 缺文件或坏 JSON：重建默认宠（blob「豆豆」+ 该种类默认盘），`onboarded = false`，下次开引导。
- 不写 LLM Key、城市、聊天记录、`hostRoom`、照片。
- 名字去首尾空白，最长 12 字；空名字不能保存。种类只允许 `cat` `dog` `rabbit` `bird` `hamster` `blob`。
- 换种类时配色立刻换成该种类 `DEFAULT_COLORS`，这一刀没有自定义调色。
- `hello` 里的 `pet` 只含 `name` / `species` / `colors`，不发 `photoDataUrl`。

### 联网

连接成功后立刻发 `hello`（`clientId` + `pet`）。校长会把人放在家里；Godot 再发 `enterPlace` `"school:campus"`，等 `snapshot` 后才显示学校内容。

`move` 约 10Hz，仅当坐标或朝向相对上次发送有变化时发。坐标用现有 `roundPose`（一位小数）。

收到：

- `welcome`：记下自己的 presence；若正在上学流程中，接着 `enterPlace` 操场。
- `snapshot`：切房间的权威结果；用其中的 `you` 和 `people` 重置该图。自己的位置在同图走动时不以服务器为准覆盖（`keepVisualPeople`）。
- `join` / `leave` / `move` / `poses`：更新「别人」。
- `error` / `notice`：顶栏显示，截断到一行。
- 其它类型（`chat` `friends` `pose` `dress` `emote` `gameState`）：丢弃，不弹窗、不崩溃。

这一刀不发 `pose` / `dress` / `chat` / 好友 / 对局。Godot 学校里的同学一律画 `idle`（可按 `facing` 左右翻）。Electron 侧仍按自己逻辑画这只 Godot 宠；Godot 不报 pose，对方看到的是校长默认的 idle。

人满时按校长返回的 `error`/`notice` 显示，不强行进门。

## 界面

### 桌宠

- 无边框、透明、始终置顶（Godot `WINDOW_FLAG_ALWAYS_ON_TOP`）。不追求 Electron 的 `screen-saver` 层级；置顶失败不阻塞上学。
- 按当前帧不透明像素生成 `mouse_passthrough_polygon`。算不出来则整窗收鼠标（透明角会挡桌面，宠仍可点可拖）。
- 移动超过 4 像素算拖拽，松手不打开面板。单击：若面板开着则关掉；若没开，未引导则开引导，已引导则开枢纽。
- 本地循环 idle / blink。不播天气装扮、不播动作。
- 右键：隐藏宠物、退出。有托盘时，隐藏后从托盘「显示」恢复。没有托盘时，「隐藏」改为最小化到任务栏，点任务栏图标恢复。禁止把窗设成完全 invisible 却无法找回。

托盘用最小 Windows NotifyIcon 封装（插件或 GDExtension）。菜单：显示/隐藏宠物、退出。创建失败则只用右键 + 任务栏；这一刀允许没有托盘，但不能为此留 Electron 壳。

退出：`WindowHub.quit` → 断 WebSocket → 关三扇窗 → 退出进程。

### 面板

贴在宠物右侧，放不下就左侧。同时只开一种：`wizard` / `hub` / `settings`。

- 引导：六种种类按钮（中文标签）+ 名字输入 + 确定。确定后 `onboarded = true`，关面板。
- 枢纽：预览当前宠；「去上学」「设置」。没有聊天、好友、回家。
- 设置：名字、种类、学校地址。保存写档案。若当时连着学校：断开，关学校窗；用户需再点「去上学」（这一刀不在线热更新 hello）。

枢纽约 300×430，设置约 340×640，引导约 340×520，对齐现有 `PANEL_SIZES`。

### 学校

- 默认 820×560，可拉到最小 520×380；关掉时把尺寸写进档案。
- 最近邻缩放，镜头跟着自己，默认缩放约 1.8，对齐现有 `WorldApp`。
- 地图用 `paint.gd` 按 `tileColor` / `tileAccent` 和标签画，必须与 Electron 同图同色。
- WASD 或方向键。每物理帧 `clampMove`。走进门砖：`triggerAt` → `enterPlace` → 等 `snapshot` → `spawnAfterEnter` 放置自己。
- 顶栏：地点名（`placeTitle`）、连接状态、错误/通知一行。
- 没有黑板输入、没有点人菜单、没有聊天条。
- 关学校窗 = 断开 WebSocket。桌宠和档案不动。再上学是一次新的 `connect` + `hello`。

## 数据流

**启动**

```
AppState.load
    → 显示桌宠
    → 未 onboarded：open_panel("wizard")
```

**去上学**

```
枢纽「去上学」
    → 学校窗已开则前置该窗，结束
    → RoomClient.connect(roomUrl) + hello
    → welcome → enterPlace("school:campus")
    → snapshot → 打开/显示学校窗，按 you 出生，开始 WASD
```

连不上：枢纽或学校顶栏「连不上学校」+ 短原因；宠物留在桌面。不自动重连。再点「去上学」才重试。

进行中断线：停止发 `move`，顶栏「已断开」，不关桌宠。

**走动**

```
每物理帧：输入 → clampMove → 更新本地 you
每 100ms：有变化则 send_move
收到别人 poses/move/join/leave：改别人列表
每帧：对别人 interpolatePose 再画
```

自己位置以本地为准。切房间只信 `snapshot`。

## 错误处理

- 地址空或不是 `ws://` / `wss://`：保存时提示，不发起连接。
- 握手失败、校长没开、中途断开：人话提示，不崩溃，不自动重连。
- 非法 `enterPlace`：停在当前图，不瞬移。
- 本机 Godot 与 Electron 共用一个 `clientId`：校长按现有逻辑顶掉旧连接。不另做双开锁；对照文档写明要用两份档案。
- 未知报文丢弃。

## 测试

纯函数与现有 TS 用例对齐，放在 `godot/tests/`，用 `godot --headless --script` 跑最小断言，不强制 GdUnit4：

- `clampMove` 撞墙停下、沿墙滑。
- 操场门 `a/b/c/d` 对应四间教室；教室 `g` 回操场；`spawnAfterEnter` 出生点。
- `interpolatePose` / `keepVisualPeople` / `roundPose`。
- 某一种类某一帧能画出至少一颗不透明像素，供穿透多边形用。

手工验收：

1. 首次打开：选种类、起名，角落出现透明宠；点空白桌面能点到后面的窗口。
2. 能隐藏/显示宠物并退出。有托盘走托盘；没有托盘时右键隐藏=最小化到任务栏，右键退出必须可用。
3. 枢纽能改名字、种类、`ws://127.0.0.1:18765`，保存后重启仍在。
4. `npm run room` 后，Godot「去上学」进操场，WASD，镜头跟随；四个门进对应教室，再出门回操场。
5. Electron `npm start` 另一只宠进同一校长：两边能看见对方走动；种类和配色对得上。
6. 关掉学校窗后桌宠还在；校长日志里该客户端离线。
7. 校长没开时点上学，有错误提示，桌宠不崩溃。

不测：黑板、加好友、家、动作、五子棋、LLM、天气、照片生成、Godot 当校长。

## 仓库与发布

- 新增 `godot/`，不删 Electron。
- 第一刀能在 Godot 编辑器运行；给同事的是 Godot 导出的 Windows EXE，不走 `electron-builder`。
- 校长仍是 `npm run room`（或同事机器上已有的校长）。Godot 设置里填 `ws://内网IP:18765`。
- README 补一小节「Godot 客户端（实验）」：如何打开 `godot/`、如何导出、如何与 Electron 对照。不把 Electron 启动说明删掉。

## 明确的选择

- 渲染：运行时画像素，不烘焙精灵表。
- 主窗即桌宠，不是隐藏根窗再开三扇。
- 学校同学画 idle，不跟 pose/dress。
- 关学校窗即断线，不断线热切换形象。
- 托盘尽力做；做不成用右键，任务照样完成。
