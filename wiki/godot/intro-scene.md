---
type: Application Feature
title: Intro Mother Scene
description: intro.tscn plays handcrafted child scenes (title, stars, camera glide) in order, then fades out and switches to main.tscn.
tags: [godot, intro, scene-switching, tweens]
status: stable
generated: { by: pi/1.5.2, at: 2026-11-25T00:00:00Z }
sources:
  - id: introgd
    resource: godot/intro.gd
    title: intro.gd (Intro mother script)
    last_modified: 2026-11-25
  - id: introscenegd
    resource: godot/intro_scene.gd
    title: intro_scene.gd (IntroScene base contract)
    last_modified: 2026-11-25
  - id: introchildgd
    resource: godot/intro/
    title: intro/ (title, stars, camera child scenes)
    last_modified: 2026-11-25
  - id: testintro
    resource: godot/test_intro.gd
    title: test_intro.gd (mother/base-contract headless tests)
    last_modified: 2026-11-25
usage_window: { from: 2026-11-25, to: 2026-11-25 }
---

# Intro Mother Scene

`intro.tscn` is the app's main scene (was `main.tscn`). The mother node
(`Intro`, `godot/intro.gd`) owns the single [Camera3D](/godot/architecture.md),
`WorldEnvironment`/sky, the `SceneSlot`, and a `CanvasLayer` with a hint label
and a full-screen `FadeRect`. It plays an exported `Array[PackedScene]` of
child scenes in order, then fades to black (0.4 s) and switches to
`main.tscn`; a failed switch is a loud `push_error`, resets the fade, and
stays on the intro (no black soft-lock).

## Child contract (`IntroScene`)

Children are dumb: they build only their own content under themselves, may
move the injected `camera`, and emit `finished` exactly once (guarded
`_finish()`). They never contain a camera, environment, or lights. Current
children in `godot/intro/`: `TitleScene` (title fade-in/hold/out, then a slow
subtitle fade lower on screen), `StarsScene` (hand-placed labelled stars plus
optional connecting line, appearing one by one), `CameraScene` (glides the
camera along an exported path through those stars, `look_at` per frame).

## Input

- `Space` (`skip_step`) — `skip()` the current child (kill its tween, advance).
- `Esc` (`skip_all`) — fade and go to `main.tscn`.
- `Ctrl+W` (`exit`) — quit.

## Testing

`test_intro.gd` (SceneTree runner, see
[Headless testing](/godot/headless-testing.md)) packs fake `IntroScene`
subclasses at runtime and asserts play order, skip advances, bad-scene skip
with error, double-`finished` ignored, and the failed-switch fallback.
