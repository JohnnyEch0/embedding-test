extends SceneTree

## Headless unit test for StarSettings (res://star_settings.gd).
##
## Run from the godot/ project directory:
##     godot --headless -s test_star_settings.gd
##
## Exit code 0 = all checks pass, 1 = at least one failure.
## StarSettings is a pure RefCounted model (like DimMap), so no scene tree
## is needed: the registry, defaults/harvesting, set/reset, parsing,
## clamping, relative adjusts, and the changed signal are all covered.

const StarSettingsScript := preload("res://star_settings.gd")

var _checks := 0
var _failures := 0


const EXPECTED_KEYS: Array[StringName] = [
	&"star_emission_energy", &"star_unshaded", &"star_size_scale",
	&"star_visibility_range_end",
	&"star_lights_enabled", &"light_energy", &"light_color", &"omni_range",
	&"omni_attenuation", &"light_specular", &"light_indirect_energy",
	&"shadow_enabled", &"distance_fade_enabled", &"distance_fade_begin",
	&"distance_fade_length",
	&"glow_enabled", &"glow_intensity", &"glow_strength", &"glow_bloom",
	&"glow_hdr_threshold", &"glow_blend_mode", &"background_energy",
	&"volumetric_fog_enabled", &"volumetric_fog_density",
	&"camera_far", &"camera_near", &"camera_fov", &"max_clustered_elements",
]


func _init() -> void:
	_test_registry()
	_test_defaults()
	_test_harvest_and_adopt()
	_test_set_get_roundtrip()
	_test_clamping()
	_test_type_rejection()
	_test_unknown_keys()
	_test_relative_adjusts()
	_test_parsing()
	_test_reset()
	_test_changed_signal()
	_test_to_dict()
	_test_keys_and_groups()
	print("%d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

func _expect(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: " + msg)


func _settings(harvested: Dictionary = {}) -> RefCounted:
	return StarSettingsScript.new(harvested)


# ---------------------------------------------------------------------------
# tests
# ---------------------------------------------------------------------------

func _test_registry() -> void:
	var s := _settings()
	_expect(s.keys().size() == EXPECTED_KEYS.size(),
		"registry has %d keys, expected %d" % [s.keys().size(), EXPECTED_KEYS.size()])
	for key in EXPECTED_KEYS:
		_expect(s.has_key(key), "missing registry key: %s" % key)
	# every entry carries its required fields
	for key in s.keys():
		var e: Dictionary = s.entry(key)
		var ok: bool = e.has("group") and e.has("type") and e.has("help") \
			and e.has("default") and e.has("restart_required")
		_expect(ok, "entry %s missing required fields" % key)


func _test_defaults() -> void:
	var s := _settings()
	_expect(s.value(&"light_energy") == 100.0, "light_energy default 100")
	_expect(s.value(&"omni_range") == 100000.0, "omni_range default 100000")
	_expect(s.value(&"camera_far") == 4000.0, "camera_far default 4000")
	_expect(s.value(&"camera_near") == 0.05, "camera_near default 0.05")
	_expect(s.value(&"glow_blend_mode") == "screen", "glow_blend_mode default screen")
	_expect(s.value(&"background_energy") == 8.23, "background_energy default 8.23")
	_expect(s.value(&"star_emission_energy") == 1.0, "star_emission_energy default 1.0")
	_expect(not s.is_modified(&"light_energy"), "unmodified at start")


func _test_harvest_and_adopt() -> void:
	var s := _settings({&"camera_far": 100000.0, &"glow_enabled": true})
	_expect(s.value(&"camera_far") == 100000.0, "harvested camera_far as current")
	_expect(s.get_default(&"camera_far") == 100000.0, "harvested camera_far as default")
	_expect(s.value(&"glow_enabled") == true, "harvested glow_enabled")

	# adopt_default (post-init harvest, e.g. first spawned star's light)
	s.adopt_default(&"light_energy", 77.0)
	_expect(s.value(&"light_energy") == 77.0, "adopt_default updates unmodified current")
	_expect(s.get_default(&"light_energy") == 77.0, "adopt_default updates default")
	_expect(s.set_value(&"light_energy", 5.0) == OK, "set after adopt")
	s.adopt_default(&"light_energy", 99.0)
	_expect(s.value(&"light_energy") == 5.0, "adopt_default does not clobber user value")
	_expect(s.get_default(&"light_energy") == 99.0, "adopt_default still updates default")
	s.adopt_default(&"no_such_key", 1.0) # must not crash


func _test_set_get_roundtrip() -> void:
	var s := _settings()
	_expect(s.set_value(&"light_energy", 42.5) == OK, "float set")
	_expect(s.value(&"light_energy") == 42.5, "float roundtrip")
	_expect(s.set_value(&"glow_blend_mode", "additive") == OK, "enum set")
	_expect(s.value(&"glow_blend_mode") == "additive", "enum roundtrip")
	_expect(s.set_value(&"light_color", Color.MAGENTA) == OK, "color set")
	_expect(s.value(&"light_color") == Color.MAGENTA, "color roundtrip")
	_expect(s.set_value(&"max_clustered_elements", 1024) == OK, "int set")
	_expect(s.value(&"max_clustered_elements") == 1024, "int roundtrip")
	_expect(s.is_modified(&"light_energy"), "modified after set")


func _test_clamping() -> void:
	var s := _settings()
	_expect(s.set_value(&"light_energy", 5000.0) == OK, "clamp returns OK")
	_expect(s.value(&"light_energy") == 1000.0, "clamped to max 1000")
	_expect(s.set_value(&"camera_near", 0.0001) == OK, "near clamp ok")
	_expect(s.value(&"camera_near") == 0.001, "clamped to min 0.001")
	_expect(s.set_value(&"max_clustered_elements", 0) == OK, "int clamp ok")
	_expect(s.value(&"max_clustered_elements") == 1, "int clamped to min 1")
	_expect(s.set_value(&"max_clustered_elements", 2000.9) == OK, "float->int ok")
	_expect(s.value(&"max_clustered_elements") == 2000, "int truncates 2000.9")


func _test_type_rejection() -> void:
	var s := _settings()
	_expect(s.set_value(&"glow_enabled", 1) == Error.ERR_INVALID_PARAMETER, "int is not bool")
	_expect(s.value(&"glow_enabled") == false, "rejected set leaves value")
	_expect(s.set_value(&"light_color", "red") == Error.ERR_INVALID_PARAMETER, "string is not color")
	_expect(s.set_value(&"omni_range", "500") == Error.ERR_INVALID_PARAMETER, "string is not float")
	_expect(s.set_value(&"glow_blend_mode", "bogus") == Error.ERR_INVALID_PARAMETER, "bad enum name")
	_expect(s.set_value(&"star_unshaded", "true") == Error.ERR_INVALID_PARAMETER, "string is not bool")


func _test_unknown_keys() -> void:
	var s := _settings()
	_expect(s.set_value(&"nope", 1.0) == StarSettingsScript.ERR_UNKNOWN_KEY, "set unknown key")
	_expect(s.reset(&"nope") == StarSettingsScript.ERR_UNKNOWN_KEY, "reset unknown key")
	_expect(s.set_from_string(&"nope", "1") == StarSettingsScript.ERR_UNKNOWN_KEY, "parse unknown key")
	_expect(s.value(&"nope") == null, "get unknown key -> null")
	_expect(s.get_default(&"nope") == null, "default unknown key -> null")
	_expect(not s.is_modified(&"nope"), "is_modified unknown key -> false")


func _test_relative_adjusts() -> void:
	var s := _settings()
	_expect(s.set_from_string(&"light_energy", "+0.5", true) == OK, "relative +")
	_expect(s.value(&"light_energy") == 100.5, "100 + 0.5")
	_expect(s.set_from_string(&"light_energy", "-0.25", true) == OK, "relative -")
	_expect(s.value(&"light_energy") == 100.25, "100.5 - 0.25")
	_expect(s.set_from_string(&"light_energy", "5", true) == Error.ERR_INVALID_PARAMETER,
		"relative requires explicit sign")
	_expect(s.value(&"light_energy") == 100.25, "bad relative leaves value")
	_expect(s.set_from_string(&"light_energy", "x", true) == Error.ERR_INVALID_PARAMETER,
		"relative must be a number")
	_expect(s.set_from_string(&"glow_enabled", "+1", true) == Error.ERR_UNAVAILABLE,
		"relative not for bool")
	_expect(s.set_from_string(&"max_clustered_elements", "+8", true) == Error.ERR_UNAVAILABLE,
		"relative not for int")
	# relative still clamps
	s.set_from_string(&"light_energy", "+10000", true)
	_expect(s.value(&"light_energy") == 1000.0, "relative result clamped to max")


func _test_parsing() -> void:
	var s := _settings()
	# bool
	for t in ["true", "1", "on", "yes", "TRUE"]:
		_expect(s.set_from_string(&"glow_enabled", t) == OK, "bool parse %s" % t)
	_expect(s.value(&"glow_enabled") == true, "bool true value")
	for t in ["false", "0", "off", "no"]:
		_expect(s.set_from_string(&"glow_enabled", t) == OK, "bool parse %s" % t)
	_expect(s.value(&"glow_enabled") == false, "bool false value")
	_expect(s.set_from_string(&"glow_enabled", "maybe") == Error.ERR_INVALID_PARAMETER,
		"bool parse rejects garbage")
	# int
	_expect(s.set_from_string(&"max_clustered_elements", "1024") == OK, "int parse")
	_expect(s.value(&"max_clustered_elements") == 1024, "int value")
	_expect(s.set_from_string(&"max_clustered_elements", "10.5") == Error.ERR_INVALID_PARAMETER,
		"int parse rejects float text")
	# float
	_expect(s.set_from_string(&"camera_fov", "60.5") == OK, "float parse")
	_expect(s.value(&"camera_fov") == 60.5, "float value")
	_expect(s.set_from_string(&"camera_fov", "wide") == Error.ERR_INVALID_PARAMETER,
		"float parse rejects garbage")
	# color
	_expect(s.set_from_string(&"light_color", "#ff8800") == OK, "hex color parse")
	_expect(s.value(&"light_color") == Color8(255, 136, 0, 255), "hex color value")
	_expect(s.set_from_string(&"light_color", "Color(1, 0.5, 0, 1)") == OK, "Color() parse")
	_expect(s.value(&"light_color") == Color(1, 0.5, 0, 1), "Color() value")
	_expect(s.set_from_string(&"light_color", "Color(1, 0, 0)") == OK, "Color() 3-arg parse")
	_expect(s.value(&"light_color") == Color.RED, "Color() 3-arg value")
	_expect(s.set_from_string(&"light_color", "#zzz") == Error.ERR_INVALID_PARAMETER, "bad hex")
	_expect(s.set_from_string(&"light_color", "#ff88001234") == Error.ERR_INVALID_PARAMETER, "bad hex length")
	_expect(s.set_from_string(&"light_color", "Color(1, x, 0)") == Error.ERR_INVALID_PARAMETER, "bad Color()")
	_expect(s.set_from_string(&"light_color", "Color(1, 0, 0, 0, 0)") == Error.ERR_INVALID_PARAMETER,
		"Color() 5-arg rejected")
	# enum (case-insensitive)
	_expect(s.set_from_string(&"glow_blend_mode", "Screen") == OK, "enum case-insensitive")
	_expect(s.value(&"glow_blend_mode") == "screen", "enum normalized to lowercase")
	_expect(s.set_from_string(&"glow_blend_mode", "bogus") == Error.ERR_INVALID_PARAMETER, "bad enum")


func _test_reset() -> void:
	var s := _settings()
	s.set_value(&"light_energy", 50.0)
	s.set_value(&"camera_fov", 100.0)
	_expect(s.reset(&"light_energy") == OK, "reset key")
	_expect(s.value(&"light_energy") == 100.0, "reset restores default")
	_expect(s.value(&"camera_fov") == 100.0, "other key untouched")
	s.reset_all()
	_expect(s.value(&"camera_fov") == 75.0, "reset_all restores defaults")
	_expect(not s.is_modified(&"light_energy"), "not modified after reset")


func _test_changed_signal() -> void:
	var s := _settings()
	var fired: Array = []
	s.changed.connect(func(key: StringName) -> void: fired.append(key))
	s.set_value(&"light_energy", 12.0)
	_expect(fired.size() == 1 and fired[0] == &"light_energy", "changed on successful set")
	s.set_value(&"glow_enabled", 1) # rejected
	_expect(fired.size() == 1, "no changed on rejected set")
	s.reset(&"light_energy")
	_expect(fired.size() == 2, "changed on reset")
	s.set_value(&"light_energy", 12.0)
	s.reset_all()
	_expect(fired.size() == 3 + s.keys().size(), "reset_all fires once per key")


func _test_to_dict() -> void:
	var s := _settings()
	s.set_value(&"light_color", Color8(255, 136, 0, 255))
	var d: Dictionary = s.to_dict()
	_expect(d.size() == EXPECTED_KEYS.size(), "to_dict has every key")
	_expect(d[&"light_energy"] == 100.0, "to_dict float value")
	_expect(d[&"light_color"] == "#ff8800", "to_dict color as hex string")
	_expect(d[&"glow_blend_mode"] == "screen", "to_dict enum as name")
	_expect(d[&"star_lights_enabled"] == true, "to_dict bool value")


func _test_keys_and_groups() -> void:
	var s := _settings()
	_expect(s.keys("glow").size() == 6, "key prefix filter glow*")
	_expect(s.keys("camera").size() == 3, "key prefix filter camera*")
	_expect(s.keys_in_group(&"star").size() == 15, "star group size")
	_expect(s.keys_in_group(&"env").size() == 9, "env group size")
	_expect(s.keys_in_group(&"camera").size() == 3, "camera group size")
	_expect(s.keys_in_group(&"project").size() == 1, "project group size")
	_expect(StarSettingsScript.type_name(StarSettingsScript.Type.FLOAT) == "float", "type_name float")
	_expect(StarSettingsScript.type_name(StarSettingsScript.Type.ENUM) == "enum", "type_name enum")
