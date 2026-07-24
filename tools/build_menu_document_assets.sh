#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_dir="$project_root/assets/menu/document_collage/source"
output_dir="$project_root/assets/menu/document_collage/final"
chroma_tool="/Users/amin/.codex/skills/.system/imagegen/scripts/remove_chroma_key.py"
font_path="/System/Library/Fonts/STHeiti Medium.ttc"

mkdir -p "$output_dir"

for source_file in "$source_dir"/*.png; do
	base_name="$(basename "$source_file")"
	python "$chroma_tool" \
		--input "$source_file" \
		--out "$output_dir/$base_name" \
		--auto-key border \
		--soft-matte \
		--transparent-threshold 12 \
		--opaque-threshold 220 \
		--despill \
		--force >/dev/null
	magick "$output_dir/$base_name" -trim +repage "$output_dir/$base_name"
done

magick "$output_dir/01_workday_report.png" -font "$font_path" -fill '#262820' -gravity North -pointsize 52 -annotate +0+115 '工作日处理回执' -pointsize 24 -annotate +0+182 '中央现实管理局 · 第十二区行政记录处' -gravity SouthWest -pointsize 22 -annotate +90+85 '经办员：████    档案号：D12-74-119-02' "$output_dir/01_workday_report.png"
magick "$output_dir/02_approval_register.png" -font "$font_path" -fill '#292a22' -gravity North -pointsize 48 -annotate +0+42 '审批事项登记册' -pointsize 23 -annotate +0+102 '第01工作日 · 现实效力追踪副本' -gravity SouthWest -pointsize 21 -annotate +105+55 '登记人：████ / 原部门：████' "$output_dir/02_approval_register.png"
magick "$output_dir/03_reality_validation.png" -font "$font_path" -fill '#e8dfc8' -gravity North -pointsize 46 -annotate +0+130 '现实效力验收单' -fill '#34362e' -pointsize 23 -annotate +0+205 '设施编号 RVU-12 / 批次 0017' -gravity SouthWest -pointsize 21 -annotate +145+155 '结果：已记录    权利效力：无' "$output_dir/03_reality_validation.png"
magick "$output_dir/04_penalty_notice.png" -font "$font_path" -fill '#29251e' -gravity North -pointsize 45 -annotate +0+155 '内部差错处罚通知' -pointsize 22 -annotate +0+216 '职员 74-119-02 / 罚款 12 配给券' -gravity SouthWest -pointsize 20 -annotate +105+95 '原因：程序完整性不足' "$output_dir/04_penalty_notice.png"
magick "$output_dir/05_housing_change.png" -font "$font_path" -fill '#292a23' -gravity North -pointsize 48 -annotate +0+94 '住房用途变更申请' -pointsize 22 -annotate +0+158 '表单 R-12 / 第十二区居住配置处' -gravity SouthWest -pointsize 20 -annotate +95+75 '申请人：周砚    共居人数：2' "$output_dir/05_housing_change.png"
magick "$output_dir/06_water_quota.png" -font "$font_path" -fill '#30332f' -gravity North -pointsize 48 -annotate +0+78 '个人饮水配额申请' -pointsize 22 -annotate +0+140 '个人生活申请处理设施 / W-07' -gravity SouthWest -pointsize 20 -annotate +105+72 '申请人：████    住所：职员宿舍 12-C' "$output_dir/06_water_quota.png"
magick "$output_dir/07_passage_permit.png" -font "$font_path" -fill '#e9e2cf' -gravity North -pointsize 44 -annotate +0+52 '临时通行申请' -fill '#30322d' -pointsize 21 -annotate +0+123 '第十二区 → 已注销行政区' -gravity SouthWest -pointsize 20 -annotate +105+65 '申请人：████    通行原因：████' "$output_dir/07_passage_permit.png"
magick "$output_dir/08_lost_property.png" -font "$font_path" -fill '#2e3028' -gravity North -pointsize 48 -annotate +0+82 '旧物认领申请' -pointsize 22 -annotate +0+145 '物品：便携式现实记录器 / 来源不明' -gravity SouthWest -pointsize 20 -annotate +92+75 '认领人：████    原持有人：████' "$output_dir/08_lost_property.png"
magick "$output_dir/09_government_report.png" -font "$font_path" -fill '#292a22' -gravity North -pointsize 54 -annotate +0+235 '中央现实管理局' -pointsize 64 -annotate +0+310 '政府报告' -pointsize 23 -annotate +0+400 '附件编号 74-119-02 / 内部传阅' -gravity SouthWest -pointsize 20 -annotate +120+115 '关键段落已依据稳定条例删节' "$output_dir/09_government_report.png"
magick "$output_dir/10_staff_transfer.png" -font "$font_path" -fill '#2d2d25' -gravity North -pointsize 47 -annotate +0+52 '职员调任通知' -pointsize 22 -annotate +0+112 '职员 74-119-02 / 由 ████ 局调入' -gravity SouthWest -pointsize 20 -annotate +110+58 '生效日期：记录缺失' "$output_dir/10_staff_transfer.png"
magick "$output_dir/11_confidential_circulation.png" -font "$font_path" -fill '#e9dfc6' -gravity North -pointsize 43 -annotate +0+60 '保密事项传阅单' -fill '#33342c' -pointsize 21 -annotate +0+140 '密级：内部 / 阅后归档 / 禁止复制' -gravity SouthWest -pointsize 19 -annotate +90+72 '事项：关于职员 74-119-02 的身份复核' "$output_dir/11_confidential_circulation.png"
magick "$output_dir/12_archive_access.png" -font "$font_path" -fill '#ece3ca' -gravity North -pointsize 44 -annotate +0+35 '档案调阅许可' -fill '#292b25' -pointsize 21 -annotate +0+105 '申请调阅：注销部门 / 人员身份卷宗' -gravity SouthWest -pointsize 19 -annotate +100+62 '许可人：████    有效期：当夜' "$output_dir/12_archive_access.png"
magick "$output_dir/13_application_receipt.png" -font "$font_path" -fill '#2d2e27' -gravity North -pointsize 40 -annotate +0+64 '申请处理回执' -pointsize 21 -annotate +0+118 '回执号 12-0017 / 等待现实生效' -gravity SouthWest -pointsize 18 -annotate +65+42 '持有人：████' "$output_dir/13_application_receipt.png"
magick "$output_dir/14_staff_id.png" -font "$font_path" -fill '#2b2d28' -gravity North -pointsize 38 -annotate +115+62 '中央现实管理局职员证' -gravity SouthEast -pointsize 26 -annotate +95+205 '身份未登记' -pointsize 18 -annotate +75+155 '编号 74-119-02 / 第十二区' "$output_dir/14_staff_id.png"
magick "$output_dir/15_reality_seal.png" -font "$font_path" -fill '#342e28' -gravity North -pointsize 36 -annotate +0+78 '现实效力封条' -gravity South -pointsize 20 -annotate +0+82 '未经设施验收不得拆封' "$output_dir/15_reality_seal.png"
magick "$output_dir/16_stamps_sheet.png" -font "$font_path" -fill '#39342b' -gravity North -pointsize 30 -annotate +0+44 '中央现实管理局 · 行政邮资凭证' -gravity South -pointsize 18 -annotate +0+42 '档案编号贴：74-119-02' "$output_dir/16_stamps_sheet.png"
