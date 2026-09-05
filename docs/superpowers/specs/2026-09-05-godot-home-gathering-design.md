# BbPet Godot 客厅与动作

在现有 Godot 客户端上补家、串门、桌宠客厅聚会，以及客厅右键动作和说话。校长协议不改。客厅叠在桌宠主窗上，有客人（或人在别人家）时拉大窗口。

## 背景

学校社交核已经能加好友、好友列表、教室黑板；关学校窗只藏窗、人仍在学校。Electron 的「家」不是瓷砖地图，而是桌宠旁的客厅：客人分槽坐、右键抱抱/倒水/拍醒/飞踢、底栏说话。去学校不会离开自己家。

Godot 要对齐这套占用和客厅，才能和 Electron 同事互相串门、在客厅互动。五子棋、LLM、天气、操场泡仍不在范围里。

## 目标

Godot 客户端能够：

1. 枢纽「回家」连校长（若未连）并回到自己家占用；已在自家时校长会忽略重复 `enterPlace`，只收起枢纽。
2. 好友列表「进他家」、学校点人「去他家」：仅当对方 `online && homeId == home:对方id`（人在学校仍算在家）。
3. 聚会时主窗按人数拉大，客人坐槽、可说话、右键四个动作；学校窗开着时来客，桌宠立刻展开客厅。
4. 姿势帧从现有 `src/pet/templates.ts` 迁入（idle/blink/talk + 叠层），不新画像素。飞踢不飞出窗口。

## 范围

做：

- 扩展 `godot/`：`PetTemplates` 姿势表、`PetRoot` 客厅布局与穿透、`RoomClient`、`WindowHub`、`PanelWindow`、`WorldWindow` 点人菜单。
- 增发 `enterPlace(home:…)`、家的 `chat`、`emote`。增收家的 `snapshot` / `join` / `leave` / `chat` / `emote` / `pose`（只更新客厅）。
- 枢纽加「回家」。好友行加「进他家」/「不在家」。学校已好友菜单加「去他家」/「不在家」。
- 客厅槽位、底栏「聊」、头顶泡、右键抱抱/倒水/拍醒/飞踢。
- 移植 `shared/homeActions.ts` 的 `yardMetrics` / `HOME_ACTIONS` / `poseForAction`（纯函数）。

不做：

- 改 `server/`、`shared/` 报文形状、Electron 客户端（README 可补一句 Godot 客厅）。
- 五子棋、LLM、天气衣服/特效、午睡摸鱼循环、操场近距泡。
- 飞出窗口的飞踢 flyer、自己给自己发动作、第四扇「家」系统窗。
- Godot 当校长、照片生成。

## 架构

三扇系统窗不变。客厅不是新 `Window`，是主窗内容切换。

```
枢纽「回家」/ 好友「进他家」/ 学校「去他家」
        │ 已连则复用；未连则 connect + hello
        ▼
RoomClient  ──WS──► 现有校长
  发: hello, enterPlace, move, chat, friendRequest, emote
  收: welcome, snapshot, join, leave, move, poses,
      chat, friends, emote, pose, error, notice
  丢: dress, gameState, …

isHomeGathering?
  否: 主窗 64×86 单宠
  是: 主窗拉到 yard 尺寸，画槽位 + 底栏
学校窗: 仅 school: snapshot 打开；关窗只藏，不离校、不影响客厅
```

`isHomeGathering(you, homePeople, myId)` 对齐 `shared/world.ts`：`homeOwnerId(you.homeId) != myId` 则为串门（恒为聚会）；否则 `homePeople.size() > 0`。

家的 snapshot **不得** `show_world`。

## 组件

| 单元 | 职责 | 依赖 |
| --- | --- | --- |
| `PetTemplates` | idle/blink/talk + drink/sleep/wake/type/phone/snack/peek/game/wave/coffee/toilet 叠层 | 无 |
| `home_logic.gd` | `yard_metrics`、`is_home_gathering`、`is_friend_at_home`、`home_place_id`、动作姿势/文案 | 无 |
| `RoomClient` | `go_home(owner_id)`、`send_emote`、`send_home_chat`；缓存 `home_people`、`home_board`、`last_emote`、`you.homeId` | AppState、SchoolSocial |
| `PetRoot` | 单宠 ↔ 客厅；改窗尺寸；穿透；拖拽；聚会时停眨眼 | RoomClient、home_logic |
| `WindowHub` | `go_home()`；枢纽回家 | RoomClient、Panel |
| `PanelWindow` | 枢纽四钮；好友「进他家」 | RoomClient、home_logic |
| `WorldWindow` | 已好友菜单「去他家」/「不在家」 | RoomClient、home_logic |

槽位常量对齐 `shared/homeActions.ts`：`SLOT_W=72`、`SLOT_H=94`、`YARD_PAD_X=24`、`YARD_PAD_TOP=40`、`MENU_RESERVE=80`、`BAR_H=30`、`BAR_MIN_W=144`、`MAX_COLS=4`。

## 数据与协议

发：

- `{ "type": "enterPlace", "placeId": "home:<id>" }` 回家用自己 id，串门用对方 id。
- `{ "type": "chat", "text": "<sanitized>", "placeId": "<当前 you.homeId>" }` 仅聚会且输入打开时发。
- `{ "type": "emote", "kind": "hug|pour|wake|kick", "targetId": "<id>", "placeId": "<you.homeId>" }`

收：

- `welcome.home`：写入 `home_people`、`home_board`、`friends`。不打开学校窗。
- `snapshot`：`placeId` 以 `home:` 开头则更新 `you` + 客厅 people/board；以 `school:` 开头则只更新学校（现有逻辑）。
- `join` / `leave`：`placeId` 为当前 `you.homeId` 时改 `home_people`。
- `chat`：`line.placeId == you.homeId` 则进 `home_board` 与头顶泡；教室规则不变。
- `emote`：写入 `last_emote`，按 `HOME_ACTIONS` 持续时间内播姿势。
- `pose`：更新客厅对应人的 resting pose（不驱动学校窗）。
- 仍丢 `dress`、`gameState`。

`sanitize_chat` 仍用学校社交核那套。动作冷却以校长为准（5 秒），本地按钮 disable 5 秒防连点，但不乐观改姿势。

## 界面

### 单宠

64×86。左键枢纽，右键隐藏/退出。眨眼循环照旧。穿透按自己那只不透明像素。

### 客厅

主窗尺寸 = `yard_metrics(1 + homePeople, chatting, log_lines)`。客人列表 = `[you] + home_people`。

每槽：姿势帧（`pixel_size` 使 16 像素宽约合槽宽）、名字、头顶字。左键点自己开枢纽；左键点客人不开关枢纽；右键客人弹出：`抱抱` `倒水` `拍醒` `飞踢`。点空白或再点关闭菜单。

底栏未聊：标题 + `{n}人` + 按钮「聊」。聊中：placeholder `回车发送`，按钮「收」。日志最多约 3 行高，显示最近家聊天。

头顶：动作进行中用 `labelForAction`；否则气泡文案约 5 秒；再否则空。

飞踢：双方留在槽内播 `wake`/`peek`，不另开窗、不隐藏槽位。

点击穿透：所有槽位不透明像素 + 底栏/日志矩形。空区点到桌面。拖窗：按住槽或底栏拖。

托盘图标仍是自己 idle，不随客厅变。

### 枢纽

按钮顺序：去上学、回家、好友、设置。文案「回家」。

### 好友

每行加按钮：`is_friend_at_home` 为真 → 「进他家」；否则禁用「不在家」。没有五子棋。

### 学校点人

未好友：加好友、取消。已好友：去他家或禁用「不在家」、取消。没有「已是好友」单独按钮、没有五子棋。

## 数据流

**回家：** `hide` 枢纽。未连则 connect（`pending_enter` 为空）再 `enterPlace(home:自己)`。已连则直接 `enterPlace(home:自己)`（已在自家则校长忽略）。

**进他家 / 去他家：** 未连先连。`enterPlace(home:对方)`。成功后 `you.homeId` 变为对方家，聚会展开。

**来客：** `join` 家 → `home_people` 变长 → `isHomeGathering` 真 → 主窗拉大。学校窗若开着保持开着。

**客人走光且你在自家：** 缩回 64×86，恢复眨眼。

**关学校窗：** 只藏学校窗。客厅状态不动。

**设置保存：** `discard_world()` + `disconnect_room()`；客厅也缩回单宠。

## 错误处理

- 连不上 / 已断开：桌宠缩回单宠，不崩。
- 串门失败：校长原文；仍留在当前 `homeId`。
- 动作失败：校长原文；不播姿势。
- 空字不发。家 chat 不进教室黑板，教室 chat 不进客厅。

## 测试

Headless：

- `get_frame` 对 talk/drink/wave/peek/wake/sleep 有别于 idle。
- `is_home_gathering` / `is_friend_at_home`（在学校仍为在家；串门中为不在家；离线为不在家）。
- 家 snapshot 不开学校窗。
- `go_home` / 串门发出 `enterPlace` 的 `home:` id。
- `send_emote` 报文形状；不乐观改 pose。
- `yard_metrics` 人数 1/2/5 的宽高与 TS 一致。

手工：

1. 甲在自家，乙进他家：甲窗变大看见乙；标题乙侧为甲的「{名}家」。
2. 甲去上学后乙再来：学校窗仍开，甲桌宠展开客厅。
3. 丙未加好友进甲家：提示还不是好友。
4. 乙去别人家后，甲看乙为「不在家」。
5. 右键抱抱双方看到姿势和字；客厅说话只在客厅。
6. 飞踢不飞出窗。客人走光后甲窗缩回 64×86。
7. 与 Electron 互串门、互动作、互说话。

## 明确的选择

- 客厅叠在桌宠主窗上，不另开家窗。
- 上学时来客立刻展开客厅。
- 「在家」= 在线且 `homeId` 仍是自己家（在学校也算）。
- 飞踢留在槽内。
- 姿势表整份从现有模板迁入，不新画。
- 不做午睡摸鱼、天气、五子棋、LLM。
