# Hostile projectile combustion volume

Original procedural Blender volume, created for this project. No third-party textures or game assets.

Render: `blender -b --disable-autoexec -t 2 -P build_fireball.py -- --out /tmp/ragecat-fireball-frames --size 160 --samples 32 --frames all`
Pack: `python pack_fireball.py /tmp/ragecat-fireball-frames ../../../../assets/projectiles/fireball/fireball_volume.png`

24 frames, 160 × 90 pixels, 6 × 4 atlas; 30 fps loop. Four unequal advected head volumes and three tapered trailing volumes share a 3D temperature/density field. Camera preserves the physical projectile center at x=0. Camera capture bounds are (-3.45, -1.434375, 5.1, 2.86875) in radius units. Godot presentation stretches Y by 1.35 and offsets X by +0.12 radius to align the visible hot body with the original collision circle. Final presentation bounds are (-3.33, -1.93640625, 5.1, 3.8728125). Transparent padding is not the collision shape. Gameplay remains a radius defined by the enemy configuration.

Godot interpolates adjacent frames with alpha-weighted color and clips the visual to the arena. Playback uses projectile travel age, not wall time, so pause/disabled AI do not animate. There is no bloom, secondary damage, or burning effect.
