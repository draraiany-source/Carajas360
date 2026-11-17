# Deploy do hosting LIVE (site principal). EXIGE GO explícito.
# NÃO executa sem -IAuthorizeLiveDeploy.
# Uso (após autorização verbal/escrita do owner):
#   powershell -ExecutionPolicy Bypass -File scripts\live_web_deploy.ps1 -IAuthorizeLiveDeploy
param(
  [switch]$IAuthorizeLiveDeploy,
  [string]$Project = 'carajas360-a17c5'
)
$ErrorActionPreference = 'Stop'
if (-not $IAuthorizeLiveDeploy) {
  Write-Host @"
ABORTADO: hosting live NÃO foi publicado.
Causa atual do HTTP 404: nenhuma versão live foi liberada (só canal homolog).
Para publicar o Flutter Web no site principal, rode de novo com:
  -IAuthorizeLiveDeploy
Após GO do owner. Isso NÃO habilita Blaze nem pagamentos.
"@
  exit 2
}

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

flutter build web --release --no-wasm-dry-run
if ($LASTEXITCODE -ne 0) { throw 'flutter build web failed' }

$stamp = Get-Date -Format 'yyyyMMddHHmmss'
$site = Join-Path $root 'build\live_site'
$public = Join-Path $site 'public'
if (Test-Path $site) { Remove-Item $site -Recurse -Force }
New-Item -ItemType Directory -Path $public | Out-Null
Copy-Item -Path (Join-Path $root 'build\web\*') -Destination $public -Recurse
foreach ($page in 'privacy.html', 'terms.html', 'account-deletion.html', 'support.html') {
  Copy-Item -Path (Join-Path $root "hosting\$page") -Destination $public -Force
}

$indexPath = Join-Path $public 'index.html'
$index = [IO.File]::ReadAllText($indexPath)
$index = $index.Replace('flutter_bootstrap.js', "flutter_bootstrap.js?v=$stamp")
[IO.File]::WriteAllText($indexPath, $index, (New-Object Text.UTF8Encoding $false))
foreach ($jsName in @('flutter_bootstrap.js', 'flutter.js')) {
  $jsPath = Join-Path $public $jsName
  if (-not (Test-Path $jsPath)) { continue }
  $js = [IO.File]::ReadAllText($jsPath)
  $js = $js.Replace('main.dart.js', "main.dart.js?v=$stamp")
  [IO.File]::WriteAllText($jsPath, $js, (New-Object Text.UTF8Encoding $false))
}

$config = @'
{
  "hosting": {
    "public": "public",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
    "headers": [
      { "source": "/index.html", "headers": [{ "key": "Cache-Control", "value": "no-cache, no-store, must-revalidate" }] },
      { "source": "**/*.js", "headers": [{ "key": "Cache-Control", "value": "no-cache, max-age=0, must-revalidate" }] }
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
firebase deploy --only hosting --project $Project --non-interactive
$code = $LASTEXITCODE
Set-Location $root
if ($code -ne 0) { throw "firebase deploy hosting failed ($code)" }
Write-Host "LIVE deploy OK stamp=$stamp https://$Project.web.app"
