# 七日 Demo 叙事内容包

这里是正式工作台使用的叙事配置。入口为 `content_pack.json`。

## 文件职责

- `content_pack.json`：声明本内容包 ID、默认工作日和所有分表路径。
- `storylines.json`：四条故事线、参与人物、案件节点和建议变量。
- `demo_cases.json`：35 宗可实际审批的案件。
- `demo_workdays.json`：七天每日五槽编排及晨间政策。
- `daily_dialogue.json`：供叙事引擎统一维护的七日白天与夜间文案登记表。
- `../../docs/narrative/secretary.md`：吉祥物“秘书”的正式称呼、神秘感边界、语言规则与运行时事件映射。
- `../ontology/people.json`：18 名人物的运行时身份、图片、声音和颜色。
- `../ontology/document_types.json`：12 类可在桌面展开的文书布局。
- `../ontology/purposes.json`：业务名称与承办部门。
- `../ontology/rules.json`：机器能够判定的材料与字段规则。

## 新增普通案件

1. 在 `demo_cases.json` 新增稳定 ID，并设置 `content_kind: "general"`。
2. 在 `pool_tags` 中加入目标工作日标签，例如 `day4`。
3. 配置一份 `DOCTYPE-APPLICATION` 主申请表和不超过五份附件。
4. 在 `required_document_type_ids` 写明当天必须出现的材料类型。
5. 在 `rule_ids` 组合缺件、签署、地址、有效期、译文或许可规则。
6. 不需要改 GDScript；对应工作日的普通槽会按随机种子抽取。

最小结构：

```json
{
  "id": "CASE-G-D4-05",
  "person_id": "PERSON-YE",
  "purpose_id": "PURPOSE-TRANSIT",
  "form_code": "T-33/归市人员夜间路线登记",
  "difficulty": 3,
  "content_kind": "general",
  "pool_tags": ["general", "day4"],
  "dialogue": {
    "greeting": "我来登记今晚的调度路线。",
    "delivery": "申请和许可都在。",
    "waiting": "路线发生过，不等于时刻表承认它。",
    "approved": "谢谢。",
    "rejected": "我会补件。"
  },
  "document_ids": ["T33-APP"],
  "required_document_type_ids": ["DOCTYPE-APPLICATION"],
  "rule_ids": ["RULE-REQUIRED-DOCUMENTS", "RULE-APPLICATION-SIGNED"],
  "consequence_correct_id": "CONSEQUENCE-CORRECT",
  "consequence_wrong_id": "CONSEQUENCE-WRONG",
  "documents": [
    {
      "id": "T33-APP",
      "document_type_id": "DOCTYPE-APPLICATION",
      "title": "归市人员夜间路线登记表",
      "fields": {"request": "登记夜间调度路线", "signed": true}
    }
  ]
}
```

## 新增剧情回访

剧情案件设置 `content_kind: "story"` 和 `storyline_id`，再把案件 ID 放入对应工作日的固定槽：

```json
{
  "slot": 4,
  "kind": "story",
  "case_id": "CASE-S-NEW-D6",
  "conditions": [
    {"kind": "decision_is", "case_id": "CASE-S-EARLIER-D3", "decision": "批准"}
  ],
  "fallback_case_id": "CASE-G-D6-04"
}
```

可用条件：

- `case_seen`：前置案件曾进入归档。
- `case_not_seen`：前置案件尚未进入归档。
- `decision_is`：前置案件最近一次归档决定等于指定 `decision`。

条件读取 `WorkdayState.archived_cases`，会随现有存档和时间线分支一起保存。

## 关键 NPC 多句对白

`greeting`、`delivery`、`waiting`、`approved`、`rejected` 均可填写单个字符串或字符串数组。普通案件推荐使用单句；故事案件使用 2–3 个短句，让人物事实、线索和情绪逐步出现。

```json
{
  "dialogue": {
    "greeting": ["我是沈青禾，从第七区申请迁入。", "林默先来过。他大概没有说完整。"],
    "delivery": ["临住证明和工作说明都在。", "原区转送编号一直没有生成。"],
    "waiting": ["那三个月我们住在第七码头附近。", "那里每晚都有一班没有时刻表的车。"],
    "waiting_delay_seconds": 7,
    "approved": ["至少这次，地址会留下来。", "请也留下开始日期。那不是填错的。"],
    "rejected": ["我会补编号。", "但日期不会因此改变。"]
  }
}
```

每句只承载一个信息点，并建议控制在 36 个字符以内。玩家作出决定或跳过演出时，尚未播放的句子会被取消。

## 七日昼夜文案

`daily_dialogue.json` 按 `daytime` 与 `evening` 管理场景、说话人、语气、
接入状态、来源和正文。

- `implemented`：正文已存在于当前游戏配置或脚本；
- `draft`：在 HTML 叙事引擎中维护、等待后续接入游戏的草案；
- HTML 编辑器使用浏览器本地草稿，并可导入或导出同结构 JSON；
- 离线 `file://` 页面不能静默改写项目文件，导出的 JSON 需要人工确认后替换本文件。

## 约束

- ID 在所属分表内必须唯一。
- 每宗案件必须恰好有一份主申请表。
- 每个文件袋最多六份材料，以适配两行缩略图托盘。
- 每日 `case_count` 必须与槽位数一致。
- 固定案件、条件案件、人物、用途、文书、规则、后果和故事线引用都必须存在。
- 所有错误会在 `ConfigDatabase.reload()` 时阻止内容包进入游戏。
