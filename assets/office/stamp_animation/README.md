# Stamp contact animation assets

The approval and rejection stamp sets each contain four transparent PNG
keyframes for a right-handed diagonal stamping motion. They are visual assets
only; no gameplay or animation logic is included here.

## Frame order

| Frame | Pose | Intended moment |
| --- | --- | --- |
| `00_tilted_entry.png` | Raised at roughly 38°, rubber face visible | Enters from the upper right |
| `01_diagonal_swing.png` | Moving down-left and rotating upright | Main swing |
| `02_aligning.png` | Almost upright, face almost parallel to paper | Final approach |
| `03_pressed_top.png` | Top-down, knob facing upward, face planted | Full contact |

## Asset contract

- Canvas: `384 × 384` pixels
- Format: RGBA PNG
- Anchor: center of the planted face in `03_pressed_top.png`
- Approval shape: circular, warm oxblood identification band
- Rejection shape: square, cool plum-red identification band
- Suggested downstroke: `00 → 01 → 02 → 03`
- The document impression should remain hidden while `03_pressed_top.png` covers
  the contact area, then appear only after a later lift animation.

No shadow is baked into the frames. A future implementation should derive a
shadow from the projected rubber face or omit it; a fixed ellipse will not stay
aligned during the diagonal rotation.
