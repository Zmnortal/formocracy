# 夜间地图正式像素资产设计

## 目标

用可直接导入 Godot 的正式 8-bit 位图替换夜间地图中的程序绘制建筑块、站点和角色 Token，同时保留已经完成的地点选择、路线移动、购买与回家填写交互。

## 视觉方向

- 行政档案纸地图与衰败公共设施结合。
- 主色为深橄榄绿、旧纸黄、暗铜红和褪色金色。
- 硬边阴影、有限色阶、明显像素颗粒；不使用平滑渐变。
- 参考现有主工作台和开场第三张图的低照度官僚主义像素风。
- 图片内不生成中文文字，地点名称继续由 Godot 的 Ark Pixel 字体渲染。

## 第一批资产

```text
assets/map/
  background/
    district_12_map.png
  locations/
    central_forms.png
    ration_depot.png
    home_12c.png
  tokens/
    player_token.png
    route_node_active.png
  stamps/
    locked_stamp.png
  source/
    *.png
  assets.json
```

`district_12_map.png` 使用 1280×720 画布，包含旧纸底板、网格、河道、红色交通路线、普通建筑和未标记站点，不包含交互地点文字、玩家 Token 或弹窗。

三个地点资产采用透明背景，统一正面略俯视的伪 3D 角度和底部锚点。玩家 Token 与路线节点保持小尺寸、强轮廓，以便在地图缩放后仍可读。

## 生成与透明处理

完整底图直接生成不透明 PNG。独立地点和 Token 先在纯品红色抠图背景上生成，再使用本地 chroma-key 工具转换为透明 PNG。所有最终素材需要检查透明角、主体覆盖率、残留色边和像素清晰度。

## Godot 接入

- 底图使用全屏 `TextureRect`，`STRETCH_SCALE` 填满 1280×720 设计画布。
- 地点资产位于现有点击按钮下方或作为按钮图标，按钮仍负责 hover、点击和禁用状态。
- 玩家 Token 使用 `TextureRect` 替换当前纯色 `Panel`。
- 动态高亮路线仍由脚本绘制，亮点使用独立像素素材。
- 纹理过滤采用 Nearest，不启用 Mipmap。
- 点击区域沿用现有地点卡，不因素材轮廓缩小。

## 验收

- 地图全屏无裁切、无黑边。
- 三个地点的素材风格、透视和色板一致。
- 交互卡、Token 和动态路线保持原有功能。
- 1280×720 与全屏窗口下像素边缘清晰。
- 生成资产均保存在仓库并记录来源提示与用途。
