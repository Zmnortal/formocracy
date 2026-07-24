# Manager 化功能域重构

## 状态

已确认并实现，2026-07-25。

## 目标

按照 Godot 游戏项目常用的 Manager 语义收口工作日与主工作台业务：

- 复杂功能拥有独立文件夹。
- 文件夹内存在同名 Manager，作为唯一公开入口。
- 场景只调用 Manager methods，不直接持有内部模块。
- `WorkdayState` 只保存跨场景状态与持久化端口。
- 版本 7 存档字段、迁移和备份恢复保持兼容。
- 不增加 Autoload，不产生第二份游戏状态。

## 目录

```text
scripts/managers/workday_manager/
├── workday_manager.gd
├── workday_context.gd
├── workday_clock_module.gd
├── workday_settlement_module.gd
├── workday_archive_module.gd
├── workday_personal_form_module.gd
├── workday_consequence_module.gd
└── workday_desk_layout_module.gd
```

`workday_manager.gd` 是同名公开入口。其余文件是 Manager 内部的原子模块，不向场景暴露。

## 公开调用

```gdscript
WorkdayState.manager.tick(delta)
WorkdayState.manager.record_case_result(case_data, decision)
WorkdayState.manager.get_pending_archives()
WorkdayState.manager.purchase_personal_form(form_type_id)
WorkdayState.manager.begin_next_day()
```

## 调用关系

```text
场景 / 玩法
    ↓
WorkdayState.manager.method()
    ↓
WorkdayManager
    ↓
内部原子模块
    ↓
WorkdayContext 状态端口
    ↓
WorkdayState + SaveSystem
```

## 模块职责

- Clock Module：倒计时、超时、新工作日时间和缺水操作倍率。
- Settlement Module：日薪、绩效、罚款、生活支出、余额和日报统计。
- Archive Module：创建归档、查询积压、机器容量验收和等待天数。
- Personal Form Module：购买、库存、提交、到期审核和审核摘要。
- Consequence Module：案件处理记录、政治信用、延迟后果和外部反馈。
- Desk Layout Module：桌面物件位置和层级持久化状态。

## 约束

- Manager 是功能域唯一公开入口。
- 内部模块不注册全局单例，也不直接访问文件系统。
- 动态存档字典只在 `WorkdayContext` 的安全读取边界完成类型转换。
- 场景内部 helper 使用私有方法，避免把构建细节暴露为公共 API。
- `make quality` 必须同时通过格式、lint 和 Godot 严格类型检查。

## 第二轮：WorkbenchManager

主工作台采用相同结构：

```text
scripts/managers/workbench_manager/
├── workbench_manager.gd
├── workbench_case_sequence.gd
├── workbench_case_presenter.gd
├── workbench_input_module.gd
├── workbench_stamp_module.gd
├── workbench_submission_module.gd
├── workbench_call_bell_module.gd
├── workbench_briefing_director.gd
├── workbench_briefing_module.gd
├── workbench_npc_performance_module.gd
└── workbench_batch_validation_module.gd
```

`main.gd` 只创建 `WorkbenchManager`，并把 `_ready`、`_process`、`_exit_tree`
三个 Godot 生命周期事件转交给 Manager。案件推进、文件袋呈现、盖章、提交、
NPC 表演、广播、召唤铃和日终送验均由 `WorkbenchManager` methods 编排。

原子模块保留各自的 UI 或规则职责，但不再由场景直接装配。测试和调试工具可以
读取 Manager 持有的模块状态，用于验证视觉层级与交互过程；生产流程只从 Manager
入口启动、推进和清理。
