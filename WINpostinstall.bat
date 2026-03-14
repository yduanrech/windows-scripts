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
    powershell -Command "Start-Process '%~dpnx0' -Verb RunAs"
    exit /b
)

:: Executa o PowerShell embutido neste mesmo arquivo
powershell -NoProfile -ExecutionPolicy Bypass -Command "& ([scriptblock]::Create((Get-Content -LiteralPath '%~dpnx0' -Raw -Encoding UTF8)))"
exit /b
#>

# ==============================================================================
#  Windows 11 - Script de Pos-Instalacao                                  v1.0
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

#region ── Listas de Aplicativos ───────────────────────────────────────────────

$appsNormal = @(
    "Google.Chrome"
    "7zip.7zip"
    "Bitwarden.Bitwarden"
    "ente-io.auth-desktop"
    "Microsoft.PowerToys"
    "Adobe.Acrobat.Reader.64-bit"
    "clsid2.mpc-hc"
    "AntibodySoftware.WizTree"
)

$appsDev = @(
    "Microsoft.VisualStudioCode"
    "Notepad++.Notepad++"
    "CoreyButler.NVMforWindows"
    "HeidiSQL.HeidiSQL"
    "Microsoft.Git"
    "GitHub.GitHubDesktop"
    "PuTTY.PuTTY"
    "WinSCP.WinSCP"
    "OpenVPNTechnologies.OpenVPN"
)

#endregion

#region ── Funcoes de Instalacao ───────────────────────────────────────────────

function Install-Apps {
    param([string]$Label, [string[]]$AppList)
    Write-Host "`n  === Instalando programas ($Label) ===`n" -ForegroundColor Cyan
    $total   = $AppList.Count
    $current = 0
    foreach ($app in $AppList) {
        $current++
        Write-Step "[$current/$total] $app"
        winget install -e --id $app --accept-source-agreements --accept-package-agreements
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
    Write-Host "`n  === Criando tarefa agendada (winget upgrade semanal) ===`n" -ForegroundColor Cyan

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

    # Remove tarefa existente, se houver
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

# 1. Menu de contexto classico (estilo Windows 10)
function Invoke-Tweak-ClassicContextMenu {
    Write-Step "Restaurando menu de contexto classico (estilo Windows 10)..."
    reg.exe add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /f /ve | Out-Null
}

# 2. Mostrar extensoes de arquivo no Explorer
function Invoke-Tweak-FileExtensions {
    Write-Step "Mostrando extensoes de arquivo no Explorer..."
    Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" 0
}

# 3. Mostrar arquivos ocultos no Explorer
function Invoke-Tweak-HiddenFiles {
    Write-Step "Mostrando arquivos ocultos no Explorer..."
    Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Hidden" 1
}

# 4. Ocultar barra de idiomas na taskbar
function Invoke-Tweak-HideLanguageBar {
    Write-Step "Ocultando barra de idiomas na taskbar..."
    Set-RegistryValue "HKCU:\Software\Microsoft\CTF\LangBar" "ShowStatus" 3
}

# 5. Ativar notificacoes de novos programas na inicializacao
function Invoke-Tweak-StartupNotifications {
    Write-Step "Ativando notificacoes de novos programas na inicializacao..."
    Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.StartupApp" "Enabled" 1
}

# 6. Usar Windows Terminal como terminal padrao
function Invoke-Tweak-DefaultTerminal {
    Write-Step "Definindo Windows Terminal como terminal padrao..."
    $path = "HKCU:\Console\%%Startup"
    Set-RegistryValue $path "DelegationConsole"  "{2EACA947-7F5F-4CFA-BA87-8F7FBEEFBE69}" "String"
    Set-RegistryValue $path "DelegationTerminal" "{E12CFF52-A866-4C77-9A90-F570A7AA2C6B}" "String"
}

# 7. Plano de energia: Alto Desempenho
function Invoke-Tweak-HighPerformance {
    Write-Step "Ativando plano de energia Alto Desempenho..."
    # Duplica o esquema caso nao esteja disponivel, depois ativa
    powercfg -duplicatescheme 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null | Out-Null
    powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
}

# 8. Ativar historico da area de transferencia (Win+V)
function Invoke-Tweak-ClipboardHistory {
    Write-Step "Ativando historico da area de transferencia (Win+V)..."
    Set-RegistryValue "HKCU:\Software\Microsoft\Clipboard" "EnableClipboardHistory" 1
}

# 9. Desabilitar hibernacao e inicializacao rapida
function Invoke-Tweak-DisableHibernation {
    Write-Step "Desabilitando hibernacao e arquivo de hibernacao..."
    powercfg /h off 2>$null
    Write-Step "Desabilitando inicializacao rapida (Fast Startup)..."
    Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" "HiberbootEnabled" 0
}

# Reiniciar Explorer para aplicar alteracoes visuais
function Invoke-RestartExplorer {
    Write-Step "Reiniciando Explorer para aplicar alteracoes..."
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Start-Process explorer.exe
}

# Aplica todos os tweaks de uma vez
function Invoke-AllTweaks {
    Write-Host "`n  === Aplicando todos os tweaks ===`n" -ForegroundColor Cyan
    Invoke-Tweak-ClassicContextMenu
    Invoke-Tweak-FileExtensions
    Invoke-Tweak-HiddenFiles
    Invoke-Tweak-HideLanguageBar
    Invoke-Tweak-StartupNotifications
    Invoke-Tweak-DefaultTerminal
    Invoke-Tweak-HighPerformance
    Invoke-Tweak-ClipboardHistory
    Invoke-Tweak-DisableHibernation
    Invoke-RestartExplorer
    Write-Host ""
    Write-Ok "Todos os tweaks aplicados com sucesso."
}

#endregion

#region ── Menu Principal ─────────────────────────────────────────────────────

function Show-Menu {
    Clear-Host
    $build = [System.Environment]::OSVersion.Version.Build
    Write-Host ""
    Write-Host "  ================================================================" -ForegroundColor Cyan
    Write-Host "       Windows 11 - Pos-Instalacao  v1.0   (Build $build)         " -ForegroundColor Cyan
    Write-Host "  ================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  -- Programas ------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "  [1]  Instalar programas - Normal"
    Write-Host "  [2]  Instalar programas - Devs (inclui Normal)"
    Write-Host ""
    Write-Host "  -- Sistema --------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "  [3]  Aplicar todos os tweaks do sistema"
    Write-Host "  [4]  Criar tarefa de atualizacao semanal (winget)"
    Write-Host ""
    Write-Host "  -- Completo -------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "  [5]  Tudo - Normal  + Tweaks + Tarefa"
    Write-Host "  [6]  Tudo - Devs    + Tweaks + Tarefa"
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
        "5" {
            Install-NormalApps
            Invoke-AllTweaks
            Register-WingetUpdateTask
            Press-Key
        }
        "6" {
            Install-DevApps
            Invoke-AllTweaks
            Register-WingetUpdateTask
            Press-Key
        }
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
