# 实时游戏状态同步设计

## 目标

Formocracy 在电脑运行时，把当前场景、发言者和台词发布到云端 Hono 服务。Rokid Kotlin 客户端和浏览器测试页面订阅同一份实时状态，在断线重连或中途加入后立即恢复当前画面。

首版不做鉴权，使用单实例内存状态，优先满足本地联调和现场演示。服务重启会清空状态，但游戏下一次发布即可恢复。

## 架构

```text
Godot 游戏
  └─ HTTPS PUT ─▶ 云端 Hono
                    ├─ 保存 gameId 最新快照与 revision
                    ├─ WebSocket ─▶ Kotlin / Rokid
                    └─ WebSocket ─▶ 浏览器测试页面
```

Godot 只承担状态发布。它不维护长连接，发布失败也不阻塞游戏流程。Hono 为每个 `gameId` 保存最新快照，为每次更新生成递增版本，并向该房间的 WebSocket 订阅者广播完整状态。订阅端首次连接时立即收到当前快照。

## 状态协议

状态包含：

- `gameId`：演示房间标识。
- `revision`：服务端递增版本。
- `updatedAt`：服务端更新时间。
- `scene`：当前场景或流程。
- `phase`：场景内阶段。
- `speaker`：发言者 ID、显示名和类型。
- `dialogue`：当前台词及开始时间；无人发言时为 `null`。
- `metadata`：工作日、案件和其他可选展示信息。

客户端事件统一使用 JSON envelope：

```json
{
  "type": "game_state",
  "state": {
    "gameId": "adventurex-demo",
    "revision": 12,
    "scene": "workbench",
    "phase": "npc_speaking",
    "speaker": {
      "id": "PERSON-LIN",
      "name": "林默",
      "kind": "npc"
    },
    "dialogue": {
      "text": "您好。我来办理共同居住配额。",
      "startedAt": "2026-07-24T10:30:12.000Z"
    },
    "metadata": {
      "day": 1,
      "caseId": "CASE-001"
    },
    "updatedAt": "2026-07-24T10:30:12.000Z"
  }
}
```

## 服务端接口

- `PUT /api/games/:gameId/state`：合并客户端提交的状态，覆盖服务端生成的 `gameId`、`revision` 和时间。
- `GET /api/games/:gameId/state`：读取最新快照；尚无状态时返回初始化快照。
- `GET /api/games/:gameId/events`：升级为 WebSocket，连接后先发送快照，再接收实时广播。
- `GET /viewer/:gameId`：测试页面，显示连接状态、场景、发言者和台词，并可手动发布测试状态。

不同 `gameId` 的状态与广播完全隔离。服务端校验路径参数和请求体，错误请求返回结构化 JSON。

## 游戏接入

新增 `GameStateSync` Autoload，集中管理服务地址、房间 ID 和非阻塞 HTTP 发布。默认指向本地服务，允许通过 Godot 环境变量覆盖云端地址和房间。

发布点包括：

- 进入主工作台和流程阶段变化。
- 秘书简报每行开始与结束。
- NPC 的问候、材料递交、等待和审批结果台词开始与结束。
- 场景退出、跳过演出时清除当前台词。

同步层的网络错误只产生警告，不修改游戏状态或中断动画。

## Kotlin / Rokid 接入

示例使用 OkHttp WebSocket 和 kotlinx.serialization。客户端把 HTTPS 地址转换为 WSS 地址，解析 `game_state` 消息，通过回调或 `StateFlow` 提供最新状态，并在异常断开后指数退避重连。UI 只消费最新 `revision`，忽略旧消息。

## 验证

- Hono 测试覆盖状态初始化、更新、版本递增、非法输入和房间隔离。
- WebSocket 集成测试验证首次快照和更新广播。
- 浏览器页面通过本地服务手动发布状态验证。
- Godot 测试验证同步客户端生成的 payload，以及现有游戏测试没有回归。
