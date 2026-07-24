# GDScript quality

This project treats GDScript checks like the strict TypeScript quality gate in
`beat-pony`:

- Godot's untyped and unsafe GDScript warnings are compile errors.
- `gdlint` enforces naming, complexity, ordering, and structural limits.
- `gdformat` owns formatting, with the same 200-column width as `beat-pony`.
- The toolchain is pinned in `pyproject.toml` and `uv.lock`.

## Commands

Install the pinned development tools:

```sh
make setup
```

Run individual checks:

```sh
make lint
make format-check
make typecheck
```

Run the complete quality gate:

```sh
make quality
```

Apply formatting:

```sh
make format
```

Use typed inference when the type is obvious:

```gdscript
var health := 100
var player := get_node("Player") as CharacterBody2D
```

Use an explicit type at API and data boundaries:

```gdscript
func take_damage(amount: int) -> void:
	health -= amount
```

Do not suppress a warning globally to make the quality gate pass. A local
`@warning_ignore(...)` is acceptable only when the unsafe behavior is
intentional and the reason is documented next to it.
