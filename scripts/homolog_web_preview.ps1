# Web homologation link via Firebase Hosting PREVIEW CHANNEL.
# Never runs `firebase deploy` (live site stays untouched). Channel expires automatically.
# Usage (from repo root):  powershell -ExecutionPolicy Bypass -File scripts\homolog_web_preview.ps1
param(
  [string]$Channel = 'homolog',
  [string]$Expires = '7d',
  [string]$Project = 'carajas360-a17c5'
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

flutter build web --release --no-wasm-dry-run
if ($LASTEXITCODE -ne 0) { throw 'flutter build web failed' }

$stamp = Get-Date -Format 'yyyyMMddHHmmss'
$site = Join-Path $root 'build\homolog_site'
$public = Join-Path $site 'public'
if (Test-Path $site) { Remove-Item $site -Recurse -Force }
New-Item -ItemType Directory -Path $public | Out-Null
Copy-Item -Path (Join-Path $root 'build\web\*') -Destination $public -Recurse
foreach ($page in 'privacy.html', 'terms.html', 'account-deletion.html', 'support.html') {
  Copy-Item -Path (Join-Path $root "hosting\$page") -Destination $public
}

# Cache-bust: browsers estavam servindo main.dart.js antigo.
$indexPath = Join-Path $public 'index.html'
$index = [IO.File]::ReadAllText($indexPath)
$index = $index.Replace('flutter_bootstrap.js', "flutter_bootstrap.js?v=$stamp")
if ($index -notmatch 'Cache-Control') {
  $index = $index.Replace('<head>', "<head>`n  <meta http-equiv=`"Cache-Control`" content=`"no-cache, no-store, must-revalidate`"/>")
}
[IO.File]::WriteAllText($indexPath, $index, (New-Object Text.UTF8Encoding $false))

foreach ($jsName in @('flutter_bootstrap.js', 'flutter.js')) {
  $jsPath = Join-Path $public $jsName
  if (-not (Test-Path $jsPath)) { continue }
  $js = [IO.File]::ReadAllText($jsPath)
  $js = $js.Replace('main.dart.js', "main.dart.js?v=$stamp")
  [IO.File]::WriteAllText($jsPath, $js, (New-Object Text.UTF8Encoding $false))
}
[IO.File]::WriteAllText((Join-Path $public 'build_stamp.txt'), "v=$stamp`nchannel=$Channel`n", (New-Object Text.UTF8Encoding $false))

$config = @'
{
  "hosting": {
    "public": "public",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
    "headers": [
      {
        "source": "/index.html",
        "headers": [{ "key": "Cache-Control", "value": "no-cache, no-store, must-revalidate" }]
      },
      {
        "source": "**/*.js",
        "headers": [{ "key": "Cache-Control", "value": "no-cache, max-age=0, must-revalidate" }]
      },
      {
        "source": "/build_stamp.txt",
        "headers": [{ "key": "Cache-Control", "value": "no-cache" }]
      }
    ],
    "rewrites": [
      { "source": "/privacy", "destination": "/privacy.html" },
      { "source": "/terms", "destination": "/terms.html" },
      { "source": "/account-deletion", "destination": "/account-deletion.html" },
      { "source": "/support", "destination": "/support.html" },
      { "source": "**", "destination": "/index.html" }
    ]
  }
}
'@
[IO.File]::WriteAllText((Join-Path $site 'firebase.json'), $config, (New-Object Text.UTF8Encoding $false))

Set-Location $site
firebase hosting:channel:deploy $Channel --expires $Expires --project $Project --non-interactive
$code = $LASTEXITCODE
Set-Location $root
if ($code -ne 0) { throw "hosting:channel:deploy failed (exit $code)" }
Write-Host "Homolog stamp: $stamp"
