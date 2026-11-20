#!/bin/sh
set -eu

# Flutter's native build hooks use PATH but may drop DEVELOPER_DIR.
# Use the same Xcode SDK in those hooks as in the enclosing build.
tool_dir="${TARGET_TEMP_DIR}/pixez-tools"
mkdir -p "$tool_dir"
printf '%s\n' "$DEVELOPER_DIR" > "$tool_dir/developer-directory"
cat > "$tool_dir/xcrun" <<'WRAPPER'
#!/bin/sh
IFS= read -r DEVELOPER_DIR < "${0%/*}/developer-directory"
export DEVELOPER_DIR
exec /usr/bin/xcrun "$@"
WRAPPER
chmod +x "$tool_dir/xcrun"

rust_bin="${PIXEZ_RUST_BIN:-${CARGO_HOME:-$HOME/.cargo}/bin}"
export PATH="$tool_dir:$rust_bin:$PATH"
exec /bin/sh "$FLUTTER_ROOT/packages/flutter_tools/bin/xcode_backend.sh" "$@"
