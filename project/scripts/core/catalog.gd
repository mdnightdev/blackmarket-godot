class_name Catalog
extends RefCounted


## Exported builds convert text resources and leave "<name>.tres.remap" stubs,
## so the suffix is stripped before loading.
static func load_folder(folder_path: String) -> Array[Resource]:
	var resources: Array[Resource] = []
	var dir := DirAccess.open(folder_path)
	if dir == null:
		push_error("Catalog folder missing: %s" % folder_path)
		return resources

	var file_names := dir.get_files()
	file_names.sort()
	for file_name in file_names:
		var resource_name := file_name.trim_suffix(".remap")
		if not (resource_name.ends_with(".tres") or resource_name.ends_with(".res")):
			continue
		var resource := load(folder_path.path_join(resource_name))
		if resource == null:
			push_error("Catalog resource failed to load: %s" % resource_name)
			continue
		resources.append(resource)
	return resources


static func index_by_id(resources: Array[Resource]) -> Dictionary:
	var index := {}
	for resource in resources:
		var id: StringName = resource.get("id")
		if id.is_empty():
			push_error("Catalog resource has no id: %s" % resource.resource_path)
			continue
		if index.has(id):
			push_error("Duplicate catalog id: %s" % id)
			continue
		index[id] = resource
	return index
