UV ?= uv
GODOT ?= godot
GDSCRIPT_PATHS := RealityBridge.gd scripts tests
TEST_SCRIPTS := \
	tests/workbench_manager_boundary_test.gd \
	tests/workday_manager_boundary_test.gd \
	tests/save_module_boundary_test.gd \
	tests/core_gameplay_test.gd \
	tests/smoke_test.gd \
	tests/config_level_test.gd \
	tests/archive_backlog_test.gd \
	tests/save_backup_recovery_test.gd \
	tests/save_tree_migration_test.gd \
	tests/save_resume_flow_test.gd

.PHONY: setup lint format format-check typecheck test quality animation-lab

setup:
	$(UV) sync --dev

lint:
	$(UV) run gdlint $(GDSCRIPT_PATHS)

format:
	$(UV) run gdformat $(GDSCRIPT_PATHS)

format-check:
	$(UV) run gdformat --check $(GDSCRIPT_PATHS)

typecheck:
	@lint_output="$$(mktemp)"; runtime_output="$$(mktemp)"; workbench_output="$$(mktemp)"; \
	trap 'rm -f "$$lint_output" "$$runtime_output" "$$workbench_output"' EXIT; \
	$(GODOT) --headless --path . --editor --quit 2>&1 | tee "$$lint_output"; \
	! grep -Eq 'SCRIPT ERROR:|ERROR: Failed to (load script|create an autoload)' "$$lint_output"; \
	$(GODOT) --headless --path . --quit-after 10 2>&1 | tee "$$runtime_output"; \
	! grep -Eq 'SCRIPT ERROR:|ERROR: Failed to load script|Invalid call' "$$runtime_output"; \
	$(GODOT) --headless --path . main.tscn --quit-after 10 2>&1 | tee "$$workbench_output"; \
	! grep -Eq 'SCRIPT ERROR:|ERROR: Failed to load script|Invalid call' "$$workbench_output"

test:
	@for test_script in $(TEST_SCRIPTS); do \
		test_output="$$(mktemp)"; \
		echo "Running $$test_script"; \
		$(GODOT) --headless --path . --script "$$test_script" 2>&1 | tee "$$test_output"; \
		! grep -Eq 'SCRIPT ERROR:|ERROR: Failed to load script|Invalid call|Assertion failed' "$$test_output" || { rm -f "$$test_output"; exit 1; }; \
		grep -Eq '^FORMOCRACY_.*_OK$$' "$$test_output" || { rm -f "$$test_output"; exit 1; }; \
		rm -f "$$test_output"; \
	done

quality: format-check lint typecheck test

animation-lab:
	@if curl --fail --silent "http://127.0.0.1:4173/tools/npc-animation-lab/" >/dev/null 2>&1; then \
		echo "NPC animation lab is already running:"; \
		echo "http://127.0.0.1:4173/tools/npc-animation-lab/"; \
	else \
		echo "NPC animation lab: http://127.0.0.1:4173/tools/npc-animation-lab/"; \
		python3 -m http.server 4173 --bind 127.0.0.1; \
	fi
