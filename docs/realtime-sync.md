# 实时画面同步使用说明

## 本地联调

先启动 Hono 服务：

```sh
cd /Users/amin/projects/formocracy
bun install
bun run dev --filter=@repo/hono-server-template
```

浏览器打开：

```text
http://localhost:3000/viewer/adventurex-demo
```

再从 Godot 编辑器启动游戏。游戏默认向 `http://127.0.0.1:3000` 的 `adventurex-demo` 房间发布状态。秘书和 NPC 发言时，浏览器会同步显示角色名和台词。秘书的正式叙事定义见 [`docs/narrative/secretary.md`](narrative/secretary.md)。

## 连接云端

启动 Godot 前设置：

```sh
export FORMOCRACY_SYNC_URL="https://your-formocracy-server.example.com"
export FORMOCRACY_GAME_ID="adventurex-demo"
godot --path /Users/amin/formocracy
```

支持的变量：

- `FORMOCRACY_SYNC_URL`：Hono 服务公网地址。
- `FORMOCRACY_GAME_ID`：演示房间 ID，仅允许字母、数字、下划线和连字符。
- `FORMOCRACY_SYNC_ENABLED=false`：关闭状态发布，适合离线运行和自动化测试。

Kotlin/Rokid 使用同一公网地址和 `gameId`。HTTPS 地址会在客户端自动转换为 WSS。

## 部署约束

首版状态保存在服务进程内存中，云端必须满足：

- 支持长期运行的 Node 进程和 WebSocket Upgrade。
- 只运行一个服务实例。
- 反向代理保留 WebSocket 连接。
- 暴露服务配置的 `PORT`，健康检查使用 `/health`。

若后续需要多实例或服务重启后保留状态，应把房间状态和广播切换到 Redis；客户端协议无需改变。
