extends Node

func _ready():
	print("--- Running test_global_utils.gd ---")
	test_get_group_invalid_node()
	test_get_group_node_not_in_tree()
	test_get_group_empty()
	test_get_group_with_members()
	test_has_group()
	print("--- All GlobalUtils tests passed! ---")

	# If running standalone, quit after tests
	if get_tree().current_scene == self or get_parent() == get_tree().root:
		get_tree().quit()

func test_get_group_invalid_node():
	# Test with null
	var result = GlobalUtils.get_group(null, "test_group")
	assert(result == [], "Expected empty array for null context node")

	# Test with freed node
	var freed_node = Node.new()
	freed_node.free()
	result = GlobalUtils.get_group(freed_node, "test_group")
	assert(result == [], "Expected empty array for freed context node")
	print("test_get_group_invalid_node passed.")

func test_get_group_node_not_in_tree():
	var orphan_node = Node.new()
	var result = GlobalUtils.get_group(orphan_node, "test_group")
	assert(result == [], "Expected empty array for node not in tree")
	orphan_node.free()
	print("test_get_group_node_not_in_tree passed.")

func test_get_group_empty():
	var context_node = Node.new()
	add_child(context_node)

	var result = GlobalUtils.get_group(context_node, "non_existent_group")
	assert(result == [], "Expected empty array for non-existent group")

	context_node.queue_free()
	print("test_get_group_empty passed.")

func test_get_group_with_members():
	var context_node = Node.new()
	add_child(context_node)

	var group_member = Node.new()
	group_member.add_to_group("test_group")
	add_child(group_member)

	var result = GlobalUtils.get_group(context_node, "test_group")
	assert(result.size() == 1, "Expected array of size 1")
	assert(result[0] == group_member, "Expected group member to be returned")

	context_node.queue_free()
	group_member.queue_free()
	print("test_get_group_with_members passed.")

func test_has_group():
	var context_node = Node.new()
	add_child(context_node)

	var group_member = Node.new()
	group_member.add_to_group("test_has_group")
	add_child(group_member)

	assert(GlobalUtils.has_group(context_node, "test_has_group") == true, "Expected true for existing group")
	assert(GlobalUtils.has_group(context_node, "non_existent_group") == false, "Expected false for non-existent group")

	context_node.queue_free()
	group_member.queue_free()
	print("test_has_group passed.")
