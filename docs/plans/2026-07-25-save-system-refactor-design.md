# 存档系统模块化重构

## 状态

已接受，2026-07-25。

## 背景

存档文件读写、备份恢复、存档树、旧版本迁移和游戏状态本身原先都集中在
`scripts/autoload/workday_state.gd`。这使工作日规则与持久化基础设施相互耦合，
也让任何存档修改都需要编辑同一个大型脚本。

## 决策

在 `scripts/save/` 下建立独立模块，并保留 `WorkdayState` 已有公共方法作为兼容层：

- `save_schema.gd`：存档版本号和文档结构校验。
- `save_repository.gd`：JSON 读取、原子写入、备份恢复与整组文件删除。
- `save_migrator.gd`：旧版单存档迁移和旧夜间状态修复。
- `save_system.gd`：最新进度、检查点树和分支操作的统一协调器。

`WorkdayState` 继续拥有运行时游戏数据，并仅负责将数据转换为快照或从快照恢复。
现有场景仍可调用 `WorkdayState.save_progress()` 等接口，因此本次重构不要求同时修改
所有玩法场景，也不改变版本 7 的磁盘格式。

## 数据流

```text
场景 / 玩法
    ↓
WorkdayState 兼容接口
    ↓
SaveSystem
    ├── SaveSchema
    ├── SaveMigrator
    └── SaveRepository
            ↓
      user://formocracy-save.json
```

## 取舍

没有把 `SaveSystem` 注册为新的全局 Autoload。这样能避免出现第二份游戏状态，也能保持
现有调用稳定；代价是 `WorkdayState` 中仍保留少量委托方法。后续若需要多存档槽位，
只需扩展 `SaveRepository` 的路径策略，不需要重新移动工作日规则。

## 失败处理

- 主文件不是合法存档时读取 `.bak` 并重建主文件。
- 原子写入失败时恢复上一份备份。
- 新游戏同时清理主文件、备份和临时文件。
- 旧版存档先迁移成当前树结构，再交给其余逻辑处理。

## 验证

保留现有存档、分支、迁移、主菜单和跨场景测试，并增加模块边界测试，确保
`WorkdayState` 不再直接调用 `FileAccess`、`DirAccess` 或 JSON 持久化逻辑。
