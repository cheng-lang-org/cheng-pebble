#!/usr/bin/env sh
set -eu
(set -o pipefail) 2>/dev/null && set -o pipefail

usage() {
  cat <<'USAGE'
Usage:
  sh scripts/production_closure.sh [--dir=<path>] [<path>]

Env:
  CHENG_LANG_ROOT       cheng-lang repo path (default: $HOME/cheng-lang)
  CHENG_STAGE0_DRIVER   preferred stage0 driver path for rebuilding ./cheng
  CHENG_REBUILD_BACKEND_DRIVER  set to 1 to force rebuilding cheng driver
  PEBBLE_QA_KEEP_DIR    set to 1 to keep existing QA dir contents
  CHENG_PKG_ROOTS       package roots for cheng/<pkg>/... import resolution
USAGE
}

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cheng_lang_root="${CHENG_LANG_ROOT:-$HOME/cheng-lang}"
if [ ! -d "$cheng_lang_root/src/tooling" ]; then
  echo "[Error] CHENG_LANG_ROOT is invalid: $cheng_lang_root" 1>&2
  echo "  hint: set CHENG_LANG_ROOT to your cheng-lang repo" 1>&2
  exit 2
fi

qa_dir="$repo_root/.pebble_qa_prod"
positional_used="0"
while [ "${1:-}" != "" ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --dir=*)
      qa_dir="${1#--dir=}"
      ;;
    --dir)
      echo "[Error] use --dir=<path>" 1>&2
      exit 2
      ;;
    *)
      if [ "$positional_used" = "0" ]; then
        qa_dir="$1"
        positional_used="1"
      else
        echo "[Error] unexpected arg: $1" 1>&2
        exit 2
      fi
      ;;
  esac
  shift || true
done

probe_stage0() {
  candidate="$1"
  if [ ! -x "$candidate" ]; then
    return 1
  fi
  probe_dir="$repo_root/.tmp"
  mkdir -p "$probe_dir"
  probe_obj="$probe_dir/stage0_probe.$$.o"
  probe_log="$probe_dir/stage0_probe.$$.log"
  rm -f "$probe_obj" "$probe_log"
  set +e
  env \
    CHENG_BACKEND_ALLOW_NO_MAIN=1 \
    CHENG_BACKEND_WHOLE_PROGRAM=1 \
    CHENG_BACKEND_EMIT=obj \
    CHENG_BACKEND_TARGET="$(sh "$cheng_lang_root/src/tooling/detect_host_target.sh")" \
    CHENG_BACKEND_FRONTEND=mvp \
    CHENG_BACKEND_INPUT="$cheng_lang_root/src/std/system_helpers_backend.cheng" \
    CHENG_BACKEND_OUTPUT="$probe_obj" \
    "$candidate" >"$probe_log" 2>&1
  status=$?
  set -e
  if [ "$status" -eq 0 ] && [ -s "$probe_obj" ]; then
    rm -f "$probe_obj" "$probe_log"
    return 0
  fi
  rm -f "$probe_obj" "$probe_log"
  return 1
}

select_stage0() {
  if [ "${CHENG_STAGE0_DRIVER:-}" != "" ]; then
    if probe_stage0 "$CHENG_STAGE0_DRIVER"; then
      printf "%s\n" "$CHENG_STAGE0_DRIVER"
      return 0
    fi
    echo "[Warn] CHENG_STAGE0_DRIVER probe failed: $CHENG_STAGE0_DRIVER" 1>&2
  fi
  for candidate in \
    "$cheng_lang_root/driver_local_patch2" \
    "$cheng_lang_root/driver_local_patch" \
    "$cheng_lang_root/driver_local" \
    "$cheng_lang_root/bin/cheng_nim" \
    "$cheng_lang_root/bin/cheng_dbg"
  do
    if probe_stage0 "$candidate"; then
      printf "%s\n" "$candidate"
      return 0
    fi
  done
  return 1
}

ensure_backend_driver() {
  if [ "${CHENG_BACKEND_DRIVER:-}" != "" ]; then
    if probe_stage0 "$CHENG_BACKEND_DRIVER"; then
      printf "%s\n" "$CHENG_BACKEND_DRIVER"
      return 0
    fi
    echo "[Warn] CHENG_BACKEND_DRIVER probe failed: $CHENG_BACKEND_DRIVER" 1>&2
  fi
  local_driver="$cheng_lang_root/cheng"
  if probe_stage0 "$local_driver"; then
    printf "%s\n" "$local_driver"
    return 0
  fi
  stage0="$(select_stage0 || true)"
  if [ "$stage0" = "" ]; then
    echo "[Error] no usable stage0 driver found for backend rebuild" 1>&2
    exit 2
  fi
  if [ "${CHENG_REBUILD_BACKEND_DRIVER:-0}" != "1" ]; then
    printf "%s\n" "$stage0"
    return 0
  fi
  echo "[production-closure] rebuilding backend driver via stage0: $stage0" 1>&2
  driver_build_log="$repo_root/.tmp/build_driver.log"
  mkdir -p "$repo_root/.tmp"
  rm -f "$driver_build_log"
  CHENG_BACKEND_BUILD_DRIVER_STAGE0="$stage0" \
  CHENG_BACKEND_BUILD_DRIVER_LINKER=self \
  CHENG_BACKEND_BUILD_DRIVER_SELFHOST=1 \
    sh "$cheng_lang_root/src/tooling/build_backend_driver.sh" --name:cheng >"$driver_build_log" 2>&1 || {
      echo "[Warn] backend driver rebuild failed; fallback to stage0 driver" 1>&2
      tail -n 80 "$driver_build_log" 1>&2 || true
      printf "%s\n" "$stage0"
      return 0
    }
  if ! probe_stage0 "$local_driver"; then
    echo "[Warn] rebuilt backend driver is not runnable: $local_driver" 1>&2
    echo "[Warn] fallback to stage0 driver: $stage0" 1>&2
    printf "%s\n" "$stage0"
    return 0
  fi
  printf "%s\n" "$local_driver"
}

default_pkg_root="$(CDPATH= cd -- "$repo_root/.." && pwd)"
pkg_roots="${CHENG_PKG_ROOTS:-$default_pkg_root}"
case ",$pkg_roots," in
  *",$default_pkg_root,"*) ;;
  *) pkg_roots="$pkg_roots,$default_pkg_root" ;;
esac

driver="$(ensure_backend_driver)"

build_dir="$repo_root/.tmp/build"
mkdir -p "$build_dir"
binary="$build_dir/pebble_qa_production"
src_main="$repo_root/src/tooling/qa_production_main.cheng"
if [ ! -f "$src_main" ]; then
  echo "[Error] missing source: $src_main" 1>&2
  exit 2
fi

echo "[production-closure] compiling: $src_main"
compile_log="$build_dir/compile.log"
rm -f "$compile_log"
(
  cd "$cheng_lang_root"
  env \
    CHENG_BACKEND_DRIVER="$driver" \
    CHENG_CLEAN_CHENG_LOCAL=0 \
    CHENG_PKG_ROOTS="$pkg_roots" \
    sh src/tooling/chengc.sh "$src_main" --name:"$binary" --backend:obj >"$compile_log" 2>&1
) || {
  echo "[Error] compile failed while building production closure runner" 1>&2
  tail -n 120 "$compile_log" 1>&2 || true
  exit 1
}

if [ ! -x "$binary" ]; then
  echo "[Error] missing binary after compile: $binary" 1>&2
  exit 2
fi

if [ "${PEBBLE_QA_KEEP_DIR:-0}" != "1" ]; then
  rm -rf "$qa_dir"
fi
mkdir -p "$qa_dir"

echo "[production-closure] running qa-production: $qa_dir"
env PEBBLE_QA_DIR="$qa_dir" "$binary"
