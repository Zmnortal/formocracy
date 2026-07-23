# `scripts/main.gd` 模块化重构设计

## 目标

把 `scripts/main.gd`（694 行）按职责拆成多个独立脚本，保留 `main.gd` 作为场景协调器，不引入新的 `.tscn` 场景文件（对应选项 B）。

拆分后要达到：
- 每个脚本只负责一个明确的职责。
- 模块之间通过信号或主脚本传递数据，避免直接访问对方内部节点。
- 现有游戏行为保持不变。
- 测试脚本做最小调整即可继续验证核心流程。

## 新文件结构

```text
scripts/
├── main.gd                              # 薄协调器
├── gameplay/
│   ├── desk_nodes.gd                    # 工作台节点引用数据对象
│   ├── desk_builder.gd                  # 静态工作台视觉构建
│   ├── case_presenter.gd                # 单个案件节点：表单、文件袋、材料、盖章、装袋
│   ├── stamp_manager.gd                 # 印章工具：创建、拖拽、悬停、盖章判定
│   ├── workbench_input.gd               # 表单/文件袋/材料拖拽与放手区域判定
│   ├── submission_manager.gd            # 提交验收：校验、记录、动画、转场
│   └── case_sequence.gd                 # 工作日案件队列：取案件、切日报
└── ui/
    └── workbench_ui.gd                  # 从 main.gd 抽出的 style_box / add_text 工厂
```

## 各模块职责

### `WorkbenchUI`

- 静态常量：`PIXEL_FONT`、调色板 `COLORS`。
- `style_box(color, radius, border_color, border)`：创建 `StyleBoxFlat`。
- `add_text(parent, text, size, color, position, dimensions)`：创建 `Label`。

### `DeskNodes`

- `class_name DeskNodes extends RefCounted`
- 只保存节点引用和常量位置，不实现逻辑：
  - `form_home: Vector2`
  - `form_base_scale: Vector2`
  - `slot: Panel`, `slot_light: ColorRect`
  - `status_label: Label`
  - `applicant_card_label: Label`, `queue_label: Label`, `timer_label: Label`
  - `validation_overlay: Control`, `validation_image: TextureRect`
  - `npc_panel: Panel`

### `DeskBuilder`

- `class_name DeskBuilder extends RefCounted`
- `build(root: Node2D) -> DeskNodes`
- 构建静态部分：背景、暗角、申请人卡、验收槽、状态栏、队列显示、计时器、验收转场遮罩。
- 不创建印章、表单、文件袋、材料，这些属于动态案件内容。

### `CasePresenter`

- `class_name CasePresenter extends RefCounted`
- 负责单个案件的全部视觉节点：
  - 创建 / 销毁表单 `form`、文件袋 `envelope`、证明材料 `document_panels`。
  - 管理盖章状态 `is_stamped()` / `stamp_type()`。
  - 打开文件袋、装袋单个 / 全部材料。
  - 暴露节点引用供输入模块使用：`form`, `envelope`, `document_panels`, `stamp_mark`。
- 状态：
  - `form_stamped: bool`, `form_stamp_type: String`
  - `envelope_opened: bool`, `envelope_on_desk: bool`
  - `primary_document_id: String`
  - `packed_document_ids: Array[String]`
  - `case_started_at: float`
- 方法：`start_case(data: Dictionary)`, `open_envelope()`, `pack_document(id: String)`, `pack_all_documents()`, `apply_stamp(kind, local_position)`, `clear_case()`。

### `StampManager`

- `class_name StampManager extends RefCounted`
- 创建批准/驳回两枚印章工具。
- 处理印章拖拽、悬停缩放、归位动画。
- 释放时判断印章中心是否在表单范围内，若是则调用 `CasePresenter.apply_stamp()`。
- 状态：`stamp_tools: Array[Panel]`。

### `WorkbenchInput`

- `class_name WorkbenchInput extends RefCounted`
- 处理表单、文件袋、材料的鼠标拖拽与释放。
- 负责把放手区域翻译成高层意图：
  - 表单拖到左下区域 -> `presenter.pack_document(primary_document_id)`
  - 材料拖到左下区域 -> `presenter.pack_document(document_id)`
  - 文件袋拖到验收槽 -> 发射 `envelope_submitted` 信号
- 信号：`envelope_submitted()`。
- 方法：`bind_case(presenter: CasePresenter)`：连接当前案件的节点输入事件。

### `SubmissionManager`

- `class_name SubmissionManager extends RefCounted`
- 处理提交动作：
  - 检查是否盖章、是否装齐材料、是否已拆封。
  - 调用 `WorkdayState.record_case_result()`。
  - 播放验收槽闪烁、表单/文件袋被吸入槽的动画。
  - 播放 `ValidationOverlay` 淡入淡出。
- 信号：`submission_finished()`。
- 方法：`submit(presenter: CasePresenter, case_data: Dictionary)`。

### `CaseSequence`

- `class_name CaseSequence extends RefCounted`
- 负责工作日的案件流转：
  - `start_day()`：启动 `LevelDirector.start_gameplay_workday()`，取出第一个案件，发射 `case_started(data)`。
  - `advance(accepting_new_cases: bool)`：取下一件案件；若已结束或时间到，发射 `day_finished()`。
- 状态：`case_index: int`, `current_case: Dictionary`（只读）。
- 信号：`case_started(case_data: Dictionary)`, `day_finished()`。

### `main.gd`（协调器）

- 在 `_ready()` 中创建所有模块并连接信号。
- 持有 `accepting_new_cases`、`case_index`（供测试使用）和 `current_case`（供提交使用）。
- 每帧调用 `WorkdayState.tick()`、更新计时器标签、判断时间到。
- 窗口变化时缩放根节点。
- 不负责任何节点构建或输入细节。

## 数据流与信号连接

```text
sequence.case_started
    ├──> presenter.start_case(data)       # 创建表单/文件袋/材料
    ├──> input_mgr.bind_case(presenter)   # 连接拖拽输入
    └──> main.current_case = data

stamp_mgr.stamp_applied
    └──> presenter.apply_stamp(...)       # 在表单上留下印章

input_mgr.envelope_submitted
    └──> main._on_envelope_submitted()
        └──> submission_mgr.submit(presenter, main.current_case)

submission_mgr.submission_finished
    └──> sequence.advance(accepting_new_cases)

sequence.day_finished
    └──> main._on_day_finished() -> change_scene_to_file(daily_report.tscn)
```

## 主脚本 `_ready()` 示例

```gdscript
func _ready() -> void:
    OpeningMusic.stop_opening(1.2)
    desk = DeskBuilder.new(self).build()

    presenter = CasePresenter.new(self, desk)
    stamp_mgr = StampManager.new(self, desk, presenter)
    input_mgr = WorkbenchInput.new(self, desk)
    submission_mgr = SubmissionManager.new(self, desk)
    sequence = CaseSequence.new()

    sequence.case_started.connect(presenter.start_case)
    sequence.case_started.connect(input_mgr.bind_case)
    sequence.case_started.connect(_on_case_started)
    stamp_mgr.stamp_applied.connect(presenter.apply_stamp)
    input_mgr.envelope_submitted.connect(_on_envelope_submitted)
    submission_mgr.submission_finished.connect(_on_submission_finished)
    sequence.day_finished.connect(_on_day_finished)

    get_viewport().size_changed.connect(fit_to_window)
    sequence.start_day()
    fit_to_window()
```

## 测试适配

拆分后测试需要改为访问新的公开接口，主要变更如下：

| 旧访问 | 新访问 |
|---|---|
| `main.form` | `main.presenter.form` |
| `main.applicant_card_label` | `main.desk.applicant_card_label` |
| `main.npc_panel` | `main.desk.npc_panel` |
| `main.envelope` / `main.document_panels` | `main.presenter.envelope` / `main.presenter.document_panels` |
| `main.envelope_opened` / `main.envelope_on_desk` | `main.presenter.envelope_opened` / `main.presenter.envelope_on_desk` |
| `main.open_envelope()` | `main.presenter.open_envelope()` |
| `main.apply_stamp(...)` | `main.presenter.apply_stamp(...)` |
| `main.pack_all_documents()` | `main.presenter.pack_all_documents()` |
| `main.submit_form()` | `main.submission_mgr.submit(...)` |
| `main.validation_overlay` | `main.desk.validation_overlay` |
| `main.stamp_mark` | `main.presenter.stamp_mark` |
| `main.stamp_tools` | `main.stamp_mgr.stamp_tools` |

`main.case_index` 保留在 `main.gd` 上供测试使用。

## 错误处理

- `LevelDirector.start_gameplay_workday()` 失败时，`CaseSequence` 通过 `push_error` 输出，并把 `case_started` 发射一个空字典；`CasePresenter.start_case()` 检测到空数据时显示原有错误提示。
- `SubmissionManager` 始终允许提交，但会把“漏盖章 / 遗漏材料 / 未拆封”记录到 `WorkdayState`，保持与现有行为一致。

## 迁移步骤

1. 创建 `ui/workbench_ui.gd` 并迁移 `style_box` / `add_text` / 调色板。
2. 创建 `gameplay/desk_nodes.gd`。
3. 创建 `gameplay/desk_builder.gd` 并迁移静态场景构建。
4. 创建 `gameplay/case_presenter.gd` 并迁移案件节点相关逻辑。
5. 创建 `gameplay/stamp_manager.gd` 并迁移印章工具。
6. 创建 `gameplay/workbench_input.gd` 并迁移拖拽输入。
7. 创建 `gameplay/submission_manager.gd` 并迁移提交动画。
8. 创建 `gameplay/case_sequence.gd` 并迁移案件队列。
9. 重写 `main.gd` 为协调器。
10. 更新测试脚本中的访问路径。
11. 运行全部测试，确保行为一致。

## 不做的范围

- 不拆 `.tscn` 场景文件（选项 B）。
- 不改动非 `main.gd` 的游戏系统（如 `WorkdayState`、`LevelDirector`、`RuleEvaluator`）。
- 不改动游戏逻辑本身（例如仍然允许提交有错误的表单，仍然不触发延迟后果）。
- 不引入新的资源加载系统（`assets/day1_8bit/assets.json` 仍保持原状）。
