extends Control

const HEADER_PAYLOAD_PATH := "res://find_me.png"
const SIGNATURE := "RAT"

var buffer: PackedByteArray

func preload_header():
	var file := FileAccess.open(HEADER_PAYLOAD_PATH, FileAccess.READ)
	buffer = file.get_buffer(file.get_length())
	file.close()

func is_encoded(contents: PackedByteArray) -> bool:
	if contents.size() > buffer.size():
		var signature := contents.slice(buffer.size(), buffer.size() + 3).get_string_from_utf8()
		return signature == SIGNATURE
	return false

## Read the raw contents
func open_contents(file: String) -> PackedByteArray:
	var handle := FileAccess.open(file, FileAccess.READ)
	var buffer := handle.get_buffer(handle.get_length())
	handle.close()
	return buffer

@onready var fade_timer := Timer.new()

func display_warning():
	fade_timer.start(5)
	$Panel/Label2.show()

func _hide_error():
	$Panel/Label2.hide()

func encode_file(path: String, file: FileAccess, contents: PackedByteArray):
	file.store_buffer(buffer)
	file.store_string(SIGNATURE)
	file.store_pascal_string(path)
	file.store_64(contents.size())
	file.store_buffer(contents)

class DecodeResult:
	var original_name: String
	var original_contents: PackedByteArray

func decode_file(file: FileAccess) -> DecodeResult:
	var result := DecodeResult.new()
	file.seek(buffer.size())
	var sig := file.get_buffer(3).get_string_from_utf8()
	assert(sig == SIGNATURE, "Failed to check signature! Wrong file handle to decode!")
	result.original_name = file.get_pascal_string()
	var size := file.get_64()
	print("Reading ", size, " bytes from '", result.original_name, "'...")
	result.original_contents = file.get_buffer(size)
	return result

@onready var file_dialog := $FileDialog

func _handle_incoming_files(files: Array[String]):
	if files.size() > 1:
		print("Can't load more than one file at a time.")
		return display_warning()
	var file := files[0]
	var contents := open_contents(file)
	if is_encoded(contents):
		var decoded := decode_file(FileAccess.open(file, FileAccess.READ))
		file_dialog.current_file = decoded.original_name
		file_dialog.filters = []
		file_dialog.file_selected.connect(func(path: String):
			var out := FileAccess.open(path, FileAccess.WRITE)
			out.store_buffer(decoded.original_contents)
			out.close(),
			CONNECT_DEFERRED|CONNECT_ONE_SHOT)
		file_dialog.show()
	else:
		print("Encoding '", file, "'...")
		file_dialog.filters = ["*.png"]
		file_dialog.current_path = str(file, ".enc.png")
		file_dialog.file_selected.connect(func(path: String):
			var out := FileAccess.open(path, FileAccess.WRITE)
			encode_file(file, out, contents)
			out.close(),
			CONNECT_DEFERRED|CONNECT_ONE_SHOT)
		file_dialog.show()

func _ready() -> void:
	var window := get_window()
	window.files_dropped.connect(_handle_incoming_files)
	preload_header()
	add_child(fade_timer)
	fade_timer.timeout.connect(_hide_error)
