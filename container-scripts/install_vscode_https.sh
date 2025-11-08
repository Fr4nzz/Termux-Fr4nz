#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "==> Setting up HTTPS for VS Code Server..."

# 1. Install mkcert
echo "[*] Installing mkcert..."
apt-get update -qq
apt-get install -y --no-install-recommends wget libnss3-tools python3

MKCERT_VERSION="v1.4.4"
ARCH="$(dpkg --print-architecture)"
case "$ARCH" in
  arm64|aarch64) MKCERT_ARCH="linux-arm64" ;;
  amd64|x86_64)  MKCERT_ARCH="linux-amd64" ;;
  *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

wget -q "https://github.com/FiloSottile/mkcert/releases/download/${MKCERT_VERSION}/mkcert-${MKCERT_VERSION}-${MKCERT_ARCH}" \
  -O /usr/local/bin/mkcert
chmod +x /usr/local/bin/mkcert

# 2. Create local CA and certificates
echo "[*] Creating local certificate authority..."
export HOME="${HOME:-/root}"
mkdir -p "$HOME/.local/share/mkcert"

# Install local CA
mkcert -install

# Get local IP using myip helper
LOCAL_IP=$(myip 2>/dev/null || echo "127.0.0.1")

# Generate certificate for localhost, IPs, and wildcard for local network
echo "[*] Generating certificates for localhost, $LOCAL_IP, and wildcards..."
mkdir -p /opt/code-server-certs
cd /opt/code-server-certs

# Include wildcards so cert works even if IP changes
mkcert localhost 127.0.0.1 "$LOCAL_IP" ::1 "*.local" "*.lan"

# Rename to simple names
mv ./localhost+*[0-9].pem cert.pem 2>/dev/null || mv ./localhost+*.pem cert.pem
mv ./localhost+*-key.pem key.pem

chmod 600 key.pem
chmod 644 cert.pem

echo "[*] Certificates created at /opt/code-server-certs/"

# 3. Create HTTPS wrapper with HTTP/HTTPS flag support
mkdir -p /usr/local/bin
tee /usr/local/bin/code-server-https >/dev/null <<'SCRIPT'
#!/bin/sh
set -e

# Parse flags
USE_HTTPS=false
PORT="13338"

while [ $# -gt 0 ]; do
  case "$1" in
    --https) USE_HTTPS=true; shift ;;
    --port) PORT="$2"; shift 2 ;;
    *) PORT="$1"; shift ;;
  esac
done

export HOME="${HOME:-/root}"
mkdir -p "$HOME/.code-server-data" "$HOME/.code-server-extensions"

# Clear problematic environment variables
unset SHELL ZDOTDIR ZSH OH_MY_ZSH

LOCAL_IP=$(myip 2>/dev/null || echo "127.0.0.1")

if [ "$USE_HTTPS" = "true" ]; then
  CERT_DIR="/opt/code-server-certs"
  
  if [ ! -f "$CERT_DIR/cert.pem" ]; then
    echo "❌ HTTPS certificates not found. Run: cert-server"
    exit 1
  fi
  
  echo "========================================="
  echo "VS Code Server (HTTPS)"
  echo "========================================="
  echo ""
  echo "🔒 HTTPS enabled:"
  echo "   https://$LOCAL_IP:$PORT (LAN)"
  echo ""
  echo "📥 First time? Install certificate:"
  echo "   http://$LOCAL_IP:8889/setup"
  echo ""
  echo "💡 Zoom UI: Ctrl+Plus/Minus or pinch gesture"
  echo ""
  echo "Press Ctrl+C to stop"
  echo "========================================="

  exec /opt/code-server/bin/code-server \
    --bind-addr "0.0.0.0:$PORT" \
    --cert "$CERT_DIR/cert.pem" \
    --cert-key "$CERT_DIR/key.pem" \
    --auth none \
    --user-data-dir "$HOME/.code-server-data" \
    --extensions-dir "$HOME/.code-server-extensions" \
    --disable-telemetry \
    --disable-update-check
else
  echo "========================================="
  echo "VS Code Server (HTTP)"
  echo "========================================="
  echo ""
  echo "Access: http://127.0.0.1:$PORT"
  echo "LAN:    http://$LOCAL_IP:$PORT"
  echo ""
  echo "💡 For HTTPS: code-server-https --https"
  echo "💡 Zoom UI: Ctrl+Plus/Minus or pinch gesture"
  echo ""
  echo "Press Ctrl+C to stop"
  echo "========================================="

  exec /opt/code-server/bin/code-server \
    --bind-addr "0.0.0.0:$PORT" \
    --auth none \
    --user-data-dir "$HOME/.code-server-data" \
    --extensions-dir "$HOME/.code-server-extensions" \
    --disable-telemetry \
    --disable-update-check
fi
SCRIPT
chmod 0755 /usr/local/bin/code-server-https

# 4. Export CA certificate for installation
CA_CERT="$(mkcert -CAROOT)/rootCA.pem"
cp "$CA_CERT" /opt/code-server-certs/rootCA.pem
chmod 644 /opt/code-server-certs/rootCA.pem

# 5. Create setup page with inline commands (more transparent)
mkdir -p /opt/code-server-certs/setup
cd /opt/code-server-certs/setup

# Create HTML setup page
cat > index.html <<'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>VS Code Server - Certificate Setup</title>
    <style>
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            max-width: 900px; 
            margin: 50px auto; 
            padding: 20px;
            background: #f5f5f5;
        }
        h1 { color: #007acc; margin-bottom: 10px; }
        .subtitle { color: #666; margin-bottom: 30px; }
        .download-btn { 
            display: inline-block; 
            padding: 12px 24px; 
            background: #007acc; 
            color: white; 
            text-decoration: none; 
            border-radius: 5px; 
            margin: 15px 0;
            font-weight: 600;
        }
        .download-btn:hover { background: #005a9e; }
        pre { 
            background: #2d2d2d; 
            color: #f8f8f2;
            padding: 20px; 
            border-radius: 5px; 
            overflow-x: auto;
            border-left: 4px solid #007acc;
            margin: 15px 0;
        }
        .section { 
            margin: 30px 0; 
            padding: 25px; 
            background: white;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        code { 
            background: #e8e8e8; 
            padding: 3px 8px; 
            border-radius: 3px;
            font-family: 'Consolas', 'Monaco', monospace;
            font-size: 0.9em;
        }
        .copy-btn {
            background: #28a745;
            color: white;
            border: none;
            padding: 8px 16px;
            border-radius: 4px;
            cursor: pointer;
            font-size: 0.9em;
            margin-left: 10px;
        }
        .copy-btn:hover { background: #218838; }
        .command-box {
            position: relative;
            margin: 15px 0;
        }
        .os-icon { font-size: 1.5em; margin-right: 10px; }
        .warning {
            background: #fff3cd;
            border-left: 4px solid #ffc107;
            padding: 15px;
            margin: 15px 0;
            border-radius: 4px;
        }
        .success {
            background: #d4edda;
            border-left: 4px solid #28a745;
            padding: 15px;
            margin: 15px 0;
            border-radius: 4px;
        }
        ol { line-height: 1.8; }
        .step { font-weight: 600; color: #007acc; }
    </style>
    <script>
        function copyToClipboard(elementId) {
            const text = document.getElementById(elementId).textContent;
            navigator.clipboard.writeText(text).then(() => {
                const btn = event.target;
                const originalText = btn.textContent;
                btn.textContent = '✓ Copied!';
                btn.style.background = '#218838';
                setTimeout(() => {
                    btn.textContent = originalText;
                    btn.style.background = '#28a745';
                }, 2000);
            });
        }
    </script>
</head>
<body>
    <h1>🔒 VS Code Server - HTTPS Certificate Setup</h1>
    <p class="subtitle">Install the certificate to access VS Code Server securely from your laptop</p>
    
    <div class="section">
        <h2>📥 Step 1: Download Certificate</h2>
        <p>First, download the root certificate:</p>
        <a href="../rootCA.pem" class="download-btn" download>⬇️ Download rootCA.pem</a>
        <div class="warning">
            <strong>Note:</strong> This certificate was generated on your phone and is unique to your setup. It's safe to install.
        </div>
    </div>

    <div class="section">
        <h2><span class="os-icon">💻</span>Windows Installation</h2>
        
        <h3 class="step">Option 1: PowerShell (Automatic - Recommended)</h3>
        <p>Open <strong>PowerShell as Administrator</strong> and run:</p>
        <div class="command-box">
            <pre id="win-cmd1">$url = "http://YOUR_PHONE_IP:8889/rootCA.pem"
$cert = "$env:TEMP\mkcert-rootCA.pem"
Invoke-WebRequest -Uri $url -OutFile $cert
Import-Certificate -FilePath $cert -CertStoreLocation Cert:\CurrentUser\Root
Write-Host "✅ Certificate installed! Restart your browser."</pre>
            <button class="copy-btn" onclick="copyToClipboard('win-cmd1')">📋 Copy</button>
        </div>
        
        <h3 class="step">Option 2: Manual Installation</h3>
        <ol>
            <li>Download the certificate using the button above</li>
            <li>Right-click on <code>rootCA.pem</code> → <strong>Install Certificate</strong></li>
            <li>Select <strong>Current User</strong> → Next</li>
            <li>Choose <strong>"Place all certificates in the following store"</strong> → Browse</li>
            <li>Select <strong>"Trusted Root Certification Authorities"</strong> → OK</li>
            <li>Click Next → Finish → Yes to security warning</li>
            <li><strong>Restart your browser</strong></li>
        </ol>
    </div>

    <div class="section">
        <h2><span class="os-icon">🐧</span>Linux Installation</h2>
        
        <h3 class="step">Ubuntu/Debian</h3>
        <p>Open terminal and run:</p>
        <div class="command-box">
            <pre id="linux-cmd1">wget http://YOUR_PHONE_IP:8889/rootCA.pem -O /tmp/mkcert-rootCA.pem
sudo cp /tmp/mkcert-rootCA.pem /usr/local/share/ca-certificates/mkcert-root.crt
sudo update-ca-certificates
echo "✅ Certificate installed! Restart your browser."</pre>
            <button class="copy-btn" onclick="copyToClipboard('linux-cmd1')">📋 Copy</button>
        </div>
        
        <h3 class="step">Fedora/RHEL/CentOS</h3>
        <div class="command-box">
            <pre id="linux-cmd2">wget http://YOUR_PHONE_IP:8889/rootCA.pem -O /tmp/mkcert-rootCA.pem
sudo cp /tmp/mkcert-rootCA.pem /etc/pki/ca-trust/source/anchors/mkcert-root.crt
sudo update-ca-trust
echo "✅ Certificate installed! Restart your browser."</pre>
            <button class="copy-btn" onclick="copyToClipboard('linux-cmd2')">📋 Copy</button>
        </div>

        <h3 class="step">Arch Linux</h3>
        <div class="command-box">
            <pre id="linux-cmd3">wget http://YOUR_PHONE_IP:8889/rootCA.pem -O /tmp/mkcert-rootCA.pem
sudo cp /tmp/mkcert-rootCA.pem /etc/ca-certificates/trust-source/anchors/mkcert-root.crt
sudo trust extract-compat
echo "✅ Certificate installed! Restart your browser."</pre>
            <button class="copy-btn" onclick="copyToClipboard('linux-cmd3')">📋 Copy</button>
        </div>
    </div>

    <div class="section">
        <h2><span class="os-icon">🍎</span>macOS Installation</h2>
        
        <h3 class="step">Terminal Command</h3>
        <p>Open Terminal and run:</p>
        <div class="command-box">
            <pre id="mac-cmd1">curl -o /tmp/mkcert-rootCA.pem http://YOUR_PHONE_IP:8889/rootCA.pem
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain /tmp/mkcert-rootCA.pem
echo "✅ Certificate installed! Restart your browser."</pre>
            <button class="copy-btn" onclick="copyToClipboard('mac-cmd1')">📋 Copy</button>
        </div>
        
        <div class="warning">
            <strong>Note:</strong> You'll be prompted for your password when using <code>sudo</code>.
        </div>
    </div>

    <div class="section">
        <h2>✅ Step 2: Verify Installation</h2>
        <p>After installing the certificate and restarting your browser:</p>
        <ol>
            <li>Visit: <a href="https://YOUR_PHONE_IP:13338" target="_blank"><strong>https://YOUR_PHONE_IP:13338</strong></a></li>
            <li>You should see a <span style="color: #28a745;">🔒 green lock</span> in the address bar with no warnings</li>
            <li>VS Code Server should load successfully!</li>
        </ol>
        
        <div class="success">
            <strong>Success!</strong> You can now use clipboard operations, webviews, and all VS Code features securely over HTTPS.
        </div>
    </div>

    <div class="section">
        <h2>🔧 Troubleshooting</h2>
        
        <h3>Certificate not trusted?</h3>
        <ul>
            <li><strong>Restart your browser</strong> after installation (important!)</li>
            <li>Clear browser cache and cookies</li>
            <li>On Windows: Make sure you imported to <code>Trusted Root Certification Authorities</code>, not Personal</li>
            <li>On Linux: Run <code>sudo update-ca-certificates</code> again</li>
            <li>On macOS: Check System Preferences → Profiles to verify the certificate is installed</li>
        </ul>

        <h3>Still not working?</h3>
        <ul>
            <li>Verify the certificate downloaded correctly (should be ~1-2 KB)</li>
            <li>Try accessing from incognito/private mode (clears cache)</li>
            <li>Make sure your phone IP hasn't changed: <strong>YOUR_PHONE_IP</strong></li>
            <li>Re-download and reinstall the certificate</li>
        </ul>
    </div>

    <div class="section">
        <h2>ℹ️ About This Certificate</h2>
        <p>This is a locally-generated certificate authority (CA) created specifically for your VS Code Server setup. It's:</p>
        <ul>
            <li>✅ Generated on your phone, unique to you</li>
            <li>✅ Only valid for your local network</li>
            <li>✅ Safe to install on your devices</li>
            <li>✅ Not sent over the internet</li>
        </ul>
        <p>The certificate allows your browser to trust the HTTPS connection to your phone, enabling secure features like clipboard access and iframe content.</p>
    </div>
</body>
</html>
HTML

# Replace placeholder IP in HTML
sed -i "s/YOUR_PHONE_IP/$LOCAL_IP/g" index.html

# 6. Create certificate server wrapper
tee /usr/local/bin/cert-server >/dev/null <<'SCRIPT'
#!/bin/sh
set -e
PORT="${1:-8889}"
LOCAL_IP=$(myip 2>/dev/null || echo "127.0.0.1")

cd /opt/code-server-certs

echo "========================================="
echo "Certificate Server"
echo "========================================="
echo ""
echo "📥 Setup page:"
echo "   http://$LOCAL_IP:$PORT/setup"
echo ""
echo "Direct download:"
echo "   http://$LOCAL_IP:$PORT/rootCA.pem"
echo ""
echo "Open the setup page on your laptop browser"
echo "for installation instructions!"
echo ""
echo "Press Ctrl+C to stop"
echo "========================================="

exec python3 -m http.server "$PORT"
SCRIPT
chmod 0755 /usr/local/bin/cert-server

echo ""
echo "✅ HTTPS setup complete!"
echo ""
echo "========================================="
echo "Quick Start:"
echo "========================================="
echo ""
echo "1. Start certificate server (for LAN access):"
echo "   cert-server"
echo ""
echo "2. On your laptop, open browser:"
echo "   http://$LOCAL_IP:8889/setup"
echo ""
echo "3. Follow instructions to install certificate"
echo ""
echo "4. Start VS Code Server:"
echo "   code-server-https          # HTTP mode (localhost)"
echo "   code-server-https --https  # HTTPS mode (LAN)"
echo ""
echo "Commands:"
echo "  cert-server              - Start certificate download server"
echo "  code-server-https        - Start VS Code (HTTP by default)"
echo "  code-server-https --https - Start VS Code with HTTPS"
