class_name DisplayAdapter
extends RefCounted

const FULLSCREEN_MODE: int = 1


func set_window_mode(mode: int) -> void:
    var server_mode := (
        DisplayServer.WINDOW_MODE_FULLSCREEN
        if mode == FULLSCREEN_MODE
        else DisplayServer.WINDOW_MODE_WINDOWED
    )
    DisplayServer.window_set_mode(server_mode)


func set_window_size(size: Vector2i) -> void:
    DisplayServer.window_set_size(size)
