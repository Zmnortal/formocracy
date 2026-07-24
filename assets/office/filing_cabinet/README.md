# Interactive Filing Cabinet Assets

Replacement-ready art for the filing cabinet on the left side of the main game screen.

## Interaction model

- Upper drawer: the government reference handbook.
  - Teaches the player the current rules, controls, procedures, and world background.
  - The handbook is removable so it can later open as a separate reading interface.
- Lower drawer: the player's private evidence drawer.
  - Holds photographs, letters, tickets, ration coupons, keys, and suspicious documents.
  - This is intentionally different from the existing daily archive tray: the tray resolves the day's work, while this drawer preserves discoveries across days.

## Cabinet states

All state images use a `512 x 640` transparent canvas and share a bottom-center anchor.

- `states/00_closed.png`
- `states/01_upper_half_open.png`
- `states/02_upper_open_handbook.png`
- `states/03_lower_half_open.png`
- `states/04_lower_open_evidence.png`

The half-open states are transition/hover frames. The fully open states are stable interaction targets.

## Removable contents

All content images use a `512 x 384` transparent canvas.

- `contents/reference_handbook_closed.png`
- `contents/reference_handbook_open.png`
- `contents/private_evidence_dossier.png`
- `contents/loose_clue_set.png`

## Integration target

The current static cabinet is instantiated by `scripts/gameplay/desk_builder.gd` from:

`res://assets/office/items/filing_cabinet.png`

For an asset-only visual swap, use `states/00_closed.png`. A later interaction pass can switch the cabinet texture through the five states and spawn the appropriate removable content.

No gameplay logic is included in this asset set.
