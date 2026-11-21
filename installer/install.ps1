# HP MCP SketchUp - bo cai dat tu dong cho Windows
# Cong dung : 1) Tim cac ban SketchUp da cai (2017 tro len)
#             2) Chep plugin "HP SketchUp MCP" vao thu muc Plugins cua tung ban
#             3) Cai MCP server (Python) vao %LOCALAPPDATA%\HP-MCP-Sketchup
#             4) Dang ky MCP ten "sketchup" voi Claude Code va Claude Desktop
# Cach dung : bam dup CaiDat.bat, hoac:
#             powershell -ExecutionPolicy Bypass -File installer\install.ps1 [-ChiPlugin] [-BoQuaClaude] [-GoCai]
# Ngay viet : 2026-11-21
param(
    [switch]$ChiPlugin,    # chi chep plugin, khong cai server / khong dang ky Claude
    [switch]$BoQuaClaude,  # cai plugin + server nhung khong dang ky voi Claude
    [switch]$GoCai,        # go plugin khoi cac ban SketchUp va bo dang ky MCP
    [string[]]$Phienban    # them nam phien ban tay neu khong tu tim thay, vd: -Phienban 2024,2025
)
$ErrorActionPreference = 'Continue'   # loi nghiem trong dung 'throw' ben duoi
$Root      = Split-Path -Parent $PSScriptRoot
$PluginSrc = Join-Path $Root 'plugin'
$ServerSrc = Join-Path $Root 'server'
$Dest      = Join-Path $env:LOCALAPPDATA 'HP-MCP-Sketchup'
$Stamp     = Get-Date -Format 'yyMMdd-HHmmss'
$McpName   = 'sketchup'

function Say($m, $c = 'Gray') { Write-Host $m -ForegroundColor $c }

# ---------- 1. Tim cac ban SketchUp ----------
function Find-SketchUpYears {
    # Chi nhan ban THUC SU da cai: co file SketchUp.exe. (Registry HKCU thuong con khoa rong
    # cua ban cu da go, nen khong dung lam bang chung.)
    $years = @{}
    $roots = @("$env:ProgramFiles\SketchUp", "${env:ProgramFiles(x86)}\SketchUp")
    foreach ($d in $roots) {
        if ($d -and (Test-Path $d)) {
            Get-ChildItem $d -Directory | ForEach-Object {
                if ($_.Name -match '^SketchUp (20\d\d)$' -and (Test-Path (Join-Path $_.FullName 'SketchUp.exe'))) { $years[$Matches[1]] = $_.FullName }
            }
        }
    }
    # Ban cai o o dia khac: doc InstallLocation trong muc go cai dat cua Windows
    $un = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    Get-ItemProperty $un -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match '^SketchUp (Pro |Make )?(20\d\d)' } | ForEach-Object {
        $y = [regex]::Match($_.DisplayName, '20\d\d').Value
        $loc = $_.InstallLocation
        if ($loc -and (Test-Path (Join-Path $loc 'SketchUp.exe'))) { $years[$y] = $loc }
    }
    foreach ($y in $Phienban) { $years["$y"] = 'chi dinh tay' }
    $years.Keys | Where-Object { [int]$_ -ge 2017 } | Sort-Object
}
$years = @(Find-SketchUpYears)
if ($years.Count -eq 0) {
    Say 'Khong tim thay SketchUp 2017 tro len tren may. Cai SketchUp truoc, hoac cai tay file dist\hp_sketchup_mcp.rbz.' Yellow
} else {
    Say ("Tim thay SketchUp: " + ($years -join ', ')) Cyan
}

foreach ($y in $years) {
    $plug = Join-Path $env:APPDATA "SketchUp\SketchUp $y\SketchUp\Plugins"
    $oldRb  = Join-Path $plug 'hp_sketchup_mcp.rb'
    $oldDir = Join-Path $plug 'hp_sketchup_mcp'
    if ($GoCai) {
        if (Test-Path $oldRb)  { Remove-Item $oldRb -Force }
        if (Test-Path $oldDir) { Remove-Item $oldDir -Recurse -Force }
        Say "  SketchUp $y : da go plugin" Green
        continue
    }
    New-Item -ItemType Directory -Force $plug | Out-Null
    if ((Test-Path $oldRb) -or (Test-Path $oldDir)) {
        # Sao luu ban cu truoc khi thay
        $bk = Join-Path $Dest "_backup\$Stamp\SketchUp $y"
        New-Item -ItemType Directory -Force $bk | Out-Null
        if (Test-Path $oldRb)  { Copy-Item $oldRb $bk -Force }
        if (Test-Path $oldDir) { Copy-Item $oldDir $bk -Recurse -Force }
        Say "  SketchUp $y : da sao luu plugin cu vao $bk"
    }
    Copy-Item (Join-Path $PluginSrc 'hp_sketchup_mcp.rb') $plug -Force
    Copy-Item (Join-Path $PluginSrc 'hp_sketchup_mcp') $plug -Recurse -Force
    Say "  SketchUp $y : da chep plugin vao $plug" Green
}

# ---------- Tim lenh claude (Claude Code) ----------
function Find-ClaudeCli {
    $c = Get-Command claude -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    $cands = @()
    foreach ($base in @("$env:APPDATA\Claude\claude-code", "$env:LOCALAPPDATA\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude\claude-code", "$env:USERPROFILE\.local\bin")) {
        if (Test-Path $base) { $cands += Get-ChildItem $base -Recurse -Filter 'claude.exe' -ErrorAction SilentlyContinue }
    }
    if ($cands.Count) { return ($cands | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName }
    return $null
}

# ---------- Claude Desktop: sua claude_desktop_config.json ----------
function Set-DesktopConfig($cfgPath, $py, $srv, [switch]$Remove) {
    $dir = Split-Path $cfgPath
    if (-not (Test-Path $dir)) { return $false }
    if (Test-Path $cfgPath) {
        Copy-Item $cfgPath "$cfgPath.bak-$Stamp" -Force
        $raw = [IO.File]::ReadAllText($cfgPath)
        $cfg = if ($raw.Trim()) { $raw | ConvertFrom-Json } else { New-Object psobject }
    } else { $cfg = New-Object psobject }
    if (-not $cfg.PSObject.Properties['mcpServers']) { $cfg | Add-Member mcpServers (New-Object psobject) }
    if ($cfg.mcpServers.PSObject.Properties[$McpName]) { $cfg.mcpServers.PSObject.Properties.Remove($McpName) }
    if (-not $Remove) {
        $cfg.mcpServers | Add-Member $McpName ([pscustomobject]@{ command = $py; args = @($srv) })
    }
    [IO.File]::WriteAllText($cfgPath, ($cfg | ConvertTo-Json -Depth 20), (New-Object Text.UTF8Encoding $false))
    return $true
}

$desktopCfgs = @("$env:APPDATA\Claude\claude_desktop_config.json",
                 "$env:LOCALAPPDATA\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude\claude_desktop_config.json")

if ($GoCai) {
    $cli = Find-ClaudeCli
    if ($cli) { & $cli mcp remove --scope user $McpName 2>$null | Out-Null; Say 'Da bo dang ky MCP trong Claude Code' Green }
    foreach ($p in $desktopCfgs) { if (Test-Path $p) { Set-DesktopConfig $p '' '' -Remove | Out-Null; Say "Da bo muc sketchup trong $p" Green } }
    Say "Thu muc server $Dest khong bi xoa; anh tu xoa neu muon." Yellow
    return
}
if ($ChiPlugin) { Say 'Xong (chi chep plugin).' Green; return }

# ---------- 3. Cai MCP server ----------
New-Item -ItemType Directory -Force $Dest | Out-Null
Copy-Item (Join-Path $ServerSrc 'server.py') $Dest -Force
Copy-Item (Join-Path $ServerSrc 'requirements.txt') $Dest -Force
$venv = Join-Path $Dest '.venv'
$py   = Join-Path $venv 'Scripts\python.exe'
$srv  = Join-Path $Dest 'server.py'
if (-not (Test-Path $py)) {
    $uv = Get-Command uv -ErrorAction SilentlyContinue
    if ($uv) {
        Say 'Tao moi truong Python bang uv...'
        & uv venv --python 3.12 $venv | Out-Null
    } else {
        $sys = Get-Command python -ErrorAction SilentlyContinue
        if (-not $sys) { throw 'Chua co Python 3.10+ hoac uv. Cai Python tu python.org (tich "Add python.exe to PATH") roi chay lai.' }
        Say 'Tao moi truong Python bang python -m venv...'
        & $sys.Source -m venv $venv
    }
}
if (-not (Test-Path $py)) { throw "Khong tao duoc $py" }
Say 'Cai thu vien mcp...'
$uv = Get-Command uv -ErrorAction SilentlyContinue
if ($uv) { & uv pip install --python $py -r (Join-Path $Dest 'requirements.txt') | Out-Null }
else     { & $py -m pip install --disable-pip-version-check -q -r (Join-Path $Dest 'requirements.txt') }
& $py -c "import sys; assert sys.version_info >= (3,10), 'Can Python 3.10+'; import mcp.server.fastmcp; print('  Python', sys.version.split()[0], '- thu vien mcp OK')"
if ($LASTEXITCODE -ne 0) { throw 'Kiem tra thu vien mcp that bai.' }
Say "  Server: $srv" Green

if ($BoQuaClaude) { Say 'Xong (khong dang ky Claude).' Green; return }

# ---------- 4. Dang ky voi Claude ----------
$cli = Find-ClaudeCli
if ($cli) {
    & $cli mcp remove --scope user $McpName 2>$null | Out-Null
    & $cli mcp add --scope user $McpName -- $py $srv
    Say "Claude Code: da dang ky MCP '$McpName' ($cli)" Green
} else {
    Say 'Khong thay Claude Code (lenh claude). Bo qua buoc nay.' Yellow
}
$didDesktop = $false
foreach ($p in $desktopCfgs) { if (Set-DesktopConfig $p $py $srv) { Say "Claude Desktop: da ghi muc '$McpName' vao $p" Green; $didDesktop = $true } }
if (-not $didDesktop) { Say 'Khong thay Claude Desktop. Bo qua.' Yellow }

Say ''
Say 'HOAN TAT. Viec tiep theo:' Cyan
Say '  1. Dong han roi mo lai SketchUp -> Extensions > HP MCP > Trang thai phai bao "dang chay".'
Say '  2. Khoi dong lai Claude (Desktop/Code), hoi: "kiem tra ket noi SketchUp".'
