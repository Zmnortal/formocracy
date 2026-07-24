# 数据驱动的 NPC 抽帧动画系统设计

## 目标

NPC 使用独立透明 PNG 组成低帧率二维动画。角色位置可以连续移动，但姿态只在离散图片帧之间跳变，以刻意的机械抽帧表达制度世界的冷漠。

系统必须支持：

- 角色逐步进入柜台。
- 到达后播放待机与角色特有的微表情。
- 同意后进入开心状态，不同意后进入生气状态。
- 角色带着审批结果对应的情绪离场。
- 策划通过“动作行 × 帧列”的二维动画表配置内容。
- 美术维护独立 PNG；程序运行时自动构建 Godot `SpriteFrames`。

## 系统分层

### NpcAnimationLibrary

读取角色动画表、验证帧路径，并构建 `SpriteFrames`。每个动作拥有独立 FPS、播放模式和帧数组。

回退顺序：

1. 跳过缺失的单帧并记录警告。
2. 整个动作缺失时尝试同情绪 `idle`。
3. 再回退到普通 `idle`。
4. 最后使用角色静态图。

### NpcAnimationPlayer

封装 `AnimatedSprite2D`，负责：

- 播放指定动作。
- `LOOP`、`ONCE`、`HOLD` 三种模式。
- 动作完成信号。
- 立即打断与动画令牌。
- 查询当前动作、帧数和 FPS。

动作切换不做插值或交叉淡化。

### NpcPerformanceDirector

协调台词、位移和动画状态。位移轨道与抽帧动画互相独立：

- Tween 负责角色在入口、柜台和出口之间移动。
- 动画播放器负责人物姿态。
- 移动采用匀速或分段匀速，不使用弹性效果。
- 动画 FPS 不随移动速度变化。

## 状态流

```text
QUEUED
  → WALK_IN
  → ARRIVE
  → GREETING
  → DELIVER
  → WAITING
      ↔ IDLE / BLINK / LOOK_ASIDE / NERVOUS
  → APPROVED_REACT
      → HAPPY_IDLE
      → WALK_OUT_HAPPY
  或
  → REJECTED_REACT
      → ANGRY_IDLE
      → WALK_OUT_ANGRY
  → EXITED
```

`WAITING` 状态按角色配置的权重选择微表情。每个微表情结束后必须回到 `idle`，经过随机冷却时间后才能再次触发。

审批结果一旦确定，立即停止微表情调度并锁定情绪分支。开心或生气状态持续到角色完全离场。

## 二维动画表

策划界面使用动作作为行、帧序号作为列。底层保存为 JSON：

```json
{
  "character_id": "NPC-001",
  "default_animation": "idle",
  "micro_expression_cooldown": [2.5, 5.0],
  "micro_expressions": [
    { "action": "blink", "weight": 50 },
    { "action": "look_aside", "weight": 30 },
    { "action": "nervous", "weight": 20 }
  ],
  "actions": {
    "idle": {
      "fps": 3,
      "mode": "LOOP",
      "frames": ["frames/idle_00.png", "frames/idle_01.png", "frames/idle_02.png"]
    },
    "walk_in": {
      "fps": 7,
      "mode": "LOOP",
      "frames": ["frames/walk_00.png", "frames/walk_01.png", "frames/walk_02.png"]
    },
    "happy_react": {
      "fps": 6,
      "mode": "ONCE",
      "frames": ["frames/happy_00.png", "frames/happy_01.png", "frames/happy_02.png"]
    }
  }
}
```

目录结构：

```text
assets/characters/npc_001/
  frames/
    idle_00.png
    walk_00.png
    happy_00.png
  animation_table.json
```

## 首版动作

| 动作 | 建议帧数 | FPS | 模式 |
|---|---:|---:|---|
| `queue_idle` | 2–3 | 2 | LOOP |
| `walk_in` | 5 | 7 | LOOP |
| `arrive` | 2–3 | 4 | ONCE |
| `idle` | 3 | 3 | LOOP |
| `blink` | 3 | 5 | ONCE |
| `look_aside` | 3–4 | 4 | ONCE |
| `nervous` | 4 | 4 | ONCE |
| `deliver` | 4–5 | 6 | ONCE |
| `happy_react` | 4–5 | 6 | ONCE |
| `happy_idle` | 2–3 | 3 | LOOP |
| `angry_react` | 4–5 | 6 | ONCE |
| `angry_idle` | 2–3 | 3 | LOOP |
| `walk_out_happy` | 5 | 7 | LOOP |
| `walk_out_angry` | 5 | 7 | LOOP |

首版离场动作允许复用走路身体帧并提供情绪面部变体。

## 美术规格

- 所有帧使用相同画布尺寸，建议 512×768。
- 使用透明 PNG，不紧贴人物边缘裁切。
- 脚底锚点固定在完全相同的画布坐标。
- 人物最大高度和头部中心保持一致。
- 地面阴影由 Godot 独立节点生成，不绘制在角色帧中。
- 导入时关闭过滤和 Mipmap，采用 nearest 像素采样。
- 表情允许头部、肩膀和手部产生小幅跳变。
- 动作首尾不强制完全无缝。

## 异常处理

- 单帧缺失：跳过并在开发模式记录警告。
- 整个动作缺失：按回退链选择可播放动作。
- 尺寸或锚点不一致：显示开发警告，但不阻止游戏启动。
- 状态跳过或场景切换：取消当前播放令牌，旧信号不得继续推动演出。
- 权重池为空：保持普通 `idle`。

## 验收标准

- 每个动作能使用独立 FPS。
- `LOOP`、`ONCE`、`HOLD` 行为正确。
- 进场动画与位移同时运行。
- 等待阶段按角色权重播放微表情，并遵守冷却。
- 同意完整进入开心反应、开心待机、开心离场链。
- 驳回完整进入生气反应、生气待机、生气离场链。
- 缺帧、缺动作和静态角色均能安全回退。
- 跳过演出和切换场景不会触发过期回调。
- 首个 NPC 的完整流程通过自动化测试和实际渲染检查。
