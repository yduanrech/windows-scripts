<# :
@echo off
setlocal
chcp 65001 >nul

:: === Elevacao automatica para Administrador (UAC) ===
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo   Solicitando permissao de administrador...
    echo.
    powershell -Command "Start-Process -FilePath '%~dpnx0' -Verb RunAs"
    exit /b
)

:: Executa o PowerShell embutido neste mesmo arquivo
powershell -NoProfile -ExecutionPolicy Bypass -Command "& ([scriptblock]::Create(([IO.File]::ReadAllText('%~f0'))))"
if %errorlevel% neq 0 ( echo. & echo   [ERRO] PowerShell retornou erro. & pause )
exit /b
#>

# ==============================================================================
#  Windows 10/11 - Script de Pos-Instalacao                               v1.0
#  Repo: github.com/yduanrech/windows-scripts
#
#  METODO 1 - Executar via PowerShell (uma linha):
#    irm https://raw.githubusercontent.com/yduanrech/windows-scripts/main/install.ps1 | iex
#
#  METODO 2 - Download direto:
#    Baixe o WINpostinstall.bat e execute como Administrador.
#    https://raw.githubusercontent.com/yduanrech/windows-scripts/main/WINpostinstall.bat
#
#  Tecnica: arquivo .bat polyglot (batch + PowerShell no mesmo arquivo).
#  O cabecalho batch cuida da elevacao UAC e chama o PowerShell com
#  -ExecutionPolicy Bypass, sem precisar de .ps1 separado.
# ==============================================================================

#region ── Helpers ─────────────────────────────────────────────────────────────

function Write-Step  ([string]$Msg) { Write-Host "  >> $Msg" -ForegroundColor Yellow }
function Write-Ok    ([string]$Msg) { Write-Host "  [OK] $Msg`n" -ForegroundColor Green }
function Write-Fail  ([string]$Msg) { Write-Host "  [ERRO] $Msg" -ForegroundColor Red }
function Write-Info  ([string]$Msg) { Write-Host "  [i] $Msg" -ForegroundColor DarkYellow }

function Press-Key {
    Write-Host ""
    Write-Host "  Pressione qualquer tecla para voltar ao menu..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Test-Admin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

function Test-Winget {
    [bool](Get-Command winget -ErrorAction SilentlyContinue)
}

function Set-RegistryValue {
    param(
        [string]$Path,
        [string]$Name,
        [object]$Value,
        [string]$Type = "DWord"
    )
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type
}

function Confirm-Action ([string]$Prompt) {
    $r = Read-Host "  $Prompt (S/n)"
    return ($r -eq '' -or $r -match '^[sS]')
}

#endregion

#region ── Verificacoes Iniciais ───────────────────────────────────────────────

if (-not (Test-Admin)) {
    Write-Fail "Este script precisa ser executado como Administrador!"
    Write-Host "  Clique com o botao direito > Executar como administrador" -ForegroundColor Yellow
    Press-Key; exit 1
}

if (-not (Test-Winget)) {
    Write-Fail "WinGet nao encontrado! Instale o 'Instalador de Aplicativo' pela Microsoft Store."
    Press-Key; exit 1
}

#endregion

#region ── Listas de Aplicativos (Id + Descricao) ─────────────────────────────

$appsNormal = @(
    @{ Id = "Google.Chrome";                Desc = "Google Chrome" }
    @{ Id = "7zip.7zip";                    Desc = "7-Zip" }
    @{ Id = "Bitwarden.Bitwarden";          Desc = "Bitwarden" }
    @{ Id = "ente-io.auth-desktop";         Desc = "Ente Auth" }
    @{ Id = "Microsoft.PowerToys";          Desc = "Microsoft PowerToys" }
    @{ Id = "Adobe.Acrobat.Reader.64-bit";  Desc = "Adobe Acrobat Reader" }
    @{ Id = "clsid2.mpc-hc";               Desc = "MPC-HC" }
    @{ Id = "AntibodySoftware.WizTree";     Desc = "WizTree" }
)

$appsDev = @(
    @{ Id = "Microsoft.VisualStudioCode";   Desc = "Visual Studio Code" }
    @{ Id = "Notepad++.Notepad++";          Desc = "Notepad++" }
    @{ Id = "CoreyButler.NVMforWindows";    Desc = "NVM for Windows" }
    @{ Id = "HeidiSQL.HeidiSQL";            Desc = "HeidiSQL" }
    @{ Id = "Microsoft.Git";                Desc = "Git" }
    @{ Id = "GitHub.GitHubDesktop";         Desc = "GitHub Desktop" }
    @{ Id = "PuTTY.PuTTY";                 Desc = "PuTTY" }
    @{ Id = "WinSCP.WinSCP";               Desc = "WinSCP" }
    @{ Id = "OpenVPNTechnologies.OpenVPN";  Desc = "OpenVPN" }
)

#endregion

#region ── Funcoes de Exibicao e Instalacao ────────────────────────────────────

function Show-AppList {
    param([string]$Label, [array]$AppList)
    Write-Host ""
    Write-Host "  === Programas - $Label ===" -ForegroundColor Cyan
    Write-Host ""
    $i = 1
    foreach ($app in $AppList) {
        $name = ($app.Id -split '\.')[-1]
        Write-Host ("  {0,2}. " -f $i) -NoNewline -ForegroundColor DarkGray
        Write-Host "$($app.Desc)" -NoNewline
        Write-Host "  ($($app.Id))" -ForegroundColor DarkGray
        $i++
    }
    Write-Host ""
    Write-Host "  Total: $($AppList.Count) programas" -ForegroundColor DarkGray
    Write-Host ""
}

function Install-Apps {
    param([string]$Label, [array]$AppList)
    Show-AppList $Label $AppList
    if (-not (Confirm-Action "Instalar esses $($AppList.Count) programas?")) {
        Write-Info "Instalacao cancelada pelo usuario."
        return
    }
    Write-Host ""
    $total   = $AppList.Count
    $current = 0
    foreach ($app in $AppList) {
        $current++
        Write-Step "[$current/$total] $($app.Desc) ($($app.Id))"
        winget install -e --id $app.Id --accept-source-agreements --accept-package-agreements
        Write-Host ""
    }
    Write-Ok "Programas ($Label) - instalacao concluida."
}

function Install-NormalApps { Install-Apps "Normal" $appsNormal }

function Install-DevApps {
    Install-Apps "Normal"          $appsNormal
    Install-Apps "Desenvolvimento" $appsDev
}

#endregion

#region ── Tarefa Agendada (winget upgrade) ────────────────────────────────────

function Register-WingetUpdateTask {
    Write-Host "`n  === Tarefa Agendada - Atualizacao Semanal ===`n" -ForegroundColor Cyan
    Write-Host "  O que sera feito:" -ForegroundColor DarkGray
    Write-Host "  - Cria uma tarefa no Agendador de Tarefas do Windows"
    Write-Host "  - Toda segunda-feira as 10:00"
    Write-Host "  - Executa: winget upgrade --all (atualiza todos os programas)"
    Write-Host ""

    if (-not (Confirm-Action "Criar esta tarefa agendada?")) {
        Write-Info "Tarefa cancelada pelo usuario."
        return
    }

    $taskName   = "WinGet - Atualizar Aplicativos"
    $wingetPath = (Get-Command winget).Source

    $action = New-ScheduledTaskAction `
        -Execute  $wingetPath `
        -Argument "upgrade --all --accept-source-agreements --accept-package-agreements --silent"

    $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 10:00

    $principal = New-ScheduledTaskPrincipal `
        -UserId    $env:USERNAME `
        -RunLevel  Highest `
        -LogonType Interactive

    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable

    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

    Register-ScheduledTask `
        -TaskName    $taskName `
        -Action      $action `
        -Trigger     $trigger `
        -Principal   $principal `
        -Settings    $settings `
        -Description "Atualiza todos os aplicativos instalados via WinGet toda segunda-feira as 10h" | Out-Null

    Write-Ok "Tarefa '$taskName' registrada (toda segunda-feira as 10:00)."
}

#endregion

#region ── Tweaks do Sistema ───────────────────────────────────────────────────

# MinBuild: 0 = Win 10+, 22000 = Win 11+
$tweakList = @(
    @{
        Name     = "Menu de contexto classico"
        Desc     = "Restaura o menu do botao direito estilo Windows 10 (sem o 'Mostrar mais opcoes')"
        MinBuild = 22000        # Somente Windows 11
        Action   = {
            reg.exe add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /f /ve | Out-Null
        }
    }
    @{
        Name     = "Mostrar extensoes de arquivo"
        Desc     = "Exibe .txt, .exe, .jpg etc. no nome dos arquivos no Explorer"
        MinBuild = 0
        Action   = {
            Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" 0
        }
    }
    @{
        Name     = "Mostrar arquivos ocultos"
        Desc     = "Torna visiveis arquivos e pastas ocultos no Explorer"
        MinBuild = 0
        Action   = {
            Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Hidden" 1
        }
    }
    @{
        Name     = "Ocultar barra de idiomas"
        Desc     = "Remove o indicador de idioma (POR/ENG) da barra de tarefas"
        MinBuild = 0
        Action   = {
            Set-RegistryValue "HKCU:\Software\Microsoft\CTF\LangBar" "ShowStatus" 3
        }
    }
    @{
        Name     = "Notificacoes de apps na inicializacao"
        Desc     = "Alerta quando um programa se adiciona a inicializacao do Windows"
        MinBuild = 0
        Action   = {
            Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.StartupApp" "Enabled" 1
        }
    }
    @{
        Name     = "Windows Terminal como padrao"
        Desc     = "Define o Windows Terminal como terminal padrao do sistema"
        MinBuild = 22000        # Somente Windows 11
        Action   = {
            $path = "HKCU:\Console\%%Startup"
            Set-RegistryValue $path "DelegationConsole"  "{2EACA947-7F5F-4CFA-BA87-8F7FBEEFBE69}" "String"
            Set-RegistryValue $path "DelegationTerminal" "{E12CFF52-A866-4C77-9A90-F570A7AA2C6B}" "String"
        }
    }
    @{
        Name     = "Plano de energia: Alto Desempenho"
        Desc     = "Ativa o plano Alto Desempenho (mais performance, mais consumo de energia)"
        MinBuild = 0
        Action   = {
            powercfg -duplicatescheme 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null | Out-Null
            powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
        }
    }
    @{
        Name     = "Historico da area de transferencia"
        Desc     = "Ativa o historico de copiar/colar (acesse com Win+V)"
        MinBuild = 0
        Action   = {
            Set-RegistryValue "HKCU:\Software\Microsoft\Clipboard" "EnableClipboardHistory" 1
        }
    }
    @{
        Name     = "Desabilitar hibernacao e inicializacao rapida"
        Desc     = "Remove o arquivo de hibernacao (hiberfil.sys) e desliga o Fast Startup"
        MinBuild = 0
        Action   = {
            powercfg /h off 2>$null
            Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" "HiberbootEnabled" 0
        }
    }
    @{
        Name     = "Desabilitar pesquisa Bing no menu Iniciar"
        Desc     = "Remove a pesquisa web (Bing) do menu Iniciar - busca fica so local"
        MinBuild = 22000        # Somente Windows 11
        Action   = {
            Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "BingSearchEnabled" 0
        }
    }
)

function Invoke-AllTweaks {
    $build = [System.Environment]::OSVersion.Version.Build
    $winVer = if ($build -ge 22000) { "Windows 11" } else { "Windows 10" }

    # Filtra tweaks compativeis com a versao atual
    $compatible = $tweakList | Where-Object { $build -ge $_.MinBuild }
    $skipped    = $tweakList | Where-Object { $build -lt $_.MinBuild }

    Write-Host "`n  === Tweaks do Sistema ($winVer - Build $build) ===`n" -ForegroundColor Cyan
    Write-Host "  O que sera feito:" -ForegroundColor DarkGray
    Write-Host ""
    $i = 1
    foreach ($t in $compatible) {
        Write-Host ("  {0,2}. " -f $i) -NoNewline -ForegroundColor DarkGray
        Write-Host "$($t.Name)" -NoNewline -ForegroundColor White
        Write-Host " - $($t.Desc)" -ForegroundColor DarkGray
        $i++
    }
    if ($skipped) {
        Write-Host ""
        Write-Host "  Ignorados (requer Windows 11):" -ForegroundColor DarkYellow
        foreach ($t in $skipped) {
            Write-Host "   x $($t.Name)" -ForegroundColor DarkGray
        }
    }
    Write-Host ""
    Write-Host "  + Reinicia o Explorer para aplicar as alteracoes visuais" -ForegroundColor DarkGray
    Write-Host ""

    if (-not (Confirm-Action "Aplicar os $($compatible.Count) tweaks compativeis?")) {
        Write-Info "Tweaks cancelados pelo usuario."
        return
    }
    Write-Host ""

    $current = 0
    foreach ($t in $compatible) {
        $current++
        Write-Step "[$current/$($compatible.Count)] $($t.Name)"
        & $t.Action
    }

    Write-Step "Reiniciando Explorer..."
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Start-Process explorer.exe

    Write-Host ""
    Write-Ok "Todos os tweaks compativeis aplicados com sucesso."
}

#endregion

#region ── Manutencao do Sistema ───────────────────────────────────────────────

function Invoke-SystemMaintenance {
    Write-Host "`n  === Manutencao do Sistema ===`n" -ForegroundColor Cyan
    Write-Host "  O que sera feito:" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "   1. " -NoNewline -ForegroundColor DarkGray
    Write-Host "Limpeza de drivers antigos/orfaos" -NoNewline -ForegroundColor White
    Write-Host " - Remove drivers que nao estao mais em uso" -ForegroundColor DarkGray
    Write-Host "   2. " -NoNewline -ForegroundColor DarkGray
    Write-Host "DISM CheckHealth" -NoNewline -ForegroundColor White
    Write-Host " - Verifica se a imagem do sistema tem corrupcao" -ForegroundColor DarkGray
    Write-Host "   3. " -NoNewline -ForegroundColor DarkGray
    Write-Host "SFC /scannow" -NoNewline -ForegroundColor White
    Write-Host " - Verifica e repara arquivos protegidos do Windows" -ForegroundColor DarkGray
    Write-Host "   4. " -NoNewline -ForegroundColor DarkGray
    Write-Host "DISM RestoreHealth" -NoNewline -ForegroundColor White
    Write-Host " - Repara a imagem do sistema usando Windows Update" -ForegroundColor DarkGray
    Write-Host "   5. " -NoNewline -ForegroundColor DarkGray
    Write-Host "DISM StartComponentCleanup" -NoNewline -ForegroundColor White
    Write-Host " - Remove versoes antigas de componentes do Windows" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [!] Este processo pode levar de 15 a 60 minutos." -ForegroundColor DarkYellow
    Write-Host ""

    if (-not (Confirm-Action "Executar manutencao do sistema?")) {
        Write-Info "Manutencao cancelada pelo usuario."
        return
    }
    Write-Host ""

    Write-Step "[1/5] Limpeza de drivers antigos..."
    Start-Process -FilePath "rundll32.exe" -ArgumentList "pnpclean.dll,RunDLL_PnpClean /drivers/maxclean" -Wait -NoNewWindow -ErrorAction SilentlyContinue
    Write-Ok "Limpeza de drivers concluida."

    Write-Step "[2/5] DISM - Verificando saude da imagem (CheckHealth)..."
    & dism /Online /Cleanup-Image /CheckHealth
    Write-Host ""

    Write-Step "[3/5] SFC - Verificando arquivos do sistema..."
    & sfc /scannow
    Write-Host ""

    Write-Step "[4/5] DISM - Reparando imagem do sistema (RestoreHealth)..."
    & dism /Online /Cleanup-Image /RestoreHealth
    Write-Host ""

    Write-Step "[5/5] DISM - Limpeza de componentes antigos..."
    & dism /Online /Cleanup-Image /StartComponentCleanup /ResetBase
    Write-Host ""

    Write-Ok "Manutencao do sistema concluida."
}

#endregion

#region ── Limpeza de Arquivos Temporarios ─────────────────────────────────────

function Remove-Silently {
    param([string[]]$Paths)
    foreach ($p in $Paths) {
        Remove-Item -Path $p -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Remove-BrowserCache {
    param(
        [string]$BrowserName,
        [string]$ProcessName,
        [string]$BasePath    # caminho relativo dentro de AppData\Local
    )
    $proc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
    if ($proc) {
        Write-Step "Fechando $BrowserName..."
        Stop-Process -Name $ProcessName -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
    }

    foreach ($user in Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue) {
        $base = Join-Path $user.FullName "AppData\Local\$BasePath"
        if (-not (Test-Path $base)) { continue }

        $profiles = @("Default", "Guest Profile")
        # Detecta Profile 1 a Profile 12
        1..12 | ForEach-Object { $profiles += "Profile $_" }

        foreach ($profile in $profiles) {
            $profPath = Join-Path $base $profile
            if (-not (Test-Path $profPath)) { continue }
            Remove-Silently @(
                "$profPath\Cache\Cache_Data\*"
                "$profPath\GPUCache\*"
                "$profPath\Code Cache\js\*"
                "$profPath\Code Cache\wasm\*"
                "$profPath\Code Cache\webui_js\*"
                "$profPath\Service Worker\CacheStorage\*"
                "$profPath\Service Worker\Database\*"
                "$profPath\Service Worker\ScriptCache\*"
                "$profPath\Storage\data_*"
                "$profPath\Storage\index*"
                "$profPath\JumpListIconsRecentClosed\*.tmp"
                "$profPath\History-journal*"
                "$profPath\Platform Notifications\*"
                "$profPath\File System\*"
                "$profPath\IndexedDB\https_ntp.msn.com_0.indexeddb.leveldb\*"
                "$profPath\EdgePushStorageWithWinRt\*.log"
                "$profPath\EdgeCoupons\coupons_data.db\*"
            )
        }
        # Arquivos na raiz do User Data
        Remove-Silently @(
            "$base\*.pma"
            "$base\BrowserMetrics\*.pma"
            "$base\crash*.pma"
        )
    }
}

function Invoke-TempCleanup {
    Write-Host "`n  === Limpeza de Arquivos Temporarios ===`n" -ForegroundColor Cyan
    Write-Host "  O que sera feito:" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "   1. " -NoNewline -ForegroundColor DarkGray
    Write-Host "Lixeira" -NoNewline -ForegroundColor White
    Write-Host " - Esvazia a lixeira de todos os usuarios" -ForegroundColor DarkGray
    Write-Host "   2. " -NoNewline -ForegroundColor DarkGray
    Write-Host "Pastas Temp" -NoNewline -ForegroundColor White
    Write-Host " - Temp dos usuarios e C:\Windows\Temp" -ForegroundColor DarkGray
    Write-Host "   3. " -NoNewline -ForegroundColor DarkGray
    Write-Host "Logs do Windows" -NoNewline -ForegroundColor White
    Write-Host " - CBS, Setup, Panther, WinSAT, .NET, etc." -ForegroundColor DarkGray
    Write-Host "   4. " -NoNewline -ForegroundColor DarkGray
    Write-Host "Logs do OneDrive" -NoNewline -ForegroundColor White
    Write-Host " - Logs, .odl, .aodl, .otc, .qmlc" -ForegroundColor DarkGray
    Write-Host "   5. " -NoNewline -ForegroundColor DarkGray
    Write-Host "Crash dumps" -NoNewline -ForegroundColor White
    Write-Host " - Arquivos .dmp de programas" -ForegroundColor DarkGray
    Write-Host "   6. " -NoNewline -ForegroundColor DarkGray
    Write-Host "Cache do IE/Edge Legacy" -NoNewline -ForegroundColor White
    Write-Host " - WebCache, INetCache, thumbnails" -ForegroundColor DarkGray
    Write-Host "   7. " -NoNewline -ForegroundColor DarkGray
    Write-Host "Cache do Edge" -NoNewline -ForegroundColor White
    Write-Host " - Cache, GPUCache, Service Workers, Code Cache" -ForegroundColor DarkGray
    Write-Host "   8. " -NoNewline -ForegroundColor DarkGray
    Write-Host "Cache do Firefox" -NoNewline -ForegroundColor White
    Write-Host " - Cache e scripts compilados" -ForegroundColor DarkGray
    Write-Host "   9. " -NoNewline -ForegroundColor DarkGray
    Write-Host "Cache do Chrome" -NoNewline -ForegroundColor White
    Write-Host " - Cache, GPUCache, Service Workers, Code Cache" -ForegroundColor DarkGray
    Write-Host "  10. " -NoNewline -ForegroundColor DarkGray
    Write-Host "Cache do Brave" -NoNewline -ForegroundColor White
    Write-Host " - Cache, GPUCache, Service Workers, Code Cache" -ForegroundColor DarkGray
    Write-Host "  11. " -NoNewline -ForegroundColor DarkGray
    Write-Host "Cache do Vivaldi" -NoNewline -ForegroundColor White
    Write-Host " - Cache, GPUCache, Service Workers, Code Cache" -ForegroundColor DarkGray
    Write-Host "  12. " -NoNewline -ForegroundColor DarkGray
    Write-Host "Spotify" -NoNewline -ForegroundColor White
    Write-Host " - Cache de dados e browser" -ForegroundColor DarkGray
    Write-Host "  13. " -NoNewline -ForegroundColor DarkGray
    Write-Host "Adobe Media Cache" -NoNewline -ForegroundColor White
    Write-Host " - Cache de midia e logs" -ForegroundColor DarkGray
    Write-Host "  14. " -NoNewline -ForegroundColor DarkGray
    Write-Host "VMware" -NoNewline -ForegroundColor White
    Write-Host " - Logs" -ForegroundColor DarkGray
    Write-Host "  15. " -NoNewline -ForegroundColor DarkGray
    Write-Host "TeamViewer" -NoNewline -ForegroundColor White
    Write-Host " - Cache do browser integrado" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [!] Navegadores abertos serao fechados automaticamente." -ForegroundColor DarkYellow
    Write-Host "  [!] Apaga somente cache/temp. Senhas e favoritos NAO sao afetados." -ForegroundColor DarkYellow
    Write-Host ""

    if (-not (Confirm-Action "Executar limpeza de temporarios?")) {
        Write-Info "Limpeza cancelada pelo usuario."
        return
    }
    Write-Host ""

    # --- 1. Lixeira ---
    Write-Step "[01/15] Esvaziando lixeira..."
    Clear-RecycleBin -Confirm:$false -ErrorAction SilentlyContinue
    Write-Ok "Lixeira esvaziada."

    # --- 2. Pastas Temp ---
    Write-Step "[02/15] Limpando pastas Temp dos usuarios..."
    foreach ($user in Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue) {
        $tempDir = Join-Path $user.FullName "AppData\Local\Temp"
        if (Test-Path $tempDir) {
            Remove-Item "$tempDir\*" -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    Write-Step "[02/15] Limpando C:\Windows\Temp..."
    Remove-Item "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Ok "Pastas Temp limpas."

    # --- 3. Logs do Windows ---
    Write-Step "[03/15] Removendo logs do Windows..."
    $winLogs = @(
        "C:\Windows\Logs\cbs\*.log"
        "C:\Windows\setupact.log"
        "C:\Windows\Logs\MeasuredBoot\*.log"
        "C:\Windows\Logs\MoSetup\*.log"
        "C:\Windows\Panther\*.log"
        "C:\Windows\Performance\WinSAT\winsat.log"
        "C:\Windows\inf\*.log"
        "C:\Windows\logs\*.log"
        "C:\Windows\SoftwareDistribution\*.log"
        "C:\Windows\Microsoft.NET\*.log"
    )
    Remove-Silently $winLogs
    # Logs do MpCmdRun em ServiceProfiles
    Remove-Silently @(
        "C:\Windows\ServiceProfiles\LocalService\AppData\Local\Temp\MpCmdRun.log"
        "C:\Windows\ServiceProfiles\NetworkService\AppData\Local\Temp\MpCmdRun.log"
    )
    foreach ($user in Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue) {
        Remove-Silently @("$($user.FullName)\AppData\Local\Microsoft\*.log")
    }
    Write-Ok "Logs do Windows removidos."

    # --- 4. Logs do OneDrive ---
    Write-Step "[04/15] Removendo logs do OneDrive..."
    $odProcs = Get-Process -Name "OneDrive" -ErrorAction SilentlyContinue
    if ($odProcs) { Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 1 }
    foreach ($user in Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue) {
        $odBase = "$($user.FullName)\AppData\Local\Microsoft\OneDrive"
        Remove-Silently @(
            "$odBase\setup\logs\*.log"
            "$odBase\*.odl"
            "$odBase\*.aodl"
            "$odBase\*.otc"
        )
        Remove-Silently @("$($user.FullName)\AppData\Local\OneDrive\*.qmlc")
    }
    Write-Ok "Logs do OneDrive removidos."

    # --- 5. Crash dumps ---
    Write-Step "[05/15] Removendo crash dumps de programas..."
    foreach ($user in Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue) {
        Remove-Silently @("$($user.FullName)\AppData\Local\CrashDumps\*.dmp")
    }
    Write-Ok "Crash dumps removidos."

    # --- 6. Cache IE/Edge Legacy ---
    Write-Step "[06/15] Limpando cache do IE/Edge Legacy..."
    foreach ($user in Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue) {
        $base = $user.FullName
        Remove-Silently @(
            "$base\AppData\Local\Microsoft\Windows\Explorer\*.db"
            "$base\AppData\Local\Microsoft\Windows\WebCache\*.log"
            "$base\AppData\Local\Microsoft\Windows\SettingSync\*.log"
            "$base\AppData\Local\Microsoft\Windows\Explorer\ThumbCacheToDelete\*.tmp"
            "$base\AppData\Local\Microsoft\Terminal Server Client\Cache\*.bin"
            "$base\AppData\Local\Microsoft\Windows\INetCache\IE\*"
            "$base\AppData\Local\Microsoft\Windows\INetCache\Low\*"
            "$base\AppData\LocalLow\Microsoft\CryptnetUrlCache\Content\*"
            "$base\AppData\LocalLow\Microsoft\CryptnetUrlCache\MetaData\*"
        )
    }
    Write-Ok "Cache IE/Edge Legacy limpo."

    # --- 7-11. Navegadores modernos ---
    Write-Step "[07/15] Limpando cache do Edge..."
    Remove-BrowserCache "Edge" "msedge" "Microsoft\Edge\User Data"
    Write-Ok "Cache do Edge limpo."

    Write-Step "[08/15] Limpando cache do Firefox..."
    $fxProc = Get-Process -Name "firefox" -ErrorAction SilentlyContinue
    if ($fxProc) { Stop-Process -Name "firefox" -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 1 }
    foreach ($user in Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue) {
        $fxPath = "$($user.FullName)\AppData\Local\Mozilla\Firefox\Profiles"
        if (Test-Path $fxPath) {
            Get-ChildItem $fxPath -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                Remove-Silently @(
                    "$($_.FullName)\cache2\entries\*"
                    "$($_.FullName)\cache2\doomed\*"
                    "$($_.FullName)\startupCache\*"
                    "$($_.FullName)\jumpListCache\*"
                )
            }
        }
    }
    Write-Ok "Cache do Firefox limpo."

    Write-Step "[09/15] Limpando cache do Chrome..."
    Remove-BrowserCache "Chrome" "chrome" "Google\Chrome\User Data"
    Remove-Silently @("C:\Program Files\Google\Chrome\Application\SetupMetrics\*.pma")
    Write-Ok "Cache do Chrome limpo."

    Write-Step "[10/15] Limpando cache do Brave..."
    Remove-BrowserCache "Brave" "brave" "BraveSoftware\Brave-Browser\User Data"
    Remove-Silently @("C:\Program Files\BraveSoftware\Brave-Browser\Application\SetupMetrics\*.pma")
    Write-Ok "Cache do Brave limpo."

    Write-Step "[11/15] Limpando cache do Vivaldi..."
    Remove-BrowserCache "Vivaldi" "vivaldi" "Vivaldi\User Data"
    Write-Ok "Cache do Vivaldi limpo."

    # --- 12. Spotify ---
    Write-Step "[12/15] Limpando cache do Spotify..."
    foreach ($user in Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue) {
        Remove-Silently @(
            "$($user.FullName)\AppData\Local\Spotify\Data\*.file"
            "$($user.FullName)\AppData\Local\Spotify\Browser\Cache\Cache_Data\f*"
            "$($user.FullName)\AppData\Local\Spotify\Browser\GPUCache\*"
        )
    }
    Write-Ok "Cache do Spotify limpo."

    # --- 13. Adobe Media Cache ---
    Write-Step "[13/15] Limpando Adobe Media Cache..."
    foreach ($user in Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue) {
        Remove-Silently @(
            "$($user.FullName)\AppData\Roaming\Adobe\Common\Media Cache Files\*"
            "$($user.FullName)\AppData\Roaming\Adobe\*.log"
        )
    }
    Write-Ok "Adobe Media Cache limpo."

    # --- 14. VMware ---
    Write-Step "[14/15] Limpando logs do VMware..."
    Remove-Silently @("C:\ProgramData\VMware\logs\*.log")
    Write-Ok "Logs do VMware limpos."

    # --- 15. TeamViewer ---
    Write-Step "[15/15] Limpando cache do TeamViewer..."
    foreach ($user in Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue) {
        $tvPath = "$($user.FullName)\AppData\Local\TeamViewer\EdgeBrowserControl"
        if (Test-Path $tvPath) {
            Remove-Item "$tvPath\Persistent\data_*" -Force -ErrorAction SilentlyContinue
            Get-ChildItem $tvPath -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match '^(f_.*|data\.|index\.|.*_[0-5])$' } |
                Remove-Item -Force -ErrorAction SilentlyContinue
        }
    }
    Write-Ok "Cache do TeamViewer limpo."

    Write-Host ""
    Write-Ok "Limpeza de arquivos temporarios concluida!"
}

#endregion

#region ── Backup e Restore de Drivers ────────────────────────────────────────

function Get-ValidDirectory {
    param([string]$Prompt)
    do {
        $path = Read-Host "  $Prompt"
        $path = $path.Trim('"').Trim()
        if (-not $path) {
            Write-Fail "Caminho nao pode ser vazio."
            continue
        }
        if (Test-Path $path) { return $path }
        $create = Read-Host "  Pasta nao encontrada. Criar '$path'? (S/n)"
        if ($create -eq '' -or $create -match '^[sS]') {
            try {
                New-Item -Path $path -ItemType Directory -Force | Out-Null
                return $path
            } catch {
                Write-Fail "Nao foi possivel criar a pasta: $_"
            }
        }
    } while ($true)
}

function Invoke-DriverBackup {
    Write-Host "`n  === Backup de Drivers ==="  -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  O que sera feito:" -ForegroundColor DarkGray
    Write-Host "  - Exporta todos os drivers de terceiros instalados para uma pasta" -ForegroundColor DarkGray
    Write-Host "  - Usa: dism /online /export-driver" -ForegroundColor DarkGray
    Write-Host "  - Cada driver fica em sua propria subpasta com os arquivos .inf/.sys" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [!] Somente drivers de terceiros sao exportados (nao os drivers" -ForegroundColor DarkYellow
    Write-Host "      embutidos do Windows). Ideal para guardar antes de reinstalar." -ForegroundColor DarkYellow
    Write-Host ""

    $dest = Get-ValidDirectory "Digite o caminho da pasta de destino para o backup"

    Write-Host ""
    if (-not (Confirm-Action "Fazer backup dos drivers em '$dest'?")) {
        Write-Info "Backup cancelado pelo usuario."
        return
    }
    Write-Host ""

    Write-Step "Exportando drivers..."
    $result = & dism /online /export-driver /destination:"$dest" 2>&1
    if ($LASTEXITCODE -eq 0) {
        $count = (Get-ChildItem $dest -Directory -ErrorAction SilentlyContinue).Count
        Write-Host ""
        Write-Ok "Backup concluido! $count drivers exportados para '$dest'."
    } else {
        Write-Host ""
        Write-Fail "DISM retornou erro (codigo $LASTEXITCODE)."
        Write-Host "  $result" -ForegroundColor DarkGray
    }
}

function Invoke-DriverRestore {
    Write-Host "`n  === Restore de Drivers ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  O que sera feito:" -ForegroundColor DarkGray
    Write-Host "  - Instala todos os drivers (.inf) encontrados na pasta selecionada" -ForegroundColor DarkGray
    Write-Host "  - Usa: pnputil /add-driver *.inf /subdirs /install" -ForegroundColor DarkGray
    Write-Host "  - Procura recursivamente em todas as subpastas" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [!] Use a pasta gerada pelo Backup de Drivers desta ferramenta," -ForegroundColor DarkYellow
    Write-Host "      ou qualquer pasta com arquivos .inf de drivers." -ForegroundColor DarkYellow
    Write-Host ""

    $src = ""
    do {
        $src = (Read-Host "  Digite o caminho da pasta com os drivers").Trim('"').Trim()
        if (-not $src) { Write-Fail "Caminho nao pode ser vazio."; continue }
        if (Test-Path $src) { break }
        Write-Fail "Pasta nao encontrada: '$src'"
    } while ($true)

    # Conta quantos .inf existem
    $infCount = (Get-ChildItem $src -Recurse -Filter "*.inf" -ErrorAction SilentlyContinue).Count
    if ($infCount -eq 0) {
        Write-Fail "Nenhum arquivo .inf encontrado em '$src'."
        return
    }

    Write-Host ""
    Write-Info "Encontrados $infCount arquivos .inf na pasta selecionada."
    Write-Host ""
    if (-not (Confirm-Action "Instalar todos os $infCount drivers de '$src'?")) {
        Write-Info "Restore cancelado pelo usuario."
        return
    }
    Write-Host ""

    Write-Step "Instalando drivers..."
    & pnputil /add-driver "$src\*.inf" /subdirs /install
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Ok "Restore concluido! Pode ser necessario reiniciar para ativar todos os drivers."
    } else {
        Write-Host ""
        Write-Info "pnputil finalizado (codigo $LASTEXITCODE). Verifique a saida acima por erros."
    }
}

#endregion

#region ── Rede ──────────────────────────────────────────────────────────

function Invoke-WifiDiagnostic {
    Write-Host "`n  === Diagnostico Wi-Fi ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  O que sera feito:" -ForegroundColor DarkGray
    Write-Host "  - Exibe o status atual de todas as interfaces Wi-Fi do sistema" -ForegroundColor DarkGray
    Write-Host "  - Opcionalmente gera um relatorio HTML completo de conectividade" -ForegroundColor DarkGray
    Write-Host ""

    Write-Step "Interfaces Wi-Fi detectadas:"
    Write-Host ""
    & netsh wlan show interfaces
    Write-Host ""

    $genReport = Read-Host "  Gerar relatorio HTML de diagnostico Wi-Fi? (S/n)"
    if ($genReport -eq '' -or $genReport -match '^[sS]') {
        Write-Host ""
        Write-Step "Gerando relatorio WLAN..."
        & netsh wlan show wlanreport | Out-Null
        $reportPath = "$env:ProgramData\Microsoft\Windows\WlanReport\wlan-report-latest.html"
        if (Test-Path $reportPath) {
            Write-Ok "Relatorio gerado em:"
            Write-Host "  $reportPath" -ForegroundColor DarkGray
            Write-Host ""
            $open = Read-Host "  Abrir relatorio no navegador? (S/n)"
            if ($open -eq '' -or $open -match '^[sS]') {
                Start-Process $reportPath
            }
        } else {
            Write-Fail "Relatorio nao encontrado. Verifique se o Wi-Fi esta ativo."
        }
    }
}

#endregion

function Show-Menu {
    Clear-Host
    $build = [System.Environment]::OSVersion.Version.Build
    Write-Host ""
    Write-Host "  ================================================================" -ForegroundColor Cyan
    Write-Host "       Windows 10/11 - Pos-Instalacao  v1.0                       " -ForegroundColor Cyan
    Write-Host "  ================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  -- Programas ------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "  [1]  Instalar programas - Normal       (8 programas)"
    Write-Host "  [2]  Instalar programas - Devs         (Normal + 9 extras)"
    Write-Host ""
    Write-Host "  -- Sistema --------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "  [3]  Aplicar tweaks do sistema         (10 ajustes)"
    Write-Host "  [4]  Criar tarefa de atualizacao semanal (winget)"
    Write-Host ""
    Write-Host "  -- Manutencao -----------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "  [5]  Manutencao do sistema (DISM/SFC)"
    Write-Host "  [6]  Limpeza de arquivos temporarios"
    Write-Host ""
    Write-Host "  -- Drivers --------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "  [7]  Backup de drivers"
    Write-Host "  [8]  Restore de drivers"
    Write-Host ""
    Write-Host "  -- Rede -----------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "  [9]  Diagnostico Wi-Fi"
    Write-Host ""
    Write-Host "  ---------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "  [0]  Sair"
    Write-Host ""
}

#endregion

#region ── Loop Principal ─────────────────────────────────────────────────────

do {
    Show-Menu
    $choice = Read-Host "  Escolha uma opcao"

    switch ($choice) {
        "1" { Install-NormalApps;          Press-Key }
        "2" { Install-DevApps;             Press-Key }
        "3" { Invoke-AllTweaks;            Press-Key }
        "4" { Register-WingetUpdateTask;   Press-Key }
        "5" { Invoke-SystemMaintenance;    Press-Key }
        "6" { Invoke-TempCleanup;          Press-Key }
        "7" { Invoke-DriverBackup;         Press-Key }
        "8" { Invoke-DriverRestore;         Press-Key }
        "9" { Invoke-WifiDiagnostic;        Press-Key }
        "0" { }
        default {
            Write-Fail "Opcao invalida!"
            Start-Sleep -Seconds 1
        }
    }
} while ($choice -ne "0")

Write-Host "`n  Ate mais!`n" -ForegroundColor Green
Start-Sleep -Seconds 2

#endregion
