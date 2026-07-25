# FORMOCRACY 人物素材库

打开 `index.html` 可离线浏览 18 位人物的统合档案。

## 目录结构

- `index.html`：统合人物档案，无需服务器。
- `manifest.json`：全包机器可读清单。
- `contact-sheet.png`：18 位人物 8-bit 头像总览。
- `SHA256SUMS.txt`：包内文件完整性校验。
- `characters/<人物 slug>/`：每位人物的独立素材目录。

每个人物目录包含：

- `metadata.json`：身份、叙事、行政、玩法、视觉与源路径元数据。
- `portrait_8bit.png`：128×128、纯黑白、1-bit 头像。
- `concept.png`：人物设定图。
- `fullbody.png`：游戏内默认全身像。
- `animation_table.json`：已改写为包内相对路径的动画表。
- `frames/*.png`：该人物动画表引用的独立帧。
- `voice_sfx.*`：当前人物绑定的语音音效。

人物数量：18
动画帧文件数量：312
