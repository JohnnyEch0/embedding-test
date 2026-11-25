class_name StarSettings
extends RefCounted

## Model for the star/light tuning settings used by the dev console.
##
## Pure state, no scene refs (like DimMap — headless-testable): a registry
## of tunable settings, their defaults, and the current values. The console
## (dev_console.gd) harvests defaults from the live scene at startup and
## applies values back onto nodes whenever `changed` fires.
##
## Values change via set_value() (typed) or set_from_string() (console
## text, incl. relative float adjusts). Unknown keys, wrong types, and
## unparseable values are rejected; `changed` fires only on success.

enum Type { FLOAT, INT, BOOL, COLOR, ENUM }

## Custom error code: unknown setting key. The subset of the engine's
## Error enum exposed to GDScript in this Godot version does not include
## ERR_ITEM_NOT_FOUND, so StarSettings defines its own for that case.
const ERR_UNKNOWN_KEY: Error = 10001

signal changed(key: StringName)

## Registry entry fields: key (StringName), group (StringName), type (Type),
## default (Variant), min/max (float, numeric types only), options
## (Array[String], ENUM only), help (String), restart_required (bool).
##
## Defaults mirror the currently committed scene values (emb_star.tscn /
## main.tscn / engine defaults). The console harvests live values at
## startup, so `reset all` stays "the scene's committed look" even after
## the scenes have changed.
const REGISTRY: Array[Dictionary] = [
	# --- star mesh (uniform for all stars) ---
	{"key": &"star_emission_energy", "group": &"star", "type": Type.FLOAT,
		"default": 1.0, "min": 0.0, "max": 32.0,
		"help": "emission_energy_multiplier of the star material — the HDR glow source (4-8 is a good star range)",
		"restart_required": false},
	{"key": &"star_unshaded", "group": &"star", "type": Type.BOOL,
		"default": false,
		"help": "material shading_mode Unshaded: stars ignore scene lighting entirely",
		"restart_required": false},
	{"key": &"star_size_scale", "group": &"star", "type": Type.FLOAT,
		"default": 1.0, "min": 0.1, "max": 10.0,
		"help": "multiplies every star's scale (incl. line/verse/poem scale); grows sub-pixel stars",
		"restart_required": false},
	{"key": &"star_visibility_range_end", "group": &"star", "type": Type.FLOAT,
		"default": 0.0, "min": 0.0, "max": 100000.0,
		"help": "visibility_range_end on the star mesh; 0 = off",
		"restart_required": false},
	# --- per-star OmniLight3D ---
	{"key": &"star_lights_enabled", "group": &"star", "type": Type.BOOL,
		"default": true,
		"help": "master switch for the per-star OmniLight3D nodes (false = emissive-only look)",
		"restart_required": false},
	{"key": &"light_energy", "group": &"star", "type": Type.FLOAT,
		"default": 100.0, "min": 0.0, "max": 1000.0,
		"help": "brightness on lit surfaces (default 2-5 for a 50-500 range; 100 is the scene's current overbright value)",
		"restart_required": false},
	{"key": &"light_color", "group": &"star", "type": Type.COLOR,
		"default": Color.WHITE,
		"help": "star color temperature; #rrggbb or Color(r, g, b[, a])",
		"restart_required": false},
	{"key": &"omni_range", "group": &"star", "type": Type.FLOAT,
		"default": 100000.0, "min": 0.0, "max": 200000.0,
		"help": "hard cutoff radius — the light has zero effect beyond this (50-500 typical)",
		"restart_required": false},
	{"key": &"omni_attenuation", "group": &"star", "type": Type.FLOAT,
		"default": 2.0, "min": 0.0, "max": 5.0,
		"help": "falloff curve: 0 = linear, 1 = default, ~2 = inverse-square (steeper = shorter reach)",
		"restart_required": false},
	{"key": &"light_specular", "group": &"star", "type": Type.FLOAT,
		"default": 0.5, "min": 0.0, "max": 1.0,
		"help": "specular contribution; 0 for a soft look",
		"restart_required": false},
	{"key": &"light_indirect_energy", "group": &"star", "type": Type.FLOAT,
		"default": 1.0, "min": 0.0, "max": 10.0,
		"help": "indirect (GI) contribution; minor tuning",
		"restart_required": false},
	{"key": &"shadow_enabled", "group": &"star", "type": Type.BOOL,
		"default": false,
		"help": "per-star shadows; off for most stars (costly)",
		"restart_required": false},
	{"key": &"distance_fade_enabled", "group": &"star", "type": Type.BOOL,
		"default": false,
		"help": "auto-disable lights far from the camera (use with many stars)",
		"restart_required": false},
	{"key": &"distance_fade_begin", "group": &"star", "type": Type.FLOAT,
		"default": 40.0, "min": 0.0, "max": 200000.0,
		"help": "camera distance where light fading starts (~1/2 omni_range)",
		"restart_required": false},
	{"key": &"distance_fade_length", "group": &"star", "type": Type.FLOAT,
		"default": 10.0, "min": 0.0, "max": 200000.0,
		"help": "distance over which the light fades out (~1/3 of begin)",
		"restart_required": false},
	# --- WorldEnvironment ---
	{"key": &"glow_enabled", "group": &"env", "type": Type.BOOL,
		"default": false,
		"help": "the star halo — emissive meshes need glow to read as stars from afar",
		"restart_required": false},
	{"key": &"glow_intensity", "group": &"env", "type": Type.FLOAT,
		"default": 0.4, "min": 0.0, "max": 10.0,
		"help": "overall glow intensity (~0.8 is a good start)",
		"restart_required": false},
	{"key": &"glow_strength", "group": &"env", "type": Type.FLOAT,
		"default": 1.0, "min": 0.0, "max": 10.0,
		"help": "how far the glow spreads from the source",
		"restart_required": false},
	{"key": &"glow_bloom", "group": &"env", "type": Type.FLOAT,
		"default": 0.0, "min": 0.0, "max": 1.0,
		"help": "soft bloom around bright areas (~0.1)",
		"restart_required": false},
	{"key": &"glow_hdr_threshold", "group": &"env", "type": Type.FLOAT,
		"default": 1.0, "min": 0.0, "max": 10.0,
		"help": "luminance that must be exceeded to glow (0.8-1.0 lets HDR emission through)",
		"restart_required": false},
	{"key": &"glow_blend_mode", "group": &"env", "type": Type.ENUM,
		"default": "screen",
		"options": ["additive", "screen", "softlight", "replace"],
		"help": "how glow composites over the image",
		"restart_required": false},
	{"key": &"background_energy", "group": &"env", "type": Type.FLOAT,
		"default": 8.23, "min": 0.0, "max": 100.0,
		"help": "sky shader background brightness (the noisy starfield backdrop)",
		"restart_required": false},
	{"key": &"volumetric_fog_enabled", "group": &"env", "type": Type.BOOL,
		"default": true,
		"help": "volumetric fog on/off (it scatters the star lights into haze)",
		"restart_required": false},
	{"key": &"volumetric_fog_density", "group": &"env", "type": Type.FLOAT,
		"default": 0.01, "min": 0.0, "max": 1.0,
		"help": "fog density; lower = crisper stars",
		"restart_required": false},
	# --- Camera3D ---
	{"key": &"camera_far", "group": &"camera", "type": Type.FLOAT,
		"default": 4000.0, "min": 1.0, "max": 10000000.0,
		"help": "far plane — must exceed the distance to the stars (engine default 4000; beware float precision at huge values)",
		"restart_required": false},
	{"key": &"camera_near", "group": &"camera", "type": Type.FLOAT,
		"default": 0.05, "min": 0.001, "max": 100.0,
		"help": "near plane; raise as far grows to keep depth precision",
		"restart_required": false},
	{"key": &"camera_fov", "group": &"camera", "type": Type.FLOAT,
		"default": 75.0, "min": 10.0, "max": 170.0,
		"help": "vertical field of view in degrees",
		"restart_required": false},
	# --- project setting (needs a restart) ---
	{"key": &"max_clustered_elements", "group": &"project", "type": Type.INT,
		"default": 512, "min": 1, "max": 1000000,
		"help": "Forward+ clustered element cap; only needed with many real lights. In-memory only: edit project.godot [rendering] and restart to make it stick",
		"restart_required": true},
]

## Listable groups (for `list <group>`).
const GROUPS: Array[StringName] = [&"star", &"env", &"camera", &"project"]

var _entries: Dictionary = {} # key -> registry entry
var _defaults: Dictionary = {} # key -> default value
var _values: Dictionary = {} # key -> current value


## harvested: key -> value, pulled from the live scene at console startup.
## Overrides both default and current for the given keys.
func _init(harvested: Dictionary = {}) -> void:
	for entry: Dictionary in REGISTRY:
		var key: StringName = entry.key
		_entries[key] = entry
		var default_value: Variant = entry.default
		if harvested.has(key):
			default_value = harvested[key]
		_defaults[key] = default_value
		_values[key] = default_value


## Adopt a value harvested from a live node after init (e.g. the first
## spawned star's light, which does not exist at console startup).
## Sets the default; the current value follows while still unmodified.
func adopt_default(key: StringName, value: Variant) -> void:
	if not _entries.has(key):
		return
	if _values[key] == _defaults[key]:
		_values[key] = value
	_defaults[key] = value


func has_key(key: StringName) -> bool:
	return _entries.has(key)


func entry(key: StringName) -> Dictionary:
	return _entries[key]


## Current value for a key (null for unknown keys).
func value(key: StringName) -> Variant:
	if not _entries.has(key):
		return null
	return _values[key]


func get_default(key: StringName) -> Variant:
	if not _entries.has(key):
		return null
	return _defaults[key]


func is_modified(key: StringName) -> bool:
	if not _entries.has(key):
		return false
	return _values[key] != _defaults[key]


## All keys, optionally filtered by key-name prefix.
func keys(prefix := "") -> Array[StringName]:
	var out: Array[StringName] = []
	for key in _entries:
		if prefix.is_empty() or str(key).begins_with(prefix):
			out.append(key)
	return out


func keys_in_group(group: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for key in _entries:
		if _entries[key].group == group:
			out.append(key)
	return out


## Set a typed value. Clamps numeric values to [min, max].
## Returns OK, or ERR_UNKNOWN_KEY / Error.ERR_INVALID_PARAMETER.
func set_value(key: StringName, value: Variant) -> Error:
	if not _entries.has(key):
		return ERR_UNKNOWN_KEY
	var e: Dictionary = _entries[key]
	var v: Variant = value
	match e.type:
		Type.FLOAT:
			if typeof(v) not in [TYPE_FLOAT, TYPE_INT]:
				return Error.ERR_INVALID_PARAMETER
			v = clampf(float(v), e.min, e.max)
		Type.INT:
			if typeof(v) not in [TYPE_INT, TYPE_FLOAT]:
				return Error.ERR_INVALID_PARAMETER
			v = clampi(int(v), int(e.min), int(e.max))
		Type.BOOL:
			if typeof(v) != TYPE_BOOL:
				return Error.ERR_INVALID_PARAMETER
		Type.COLOR:
			if not (v is Color):
				return Error.ERR_INVALID_PARAMETER
		Type.ENUM:
			if not e.options.has(v):
				return Error.ERR_INVALID_PARAMETER
	_values[key] = v
	changed.emit(key)
	return OK


## Set from console text. relative=true is only for floats and requires an
## explicit + or - sign. Returns OK, or ERR_UNKNOWN_KEY /
## Error.ERR_INVALID_PARAMETER / Error.ERR_UNAVAILABLE.
func set_from_string(key: StringName, text: String, relative := false) -> Error:
	if not _entries.has(key):
		return ERR_UNKNOWN_KEY
	var e: Dictionary = _entries[key]
	var value: Variant
	match e.type:
		Type.FLOAT:
			if not text.strip_edges().is_valid_float():
				return Error.ERR_INVALID_PARAMETER
			var v := float(text.strip_edges())
			if relative:
				if not text.strip_edges().begins_with("+") and not text.strip_edges().begins_with("-"):
					return Error.ERR_INVALID_PARAMETER
				v += float(_values[key])
			value = v
		Type.INT:
			if relative:
				return Error.ERR_UNAVAILABLE
			if not text.strip_edges().is_valid_int():
				return Error.ERR_INVALID_PARAMETER
			value = int(text.strip_edges())
		Type.BOOL:
			if relative:
				return Error.ERR_UNAVAILABLE
			value = _parse_bool(text)
			if value == null:
				return Error.ERR_INVALID_PARAMETER
		Type.COLOR:
			if relative:
				return Error.ERR_UNAVAILABLE
			value = _parse_color(text)
			if value == null:
				return Error.ERR_INVALID_PARAMETER
		Type.ENUM:
			if relative:
				return Error.ERR_UNAVAILABLE
			var name := text.strip_edges().to_lower()
			if not e.options.has(name):
				return Error.ERR_INVALID_PARAMETER
			value = name
	return set_value(key, value)


func reset(key: StringName) -> Error:
	if not _entries.has(key):
		return ERR_UNKNOWN_KEY
	_values[key] = _defaults[key]
	changed.emit(key)
	return OK


func reset_all() -> void:
	for key in _values:
		reset(key)


## Current values as a JSON-friendly dict (colors as hex strings).
func to_dict() -> Dictionary:
	var out := {}
	for key in _values:
		var v: Variant = _values[key]
		if v is Color:
			out[key] = "#" + v.to_html(v.a < 1.0)
		else:
			out[key] = v
	return out


static func type_name(t: int) -> String:
	match t:
		Type.FLOAT: return "float"
		Type.INT: return "int"
		Type.BOOL: return "bool"
		Type.COLOR: return "color"
		Type.ENUM: return "enum"
	return "?"


# ---------------------------------------------------------------------------
# parsing
# ---------------------------------------------------------------------------

func _parse_bool(text: String) -> Variant:
	var t := text.strip_edges().to_lower()
	if t in ["true", "1", "on", "yes"]:
		return true
	if t in ["false", "0", "off", "no"]:
		return false
	return null


func _parse_color(text: String) -> Variant:
	var t := text.strip_edges()
	if t.begins_with("#"):
		var hex := t.substr(1)
		if hex.length() not in [6, 8]:
			return null
		var r: Variant = _hex_pair(hex, 0)
		var g: Variant = _hex_pair(hex, 2)
		var b: Variant = _hex_pair(hex, 4)
		var a: Variant = 255
		if hex.length() == 8:
			a = _hex_pair(hex, 6)
		if r == null or g == null or b == null or a == null:
			return null
		return Color8(r, g, b, a)
	if t.begins_with("Color(") and t.ends_with(")"):
		var parts: PackedStringArray = t.substr(6, t.length() - 7).split(",")
		if parts.size() not in [3, 4]:
			return null
		var r: Variant = _parse_color_component(parts[0])
		var g: Variant = _parse_color_component(parts[1])
		var b: Variant = _parse_color_component(parts[2])
		if r == null or g == null or b == null:
			return null
		if parts.size() == 3:
			return Color(r, g, b, 1.0)
		var a: Variant = _parse_color_component(parts[3])
		if a == null:
			return null
		return Color(r, g, b, a)
	return null


func _parse_color_component(text: String) -> Variant:
	var t := text.strip_edges()
	if not t.is_valid_float():
		return null
	return float(t)


const _HEX_DIGITS := "0123456789abcdef"


## Two hex chars at offset -> 0-255, or null if not valid hex.
func _hex_pair(hex: String, offset: int) -> Variant:
	var hi := _HEX_DIGITS.find(hex[offset].to_lower())
	var lo := _HEX_DIGITS.find(hex[offset + 1].to_lower())
	if hi < 0 or lo < 0:
		return null
	return hi * 16 + lo
