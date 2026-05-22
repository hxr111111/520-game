# ============================================================
#  一键分享游戏：链接 + APK 一次搞定
#
#  用法（在本文件夹打开 PowerShell）：
#     .\分享游戏.ps1 -game 斗蛐蛐.html -name 斗蛐蛐
#     .\分享游戏.ps1 -game 小游戏.html -name 给雨 -id com.hxr.yuyu520
#
#  参数：
#     -game  游戏 HTML 文件名（必填）
#     -name  手机上显示的应用名（必填）
#     -id    App 包名（可选，不填自动生成）
#
#  做了什么：
#     1. 把游戏提交并推送到 GitHub  →  自动得到分享【链接】
#     2. 触发 GitHub 云端编译        →  自动生成离线【APK】
#     3. 编译完成后把 APK 下载到 dist 文件夹
#  全程不占用你电脑资源，编译在 GitHub 服务器上完成。
# ============================================================

param(
  [Parameter(Mandatory=$true)][string]$game,
  [Parameter(Mandatory=$true)][string]$name,
  [string]$id = ""
)

$ErrorActionPreference = 'Stop'
$gh = "$env:ProgramFiles\GitHub CLI\gh.exe"
Set-Location $PSScriptRoot

# 仓库信息（如果以后换仓库，改这两行即可）
$owner = "hxr111111"
$repo  = "520-game"

# --- 校验 ---
if (-not (Test-Path $game)) { Write-Host "[X] 找不到游戏文件: $game" -ForegroundColor Red; exit 1 }
if (-not (Test-Path $gh))   { Write-Host "[X] 未找到 GitHub CLI" -ForegroundColor Red; exit 1 }

# --- 自动生成包名（取文件名里的英文/数字；没有就用时间戳） ---
if ([string]::IsNullOrWhiteSpace($id)) {
  $slug = ([System.IO.Path]::GetFileNameWithoutExtension($game)) -replace '[^a-zA-Z0-9]', ''
  if ([string]::IsNullOrWhiteSpace($slug)) { $slug = "game" + (Get-Date -Format 'MMddHHmm') }
  $id = "com.hxr." + $slug.ToLower()
}

Write-Host ""
Write-Host "游戏文件 : $game"
Write-Host "应用名称 : $name"
Write-Host "包名     : $id"
Write-Host ""

# --- 1) 提交并推送（生成链接）---
Write-Host "[1/4] 提交并推送到 GitHub ..." -ForegroundColor Cyan
git add -A
git commit -m "share game: $game" 2>$null | Out-Null
git push 2>&1 | Out-Null

$link = "https://$owner.github.io/$repo/" + [uri]::EscapeDataString($game)

# --- 2) 触发云端编译 ---
Write-Host "[2/4] 触发 GitHub 云端编译 APK ..." -ForegroundColor Cyan
& $gh workflow run build-apk.yml -f game_file="$game" -f app_name="$name" -f app_id="$id"
Start-Sleep -Seconds 6

# 获取本次运行 ID
$runId = & $gh run list --workflow build-apk.yml --limit 1 --json databaseId --jq '.[0].databaseId'
Write-Host "      运行编号: $runId"

# --- 3) 等待编译完成 ---
Write-Host "[3/4] 等待编译完成（约 2-4 分钟）..." -ForegroundColor Cyan
& $gh run watch $runId --exit-status --interval 10
if ($LASTEXITCODE -ne 0) {
  Write-Host ""
  Write-Host "[X] 编译失败，查看详情: https://github.com/$owner/$repo/actions/runs/$runId" -ForegroundColor Red
  exit 1
}

# --- 4) 下载 APK ---
Write-Host "[4/4] 下载 APK ..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path dist | Out-Null
if (Test-Path "dist\game.apk") { Remove-Item "dist\game.apk" -Force }
& $gh run download $runId -n apk -D dist
$apkOut = "dist\$name.apk"
if (Test-Path $apkOut) { Remove-Item $apkOut -Force }
Move-Item "dist\game.apk" $apkOut -Force

# --- 完成 ---
Write-Host ""
Write-Host "[OK] 全部完成!" -ForegroundColor Green
Write-Host "链接: $link"
Write-Host "APK : $(Resolve-Path $apkOut)"
Write-Host ""
Write-Host "  链接可直接发微信/浏览器打开; APK 可发给安卓用户离线安装。"
