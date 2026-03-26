$ErrorActionPreference = "Stop"

$serverHost  = "www1045.conoha.ne.jp"
$serverUser  = "c6924945"
$serverPort  = "8022"
$remoteDir   = "public_html/door-fujita.com/contents/VoiceDropper"
$sshKeyPath  = "../Youkan/docs/01_RULES/UPLOAD/key-2025-11-29-07-10.pem"
$archiveName = "deploy.tar.gz"

Write-Host "VoiceDropper デプロイ開始..." -ForegroundColor Cyan
Write-Host "  Server : $serverHost"
Write-Host "  Target : $remoteDir"

# 1. パッケージ作成（web/ をそのままデプロイ）
Write-Host "`n[1/3] パッケージ作成..." -ForegroundColor Yellow
$deployTmp = "deploy_tmp"
if (Test-Path $deployTmp) { Remove-Item $deployTmp -Recurse -Force }
New-Item -ItemType Directory -Path $deployTmp | Out-Null

Get-ChildItem "web" | Copy-Item -Destination $deployTmp -Recurse -Force

# 2. アーカイブ
Write-Host "`n[2/3] アーカイブ作成..." -ForegroundColor Yellow
tar -czf $archiveName -C $deployTmp .
if ($LASTEXITCODE -ne 0) { throw "tar failed" }
$size = [math]::Round((Get-Item $archiveName).Length / 1KB, 1)
Write-Host "  done ${size} KB" -ForegroundColor Green
Remove-Item $deployTmp -Recurse -Force

# 3. 転送・展開
Write-Host "`n[3/3] サーバーへ転送..." -ForegroundColor Yellow
$sshOpts = @("-o", "StrictHostKeyChecking=no", "-p", $serverPort, "-i", $sshKeyPath)
$scpOpts = @("-o", "StrictHostKeyChecking=no", "-P", $serverPort, "-i", $sshKeyPath)

try {
    & ssh @sshOpts "$serverUser@$serverHost" "mkdir -p $remoteDir"
    & scp @scpOpts $archiveName "${serverUser}@${serverHost}:${remoteDir}/${archiveName}"
    & ssh @sshOpts "$serverUser@$serverHost" `
        "cd $remoteDir && tar -xzf $archiveName && rm $archiveName && find . -type d -exec chmod 755 {} + && find . -type f -exec chmod 644 {} +"

    Write-Host "`nデプロイ完了!" -ForegroundColor Green
    Write-Host "  URL: https://door-fujita.com/contents/VoiceDropper/" -ForegroundColor Cyan
} finally {
    if (Test-Path $archiveName) { Remove-Item $archiveName }
}
