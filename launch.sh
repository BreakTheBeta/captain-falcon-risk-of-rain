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
unset FALCON_LAUNCH_LOCK
export WINEPREFIX="${FALCON_WINEPREFIX:-${falcon_paths[1]}}"
export WINEDLLOVERRIDES='d3d11,dxgi=n,b'
export DXVK_LOG_PATH="${falcon_paths[2]}" WINEDEBUG=-all
export TMPDIR="$base/tmp"
mkdir -p "$TMPDIR" "$DXVK_LOG_PATH"
printf '[launcher]\nprofile=FalconRain\n' > "$runtime/launchersettings.ini"
python3 -c 'import json,sys; p=sys.argv[1]; d=json.load(open(p)); d["video"]["fullscreen"]=True; open(p,"w").write(json.dumps(d,indent=2)+"\n")' "$runtime/prefs.json"
cd "$runtime"
wine reg add 'HKCU\Software\Wine\Drivers' /v Audio /d pulse /f >> "$DXVK_LOG_PATH/launch.log" 2>&1
falcon_exe="$(winepath -w "$runtime/RoRML.exe")"
falcon_exit=0
wine explorer '/desktop=FalconRainSource,1280x720' "$falcon_exe" >> "$DXVK_LOG_PATH/launch.log" 2>&1 || falcon_exit=$?
if command -v xdotool >/dev/null; then
    while read -r falcon_window; do xdotool windowclose "$falcon_window" 2>/dev/null || true
    done < <(xdotool search --onlyvisible --name '^FalconRainSource - Wine Desktop$' 2>/dev/null || true)
fi
exit "$falcon_exit"
