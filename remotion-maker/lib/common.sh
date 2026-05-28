#!/usr/bin/env bash
set -euo pipefail

# Constants
RM_PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RM_DATA_DIR=".remotion-maker"
RM_STYLES_DIR="${RM_DATA_DIR}/styles"
RM_MEDIA_DIR="${RM_DATA_DIR}/media/sourced"
RM_PREVIEW_DIR="${RM_DATA_DIR}/preview"
RM_VERIFY_DIR="${RM_DATA_DIR}/verify"

# Directory Setup
rm_ensure_dirs() {
  local project_dir="${1:-.}"
  mkdir -p "${project_dir}/${RM_STYLES_DIR}"
  mkdir -p "${project_dir}/${RM_MEDIA_DIR}"
  mkdir -p "${project_dir}/${RM_PREVIEW_DIR}"
  mkdir -p "${project_dir}/${RM_VERIFY_DIR}"
}

# Style Helpers
rm_list_styles() {
  local project_dir="${1:-.}"
  local styles_dir="${project_dir}/${RM_STYLES_DIR}"
  if [ -d "$styles_dir" ]; then
    find "$styles_dir" -name '*.md' -print 2>/dev/null | while read -r f; do
      basename "$f" .md
    done
  fi
}

rm_style_exists() {
  local project_dir="${1:-.}"
  local name="$2"
  [ -f "${project_dir}/${RM_STYLES_DIR}/${name}.md" ]
}

# Preset Helpers
rm_list_presets() {
  find "${RM_PLUGIN_DIR}/presets" -name '*.md' -print 2>/dev/null | while read -r f; do
    basename "$f" .md
  done
}

rm_read_preset() {
  local name="$1"
  local preset_file="${RM_PLUGIN_DIR}/presets/${name}.md"
  if [ -f "$preset_file" ]; then
    cat "$preset_file"
  else
    echo "ERROR: Preset '${name}' not found" >&2
    return 1
  fi
}

# Preview Helpers
rm_clear_preview() {
  local project_dir="${1:-.}"
  rm -f "${project_dir}/${RM_PREVIEW_DIR}"/frame-*.png
}

rm_list_preview_frames() {
  local project_dir="${1:-.}"
  find "${project_dir}/${RM_PREVIEW_DIR}" -name 'frame-*.png' -print 2>/dev/null | sort
}
