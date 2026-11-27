extends SceneTree
const C = preload("res://experimental/hyper/career.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var path: String = "user://hyper_qa_recovery.bin"
	for name in [path,path+".bak",path+".tmp"]:
		if FileAccess.file_exists(name): DirAccess.remove_absolute(ProjectSettings.globalize_path(name))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/season_2012.json"))
	var c = C.new(path)
	var ok: bool = c.create("Ferrari",2026,data)
	var before: Dictionary = c.state.duplicate(true)
	ok = ok and c.start_project("Asa","durabilidade").begins_with("Projeto")
	var file := FileAccess.open(path,FileAccess.WRITE); file.store_buffer(PackedByteArray([1,2,3,4,5])); file.close()
	var recovered = C.new(path)
	ok = ok and recovered.recovered_backup and recovered.state==before
	ok = ok and recovered.start_project("Motor","equilibrado").begins_with("Projeto")
	var again = C.new(path)
	ok = ok and not again.recovered_backup and again.state==recovered.state
	print("HYPER_RECOVERY ","PASS" if ok else "FAIL")
	quit(0 if ok else 1)
