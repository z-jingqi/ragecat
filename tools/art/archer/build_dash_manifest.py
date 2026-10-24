#!/usr/bin/env python3
"""Assemble only verified authored dash frames for the Godot atlas importer.

Usage: python build_dash_manifest.py RENDER_DIRECTORY OUTPUT_JSON [--partial]
The normal/release path requires all 672 unique frames. --partial is for isolated
preview validation only, never a release manifest. No image data is modified.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path

DIRECTIONS = ("east", "southeast", "south", "southwest", "west", "northwest", "north", "northeast")
TIMES = [0.0, .17, .36, .56, .78, 1.0, 1.1333333, 1.2666667, 1.4]
NEAR, FAR = 6.0551778793335, 8.55949668884277

def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def read(path: Path) -> dict:
    return json.loads(path.read_text())

def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)

def build(root: Path, output: Path, partial: bool = False) -> dict:
    progress = read(root / "all_direction_completion.json")
    recommendations = read(root / "gait_entry_recommendations.json")["clips"]
    if not partial:
        require(progress["queue_status"] == "complete", "Renderer is not complete")
        require(progress["verified_frames"] == 672, "Expected all 672 verified unique frames")
        require(progress["failed_jobs"] == 0, "Renderer contains failed jobs")
    result = {"version": 1, "preview_only": partial, "canvas_px": [192, 192],
              "depth_near": NEAR, "depth_far": FAR, "normalized_times": TIMES,
              "source_sha256": progress["source_identity"]["sha256"], "clips": {}}
    total = 0
    for job in progress["jobs"]:
        if job["status"] not in ("complete", "reused"):
            require(partial, f"Incomplete job: {job['id']}")
            continue
        role, camera, relative = job["kind"], job["camera"], job["relative"]
        require(camera in DIRECTIONS and 0 <= relative < 8, f"Invalid direction: {job['id']}")
        require(sorted(job["verified_frames"]) == list(range(job["count"])), f"Incomplete verified indexes: {job['id']}")
        metadata_path = root / job["metadata"]
        metadata = read(metadata_path)
        source_frames = {frame["index"]: frame for frame in metadata["frames"]}
        require(len(source_frames) == job["count"], f"Pose frame count differs: {job['id']}")
        pivot = metadata.get("pivot_px", metadata.get("canonical_pivot_px"))
        if "pivot_px" not in result:
            result["pivot_px"] = pivot
        require(all(abs(a-b) < .0001 for a,b in zip(pivot,result["pivot_px"])), "Pose pivots differ")
        clip = f"{camera}/dash_{relative}" if role == "body" else f"{camera}/{role}"
        require(clip not in result["clips"], f"Duplicate clip: {clip}")
        definition = {"role": role, "frames": []}
        if role == "body":
            require(job["id"] in recommendations, f"Missing planted-foot handoff: {job['id']}")
            recommendation = recommendations[job["id"]]
            definition["entry_phase"] = recommendation["recommended_gait_entry_phase"]
            definition["handoff_review_required"] = recommendation["review_required_over_6px"]
        elif role == "guard_move":
            require(job["id"] in recommendations, f"Missing moving recovery handoff: {job['id']}")
            recommendation = recommendations[job["id"]]
            definition.update(base_clip=f"{camera}/guard", base_frame_count=6,
                              recovery_distance=metadata["distance_total_game_px"],
                              exit_phase=recommendation["recommended_guard_move_exit_phase"],
                              handoff_review_required=recommendation["review_required_over_6px"])
        for index in range(job["count"]):
            validation_path = root / "validation" / job["tag"] / f"{job['prefix']}_{index:03}.json"
            validation = read(validation_path)
            require((validation["role"],validation["camera"],validation["relative"],validation["frame"]) ==
                    (role,camera,relative,index), f"Validation identity differs: {validation_path}")
            require(validation["source_identity"]["sha256"] == result["source_sha256"], "Mixed source model versions")
            require(validation["pose_metadata_sha256"] == digest(metadata_path), "Pose metadata changed after validation")
            require(validation["canvas_px"] == [192,192] and not validation["touches_canvas_edge"], "Clipped or wrong-sized frame")
            require(validation["safe_surface_depth_range"], "Surface depth exceeds shared range")
            color, depth = Path(validation["color"]), Path(validation["depth"])
            require(digest(color) == validation["color_sha256"] and digest(depth) == validation["depth_sha256"], "Rendered bytes changed after validation")
            frame = source_frames[index]
            bob = frame.get("shared_bob_game_px")
            if bob is None:
                bob = [value * metadata["texture_to_game_scale"] for value in frame["shared_screen_shift_px"]]
            definition["frames"].append({"color":os.path.relpath(color,output.parent),
                                         "depth":os.path.relpath(depth,output.parent), "bob":bob})
            total += 1
        result["clips"][clip] = definition
    if not partial:
        expected = {f"{direction}/dash_{relative}" for direction in DIRECTIONS for relative in range(8)}
        expected |= {f"{direction}/{role}" for direction in DIRECTIONS for role in ("guard","guard_move")}
        require(set(result["clips"]) == expected and total == 672, "Incomplete release direction matrix")
    for clip, definition in result["clips"].items():
        if definition["role"] == "guard_move":
            require(definition["base_clip"] in result["clips"], f"Missing shared guard frames: {clip}")
    result["unique_frames"] = total
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps(result,indent=2) + "\n")
    return result

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("render_directory",type=Path)
    parser.add_argument("output",type=Path)
    parser.add_argument("--partial",action="store_true")
    args = parser.parse_args()
    result = build(args.render_directory.resolve(),args.output.resolve(),args.partial)
    print(f"DASH MANIFEST: {len(result['clips'])} clips, {result['unique_frames']} verified unique frames; preview_only={result['preview_only']}")
