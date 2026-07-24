#!/usr/bin/env python3

import argparse
from pathlib import Path

from PIL import Image


def _find_occupied_bands(mask: Image.Image, axis: str) -> list[tuple[int, int]]:
    length = mask.height if axis == "rows" else mask.width
    cross_length = mask.width if axis == "rows" else mask.height
    bands: list[tuple[int, int]] = []
    start: int | None = None

    for index in range(length):
        if axis == "rows":
            strip = mask.crop((0, index, cross_length, index + 1))
        else:
            strip = mask.crop((index, 0, index + 1, cross_length))
        occupied = strip.getbbox() is not None
        if occupied and start is None:
            start = index
        elif not occupied and start is not None:
            bands.append((start, index - 1))
            start = None

    if start is not None:
        bands.append((start, length - 1))
    return bands


def _normalize_frame(
    frame: Image.Image,
    canvas_size: tuple[int, int],
    subject_size: tuple[int, int],
    bottom_padding: int,
) -> Image.Image:
    alpha_box = frame.getchannel("A").getbbox()
    if alpha_box is None:
        raise ValueError("Detected an empty sprite frame.")
    subject = frame.crop(alpha_box)
    scale = min(subject_size[0] / subject.width, subject_size[1] / subject.height)
    resized_size = (
        max(1, round(subject.width * scale)),
        max(1, round(subject.height * scale)),
    )
    subject = subject.resize(resized_size, Image.Resampling.NEAREST)

    canvas = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    x = (canvas_size[0] - subject.width) // 2
    y = canvas_size[1] - bottom_padding - subject.height
    canvas.alpha_composite(subject, (x, y))
    return canvas


def split_sheet(
    input_path: Path,
    output_root: Path,
    actions: list[str],
    columns: int,
    canvas_size: tuple[int, int],
    subject_size: tuple[int, int],
    bottom_padding: int,
) -> int:
    sheet = Image.open(input_path).convert("RGBA")
    alpha_mask = sheet.getchannel("A").point(lambda value: 255 if value > 0 else 0)
    row_bands = _find_occupied_bands(alpha_mask, "rows")
    if len(row_bands) != len(actions):
        raise ValueError(
            f"{input_path} contains {len(row_bands)} occupied rows, "
            f"but {len(actions)} actions were supplied."
        )

    frame_count = 0
    for action, (top, bottom) in zip(actions, row_bands, strict=True):
        row_mask = alpha_mask.crop((0, top, sheet.width, bottom + 1))
        column_bands = _find_occupied_bands(row_mask, "columns")
        if len(column_bands) != columns:
            raise ValueError(
                f"{input_path} action {action} contains {len(column_bands)} "
                f"occupied columns, expected {columns}."
            )

        action_dir = output_root / action
        action_dir.mkdir(parents=True, exist_ok=True)
        for index, (left, right) in enumerate(column_bands):
            frame = sheet.crop((left, top, right + 1, bottom + 1))
            normalized = _normalize_frame(
                frame,
                canvas_size=canvas_size,
                subject_size=subject_size,
                bottom_padding=bottom_padding,
            )
            normalized.save(action_dir / f"frame-{index:02d}.png")
            frame_count += 1
    return frame_count


def _size(value: str) -> tuple[int, int]:
    width, height = value.lower().split("x", 1)
    return int(width), int(height)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Split a transparent action sheet by occupied pixel bands."
    )
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output-root", type=Path, required=True)
    parser.add_argument("--actions", nargs="+", required=True)
    parser.add_argument("--columns", type=int, default=5)
    parser.add_argument("--canvas-size", type=_size, default=(512, 768))
    parser.add_argument("--subject-size", type=_size, default=(460, 700))
    parser.add_argument("--bottom-padding", type=int, default=16)
    args = parser.parse_args()

    count = split_sheet(
        input_path=args.input,
        output_root=args.output_root,
        actions=args.actions,
        columns=args.columns,
        canvas_size=args.canvas_size,
        subject_size=args.subject_size,
        bottom_padding=args.bottom_padding,
    )
    print(f"Wrote {count} frames from {args.input}.")


if __name__ == "__main__":
    main()
