<#
.SYNOPSIS
  Auto-discover Termux on the local network and SSH into it.
.PARAMETER User
  Termux username (from 'whoami' in Termux). If omitted, you'll be prompted.
.EXAMPLE
  .\connect-termux.ps1 u0_a598
#>
param(
    [string]$User
)

$Port      = 8022
$TimeoutMs = 400

# --- Find local subnet prefixes (prefer DHCP/Wi-Fi, scan all LAN interfaces) ---
$adapters = Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' -and $_.PrefixOrigin -ne 'WellKnown' } |
    Sort-Object { if ($_.PrefixOrigin -eq 'Dhcp') { 0 } else { 1 } }

if (-not $adapters) {
    Write-Host "Could not find any network adapters." -ForegroundColor Red
    exit 1
}

# Scan each unique subnet until we find Termux
$found = @()
$scannedPrefixes = @()

foreach ($adapter in $adapters) {
    $prefix = $adapter.IPAddress -replace '\.\d+$', ''
    if ($scannedPrefixes -contains $prefix) { continue }
    $scannedPrefixes += $prefix

    Write-Host "Scanning ${prefix}.1-254 ($(($adapter).InterfaceAlias))..." -ForegroundColor Cyan

    # Fire 254 async TCP connections at once
    $clients = @{}
    1..254 | ForEach-Object {
        $target = "$prefix.$_"
        $client = New-Object System.Net.Sockets.TcpClient
        $clients[$target] = @{
            Client = $client
            Task   = $client.ConnectAsync($target, $Port)
        }
    }

    Start-Sleep -Milliseconds $TimeoutMs

    foreach ($kv in $clients.GetEnumerator()) {
        $ok = $kv.Value.Task.Status -eq 'RanToCompletion'
        try { $kv.Value.Client.Dispose() } catch {}
        if ($ok) { $found += $kv.Key }
    }

    if ($found.Count -gt 0) { break }
}

if ($found.Count -eq 0) {
    Write-Host "No device with port $Port found on the network." -ForegroundColor Red
    exit 1
}

$target = $found[0]
if ($found.Count -gt 1) {
    Write-Host "Multiple devices found:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $found.Count; $i++) {
        Write-Host "  [$i] $($found[$i])"
    }
    $choice = Read-Host "Pick a number (default 0)"
    if ($choice -match '^\d+$') { $target = $found[[int]$choice] }
}

Write-Host "Found Termux at $target" -ForegroundColor Green

# --- Save discovered IP for quick-connect alias ---
$cacheDir = "$env:USERPROFILE\.termux"
if (-not (Test-Path $cacheDir)) { New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null }
Set-Content -Path "$cacheDir\last-ip" -Value $target -NoNewline
Write-Host "Saved IP to ~/.termux/last-ip (use 'termux' alias to reconnect)" -ForegroundColor DarkGray

# --- Prompt for username if not given ---
if (-not $User) {
    $User = Read-Host "Termux username (run 'whoami' on phone)"
}

Set-Content -Path "$cacheDir\last-user" -Value $User -NoNewline

# --- Ensure SSH key is set up ---
$keyPath = "$env:USERPROFILE\.ssh\id_ed25519"
$pubPath = "${keyPath}.pub"

# Generate key if it doesn't exist
if (-not (Test-Path $pubPath)) {
    Write-Host "No SSH key found. Generating one..." -ForegroundColor Yellow
    ssh-keygen -t ed25519 -f $keyPath -N '""' -q
    Write-Host "SSH key generated." -ForegroundColor Green
}

# Test if key auth already works (BatchMode fails if password is needed)
$testResult = ssh -o BatchMode=yes -o ConnectTimeout=3 -p $Port "${User}@${target}" "echo ok" 2>&1
if ($testResult -ne 'ok') {
    Write-Host "Copying SSH key to Termux (enter password one last time)..." -ForegroundColor Yellow
    Get-Content $pubPath | ssh -p $Port "${User}@${target}" "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
    Write-Host "Key installed. Future connections will be passwordless." -ForegroundColor Green
}

# --- Connect ---
ssh -p $Port "${User}@${target}"
