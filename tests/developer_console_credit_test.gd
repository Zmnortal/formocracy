extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state := root.get_node("WorkdayState")
	state.reset_for_tests()
	var console = load("res://scripts/autoload/developer_console.gd").new()
	root.add_child(console)
	await process_frame

	console.toggle_console()
	assert(console.credit_selector != null, "developer console must expose political credit controls")
	console.credit_selector.value = 25
	console.set_credit_from_selector()
	assert(state.political_credit == 25, "credit selector must set political credit")
	console.adjust_credit(-10)
	assert(state.political_credit == 15, "credit shortcuts must adjust political credit")
	console.execute_command("credit add 7")
	assert(state.political_credit == 22, "credit command must add political credit")
	console.execute_command("credit set -3")
	assert(state.political_credit == -3, "credit command must set political credit")
	assert(console.status_label.text.contains("Credit：-3"), "credit changes must refresh status")

	print("FORMOCRACY_DEVELOPER_CONSOLE_CREDIT_TEST_OK")
	quit(0)
