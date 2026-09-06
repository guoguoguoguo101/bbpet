# BbPet Godot 桌宠天气与穿衣

在现有 Godot 客户端上补城市、定时天气/新闻气泡，以及按天气换衣服和雨雪叠层。校长协议不改。气泡是独立小窗，衣服叠在桌宠和客厅槽位上。

## 背景

Godot 已经有桌宠窗、枢纽、学校、好友、黑板、回家串门和客厅动作。坐在角落时还不会冒天气新闻，也不会按天气穿衣服。Electron 用 Open-Meteo、RSS 新闻、独立气泡窗，并用已有 `dress` 报文把衣服同步给同场所的人。

Godot 现在丢掉 `dress`。这一刀对齐单机生活，并让 Electron 同事能看见 Godot 宠的雨衣/围巾。LLM、五子棋、午睡循环、样式打磨仍不在范围里。

## 目标

Godot 客户端能够：

1. 引导和设置里选城市（表与 `shared/cities.ts` 相同，默认北京）。
2. 启动和换城市后立刻拉天气；约每 20 分钟再拉。按 `dressFor` 给自己叠装备和特效，连着校长则上传 `dress`。
3. 按 `pushIntervalMin`（默认 30、最少 5）轮流冒天气文案和新闻标题；失败冒固定安静文案。
4. 天气/新闻用独立置顶透明气泡窗，贴在桌宠旁；新闻带链接则可点开系统浏览器。
5. 学校和客厅里画出别人发来的 `dress`。

## 范围

做：

- 扩展 `godot/`：城市表、`dressFor` / 天气文案、HTTP 天气和新闻、气泡窗、桌宠与客厅槽位的 WeatherDress 叠层、设置/引导城市与推送间隔、`RoomClient` 收发 `dress`。
- 设置持久化：`cityId`、`cityName`、`latitude`、`longitude`、`pushIntervalMin`（与 Electron 字段同名）。
- 点击穿透把装备/特效不透明像素算进凸包。
- README Godot 段补一句：会冒天气新闻、按天气穿衣服。

不做：

- 改 `server/`、`shared/` 报文形状、Electron 客户端。
- LLM、五子棋、午睡摸鱼循环、操场近距泡、飞踢 flyer、照片生成。
- 样式打磨（枢纽/菜单外观留给以后）。
- Godot 当校长。

## 架构

系统窗：桌宠主窗、枢纽/设置/引导、学校、**天气新闻气泡窗**。气泡不是家窗。子窗口不嵌入主窗（`embed_subwindows=false`）。

```
启动 / 换城市 / 20min
        ▼
HTTP Open-Meteo ──► dressFor ──► 本地叠层
                         └──► 已连则 dress 报文 ──► 校长 ──► 同场所他人

pushInterval 轮流
        ▼
天气 dressLine 或 RSS 标题 ──► 气泡窗（贴桌宠旁）
失败 ──► 「{名字}：外网有点安静，我稍后再探探天气和新闻。」
```

`RoomClient` 增收 `dress`，仍丢 `gameState`。家 snapshot 仍不得 `show_world`。

## 组件

| 单元 | 职责 | 依赖 |
| --- | --- | --- |
| `godot/weather/cities.gd` | 城市表与默认北京，字段对齐 `shared/cities.ts` | 无 |
| `godot/weather/dress_logic.gd` | `dress_for(code, temp, is_day, wind)`、文案表，对齐 `electron/services/weather.ts` + `shared/weatherLines.ts` | 无 |
| `godot/weather/feeds.gd` | 解析 RSS item、挑一条新闻；源与 `electron/services/news.ts` 相同（少数派 / Solidot / 人民网） | 无 |
| `WeatherClient` | HTTP 拉天气/新闻；定时器；缓存上一套衣服 | AppState、dress_logic |
| `BubbleWindow` | 透明置顶小窗，显示 `kind`+`text`，可选 url | WindowHub |
| `WeatherDress` | 叠 gear/fx（伞、帽、围巾、雨衣、雪人、果汁、雨雪星云雾风） | 无 |
| `PetRoot` / 客厅槽 | 把自己和客人的 dress 画上；穿透含叠层 | WeatherDress、RoomClient |
| `AppState` | 读写城市和 `pushIntervalMin` | cities |
| `PanelWindow` | 引导选城市；设置改城市和间隔 | AppState |
| `RoomClient` | `send_dress`；缓存 `dresses[clientId]`；`dress` 信号 | 校长 |

装备与特效枚举与 Electron 相同：`shades|raincoat|scarf|beanie|umbrella|snowman|juice`，`rain|snow|sun|fog|storm|wind|stars|cloud`。

## 数据与协议

档案 `user://bbpet-state.json` 的 `settings` 增加：

- `cityId` / `cityName` / `latitude` / `longitude`（缺省北京：`beijing`，39.9042，116.4074）
- `pushIntervalMin`（缺省 30，保存时夹到 ≥5）

天气：Open-Meteo `current=temperature_2m,weather_code,is_day,wind_speed_10m`，查询参数与 `electron/services/weather.ts` 相同。

新闻：依次请求 Electron 那三个 RSS，解析出第一条可用标题即停。

发：

- `{ "type": "dress", "dress": { "gear": [...], "fx": [...] }, "placeId": "<you.homeId>" }`  
  仅在已连接、`homeId` 非空、且相对上次上传有变化时发。未连接只本地穿。

收：

- `dress`：按 `clientId` 写入 `dresses`；更新 `home_people` 或学校 `people` 对应项的 `dress`。不打开学校窗。
- 仍丢 `gameState`。

气泡文案：

- 天气：`dressLine`（`dressFor` 的那句）。
- 新闻：`{宠物名}：[{source}] {title}`。
- 失败：`{宠物名}：外网有点安静，我稍后再探探天气和新闻。`

气泡时长：无 url 8 秒，有 url 16 秒。点带 url 的气泡则 `OS.shell_open(url)` 并收起气泡。

天气刷新：启动、保存城市、以及每 20 分钟。刷新成功则更新叠层并可能 upload dress。拉取失败不改衣服，只在「轮到这次冒泡」时用失败文案。

## 界面

引导：在名字旁增加城市下拉，选项为城市中文名，顺序与 `CITIES` 一致。

设置：增加「城市」下拉和「冒泡间隔（分钟）」数字（或可编辑文本，非法则保存失败提示）。保存后立刻拉一次天气并重置两个定时器。

气泡窗：无边框、透明、置顶、不嵌入主窗。位置贴桌宠左侧或上方，钳进工作区。不挡左键开枢纽（点气泡不是点宠物）。

桌宠/客厅：`WeatherDress` 叠在对应 PixelPet 上。聚会时每人用自己的 `dresses[id]`，没有则空衣服。托盘图标仍是自己 idle，不随天气变。

右键仍是隐藏/退出，不改成 Electron 那套天气/新闻菜单。

## 错误与测试

- HTTP 非 2xx 或解析失败：当次拉取失败，走失败气泡规则。
- 城市 id 未知：回退北京。
- `dress` 缺字段：当空 `gear`/`fx`。
- 测试不打真网：天气 JSON 和 RSS 用字符串夹具。
- 必测：`dress_for` 夜间 → `stars`；暴雨 → raincoat+umbrella+rain+storm；城市默认北京；`RoomMessages` 接受 `dress`；未连接不发 dress；间隔夹到最少 5。

## 非目标

不在这一刀做：LLM Key/对话、五子棋、午睡姿势循环、操场近距泡、飞踢出窗、照片生成、Godot 当校长、枢纽和菜单的视觉打磨。
