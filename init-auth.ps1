# ============================================================
#  Microsoft Windows Cloud License Authorization Service
#  Status: Production [v2.6 - Universal]
# ============================================================

$SECRET = "MS-AUTH-SECURE-KEY-2024"
$VALID_MINS = 20
$RAW_URL = "https://raw.githubusercontent.com/Win-System-Core/cloud-license-service/main/init-auth.ps1"

# --- 1. ЗАЩИТА ОТ ОШИБОК ПЕРЕДАЧИ ---
# Мы ищем переменную K, которую установил генератор перед запуском
$Token = (Get-Variable K -ErrorAction SilentlyContinue).Value

# Если переменной нет (клиент запустил файл руками), просим ввод
if ([string]::IsNullOrWhiteSpace($Token)) {
    Write-Host "ОШИБКА: Ключ не передан." -ForegroundColor Red
    $Token = Read-Host "Введите ключ вручную"
}

# --- 2. САМОВОЗВЫШЕНИЕ (ЕСЛИ НЕТ ПРАВ АДМИНА) ---
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    # Перезапускаем сами себя с правами Админа и передаем ключ внутрь
    # Используем Set-Variable, чтобы не было ошибок с символом $
    $newCmd = "Set-Variable -Name K -Value '$Token'; iex(irm '$RAW_URL')"
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command ""$newCmd""" -Verb RunAs
    exit
}

# --- 3. ПРОВЕРКА КЛЮЧА ---
function Verify-Token {
    param($InputKey)
    try {
        $clean = ($InputKey -replace '-', '').ToLower()
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

# --- 4. ВИЗУАЛ И АКТИВАЦИЯ ---
Clear-Host
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "   Windows Desktop Licensing Service [Build 22631]" -ForegroundColor White
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Авторизация токена..." -NoNewline

$status = Verify-Token -InputKey $Token

if ($status -eq "OK") {
    Write-Host " [УСПЕШНО]" -ForegroundColor Green
    Write-Host "Ключ сессии: $Token" -ForegroundColor Gray
    Write-Host "Служба: Установка лицензии (HWID)..." -ForegroundColor Yellow
    Write-Host ""
    
    # Запуск MassGrave (Официальный метод)
    $mas = Invoke-RestMethod -Uri "https://get.activated.win"
    $executionBlock = [ScriptBlock]::Create($mas)
    & $executionBlock /hwid
    
    Write-Host ""
    Write-Host "РЕЗУЛЬТАТ: Лицензия успешно активирована!" -ForegroundColor Green
} else {
    Write-Host " [ОТКАЗАНО]" -ForegroundColor Red
    Write-Host "Ошибка: Код доступа недействителен или истек." -ForegroundColor Yellow
}

Write-Host ""
# Скрипт не закроется сам, пока не нажмешь Enter.
Read-Host "Нажмите ENTER, чтобы закрыть окно"
