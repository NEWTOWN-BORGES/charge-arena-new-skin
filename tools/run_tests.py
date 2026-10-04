#!/usr/bin/env python3
"""Run Godot regressions in a disposable project with separate saves per test.

Import once with Godot --headless --editor --import, then run this script.
Logs and the machine-readable report stay in .qa/. No player save is read or written.
"""
from __future__ import annotations

import argparse
import concurrent.futures
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import threading
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
NETWORK = {"test_network", "test_pvp_powers", "test_feedback_network", "test_pvp_suspension"}
GPU = {"test_visual", "test_polish_visual", "test_portrait_visual"}
LAN_UNIT = {"test_pvp_kit", "test_pvp_map"}
LAN_LOCK = threading.Lock()


def mirror(destination: Path) -> None:
    destination.mkdir(parents=True)
    for directory in ("scripts", "systems", "localization", "scenes", "shaders", "art", "audio", "tests", ".godot"):
        source = ROOT / directory
        for path in source.rglob("*"):
            if not path.is_file() or "editor" in path.relative_to(source).parts:
                continue
            target = destination / directory / path.relative_to(source)
            target.parent.mkdir(parents=True, exist_ok=True)
            # Source and imported resources are only read. Tests' temporary files are
            # created in the mirror, never alongside production code or player saves.
            if path.name == ".gdignore" or path.suffix in {".gd", ".gdshader", ".tscn", ".cfg", ".godot", ".uid", ".import"}:
                shutil.copy2(path, target)
            else:
                try:
                    os.link(path, target)
                except OSError:
                    shutil.copy2(path, target)
    for name in ("project.godot", "icon.svg", "icon.svg.import", "export_presets.cfg"):
        if (ROOT / name).exists():
            shutil.copy2(ROOT / name, destination / name)


def run_one(script: Path, workspace: Path, godot: str, timeout: int) -> dict:
    if script.stem in LAN_UNIT:
        with LAN_LOCK:
            return run_isolated(script, workspace, godot, timeout)
    return run_isolated(script, workspace, godot, timeout)


def run_isolated(script: Path, workspace: Path, godot: str, timeout: int) -> dict:
    name = script.stem
    project = workspace / name
    mirror(project)
    identity = f"ChargeArenaQA/{workspace.name}/{name}"
    with (project / "override.cfg").open("w", encoding="utf-8") as config:
        config.write('[application]\nconfig/use_custom_user_dir=true\n')
        config.write(f'config/custom_user_dir_name="{identity}"\n')
    relative = script.relative_to(ROOT).as_posix()
    command = [godot, "--headless", "--audio-driver", "Dummy", "--path", str(project),
               "--script", f"res://{relative}"]
    if name == "test_squad":
        command.extend(["--", "60"])
    started = time.monotonic()
    try:
        process = subprocess.run(command, capture_output=True, text=True, encoding="utf-8",
                                 errors="replace", timeout=timeout)
        output = process.stdout + process.stderr
        failed = process.returncode != 0 or bool(re.search(r"(?:SCRIPT ERROR:|ERROR:|FAIL:)", output))
        code = process.returncode
    except subprocess.TimeoutExpired as error:
        output = str(error.stdout or "") + str(error.stderr or "") + "\nTIMEOUT"
        failed, code = True, -1
    (workspace / f"{name}.log").write_text(output, encoding="utf-8")
    result = {"test": relative, "passed": not failed, "exit_code": code,
              "seconds": round(time.monotonic() - started, 2), "user_dir": identity}
    print(f'{"PASS" if result["passed"] else "FAIL"} {name} ({result["seconds"]}s)', flush=True)
    return result


def run_pair(script: Path, workspace: Path, godot: str, timeout: int) -> dict:
    """Separate saves and processes, sequential pairs because the game uses one LAN port."""
    started = time.monotonic()
    peers = []
    relative = script.relative_to(ROOT).as_posix()
    # Prepare both projects before starting either connection timer.
    for role in ("host", "client"):
        project = workspace / f"{script.stem}-{role}"
        mirror(project)
        identity = f"ChargeArenaQA/{workspace.name}/{script.stem}-{role}"
        (project / "override.cfg").write_text(
            '[application]\nconfig/use_custom_user_dir=true\n'
            f'config/custom_user_dir_name="{identity}"\n', encoding="utf-8")
        peers.append((role, project))
    running = []
    outputs = []
    try:
        for role, project in peers:
            log = (workspace / f"{script.stem}-{role}.log").open("w", encoding="utf-8")
            process = subprocess.Popen([godot, "--headless", "--audio-driver", "Dummy",
                "--path", str(project), "--script", f"res://{relative}", "--", f"--{role}"],
                stdout=log, stderr=subprocess.STDOUT)
            running.append((role, process, log))
            if role == "host":
                time.sleep(2)
        deadline = time.monotonic() + timeout
        for role, process, log in running:
            try:
                process.wait(timeout=max(1, deadline - time.monotonic()))
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
            log.flush()
            output = (workspace / f"{script.stem}-{role}.log").read_text(encoding="utf-8")
            outputs.append(process.returncode == 0 and not re.search(r"(?:SCRIPT ERROR:|ERROR:|FAIL:)", output))
    finally:
        for _, process, log in running:
            if process.poll() is None:
                process.kill()
                process.wait()
            log.close()
    result = {"test": relative, "passed": all(outputs) and len(outputs) == 2,
              "seconds": round(time.monotonic() - started, 2), "peers": 2}
    print(f'{"PASS" if result["passed"] else "FAIL"} {script.stem} (two peers)', flush=True)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tests", nargs="*", help="Test stems, e.g. test_battery test_progress")
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--jobs", type=int, default=2)
    parser.add_argument("--timeout", type=int, default=120)
    parser.add_argument("--label", default="regression")
    parser.add_argument("--network", action="store_true", help="Run host/client integration pairs")
    args = parser.parse_args()
    scripts = sorted((ROOT / "tests").rglob("test_*.gd"))
    if args.tests:
        wanted = set(args.tests)
        scripts = [s for s in scripts if s.stem in wanted]
        missing = wanted - {s.stem for s in scripts}
        if missing:
            parser.error("Unknown tests: " + ", ".join(sorted(missing)))
    elif args.network:
        scripts = [s for s in scripts if s.stem in NETWORK]
    else:
        scripts = [s for s in scripts if s.stem not in NETWORK | GPU]
    workspace = ROOT / ".qa" / (args.label + "-" + uuid.uuid4().hex[:8])
    workspace.mkdir(parents=True)
    (ROOT / ".qa" / ".gdignore").touch()
    results = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futures = [pool.submit(run_one, s, workspace, args.godot, args.timeout) for s in scripts if s.stem not in NETWORK]
        for future in concurrent.futures.as_completed(futures):
            results.append(future.result())
    for script in scripts:
        if script.stem in NETWORK:
            results.append(run_pair(script, workspace, args.godot, args.timeout))
    results.sort(key=lambda result: result["test"])
    (workspace / "results.json").write_text(json.dumps(results, indent=2), encoding="utf-8")
    passed = sum(result["passed"] for result in results)
    print(f"RESULT {passed}/{len(results)} passed; logs: {workspace}", flush=True)
    return int(passed != len(results))


if __name__ == "__main__":
    raise SystemExit(main())
