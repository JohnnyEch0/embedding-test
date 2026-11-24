class_name DimsHud
extends Label

## Always-visible dimension-mapping readout, top-left.
##
## Pure presentation of DimMap state: text format lives here, the mapping
## itself never does. main.gd binds the DimMap once; from then on this
## label tracks every `changed` emission. Identity wraps are silent
## upstream, so no spurious refreshes arrive.
##
## Layout (anchors, offsets, font color) lives in main.tscn.

var dim_map: DimMap


## Attach to a DimMap and render its current mapping.
func bind(map: DimMap) -> void:
	dim_map = map
	dim_map.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var v := dim_map.axes_vector()
	text = "dims  X:%d  Y:%d  Z:%d  (of %d)" % [v.x, v.y, v.z, dim_map.dim_count]
