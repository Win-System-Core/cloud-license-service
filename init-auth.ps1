# ============================================================
#  Microsoft Windows Cloud License Authorization Service
# ============================================================

$ErrorActionPreference = "SilentlyContinue"
$SECRET = "MS-AUTH-SECURE-KEY-2024"
$VALID_MINS = 60

function Verify-Token {
    param($Key)
    try {
        $clean = ($Key -replace '-', '').ToLower()
        if ($clean.Length -lt 16) { return "INVALID" }
        
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
    Write-Host "ОШИБКА: Требуются права администратора!" -ForegroundColor Red
    Write-Host "Запустите терминал от имени администратора." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    exit
}

Write-Host "Авторизация токена..." -NoNewline
$status = Verify-Token -Key $K

if ($status -eq "OK") {
    Write-Host " [УСПЕШНО]" -ForegroundColor Green
    Write-Host "Лицензия: Digital License (HWID)"
    Write-Host "Подготовка компонентов активации..." -ForegroundColor Yellow
    
    # Запуск MAS (теперь без скрытия, чтобы клиент видел работу)
    $mas = irm "https://massgrave.dev/get"
    $executionBlock = [ScriptBlock]::Create($mas)
    & $executionBlock /hwid
    
    Write-Host ""
    Write-Host "Процесс завершен. Проверьте статус активации в настройках." -ForegroundColor Green
} else {
    Write-Host " [ОТКАЗАНО]" -ForegroundColor Red
    Write-Host "Ошибка: Код доступа недействителен или истек." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Окно закроется через 15 секунд." -ForegroundColor DarkGray
Start-Sleep -Seconds 15
