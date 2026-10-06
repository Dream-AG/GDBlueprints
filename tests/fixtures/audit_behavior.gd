extends RefCounted

func run(node: Node) -> void:
	node.set_meta("audit_ran", true)
