@echo off
setlocal EnableExtensions EnableDelayedExpansion

title Test-Job Direct
set "TESTJOB_BAT_VERSION=2026.06.18.1"
set "TESTJOB_OUTPUT_DIR=%~dp0"
set "TESTJOB_CACHE_DIR=%TEMP%\TestJob"
set "TESTJOB_REMOTE_URL_FILE=%~dp0Test-Job-update-url.txt"
set "TESTJOB_DEFAULT_REMOTE_URL=https://mspsgroep.filemail.com/d/iqflrzgbrbisuqk"
set "TESTJOB_REMOTE_PS1=%TESTJOB_CACHE_DIR%\Test-Job-latest.ps1"

if /i not "%~1"=="__run_hidden" (
    start "" /min powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -Command "Start-Process -FilePath $env:ComSpec -ArgumentList '/c """"%~f0"""" __run_hidden' -WindowStyle Hidden"
    exit /b 0
)

set "TESTJOB_REMOTE_URL=%TESTJOB_DEFAULT_REMOTE_URL%"
if exist "%TESTJOB_REMOTE_URL_FILE%" (
    for /f "usebackq delims=" %%u in ("%TESTJOB_REMOTE_URL_FILE%") do (
        if not "%%u"=="" set "TESTJOB_REMOTE_URL=%%u"
    )
)

if not exist "%TESTJOB_CACHE_DIR%" mkdir "%TESTJOB_CACHE_DIR%"
del /f /q "%TESTJOB_REMOTE_PS1%" "%TESTJOB_CACHE_DIR%\Test-Job-online-error.txt" > nul 2>&1

powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -Command ^
 "$ErrorActionPreference='Stop';" ^
 "try{" ^
 "$dir=$env:TESTJOB_CACHE_DIR;" ^
 "if(-not (Test-Path -LiteralPath $dir)){[void](New-Item -ItemType Directory -Path $dir -Force)};" ^
 "$out=$env:TESTJOB_REMOTE_PS1;" ^
 "$requestUri=[Uri]$env:TESTJOB_REMOTE_URL;" ^
 "$transferId=$requestUri.AbsolutePath.Trim('/');" ^
 "if([string]::IsNullOrWhiteSpace($transferId)){throw 'Ongeldige Filemail-link'};" ^
 "$headers=@{ 'Accept'='application/json'; 'Origin'=$requestUri.GetLeftPart([System.UriPartial]::Authority); 'Referer'=$requestUri.AbsoluteUri; 'x-api-version'='2.0'; 'source'='web' };" ^
 "$transfer=Invoke-RestMethod -Uri ('https://api.filemail.com/downloadpage/transfer?id=' + [Uri]::EscapeDataString($transferId)) -Headers $headers;" ^
 "$token=$transfer.data.filestoken;" ^
 "if([string]::IsNullOrWhiteSpace($token)){throw 'Ongeldige Filemail payload: filestoken ontbreekt'};" ^
 "$files=Invoke-RestMethod -Uri ('https://api.filemail.com/downloadpage/files?id=' + [Uri]::EscapeDataString($transferId) + '&filesToken=' + [Uri]::EscapeDataString($token)) -Headers $headers;" ^
 "$file=@($files.data.files | Where-Object { $_.filename -eq 'Test-Job-online.txt' } | Select-Object -First 1);" ^
 "if(-not $file){throw 'Test-Job-online.txt ontbreekt in Filemail transfer'};" ^
 "$response=Invoke-WebRequest -UseBasicParsing -Uri ($file.downloadurl + '&skipcheck=true&skipreg=true');" ^
 "$content=if($response.Content -is [byte[]]){[Text.Encoding]::ASCII.GetString($response.Content)}else{[string]$response.Content};" ^
 "if([string]::IsNullOrWhiteSpace($content) -or $content -notmatch 'TESTJOB_ONLINE_SENTINEL: TESTJOB_PS1_V1'){throw 'Ongeldige online payload'};" ^
 "Set-Content -LiteralPath $out -Value $content -Encoding ASCII;" ^
 "$env:TESTJOB_RUN_SOURCE='filemail';" ^
 "& $out;" ^
 "exit $LASTEXITCODE" ^
 "}catch{" ^
 "$err=($_ | Out-String).Trim();" ^
 "if($err){ Set-Content -LiteralPath (Join-Path $env:TESTJOB_CACHE_DIR 'Test-Job-online-error.txt') -Value $err -Encoding UTF8 };" ^
 "Write-Host 'Test-Job kon niet vanaf Filemail worden geladen.' -ForegroundColor Red;" ^
 "Write-Host 'Download de nieuwste Test-Job.bat via: https://mspsgroep.filemail.com/d/qzhhprvjrtrggzo' -ForegroundColor Yellow;" ^
 "exit 1" ^
 "}"
set "PS_EXIT_CODE=%ERRORLEVEL%"

if "%PS_EXIT_CODE%" neq "0" (
    echo.
    echo Test-Job kon niet vanaf Filemail worden geladen.
    echo Download de nieuwste Test-Job.bat via:
    echo https://mspsgroep.filemail.com/d/qzhhprvjrtrggzo
    echo.
    pause
    exit /b %PS_EXIT_CODE%
)

exit /b 0
