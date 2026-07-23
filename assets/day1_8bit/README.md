# FORMOCRACY Day 1 — 8-bit Asset Pack

本资源包由 `opening-03-day-one-reveal-8bit-v1.png` 的视觉概念拆层重绘而成，适用于 Godot 2D 场景搭建。

## 目录

- `background/office_validation_room.png`：办公室与现实验收设施背景板，16:9。
- `interactive/applicant_terminal.png`：申请人通讯终端。
- `interactive/water_request_form.png`：饮水许可申请表。
- `interactive/water_regulation_handbook.png`：饮水法规册。
- `interactive/citizen_id.png`：公民身份证件。
- `interactive/attachments_stack.png`：证明附件。
- `interactive/return_stamp.png`：退回印章。
- `interactive/approve_stamp.png`：批准印章。
- `interactive/secretary_note.png`：秘书便笺。
- `interactive/candidate_rack.png`：已批准事项候选架。
- `interactive/validation_machine.png`：验收机与传送带前景版本；背景板已经包含静态验收机，二者择一使用。
- `source/interactive_chromakey.png`：生成时的洋红键控母版。
- `source/interactive_transparent.png`：去除键控背景后的完整透明母版。
- `preview/asset_contact_sheet.png`：资产总览。

## Godot 导入建议

- Texture Filter：`Nearest`
- Mipmaps：关闭
- Repeat：关闭
- Compress Mode：`Lossless`
- 以 320×180 作为逻辑画布，窗口按整数倍放大。
- 表单、证件、法规册和便笺使用 `Area2D` 或 `TextureButton` 处理交互。
- 印章建议将碰撞区域限制在底座范围，不要直接采用透明图片外框。
- 候选架应作为独立 HUD 层；表单进入槽位时，仅移动表单缩略图，不移动候选架本身。

## 推荐绘制顺序

1. `office_validation_room`
2. 桌面底板（由 Godot 原生九宫格或单独绘制）
3. `applicant_terminal`、`water_regulation_handbook`
4. `citizen_id`、`attachments_stack`、`secretary_note`
5. `water_request_form`
6. `return_stamp`、`approve_stamp`
7. `candidate_rack`
8. 字幕、光标、字段高亮等动态 UI
