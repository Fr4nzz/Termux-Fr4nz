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

# Get local IP
LOCAL_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "127.0.0.1")

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

# 3. Create HTTPS wrapper
mkdir -p /usr/local/bin
tee /usr/local/bin/code-server-https >/dev/null <<'SCRIPT'
#!/bin/sh
set -e
PORT="${1:-13338}"
export HOME="${HOME:-/root}"
mkdir -p "$HOME/.code-server-data" "$HOME/.code-server-extensions"

CERT_DIR="/opt/code-server-certs"
LOCAL_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "N/A")

echo "========================================="
echo "VS Code Server (HTTPS)"
echo "========================================="
echo ""
echo "🔒 Access via HTTPS:"
echo "   https://127.0.0.1:$PORT (localhost)"
echo "   https://$LOCAL_IP:$PORT (LAN)"
echo ""
echo "📥 First time? Install certificate:"
echo "   http://$LOCAL_IP:8889/setup"
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
SCRIPT
chmod 0755 /usr/local/bin/code-server-https

# 4. Export CA certificate for installation
CA_CERT="$(mkcert -CAROOT)/rootCA.pem"
cp "$CA_CERT" /opt/code-server-certs/rootCA.pem
chmod 644 /opt/code-server-certs/rootCA.pem

# 5. Create setup page and scripts
mkdir -p /opt/code-server-certs/setup
cd /opt/code-server-certs/setup

# Create HTML setup page with proper encoding
cat > index.html <<'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>VS Code Server - Certificate Setup</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; }
        h1 { color: #007acc; }
        .download-btn { display: inline-block; padding: 10px 20px; background: #007acc; color: white; 
                       text-decoration: none; border-radius: 5px; margin: 10px 0; }
        .download-btn:hover { background: #005a9e; }
        pre { background: #f5f5f5; padding: 15px; border-radius: 5px; overflow-x: auto; }
        .section { margin: 30px 0; padding: 20px; border: 1px solid #ddd; border-radius: 5px; }
        code { background: #e8e8e8; padding: 2px 6px; border-radius: 3px; }
    </style>
</head>
<body>
    <h1>&#128274; VS Code Server - Certificate Setup</h1>
    
    <div class="section">
        <h2>&#128229; Step 1: Download Certificate</h2>
        <a href="../rootCA.pem" class="download-btn" download>Download rootCA.pem</a>
    </div>

    <div class="section">
        <h2>&#128187; Windows Installation</h2>
        <p><strong>Option 1: Automatic (PowerShell as Admin)</strong></p>
        <pre>Invoke-WebRequest -Uri "http://YOUR_PHONE_IP:8889/install-windows.ps1" -OutFile "$env:TEMP\install-cert.ps1"
PowerShell -ExecutionPolicy Bypass -File "$env:TEMP\install-cert.ps1"</pre>
        
        <p><strong>Option 2: Manual</strong></p>
        <ol>
            <li>Download the certificate above</li>
            <li>Right-click <code>rootCA.pem</code> &rarr; "Install Certificate"</li>
            <li>Select "Current User" &rarr; Next</li>
            <li>Choose "Place all certificates in the following store" &rarr; Browse</li>
            <li>Select "Trusted Root Certification Authorities" &rarr; OK</li>
            <li>Next &rarr; Finish &rarr; Yes to security warning</li>
            <li>Restart browser</li>
        </ol>
    </div>

    <div class="section">
        <h2>&#128039; Linux Installation</h2>
        <p><strong>Automatic Script:</strong></p>
        <pre>curl -fsSL http://YOUR_PHONE_IP:8889/install-linux.sh | bash</pre>
        
        <p><strong>Manual:</strong></p>
        <pre>wget http://YOUR_PHONE_IP:8889/rootCA.pem
sudo cp rootCA.pem /usr/local/share/ca-certificates/mkcert-root.crt
sudo update-ca-certificates</pre>
    </div>

    <div class="section">
        <h2>&#127823; macOS Installation</h2>
        <p><strong>Automatic Script:</strong></p>
        <pre>curl -fsSL http://YOUR_PHONE_IP:8889/install-macos.sh | bash</pre>
        
        <p><strong>Manual:</strong></p>
        <pre>curl -O http://YOUR_PHONE_IP:8889/rootCA.pem
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain rootCA.pem</pre>
    </div>

    <div class="section">
        <h2>&#9989; Verify Installation</h2>
        <p>After installing, go to: <a href="https://YOUR_PHONE_IP:13338" target="_blank">https://YOUR_PHONE_IP:13338</a></p>
        <p>You should see a green lock &#128274; with no warnings!</p>
    </div>

    <div class="section">
        <h2>&#128161; Troubleshooting</h2>
        <p><strong>Certificate still not working?</strong></p>
        <ul>
            <li>Make sure you restarted your browser after installation</li>
            <li>Try clearing browser cache and cookies</li>
            <li>On Windows, make sure you imported to "Trusted Root Certification Authorities"</li>
            <li>On Linux/macOS, you may need to restart the browser or run <code>sudo update-ca-certificates</code></li>
        </ul>
    </div>
</body>
</html>
HTML

# Windows installation script
cat > install-windows.ps1 <<'PS1'
# Download certificate
$certUrl = "http://YOUR_PHONE_IP:8889/rootCA.pem"
$certPath = "$env:TEMP\mkcert-rootCA.pem"
Invoke-WebRequest -Uri $certUrl -OutFile $certPath

# Import to Trusted Root
Import-Certificate -FilePath $certPath -CertStoreLocation Cert:\CurrentUser\Root

Write-Host "✅ Certificate installed successfully!"
Write-Host "Please restart your browser."
PS1

# Linux installation script
cat > install-linux.sh <<'BASH'
#!/bin/bash
set -e

PHONE_IP="YOUR_PHONE_IP"
CERT_URL="http://$PHONE_IP:8889/rootCA.pem"

echo "Downloading certificate..."
wget -q "$CERT_URL" -O /tmp/mkcert-rootCA.pem

echo "Installing certificate..."
sudo cp /tmp/mkcert-rootCA.pem /usr/local/share/ca-certificates/mkcert-root.crt
sudo update-ca-certificates

echo "✅ Certificate installed successfully!"
echo "Restart your browser to apply changes."
BASH
chmod +x install-linux.sh

# macOS installation script
cat > install-macos.sh <<'BASH'
#!/bin/bash
set -e

PHONE_IP="YOUR_PHONE_IP"
CERT_URL="http://$PHONE_IP:8889/rootCA.pem"

echo "Downloading certificate..."
curl -fL "$CERT_URL" -o /tmp/mkcert-rootCA.pem

echo "Installing certificate (requires sudo)..."
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain /tmp/mkcert-rootCA.pem

echo "✅ Certificate installed successfully!"
echo "Restart your browser to apply changes."
BASH
chmod +x install-macos.sh

# Replace placeholder IP in all files
cd /opt/code-server-certs/setup
sed -i "s/YOUR_PHONE_IP/$LOCAL_IP/g" index.html install-windows.ps1 install-linux.sh install-macos.sh

# 6. Create certificate server wrapper
tee /usr/local/bin/cert-server >/dev/null <<'SCRIPT'
#!/bin/sh
set -e
PORT="${1:-8889}"
LOCAL_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "127.0.0.1")

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
echo "for installation instructions and scripts!"
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
echo "1. Start certificate server:"
echo "   cert-server"
echo ""
echo "2. On your laptop, open browser:"
echo "   http://$LOCAL_IP:8889/setup"
echo ""
echo "3. Follow instructions to install certificate"
echo ""
echo "4. Start HTTPS server:"
echo "   code-server-https"
echo ""
echo "5. Access VS Code:"
echo "   https://$LOCAL_IP:13338"
echo ""
echo "Commands:"
echo "  cert-server           - Start certificate download server"
echo "  code-server-https     - Start VS Code with HTTPS"
