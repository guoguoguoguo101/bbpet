# BbPet

公司内部像素桌宠。v1：角落一只可爱宠物，定时冒天气和新闻，点击就能跟 LLM 聊天。会议室见 [docs/v2-meeting-room.md](docs/v2-meeting-room.md)。

## 本机开发

```bat
copy .env.example .env
npm install
npm start
```

`.env` 只留在你自己电脑上，不要提交。也可以启动后在设置页填写 Base URL / Key / 模型。

默认走 OpenRouter：

- Base URL：`https://openrouter.ai/api/v1`
- 模型：`minimax/minimax-m3:free`
- 失败回退：`minimax/minimax-m2.7:free`

以后换 DeepSeek 或其他 OpenAI 兼容接口，只改设置里的地址和模型名。

## 打包发给同事

```bat
npm run dist
```

安装包在 `release/`。打包后的 EXE **不会**带上你的 Key，同事需要自己填，或你私下告知配置。

## 用法

1. 第一次打开：上传宠物照片、选种类、起名、选城市。
2. 宠物待在右下角，左键聊天，右键看天气/新闻/设置。
3. 托盘图标也能显示、隐藏、退出。
