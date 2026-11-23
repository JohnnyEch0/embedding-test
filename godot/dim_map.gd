class_name DimMap
extends RefCounted

## Pure state for the X/Y/Z embedding-dimension mapping.
##
## Owns which embedding dimension index is displayed on each spatial axis.
## Knows nothing about scenes, meshes or input -- main.gd feeds it keypresses,
## spheres.gd consumes its mapping. This keeps the switching logic headless-
## testable (see test_dim_map.gd).
##
## Two switching modes:
##   advance_window()  -- the "one key" operation: shifts ALL axes by +/-3,
##                        i.e. jumps to the next/previous trio of dimensions.
##                        A pure translation mod dim_count, so it preserves
##                        whatever distinctness the mapping already had.
##   advance_axis()    -- fine control: steps ONE axis to the next dimension,
##                        skipping dimensions held by the other axes while
##                        enforce_distinct is on (wraps around dim_count).
##                        If no distinct slot exists (dim_count <= 3 with a
##                        distinct mapping), it degrades to a plain step and
##                        accepts a duplicate rather than deadlocking.
##
## Both emit `changed` exactly once per call; readers never emit.

signal changed

const AXES: Array[StringName] = [&"x", &"y", &"z"]

var dim_count: int          # total embedding dimensions; clamped to >= 1
var enforce_distinct: bool  # true: no dimension on two axes (where possible)

var _dims := {&"x": 0, &"y": 1, &"z": 2}


func _init(count: int, distinct := true) -> void:
	dim_count = maxi(1, count)
	enforce_distinct = distinct
	# collapse axes for degenerate counts (d=2 -> 0/1/1, d=1 -> 0/0/0)
	_dims = {&"x": 0, &"y": mini(1, dim_count - 1), &"z": mini(2, dim_count - 1)}


## Dimension index currently shown on the given axis (&"x"/&"y"/&"z").
func get_dim(axis: StringName) -> int:
	return _dims.get(axis, 0)


## Copy of the mapping, e.g. {&"x": 3, &"y": 4, &"z": 5}.
func mapping() -> Dictionary:
	return _dims.duplicate()


## The mapping packed for direct use as a position index triple.
func axes_vector() -> Vector3i:
	return Vector3i(_dims[&"x"], _dims[&"y"], _dims[&"z"])


## Jump to the next/previous trio of dimensions (dir: +1/-1).
func advance_window(dir := 1) -> void:
	for axis in AXES:
		_dims[axis] = posmod(_dims[axis] + 3 * dir, dim_count)
	changed.emit()


## Step one axis to the next/previous dimension (dir: +1/-1), skipping
## dimensions held by the other axes while enforce_distinct is on.
## Unknown axis names are a warned no-op.
func advance_axis(axis: StringName, dir := 1) -> void:
	if not _dims.has(axis):
		push_warning("DimMap.advance_axis: unknown axis %s" % axis)
		return
	var cur: int = _dims[axis]
	var taken := {}
	if enforce_distinct:
		for other in AXES:
			if other != axis:
				taken[_dims[other]] = true
	for i in range(1, dim_count + 1):
		var candidate := posmod(cur + dir * i, dim_count)
		if candidate != cur and not taken.has(candidate):
			_dims[axis] = candidate
			changed.emit()
			return
	# no distinct slot anywhere: degrade to a plain step (duplicate axis).
	_dims[axis] = posmod(cur + dir, dim_count)
	changed.emit()
