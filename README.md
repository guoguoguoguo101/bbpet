# BbPet

公司内部像素桌宠。角落一只宠物，定时冒天气和新闻，也能跟 LLM 聊天。左键打开枢纽，可以去学校走动、加好友、串门。学校规划见 [docs/v2-meeting-room.md](docs/v2-meeting-room.md)。

仓库：https://github.com/guoguoguoguo101/bbpet

## 本机开发

需要先装 [Node.js](https://nodejs.org/)。

```bat
git clone https://github.com/guoguoguoguo101/bbpet.git
cd bbpet
copy .env.example .env
npm install
```

`.env` 只留在你自己电脑上，不要提交。也可以启动后在设置页填写 Base URL / Key / 模型。

默认走 OpenRouter：

- Base URL：`https://openrouter.ai/api/v1`
- 模型：`minimax/minimax-m3:free`
- 失败回退：`minimax/minimax-m2.7:free`

以后换 DeepSeek 或其他 OpenAI 兼容接口，只改设置里的地址和模型名。没填 Key 时，桌宠和天气一般还能看，跟 LLM 聊天不可用。

## Godot 客户端（实验）

需要 [Godot 4.4+](https://godotengine.org/download)（编辑器命令行能跑 `godot`）。校长仍是 Node，不要用 Godot 当校长。

会按城市冒天气和新闻气泡，并按天气穿衣服；和 Electron 同学同场时应能看见雨衣/围巾。

用编辑器打开 `godot/project.godot`，或：

```bat
godot --path godot
```

纯函数测试：

```bat
npm run test:godot
```

先另开一个终端跑 `npm run room`。Godot 里左键枢纽 → 去上学；教室可写黑板、点同学加好友；操场走近才看得到说话气泡。枢纽可和宠物聊 LLM（设置里填 Key），好友页能同意/拒绝申请；客厅飞踢会飞出独立小窗。好友列表和学校点同学可邀五子棋，对局在独立棋盘窗里下；Godot 仍不当校长。枢纽「回家」/好友「进他家」会展开桌宠客厅，可说话和右键动作；上学时家里来客桌宠也会变大。枢纽「好友」会连校长，但不自动打开学校窗。关掉学校窗后连接还在，人还在学校里，再点去上学会回到刚才的地图。设置里学校地址默认 `ws://127.0.0.1:18765`。和 Electron 同学同班时，黑板和加好友应互通。

和现在的 Electron 客户端对照时，用两只不同的宠（两份档案、两个 id）。不要把 Godot 的 `user://bbpet-state.json` 拷到 Electron 的 userData。本机可同时 `npm start` 一只 Electron 宠，进同一所学校应能互相看见。

导出给同事：编辑器 项目 → 导出 → Windows Desktop。EXE 不包含校长进程，同事仍要有人跑 `npm run room`，并在设置里填 `ws://内网IP:18765`。

## 学校（校长服务 + 桌宠）

学校位置、谁在哪间教室、好友列表都在**校长进程**里。桌宠只当学生去连它，不要两边都勾「我来当校长」。

开三个窗口：

```bat
npm run room
```

```bat
npm start
```

本机再开一只测试宠（橘色猫「豆豆2」，位置会偏左一点）：

```bat
npm run start:pet2
```

设置里学校地址填 `ws://127.0.0.1:18765`，不要勾「我来当校长」。

同事连你这台机时，填 `ws://你的内网IP:18765`，并放行防火墙入站 18765。

校长终端里能看到谁上线、谁加了好友，例如：

```
[hello] 豆包 f47c9e5c 上线
[friend] 豆包 -> 豆豆2 (accepted)
```

好友数据写在校长进程目录的 `bbpet-friends.json`，这个文件不要提交。

### 学校里怎么玩

1. 左键宠物 → **去上学**。两人都要开着学校窗口，并且在同一张图（操场或同一间教室）。
2. WASD 走动。镜头跟着自己，对方走远了会出画面。
3. 点另一个同学 → **加好友**，不用对方确认，立刻出现在好友列表。
4. 桌宠枢纽里打开 **好友**，可以看在不在线、进他家。

## 数据在哪

不是客户端不停拉取。连上之后校长用 WebSocket **推送**变化。

| 数据 | 存在哪 | 怎么同步 |
| --- | --- | --- |
| 名字、形象、自己的 id、LLM Key | 各自电脑本地 | 连上时把形象发给校长一次 |
| 位置、谁在哪间教室 | 校长内存 | 走动时推给同一张图的人 |
| 好友列表 | 校长的 `bbpet-friends.json` | 加好友时推一次 |
| 天气、新闻、私聊 | 只在自己电脑 | 不上校长 |

## 打包发给同事

```bat
npm run dist
```

安装包在 `release/`。打包后的 EXE **不会**带上你的 Key，同事需要自己填，或你私下告知配置。同事如果要进学校，仍然需要有人先跑 `npm run room`（或设置里勾「我来当校长」）。

## 用法

1. 第一次打开：上传宠物照片、选种类、起名、选城市。
2. 宠物待在右下角，左键开枢纽，右键看天气/新闻/设置。
3. 托盘图标也能显示、隐藏、退出。
