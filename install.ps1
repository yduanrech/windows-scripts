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

    $URL = 'https://raw.githubusercontent.com/yduanrech/windows-scripts/main/WinKit.bat'

    Write-Host ""
    Write-Host "  Windows 10/11 - Pos-Instalacao" -ForegroundColor Cyan
    Write-Host ""
    Write-Progress -Activity "Baixando script..." -Status "Aguarde"
    try {
        $response = Invoke-RestMethod -Uri $URL -ErrorAction Stop
    }
    catch {
        Write-Progress -Activity "Baixando script..." -Status "Erro" -Completed
        Write-Host "  Erro: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  Falha ao baixar. Verifique conexao ou antivirus." -ForegroundColor Red
        Write-Host "  Ajuda - $troubleshoot" -ForegroundColor White -BackgroundColor Blue
        return
    }
    Write-Progress -Activity "Baixando script..." -Status "Concluido" -Completed

    if (-not $response) {
        Write-Host "  Resposta vazia do servidor, abortando!" -ForegroundColor Red
        return
    }

    # --- Extrai somente a parte PowerShell (tudo apos o marcador #>) ---
    # O bat e um polyglot: o cabecalho batch fica entre <# : ... #>
    # Para irm|iex nao precisamos do batch - rodamos PowerShell direto.
    $psCode = ($response -split '#>', 2)[1]
    if (-not $psCode) {
        Write-Host "  Falha ao extrair codigo PowerShell do script." -ForegroundColor Red
        return
    }

    $rand     = [Guid]::NewGuid().Guid
    $isAdmin  = [bool]([Security.Principal.WindowsIdentity]::GetCurrent().Groups -match 'S-1-5-32-544')
    $FilePath = if ($isAdmin) {
        "$env:SystemRoot\Temp\WPI_$rand.ps1"
    } else {
        "$env:USERPROFILE\AppData\Local\Temp\WPI_$rand.ps1"
    }

    # Grava como .ps1 (UTF-8 sem BOM)
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($FilePath, $psCode, $utf8NoBom)

    if (-not (Test-Path $FilePath)) {
        Write-Host "  Falha ao criar arquivo temporario, abortando!" -ForegroundColor Red
        Write-Host "  Ajuda - $troubleshoot" -ForegroundColor White -BackgroundColor Blue
        return
    }

    if ($isAdmin) {
        # Ja e admin - executa direto neste console (interativo)
        Write-Host "  Executando..." -ForegroundColor Green
        Write-Host ""
        try {
            & ([scriptblock]::Create($psCode))
        }
        finally {
            Remove-Item -Path $FilePath -Force -ErrorAction SilentlyContinue
        }
    }
    else {
        # Precisa elevar - abre nova janela PowerShell como admin com -File
        Write-Host "  Solicitando permissao de Administrador (UAC)..." -ForegroundColor Green
        try {
            Start-Process powershell -Verb RunAs -Wait -ArgumentList (
                "-NoProfile -ExecutionPolicy Bypass -File `"$FilePath`""
            )
        }
        catch {
            Write-Host "  Elevacao cancelada ou falhou." -ForegroundColor Red
        }
        finally {
            Remove-Item -Path $FilePath -Force -ErrorAction SilentlyContinue
        }
    }
} @args
