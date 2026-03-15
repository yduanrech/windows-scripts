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

# Definicao de todos os tweaks com nome, descricao e funcao
$tweakList = @(
    @{
        Name = "Menu de contexto classico"
        Desc = "Restaura o menu do botao direito estilo Windows 10 (sem o 'Mostrar mais opcoes')"
        Action = {
            reg.exe add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /f /ve | Out-Null
        }
    }
    @{
        Name = "Mostrar extensoes de arquivo"
        Desc = "Exibe .txt, .exe, .jpg etc. no nome dos arquivos no Explorer"
        Action = {
            Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" 0
        }
    }
    @{
        Name = "Mostrar arquivos ocultos"
        Desc = "Torna visiveis arquivos e pastas ocultos no Explorer"
        Action = {
            Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Hidden" 1
        }
    }
    @{
        Name = "Ocultar barra de idiomas"
        Desc = "Remove o indicador de idioma (POR/ENG) da barra de tarefas"
        Action = {
            Set-RegistryValue "HKCU:\Software\Microsoft\CTF\LangBar" "ShowStatus" 3
        }
    }
    @{
        Name = "Notificacoes de apps na inicializacao"
        Desc = "Alerta quando um programa se adiciona a inicializacao do Windows"
        Action = {
            Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.StartupApp" "Enabled" 1
        }
    }
    @{
        Name = "Windows Terminal como padrao"
        Desc = "Define o Windows Terminal como terminal padrao do sistema"
        Action = {
            $path = "HKCU:\Console\%%Startup"
            Set-RegistryValue $path "DelegationConsole"  "{2EACA947-7F5F-4CFA-BA87-8F7FBEEFBE69}" "String"
            Set-RegistryValue $path "DelegationTerminal" "{E12CFF52-A866-4C77-9A90-F570A7AA2C6B}" "String"
        }
    }
    @{
        Name = "Plano de energia: Alto Desempenho"
        Desc = "Ativa o plano Alto Desempenho (mais performance, mais consumo de energia)"
        Action = {
            powercfg -duplicatescheme 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null | Out-Null
            powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
        }
    }
    @{
        Name = "Historico da area de transferencia"
        Desc = "Ativa o historico de copiar/colar (acesse com Win+V)"
        Action = {
            Set-RegistryValue "HKCU:\Software\Microsoft\Clipboard" "EnableClipboardHistory" 1
        }
    }
    @{
        Name = "Desabilitar hibernacao e inicializacao rapida"
        Desc = "Remove o arquivo de hibernacao (hiberfil.sys) e desliga o Fast Startup"
        Action = {
            powercfg /h off 2>$null
            Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" "HiberbootEnabled" 0
        }
    }
)

function Invoke-AllTweaks {
    Write-Host "`n  === Tweaks do Sistema ===`n" -ForegroundColor Cyan
    Write-Host "  O que sera feito:" -ForegroundColor DarkGray
    Write-Host ""
    $i = 1
    foreach ($t in $tweakList) {
        Write-Host ("  {0,2}. " -f $i) -NoNewline -ForegroundColor DarkGray
        Write-Host "$($t.Name)" -NoNewline -ForegroundColor White
        Write-Host " - $($t.Desc)" -ForegroundColor DarkGray
        $i++
    }
    Write-Host ""
    Write-Host "  + Reinicia o Explorer para aplicar as alteracoes visuais" -ForegroundColor DarkGray
    Write-Host ""

    if (-not (Confirm-Action "Aplicar todos os $($tweakList.Count) tweaks?")) {
        Write-Info "Tweaks cancelados pelo usuario."
        return
    }
    Write-Host ""

    $current = 0
    foreach ($t in $tweakList) {
        $current++
        Write-Step "[$current/$($tweakList.Count)] $($t.Name)"
        & $t.Action
    }

    Write-Step "Reiniciando Explorer..."
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Start-Process explorer.exe

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
    Write-Host "  [1]  Instalar programas - Normal       (8 programas)"
    Write-Host "  [2]  Instalar programas - Devs         (Normal + 9 extras)"
    Write-Host ""
    Write-Host "  -- Sistema --------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "  [3]  Aplicar tweaks do sistema         (9 ajustes)"
    Write-Host "  [4]  Criar tarefa de atualizacao semanal (winget)"
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
