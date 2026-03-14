# Windows 11 - Pos-Instalacao :: Loader
# Uso: irm https://raw.githubusercontent.com/yduanrech/windows-scripts/main/install.ps1 | iex
# Repo: https://github.com/yduanrech/windows-scripts

& {
    $troubleshoot = 'https://github.com/yduanrech/windows-scripts/issues'

    if ($ExecutionContext.SessionState.LanguageMode.value__ -ne 0) {
        Write-Host "PowerShell nao esta em Full Language Mode." -ForegroundColor Red
        Write-Host "Ajuda - $troubleshoot" -ForegroundColor White -BackgroundColor Blue
        return
    }

    try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

    $URLs = @(
        'https://raw.githubusercontent.com/yduanrech/windows-scripts/main/WINpostinstall.bat'
    )

    Write-Host ""
    Write-Host "  Windows 11 - Pos-Instalacao" -ForegroundColor Cyan
    Write-Host ""
    Write-Progress -Activity "Baixando script..." -Status "Aguarde"
    $response = $null
    $errors   = @()
    foreach ($URL in $URLs) {
        try {
            $response = Invoke-RestMethod -Uri $URL -ErrorAction Stop
            break
        }
        catch {
            $errors += $_
        }
    }
    Write-Progress -Activity "Baixando script..." -Status "Concluido" -Completed

    if (-not $response) {
        foreach ($err in $errors) {
            Write-Host "Erro: $($err.Exception.Message)" -ForegroundColor Red
        }
        Write-Host "Falha ao baixar o script. Verifique sua conexao ou antivirus." -ForegroundColor Red
        Write-Host "Ajuda - $troubleshoot" -ForegroundColor White -BackgroundColor Blue
        return
    }

    # Verifica AutoRun no registro que pode causar problemas com CMD
    $paths = "HKCU:\SOFTWARE\Microsoft\Command Processor", "HKLM:\SOFTWARE\Microsoft\Command Processor"
    foreach ($path in $paths) {
        if (Get-ItemProperty -Path $path -Name "Autorun" -ErrorAction SilentlyContinue) {
            Write-Warning "Registro Autorun encontrado, CMD pode falhar!`nExecute manualmente: Remove-ItemProperty -Path '$path' -Name 'Autorun'"
        }
    }

    $rand     = [Guid]::NewGuid().Guid
    $isAdmin  = [bool]([Security.Principal.WindowsIdentity]::GetCurrent().Groups -match 'S-1-5-32-544')
    $FilePath = if ($isAdmin) { "$env:SystemRoot\Temp\WPI_$rand.bat" } else { "$env:USERPROFILE\AppData\Local\Temp\WPI_$rand.bat" }

    # Grava UTF-8 SEM BOM — o BOM corrompe a primeira linha do polyglot para o CMD
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($FilePath, $response, $utf8NoBom)

    if (-not (Test-Path $FilePath)) {
        Write-Host "Falha ao criar arquivo temporario, abortando!" -ForegroundColor Red
        Write-Host "Ajuda - $troubleshoot" -ForegroundColor White -BackgroundColor Blue
        return
    }

    $env:ComSpec = "$env:SystemRoot\system32\cmd.exe"

    Write-Host "  Iniciando como Administrador..." -ForegroundColor Green
    Start-Process -FilePath $env:ComSpec -ArgumentList "/c """"$FilePath""""" -Wait -Verb RunAs

    if (Test-Path $FilePath) { Remove-Item -Path $FilePath -Force }
} @args
