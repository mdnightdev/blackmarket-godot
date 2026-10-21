class_name Utils

## Safely clears and queue-frees all children of a node.
static func clear_container(container: Node) -> void:
	if container == null:
		return
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
