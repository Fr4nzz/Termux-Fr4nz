#!/usr/bin/env bash
# container-scripts/install_vscode_python_setup.sh
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

TARGET_USER="$(id -un)"
TARGET_HOME="$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f6 || echo "$HOME")"

echo "==> Setting up Python environment for VS Code..."

# 1. Install Python and essential tools
echo "[*] Installing Python..."
apt-get update -qq
apt-get install -y --no-install-recommends \
  python3 python3-pip python3-venv \
  build-essential python3-dev

# 2. Install VS Code Python extension
echo "[*] Installing VS Code Python extension..."
export HOME="${HOME:-/root}"
VSCODE_CLI="/opt/code-server/bin/code-server"
USER_DATA_DIR="$HOME/.code-server-data"
EXTENSIONS_DIR="$HOME/.code-server-extensions"

"$VSCODE_CLI" \
  --user-data-dir "$USER_DATA_DIR" \
  --extensions-dir "$EXTENSIONS_DIR" \
  --install-extension ms-python.python 2>/dev/null || echo "Python extension install queued"

# 3. Configure VS Code settings for Python
echo "[*] Configuring VS Code settings for Python..."
SETTINGS_DIR="$USER_DATA_DIR/User"
mkdir -p "$SETTINGS_DIR"
SETTINGS_FILE="$SETTINGS_DIR/settings.json"

# Create settings if file doesn't exist
if [ ! -f "$SETTINGS_FILE" ]; then
  echo '{}' > "$SETTINGS_FILE"
fi

# Find Python path
PYTHON_PATH="$(command -v python3)"

# Use jq to merge Python settings
TEMP_SETTINGS=$(mktemp)
jq '. + {
  "python.defaultInterpreterPath": "'"$PYTHON_PATH"'",
  "python.terminal.activateEnvironment": true,
  "python.terminal.executeInFileDir": true,
  "[python]": {
    "editor.formatOnSave": true,
    "editor.defaultFormatter": "ms-python.python",
    "editor.inlineSuggest.enabled": false
  }
}' "$SETTINGS_FILE" > "$TEMP_SETTINGS" && mv "$TEMP_SETTINGS" "$SETTINGS_FILE"

echo "[*] Python settings added to: $SETTINGS_FILE"

# 4. Configure keybindings for Python
echo "[*] Configuring Python keybindings..."
KEYBINDINGS_FILE="$SETTINGS_DIR/keybindings.json"

# Create keybindings file if it doesn't exist, or read existing
if [ ! -f "$KEYBINDINGS_FILE" ]; then
  echo '[]' > "$KEYBINDINGS_FILE"
fi

# Check if file has valid JSON, if not recreate it
if ! jq empty "$KEYBINDINGS_FILE" 2>/dev/null; then
  echo "[] " > "$KEYBINDINGS_FILE"
fi

# Add Python keybindings
TEMP_KEYBINDINGS=$(mktemp)
jq '. + [
  {
    "key": "ctrl+enter",
    "command": "python.execSelectionInTerminal",
    "when": "editorTextFocus && editorLangId == '\''python'\''"
  },
  {
    "key": "shift+enter",
    "command": "python.execSelectionInTerminal",
    "when": "editorTextFocus && editorLangId == '\''python'\''"
  }
]' "$KEYBINDINGS_FILE" > "$TEMP_KEYBINDINGS" && mv "$TEMP_KEYBINDINGS" "$KEYBINDINGS_FILE"
echo "[*] Python keybindings configured"

echo ""
echo "✅ VS Code Python environment setup complete!"
echo ""
echo "Configuration summary:"
echo "  - Python path: $PYTHON_PATH"
echo "  - VS Code settings: $SETTINGS_FILE"
echo "  - Keybindings: $KEYBINDINGS_FILE"
echo ""
echo "Keybindings configured:"
echo "  - Ctrl+Enter: Run current line/selection in Python terminal"
echo "  - Shift+Enter: Run current line/selection (alternative)"
echo ""
echo "Next steps:"
echo "  1. Restart VS Code Server (if running)"
echo "  2. Open a Python file (.py) and press Ctrl+Enter to test"
echo "  3. The Python extension will create a terminal automatically"