#!/usr/bin/env bash
set -euo pipefail
base="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
python3 "$base/scripts/runtime-paths.py" >/dev/null
mapfile -t falcon_paths < <(python3 "$base/scripts/runtime-paths.py")
runtime="${falcon_paths[0]}"
# Keep the lock out of Wine's background services.
if [[ "${FALCON_LAUNCH_LOCK:-}" != 1 ]]; then
    exec flock -n -o "$runtime/game.lock" env FALCON_LAUNCH_LOCK=1 "$0" "$@"
fi
# Steam and Moonlight see one fullscreen Gamescope surface. Wine and the
# game stay at a fixed internal 720p size so menu and mouse coordinates agree.
if [[ "${FALCON_GAMESCOPE:-1}" != 0 && "${FALCON_INSIDE_GAMESCOPE:-0}" != 1 && -z "${GAMESCOPE_WAYLAND_DISPLAY:-}" ]]; then
    falcon_gamescope="$(command -v gamescope || true)"
    if [[ -z "$falcon_gamescope" && -x /usr/games/gamescope ]]; then falcon_gamescope=/usr/games/gamescope; fi
    if [[ -z "$falcon_gamescope" ]]; then
        echo 'Gamescope is required for fullscreen play. Install gamescope, or use FALCON_GAMESCOPE=0 for diagnostics.' >&2
        exit 1
    fi
    export PATH="$(dirname "$falcon_gamescope"):$PATH"
    falcon_scope_args=(-f -w 1280 -h 720 -W "${FALCON_OUTPUT_WIDTH:-1920}" -H "${FALCON_OUTPUT_HEIGHT:-1080}" -r 60 -S fit -F nearest)
    if [[ -n "${FALCON_GAMESCOPE_BACKEND:-}" ]]; then falcon_scope_args+=(--backend "$FALCON_GAMESCOPE_BACKEND"); fi
    mkdir -p "${falcon_paths[2]}"
    exec "$falcon_gamescope" "${falcon_scope_args[@]}" -- env FALCON_INSIDE_GAMESCOPE=1 FALCON_LAUNCH_LOCK=1 "$0" "$@" >> "${falcon_paths[2]}/gamescope.log" 2>&1
fi
unset FALCON_LAUNCH_LOCK
export WINEPREFIX="${FALCON_WINEPREFIX:-${falcon_paths[1]}}"
export WINEDLLOVERRIDES='d3d11,dxgi=n,b'
export DXVK_LOG_PATH="${falcon_paths[2]}" WINEDEBUG=-all
export TMPDIR="$base/tmp"
mkdir -p "$TMPDIR" "$DXVK_LOG_PATH"
printf '[launcher]\nprofile=%s\n' "${falcon_paths[3]}" > "$runtime/launchersettings.ini"
python3 -c 'import json,sys; p=sys.argv[1]; d=json.load(open(p)); d["video"]["fullscreen"]=True; open(p,"w").write(json.dumps(d,indent=2)+"\n")' "$runtime/prefs.json"
cd "$runtime"
wine reg add 'HKCU\Software\Wine\Drivers' /v Audio /d pulse /f >> "$DXVK_LOG_PATH/launch.log" 2>&1
falcon_exe="$(winepath -w "$runtime/RoRML.exe")"
falcon_exit=0
if [[ "${FALCON_INSIDE_GAMESCOPE:-0}" == 1 || -n "${GAMESCOPE_WAYLAND_DISPLAY:-}" ]]; then
    # Gamescope owns the fixed display; run the actual game as the tracked
    # child. A Wine Explorer desktop can outlive it and leave Steam running.
    wine "$falcon_exe" >> "$DXVK_LOG_PATH/launch.log" 2>&1 || falcon_exit=$?
    # This is a dedicated game prefix. Background Wine services otherwise
    # keep gamescopereaper/Steam alive after the game process has exited.
    python3 "$base/scripts/stop-wine-helpers.py" >> "$DXVK_LOG_PATH/launch.log" 2>&1 || true
else
    wine explorer '/desktop=FalconRainSource,1280x720' "$falcon_exe" >> "$DXVK_LOG_PATH/launch.log" 2>&1 || falcon_exit=$?
fi
if command -v xdotool >/dev/null; then
    while read -r falcon_window; do xdotool windowclose "$falcon_window" 2>/dev/null || true
    done < <(xdotool search --onlyvisible --name '^FalconRainSource - Wine Desktop$' 2>/dev/null || true)
fi
exit "$falcon_exit"
