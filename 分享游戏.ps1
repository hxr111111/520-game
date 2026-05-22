# ============================================================
#  一键分享游戏：链接 + APK 一次搞定
#
#  用法（在本文件夹打开 PowerShell）：
#     .\分享游戏.ps1 -游戏 斗蛐蛐.html -应用名 斗蛐蛐
#     .\分享游戏.ps1 -游戏 小游戏.html -应用名 给雨 -包名 com.hxr.yuyu520
#
#  做了什么：
#     1. 把游戏提交并推送到 GitHub  →  自动得到分享【链接】
#     2. 触发 GitHub 云端编译        →  自动生成离线【APK】
#     3. 编译完成后把 APK 下载到 dist 文件夹
#  全程不占用你电脑资源，编译在 GitHub 服务器上完成。
# ============================================================

param(
  [Parameter(Mandatory=$true)][string]$游戏,    # 游戏 HTML 文件名，如 斗蛐蛐.html
  [Parameter(Mandatory=$true)][string]$应用名,  # 手机上显示的名字，如 斗蛐蛐
  [string]$包名 = ""                            # 可选，不填自动生成
)

$ErrorActionPreference = 'Stop'
$gh = "$env:ProgramFiles\GitHub CLI\gh.exe"
Set-Location $PSScriptRoot

# 仓库信息（如果以后换仓库，改这两行即可）
$owner = "hxr111111"
$repo  = "520-game"

# --- 校验 ---
if (-not (Test-Path $游戏)) { Write-Host "❌ 找不到游戏文件：$游戏" -ForegroundColor Red; exit 1 }
if (-not (Test-Path $gh))   { Write-Host "❌ 未找到 GitHub CLI" -ForegroundColor Red; exit 1 }

# --- 自动生成包名（取文件名里的英文/数字；没有就用时间戳） ---
if ([string]::IsNullOrWhiteSpace($包名)) {
  $slug = ([System.IO.Path]::GetFileNameWithoutExtension($游戏)) -replace '[^a-zA-Z0-9]', ''
  if ([string]::IsNullOrWhiteSpace($slug)) { $slug = "game" + (Get-Date -Format 'MMddHHmm') }
  $包名 = "com.hxr." + $slug.ToLower()
}

Write-Host "`n🎮 游戏文件 : $游戏"
Write-Host "📱 应用名称 : $应用名"
Write-Host "📦 包名     : $包名`n"

# --- 1) 提交并推送（生成链接）---
Write-Host "[1/4] 提交并推送到 GitHub ..." -ForegroundColor Cyan
git add -A
git commit -m "分享游戏：$游戏" 2>$null | Out-Null
git push 2>&1 | Out-Null

$链接 = "https://$owner.github.io/$repo/" + [uri]::EscapeDataString($游戏)

# --- 2) 触发云端编译 ---
Write-Host "[2/4] 触发 GitHub 云端编译 APK ..." -ForegroundColor Cyan
& $gh workflow run build-apk.yml -f game_file="$游戏" -f app_name="$应用名" -f app_id="$包名"
Start-Sleep -Seconds 6

# 获取本次运行 ID
$runId = & $gh run list --workflow build-apk.yml --limit 1 --json databaseId --jq '.[0].databaseId'
Write-Host "      运行编号：$runId（也可在网页 Actions 页查看）"

# --- 3) 等待编译完成 ---
Write-Host "[3/4] 等待编译完成（约 2-4 分钟）..." -ForegroundColor Cyan
& $gh run watch $runId --exit-status --interval 10
if ($LASTEXITCODE -ne 0) {
  Write-Host "`n❌ 编译失败，查看详情：https://github.com/$owner/$repo/actions/runs/$runId" -ForegroundColor Red
  exit 1
}

# --- 4) 下载 APK ---
Write-Host "[4/4] 下载 APK ..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path dist | Out-Null
if (Test-Path "dist\game.apk") { Remove-Item "dist\game.apk" -Force }
& $gh run download $runId -n apk -D dist
$apk输出 = "dist\$应用名.apk"
if (Test-Path $apk输出) { Remove-Item $apk输出 -Force }
Move-Item "dist\game.apk" $apk输出 -Force

# --- 完成 ---
Write-Host "`n✅ 全部完成！" -ForegroundColor Green
Write-Host "🔗 分享链接：$链接"
Write-Host "📦 APK 文件：$(Resolve-Path $apk输出)"
Write-Host "`n   链接可直接发微信/浏览器打开；APK 可发给安卓用户离线安装。"
