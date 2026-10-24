"""Release geometry for grouped flame tongues and gas-textured ignition patches.
Pure Python geometry with head-only UV transport and bounded local shoulder corrections.

Coordinates are collision-radius units: +X is travel, X=+1 is the leading
collision limit, Z is screen-up, and Y provides small layer separation.
The only periodic reset occurs while a tongue is transparent.
"""
from dataclasses import dataclass
import math
import random

TAU = math.tau


def clamp(x, lo=0.0, hi=1.0):
    return max(lo, min(hi, x))


def smooth(lo, hi, x):
    q = clamp((x - lo) / (hi - lo))
    return q * q * (3.0 - 2.0 * q)


def mix(a, b, q):
    return a + (b - a) * q


@dataclass(frozen=True)
class Tongue:
    name: str
    root_x: float
    root_z: float
    depth: float
    length: float
    half_width: float
    bend: float
    curl_sign: float
    phase: float
    cycles: int
    seed: float
    head: bool
    branch: str
    heat: float
    opacity: float
    break_age: float = .56
    neck_u: float = .64


def make_tongues(seed=24026, loop_frames=32):
    """Six contour tongues and four small alternating ignition tongues.

    Unequal, explicitly asymmetric launch locations avoid a meridional cage.
    Randomness is local, seeded, and cosmetic; never use it for collision logic.
    """
    rng = random.Random(seed)
    contour = [
        (.62, -.12, 2.55, .32,  .16, -1, .03),  # broad main; gentle rear S
        (.57,  .16, 2.75, .16, -.12,  1, .19),  # long fine tongue through center
        (.52,  .08, 2.25, .29, -.16,  1, .37),  # shorter second main, low sweep
        (.58,  .04, 1.85, .20,  .29, -1, .54),  # short upper peel
        (.46, -.20, 2.15, .14,  .13,  1, .73),  # fine lower tongue rising inward
        (.60, -.02, 2.40, .18, -.04, -1, .88),  # fine central tongue
    ]
    result = []
    for j, (x, z, length, width, bend, sign, phase) in enumerate(contour):
        result.append(Tongue(
            f"Contour_tongue_{j:02d}", x, z, .10 + j * .018,
            length, width, bend, sign, phase, 1, rng.random() * TAU,
            False, "upper" if j % 2 == 0 else "lower", .66 + .05 * (j % 3), .76,
            .52 + .035 * (j % 4), .60 + .025 * (j % 3),
        ))
    for j, (z, width, phase) in enumerate([
        (-.48, .34, .035), (-.13, .42, .28), (.22, .41, .39), (.54, .31, .775),
    ]):
        result.append(Tongue(
            f"Ignition_tongue_{j:02d}", math.sqrt(1.0 - z * z) * .995,
            z, -.16 - j * .014, 1.40 + .11 * (j % 2), width,
            -.13 if j % 2 else .11, 1 if j % 2 else -1,
            phase, [1, 2, 1, 2][j], rng.random() * TAU, True,
            "lower" if j % 2 == 0 else "upper", .90 + .025 * (j % 2), .90,
            .55 + .025 * j, .82 + .008 * j,
        ))
    # Place an exactly transparent reset on the actual atlas sampling grid.
    from dataclasses import replace
    return [replace(t, phase=round(t.phase * loop_frames / t.cycles)
                    * t.cycles / loop_frames) for t in result]


def age_at(tongue, loop_t):
    return (loop_t * tongue.cycles + tongue.phase) % 1.0


def envelope(age):
    """Transparent at either reset endpoint; no persistent/static layer."""
    return smooth(.035, .17, age) * (1.0 - smooth(.72, .95, age))


def controls(tongue, loop_t):
    age = age_at(tongue, loop_t)
    return {
        "age": age,
        "opacity": envelope(age) * tongue.opacity,
        "rupture": smooth(tongue.break_age, tongue.break_age + .16, age),
        "tip_death": smooth(.73, .94, age),
    }


def outer_rear_sweep(tongue, loop_t, u, world_x):
    """Two unequal open S offsets only behind the core, never a closed swirl.

    The other four outer tongues use unequal monotonic arcs from their own
    clustered root and bend. X remains the dominant backwards flow direction.
    """
    if tongue.head or world_x >= 0.0:
        return 0.0
    index = int(tongue.name.rsplit('_', 1)[1])
    if index not in (0, 1):
        return 0.0
    if index == 0:
        offset = .20 * math.sin(math.pi * u) - .14 * u
    else:
        offset = -.17 * math.sin(math.pi * u) - .06 * u
    grown = smooth(.025, .66, age_at(tongue, loop_t))
    rear = 1.0 - smooth(-.9, 0.0, world_x)
    return offset * grown * rear


HEAD_PATCHES = {
    "upper": (.64, .85, .26, .70),
    "lower": (.60, .83, .36, .76),
}

# Distinct near-isometric internal crops and forward source-X transport speeds.
# Feature equation x1-range*u+speed*age=constant moves features toward +u.
HEAD_CROP_SPECS = [
    (.59, .800, .26, .70, .045),
    (.60, .805, .34, .76, .035),
    (.62, .810, .28, .70, .035),
    (.58, .790, .36, .76, .060),
]


def head_patch_center_and_width(tongue, loop_t, u):
    """An open, near-isometric gas patch, not a clamped enlarged long strip."""
    age=age_at(tongue,loop_t)
    j=int(tongue.name.rsplit('_',1)[1])
    growth=smooth(.01,.22,age)
    length=(1.82+.06*(j%2))*mix(.28,1.0,growth)
    root_x=tongue.root_x-.018*smooth(.12,.92,age)
    x=root_x-length*u
    root_z=tongue.root_z*(1-.56*smooth(-.12,.82,root_x))
    z=root_z*(1-smooth(0,.14,u))
    z += [-.012,.012,-.010,.010][j]*math.sin(math.pi*u)*growth
    z += .012*math.sin(u*8+age*3+tongue.seed)*math.sin(math.pi*u)*growth
    rupture=smooth(tongue.break_age,tongue.break_age+.22,age)
    detached=smooth(tongue.neck_u-.045,tongue.neck_u+.07,u)*rupture
    x -= .08*detached
    z += tongue.curl_sign*.045*detached
    # Local open tip curvature still evolves and the old neck severs it.
    theta=.2+2.5*smooth(.10,.88,age)
    curl=.055*growth*u**3
    x += curl*(1-math.cos(theta))
    z += tongue.curl_sign*curl*math.sin(theta)
    y=tongue.depth+.025*math.sin(u*4+tongue.seed)*u*growth
    width=1.08*growth*max(0,math.sin(math.pi*u))**.40
    width*=smooth(0,.10,u)*(1-.10*u)
    neck=1-smooth(.018,.078,abs(u-tongue.neck_u))
    width*=1-.96*rupture*neck
    width*=1-.48*smooth(.78,.99,age)*smooth(.65,.90,u)
    return x,y,z,max(0,width)


def center_and_width(tongue, loop_t, u):
    if tongue.head:
        return head_patch_center_and_width(tongue,loop_t,u)
    age = age_at(tongue, loop_t)
    grown = smooth(.025, .66, age)
    rupture = smooth(tongue.break_age, tongue.break_age + .22, age)
    length = tongue.length * mix(.36, 1.0, grown)
    # Head tips remain anchored; only the short ignition ribbon behind them grows.
    root_drift = (.018 if tongue.head else .16) * smooth(.12, .92, age)
    x = tongue.root_x - root_drift - length * u
    z = tongue.root_z + tongue.bend * math.sin(math.pi * .65 * u) * grown
    # Local billowing only, with anchored endpoints and no whole-sprite transform.
    wave = math.sin(TAU * (u * 1.30 - age * 1.08) + tongue.seed)
    z += (.042 if tongue.head else .095) * wave * math.sin(math.pi * u) * grown
    x += .025 * math.sin(TAU * u * 1.7 + tongue.seed + age * 3) * u * grown
    # An open curled tip turns through less than one turn, never a closed ring.
    theta = .20 + 3.15 * smooth(.08, .86, age)
    curl = (.055 if tongue.head else .21) * grown * u ** 3
    x += curl * (1.0 - math.cos(theta))
    z += tongue.curl_sign * curl * math.sin(theta)
    detached = smooth(tongue.neck_u - .045, tongue.neck_u + .07, u) * rupture
    x -= (.07 if tongue.head else .27) * detached
    z += tongue.curl_sign * (.055 if tongue.head else .20) * detached
    z += outer_rear_sweep(tongue, loop_t, u, x)
    if tongue.head:
        # The four short ignition sheets share a compact burning region at
        # the front, then open back into their unequal flowing paths. This is
        # centerline bending only: no object scaling, disk, or static filler.
        front_cohesion = smooth(-.12, .82, x)
        z *= 1.0 - .56 * front_cohesion
    y = tongue.depth + .045 * math.sin(u * 4.0 + tongue.seed) * u * grown
    # Compression of the texture's broad root makes one hot leading point,
    # not repeated rounded fireballs. It widens behind the collision front.
    # Only ignition tongues flare sooner, so their source-alpha interiors
    # overlap before the head-to-wake seam. Outer contour sheets are unchanged.
    width_power = .38 if tongue.head else .58
    width_profile = (max(0, math.sin(math.pi * u)) ** width_power) * (1.0 - .38 * u)
    width = tongue.half_width * width_profile * mix(.54, 1.0, grown)
    width *= 1.0 + .14 * math.sin(u * 13.0 - age * 5.0 + tongue.seed)
    neck = 1.0 - smooth(.018, .078, abs(u - tongue.neck_u))
    width *= 1.0 - .96 * rupture * neck
    width *= 1.0 - .48 * smooth(.78, .99, age) * smooth(.65, .90, u)
    return x, y, z, max(0.0, width)


def vertex(tongue, loop_t, u, side):
    x, y, z, width = center_and_width(tongue, loop_t, u)
    # Twist is small, unequal, and local. Ribbons remain visibly open tongues.
    twist = .20 * math.sin(tongue.seed + u * 3.2 + age_at(tongue, loop_t) * 1.8)
    z += side * width * math.cos(twist)
    y += side * width * math.sin(twist)
    if tongue.head:
        # Local soft shoulders move only: lower <=.032R and upper <=.025R.
        # Root, rear tip, source mapping and six outer tongues are unchanged.
        z -= .032*smooth(.35,.85,-side)*smooth(.08,.22,u)*(1-smooth(.62,.80,u))
        # Final 64-sample coverage repair: upper soft shoulder only, <= .025R.
        z += .025*smooth(.35,.85,side)*smooth(.08,.22,u)*(1-smooth(.62,.80,u))
    # Collision silhouette is bounded, not a luminous sphere filler.
    if x > 0.0 and not tongue.head:
        x = min(x, math.sqrt(max(0.0, 1.0 - min(.998, abs(z)) ** 2)))
    return (max(-2.62, x), y, z)


def vertices(tongue, loop_t, steps=36, across=6):
    return [vertex(tongue, loop_t, row / steps, col / across * 2.0 - 1.0)
            for row in range(steps + 1) for col in range(across + 1)]


def faces(steps=36, across=6):
    return [(q, q + 1, q + across + 2, q + across + 1)
            for row in range(steps) for col in range(across)
            for q in [row * (across + 1) + col]]


# Source image coordinates use top-left Y. These NEW paths follow actual gas
# filaments inside gas_black_master.png, never the truncated right edge. Both
# stay strictly in x=0.40..0.85 and include the natural dark gaps between folds.
BRANCH_PATHS = {
    "upper": [(.85, .44, .065), (.76, .40, .065), (.67, .395, .075),
              (.57, .32, .095), (.43, .46, .055)],
    "lower": [(.84, .62, .090), (.74, .63, .080), (.65, .60, .075),
              (.54, .62, .085), (.40, .52, .060)],
}


def source_uv(tongue, u, side, orientation="base-right", source_mode="branch"):
    if source_mode != "branch":
        raise ValueError("Use the internal gas-source paths, not the cropped full image.")
    if tongue.head:
        x0,x1,y0,y1,_=HEAD_CROP_SPECS[int(tongue.name.rsplit('_',1)[1])]
        x=mix(x1,x0,u)
        sign=-1 if tongue.seed>math.pi else 1
        v=1.0-mix(y0,y1,(side*sign+1)*.5)
        if orientation=="base-left": x=1-x
        elif orientation=="base-up": x,v=v,x
        return clamp(x),clamp(v)
    if source_mode == "branch":
        path = BRANCH_PATHS[tongue.branch]
        q = clamp(u) * (len(path) - 1)
        i = min(len(path) - 2, int(q))
        f = q - i
        x, y, half = [mix(path[i][k], path[i + 1][k], f) for k in range(3)]
        # Flip only alternate sampling cross-sections, not the world transform.
        sign = -1 if tongue.seed > math.pi else 1
        v = 1.0 - (y + side * half * sign)
    else:
        x, v = 1.0 - u, .5 + side * .5
    if orientation == "base-left":
        x = 1.0 - x
    elif orientation == "base-up":
        x, v = v, x
    return clamp(x), clamp(v)


def local_alpha(tongue, loop_t, u, side=0.0):
    """Matches the analytic portion of the Blender material, excluding texture."""
    c = controls(tongue, loop_t)
    neck = 1.0 - smooth(.026, .085, abs(u - tongue.neck_u))
    gap = 1.0 - c["rupture"] * neck
    tip = 1.0 - c["tip_death"] * smooth(tongue.neck_u + .01, tongue.neck_u + .17, u)
    soft_edge = 1.0 - smooth(.70, 1.0, abs(side))
    return c["opacity"] * gap * tip * soft_edge


def source_uv_at_age(tongue,u,side,age):
    """Matches the V9 head-only shader transport; tail sampling is unchanged."""
    x,v=source_uv(tongue,u,side)
    if tongue.head:
        speed=HEAD_CROP_SPECS[int(tongue.name.rsplit('_',1)[1])][4]
        x+=speed*age*smooth(.01,.10,u)
    return x,v
