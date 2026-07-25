# 日终送验 · 图 3 落地 Design QA

## Comparison Target

- Source visual truth: `/Users/amin/.codex/generated_images/019f9426-aa65-73b2-a188-d8828803436c/call_ZKGWzvSA4Zn78Z52hqqon4XM.png`
- Rendered implementation: `/tmp/formocracy-batch-validation.png`
- Normalized source: `/Users/amin/formocracy/tmp/design-qa/batch-validation-source.png`
- Normalized implementation: `/Users/amin/formocracy/tmp/design-qa/batch-validation-implementation.png`
- Side-by-side evidence: `/Users/amin/formocracy/tmp/design-qa/batch-validation-source-vs-implementation.png`
- Logical viewport: `1280 × 720`
- Source pixels: `1672 × 941`
- Implementation capture pixels: `3420 × 2146`
- Density normalization: both artifacts were resized to the scene's `1280 × 720` logical design canvas before comparison; device scale factor is not applicable to the Godot render.
- State: five stamped archives are eligible, two are selected in the waiting zone, confirmation is enabled, ingestion has not started.

## Full-view Comparison

The normalized side-by-side image verifies the same state and composition. The implementation now follows the selected direction's physical reading order: numbered desk positions → waiting tray → short conveyor → machine intake. Documents, rather than overlay panels, are the main interactive objects.

The implementation intentionally keeps the project's approved split machine, rail, and envelope assets instead of reproducing the generated concept's painted versions. Their proportions differ slightly, but their placement and hierarchy preserve the selected composition.

## Focused-region Comparison

A separate crop was not required. The original-resolution implementation capture was inspected alongside the full normalized comparison, and the only dense areas—the waiting tray, wall counter, clipboard, and action controls—remain legible at the logical viewport.

## Required Fidelity Surfaces

- Fonts and typography: existing project font and pixel-rendered hierarchy are retained. Title, quota, clipboard copy, archive identity, waiting count, and actions have distinct optical weights without overflow.
- Spacing and layout rhythm: the former three floating dashboard regions are removed. The tray, rail, machine, and five numbered slots share a continuous physical axis and no persistent control covers a document slot.
- Colors and visual tokens: dark olive enamel, aged paper, muted brass, amber confirmation, and red selected stamps match the target direction and existing Formocracy assets.
- Image quality and asset fidelity: the desk is a dedicated raster environment asset. Machine, rail, foreground mask, lights, and document bags use approved project textures; no placeholder art is visible.
- Copy and content: the screen uses short operational language: quota, checklist, waiting count, confirm, leave, and contextual machine state. Redundant dashboard prose has been removed.

## Comparison History

### Iteration 1

- Earlier findings: the rail extended through the waiting tray; clipboard status rendered behind the background; the action controls overlapped the fifth document position; selected archive metadata crowded the central axis.
- Fixes: shortened the three rail segments, raised clipboard text above the environment plate, moved actions to the right-side control area, widened the selected-document spacing, and hid secondary metadata while a bag is in the waiting zone.
- Post-fix evidence: `/Users/amin/formocracy/tmp/design-qa/batch-validation-source-vs-implementation.png`

### Iteration 2

- Earlier findings: slot numbers moved away with selected bags; archive bags were visually underweighted; the clipboard lacked a physical checklist hierarchy.
- Fixes: made numbers permanent desk markings, increased document-bag scale, changed the title to a brass wall plate, and added a compact four-line checklist with dynamic machine state below it.
- Post-fix evidence: `/Users/amin/formocracy/tmp/design-qa/batch-validation-source-vs-implementation.png`

## Findings

No actionable P0, P1, or P2 differences remain.

## Follow-up Polish

- P3: a future dedicated raster texture for the confirm switch could add more mechanical depth than the current themed Godot button, but the existing control is clear, consistent, and fully interactive.

## Interaction Verification

- Selecting a numbered document moves it into the waiting zone without starting the conveyor.
- Clicking the same selected document returns it to its original numbered slot.
- The daily upper limit prevents an extra selection.
- Confirm locks the batch and ingests selected bags sequentially.
- Leave exits without validating unconfirmed selections.
- Unstamped archives remain excluded.

final result: passed
