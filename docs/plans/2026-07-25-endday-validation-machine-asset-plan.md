# 日终送验新视图与验收机资产计划

## 目标

日终送验改为一套独立的俯视视图。画面只强调三件事：

1. 一台位于画面上方的表单验收机。
2. 一条从下方连接到机器入口的直线轨道。
3. 一只竖向文件袋沿轨道进入机器并被吞掉。

机器、轨道、文件袋和地面必须是独立资源。机器不能烘焙在房间背景里，轨道也不能画进机器主体。

## 视觉基准

- 文件袋基准：`/Users/amin/Desktop/FORMOCRACY/文档袋.png`
- 文件袋比例：1023 × 1537，竖向约 2:3。
- 机器独立概念资产：`assets/concepts/endday_validation/validation_machine_topdown_concept.png`
- 吞入效果图：`output/endday-validation-concept/validation-machine-ingesting-document-bag.png`
- 游戏设计视口：1280 × 720。
- 构图：机器位于顶部中央，轨道保持垂直，文件袋不旋转、不缩小，只沿 Y 轴移动。

## 资产拆分

### 机器包

`validation_machine_body.png`

- 透明背景的完整机器主体。
- 包含机壳、面板、进料口和静态滚筒。
- 不包含轨道、地板、文件袋、文字或场景阴影。
- 建议游戏显示宽度约 420–480 px。

`validation_machine_intake_foreground.png`

- 只包含入口下沿、前置滚筒和遮挡边缘。
- 放在文件袋上方，用于制造文件袋进入机器内部的遮挡关系。
- 必须与 `validation_machine_body.png` 使用相同画布、原点和尺寸。

`validation_machine_lights.png`

- 透明灯光覆盖层。
- 至少提供待机、运行、完成、故障四种颜色状态。
- 若只改变颜色，可在 Godot 中通过 `modulate` 复用同一张灯光遮罩。

`validation_machine_rollers_strip.png`

- 可选的 4 帧滚筒动画条。
- 如果静态滚筒配合音效已经足够，可推迟到第二轮。

### 轨道包

`validation_rail_middle.png`

- 可纵向平铺的中段。
- 宽度约为文件袋显示宽度的 1.15 倍。

`validation_rail_machine_cap.png`

- 轨道与机器入口之间的连接段。
- 不画入机器主体，便于以后更换轨道长度。

`validation_rail_bottom_cap.png`

- 轨道在画面底部或装载台处的收口。

### 文件袋包

文件袋素材由正在进行的重构任务负责。日终送验只依赖以下稳定接口：

- 竖向文件袋。
- 透明背景。
- 统一锚点位于底边中央。
- 关闭状态是必需资源。
- 可选提供选中、送验中、已盖验收标记等覆盖层。

### 场景包

`validation_floor.png`

- 只包含模块化暗色地板。
- 不包含机器和轨道，后续可独立换肤。

`validation_intake_glow.png`

- 机器工作时入口内部的暖色光。
- 作为轻量特效，不与主体合并。

## Godot 场景结构

```text
EndDayValidationView
├── Floor
├── RailLayer
│   ├── RailMiddle
│   ├── RailMachineCap
│   └── RailBottomCap
├── DocumentLayer
│   ├── QueueSlots
│   └── ActiveDocumentBag
├── MachineLayer
│   ├── MachineBody
│   ├── IntakeGlow
│   ├── MachineLights
│   └── IntakeForeground
├── EffectLayer
└── StatusLayer
```

遮挡顺序必须是：

```text
地板 < 轨道 < 机器主体 < 文件袋 < 入口前景遮挡
```

这样文件袋移动到入口时，入口前景会逐渐盖住文件袋，形成真正的“吞入”，而不是通过缩小或淡出来假装消失。

## 一次送验动画

1. **装载**：玩家点击文件袋，文件袋移动到轨道起点。
2. **启动**：机器待机灯切换为运行灯，传送带音效开始。
3. **运输**：文件袋保持原比例和朝向，以恒定速度沿轨道上移。
4. **吞入**：文件袋进入机器口，被 `IntakeForeground` 逐步遮挡。
5. **验收**：滚筒短促震动，入口灯闪一次，播放机械压入音。
6. **完成**：文件袋完全不可见，后台记录该档案已送验。
7. **下一份**：轨道恢复待机，允许玩家选择下一只文件袋。

建议时长：

- 装载：0.20–0.30 秒。
- 轨道运输：0.65–0.90 秒。
- 机器吞入：0.35–0.50 秒。
- 完成反馈：0.20 秒。

整个过程控制在约 1.4–1.8 秒，既能感到机械重量，又不会拖慢每天五份档案的节奏。

## 游戏逻辑边界

- 沿用现有 `get_pending_archives()` 与 `validate_archive_batch()` 数据接口。
- 新视图只替换表现层，不改变档案状态结构、机器容量或日报跳转。
- 文件袋素材通过配置路径加载，避免正在重构的文件袋资源与送验场景耦合。
- 玩家只能在机器待机时选择下一只文件袋。
- 动画中断时，档案状态仍保持“待验”，只有吞入完成后才写入本批选择。

## 实施阶段

### 第一阶段：锁定机器资产

- [x] 确认机器主体造型和入口宽度。
- [x] 输出透明机器主体。
- [x] 从主体衍生入口前景遮挡层和灯光层。
- [x] 在透明棋盘格上检查边缘和图层对齐。

### 第二阶段：轨道与场景组装

- [x] 制作可平铺轨道三件套。
- 建立 1280 × 720 新视图。
- 使用临时矩形验证机器、轨道和文件袋的比例，不接游戏逻辑。

### 第三阶段：吞入原型

- 接入竖向文件袋。
- 完成直线移动、遮挡、灯光和音效。
- 验证不使用缩放和淡出来表现吞入。

### 第四阶段：接入日终流程

- 把待验档案映射为文件袋队列。
- 接入机器容量、选择锁定、批次完成和积压。
- 全批完成后进入日报。

### 第五阶段：验证

- 视觉：机器、轨道、文件袋在任意状态都不穿帮。
- 交互：连续点击不会重复送验。
- 状态：动画中断不会丢档案。
- 流程：容量满后正确进入日报，未送验档案继续积压。
- 性能：1280 × 720 下动画稳定，无临时大纹理重复加载。

## 暂不做

- 不制作完整验收室背景。
- 不在机器上加入可阅读文字。
- 不做多轨道或自动分拣。
- 不在文件袋重构完成前固化最终文件袋尺寸。
- 不改动 `desk_item_controller.gd`。

## 已产出的资源

### 机器

- `assets/concepts/endday_validation/validation_machine_topdown_concept.png`
  - 1254 × 1254，透明背景。
- `assets/concepts/endday_validation/validation_machine_intake_foreground.png`
  - 1254 × 1254，与机器主体使用完全相同的画布和原点。
- `assets/concepts/endday_validation/validation_machine_lights.png`
  - 1254 × 1254，只保留两个红灯和一个琥珀灯。

### 轨道

- `assets/concepts/endday_validation/validation_rail_machine_cap.png`
  - 360 × 520，机器接口段。
- `assets/concepts/endday_validation/validation_rail_middle.png`
  - 360 × 610，无端盖的可重复中段；纵向重复时使用 2 px 重叠隐藏边缘采样线。
- `assets/concepts/endday_validation/validation_rail_bottom_cap.png`
  - 360 × 760，底部装载收口。

### 预览

- `output/endday-validation-concept/validation-machine-layer-preview.png`
  - 机器主体、入口前景遮挡和灯光层的棋盘格对照。
- `output/endday-validation-concept/validation-rail-three-piece-preview.png`
  - 轨道三件套对照。
- `output/endday-validation-concept/validation-machine-ingesting-document-bag.png`
  - 文件袋被机器吞入的目标效果图。
