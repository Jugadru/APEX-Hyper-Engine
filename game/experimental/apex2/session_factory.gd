extends RefCounted
## Single selection point for live race sessions. Core 2 remains a safe rollback.
const Primary = preload("res://experimental/apex2/primary_session.gd")
const CoreReplay = preload("res://scripts/core/race_replay_0660.gd")
const SETTING: String = "apex2/primary_controller"

static func primary_enabled() -> bool:
	return bool(ProjectSettings.get_setting(SETTING, true))

static func create(engine, modes: Dictionary = {}, staff: Dictionary = {}):
	var session = Primary.new() if primary_enabled() else CoreReplay.new()
	session.attach(engine, modes, staff)
	return session

static func runtime_label() -> String:
	return "APEX 2 / CORE 2 física compatível" if primary_enabled() else "CORE 2 / modo seguro"
