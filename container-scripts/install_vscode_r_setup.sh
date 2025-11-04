#!/usr/bin/env bash
# container-scripts/install_vscode_r_setup.sh
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
export HOME="${HOME:-/root}"  # Set HOME at the start

TARGET_USER="$(id -un)"
TARGET_HOME="$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f6 || echo "$HOME")"

echo "==> Setting up R environment for VS Code..."

# 1. Install R with binary support (if not already installed)
if ! command -v R >/dev/null 2>&1; then
  echo "[*] Installing R with bspm support..."
  curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main/container-scripts/install_r_binaries.sh | bash
fi

# 2. Install radian (better R console)
echo "[*] Installing radian..."
apt-get update -qq
apt-get install -y --no-install-recommends pipx python3-venv python3-pip

# Ensure ~/.local/bin is in PATH permanently
if ! grep -q '.local/bin' "$TARGET_HOME/.bashrc" 2>/dev/null; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$TARGET_HOME/.bashrc"
fi
export PATH="$HOME/.local/bin:$PATH"

# Install radian
if ! command -v radian >/dev/null 2>&1; then
  pip3 install --break-system-packages radian || pip3 install radian
fi

RADIAN_PATH="$(command -v radian)"
echo "[*] Radian installed at: $RADIAN_PATH"

# 3. Install R packages for VS Code
echo "[*] Installing R packages (languageserver, httpgd, shiny)..."
R --quiet --no-save <<'RSCRIPT'
if (!requireNamespace("languageserver", quietly = TRUE)) {
  install.packages("languageserver")
}
if (!requireNamespace("httpgd", quietly = TRUE)) {
  install.packages("httpgd")
}
if (!requireNamespace("shiny", quietly = TRUE)) {
  install.packages("shiny")
}
RSCRIPT

# 4. Install VS Code extensions
echo "[*] Installing VS Code extensions..."
export HOME="${HOME:-/root}"
VSCODE_CLI="/opt/code-server/bin/code-server"
USER_DATA_DIR="$HOME/.code-server-data"
EXTENSIONS_DIR="$HOME/.code-server-extensions"

"$VSCODE_CLI" \
  --user-data-dir "$USER_DATA_DIR" \
  --extensions-dir "$EXTENSIONS_DIR" \
  --install-extension REditorSupport.r 2>/dev/null || echo "R extension install queued"

"$VSCODE_CLI" \
  --user-data-dir "$USER_DATA_DIR" \
  --extensions-dir "$EXTENSIONS_DIR" \
  --install-extension RDebugger.r-debugger 2>/dev/null || echo "R Debugger install queued"

# 5. Configure VS Code settings
echo "[*] Configuring VS Code settings for R..."
SETTINGS_DIR="$USER_DATA_DIR/User"
mkdir -p "$SETTINGS_DIR"

SETTINGS_FILE="$SETTINGS_DIR/settings.json"

if [ ! -f "$SETTINGS_FILE" ]; then
  echo '{}' > "$SETTINGS_FILE"
fi

TEMP_SETTINGS=$(mktemp)
jq '. + {
  "r.rterm.linux": "'"$RADIAN_PATH"'",
  "r.alwaysUseActiveTerminal": false,
  "r.bracketedPaste": true,
  "r.plot.useHttpgd": true,
  "r.sessionWatcher": true,
  "r.source.focus": "terminal",
  "r.rterm.option": [
    "--no-save",
    "--no-restore"
  ],
  "[r]": {
    "editor.inlineSuggest.enabled": false
  }
}' "$SETTINGS_FILE" > "$TEMP_SETTINGS" && mv "$TEMP_SETTINGS" "$SETTINGS_FILE"

echo "[*] VS Code settings updated"

# 6. Configure keybindings
echo "[*] Configuring VS Code keybindings..."
KEYBINDINGS_FILE="$SETTINGS_DIR/keybindings.json"

if [ ! -f "$KEYBINDINGS_FILE" ]; then
  echo '[]' > "$KEYBINDINGS_FILE"
fi

TEMP_KEYBINDINGS=$(mktemp)
jq '. + [
  {
    "key": "ctrl+enter",
    "command": "r.runSelection",
    "when": "editorTextFocus && editorLangId == '\''r'\''"
  },
  {
    "key": "ctrl+shift+enter",
    "command": "r.runCurrentChunk",
    "when": "editorTextFocus && editorLangId == '\''r'\''"
  }
]' "$KEYBINDINGS_FILE" > "$TEMP_KEYBINDINGS" && mv "$TEMP_KEYBINDINGS" "$KEYBINDINGS_FILE"

echo "[*] VS Code keybindings updated"

# 7. Create VS Code task for Shiny apps
echo "[*] Creating VS Code task for Shiny apps..."
TASKS_FILE="$SETTINGS_DIR/tasks.json"

if [ ! -f "$TASKS_FILE" ]; then
  echo '{"version": "2.0.0", "tasks": []}' > "$TASKS_FILE"
fi

TEMP_TASKS=$(mktemp)
jq '.tasks += [{
  "label": "Run Shiny App",
  "type": "shell",
  "command": "Rscript",
  "args": [
    "-e",
    "shiny::runApp(dirname('\''${file}'\''), host='\''0.0.0.0'\'', port=3838, launch.browser=TRUE)"
  ],
  "problemMatcher": [],
  "presentation": {
    "reveal": "always",
    "panel": "dedicated",
    "focus": true
  }
}]' "$TASKS_FILE" > "$TEMP_TASKS" && mv "$TEMP_TASKS" "$TASKS_FILE"

echo "[*] VS Code task created"

# 8. Add F5 keybinding for Shiny apps
echo "[*] Adding F5 keybinding for Shiny apps..."
TEMP_KEYBINDINGS=$(mktemp)
jq '. + [
  {
    "key": "f5",
    "command": "workbench.action.tasks.runTask",
    "args": "Run Shiny App",
    "when": "editorTextFocus && resourceFilename =~ /app\\\\.R$/"
  }
]' "$KEYBINDINGS_FILE" > "$TEMP_KEYBINDINGS" && mv "$TEMP_KEYBINDINGS" "$KEYBINDINGS_FILE"

echo "[*] F5 keybinding configured"

echo ""
echo "✅ VS Code R environment setup complete!"
echo ""
echo "Configuration summary:"
echo "  - Radian: $RADIAN_PATH"
echo "  - R packages: languageserver, httpgd, shiny"
echo ""
echo "Keybindings:"
echo "  - Ctrl+Enter: Run current line/selection"
echo "  - Ctrl+Shift+Enter: Run current chunk"
echo "  - F5: Run Shiny app (for *app.R files)"
echo ""
echo "Next steps:"
echo "  1. Restart VS Code Server"
echo "  2. Open an R file and press Ctrl+Enter"
echo "  3. Plots appear in PLOTS panel"