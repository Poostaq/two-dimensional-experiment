class_name WorldExitAdapter
extends RefCounted

var requested_status: int = -1
var request_count: int = 0
var terminate_process: bool = true


func request_exit(tree: SceneTree, status: int = 0) -> void:
    requested_status = status
    request_count += 1
    if terminate_process:
        tree.quit(status)
