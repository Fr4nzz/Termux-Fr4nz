<#
.SYNOPSIS
  Quick SSH into Termux using the last discovered IP.
  Run connect-termux.ps1 first to discover and cache the phone's IP.
.EXAMPLE
  .\termux.ps1           # connect using cached IP
  .\termux.ps1 ls        # run a command and exit
#>
param(
    [Parameter(ValueFromRemainingArguments)]
    [string[]]$Command
)

$Port     = 8022
$cacheDir = "$env:USERPROFILE\.termux"
$ipFile   = "$cacheDir\last-ip"
$userFile = "$cacheDir\last-user"

if (-not (Test-Path $ipFile) -or -not (Test-Path $userFile)) {
    Write-Host "No cached connection. Run connect-termux.ps1 first to discover your phone." -ForegroundColor Yellow
    exit 1
}

$ip   = (Get-Content $ipFile).Trim()
$user = (Get-Content $userFile).Trim()

if ($Command) {
    $cmd = $Command -join ' '
    ssh -o ConnectTimeout=5 -p $Port "${user}@${ip}" $cmd
} else {
    ssh -o ConnectTimeout=5 -p $Port "${user}@${ip}"
}
