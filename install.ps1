# ==============================================================================
#  Windows 11 - Pos-Instalacao :: Loader
#
#  Uso:
#    irm https://raw.githubusercontent.com/yduanrech/windows-scripts/main/install.ps1 | iex
#
#  Este loader baixa o script principal (WINpostinstall.bat) e o executa
#  com privilegios de administrador. O .bat e um polyglot batch+PowerShell
#  que funciona tanto por duplo-clique quanto via este loader.
# ==============================================================================

$repo   = "yduanrech/windows-scripts"
$branch = "main"
$file   = "WINpostinstall.bat"
$url    = "https://raw.githubusercontent.com/$repo/$branch/$file"

Clear-Host
Write-Host ""
Write-Host "  ================================================================" -ForegroundColor Cyan
Write-Host "       Windows 11 - Pos-Instalacao                                " -ForegroundColor Cyan
Write-Host "  ================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Repo: github.com/$repo"                                            -ForegroundColor DarkGray
Write-Host ""
Write-Host "  [1]  Executar agora (baixa e inicia como Administrador)"
Write-Host "  [2]  Baixar para a Area de Trabalho"
Write-Host "  [3]  Baixar para a pasta Downloads"
Write-Host ""
Write-Host "  [0]  Sair"
Write-Host ""

$choice = Read-Host "  Escolha uma opcao"

function Download-Script ([string]$Dest) {
    Write-Host ""
    Write-Host "  Baixando $file ..." -ForegroundColor Yellow
    try {
        Invoke-RestMethod -Uri $url -OutFile $Dest -ErrorAction Stop
        return $true
    }
    catch {
        Write-Host "  [ERRO] Falha ao baixar: $_" -ForegroundColor Red
        return $false
    }
}

switch ($choice) {
    "1" {
        $dest = Join-Path $env:TEMP $file
        if (Download-Script $dest) {
            Write-Host "  Iniciando como Administrador (UAC)..." -ForegroundColor Green
            try {
                Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$dest`"" -Verb RunAs
            }
            catch {
                Write-Host "  [ERRO] Elevacao cancelada ou falhou." -ForegroundColor Red
            }
        }
    }
    "2" {
        $dest = Join-Path ([Environment]::GetFolderPath("Desktop")) $file
        if (Download-Script $dest) {
            Write-Host "  Salvo em: $dest" -ForegroundColor Green
            Write-Host ""
            Write-Host "  Para executar: clique com o botao direito > Executar como administrador" -ForegroundColor Yellow
        }
    }
    "3" {
        $downloads = (New-Object -ComObject Shell.Application).Namespace('shell:Downloads').Self.Path
        $dest = Join-Path $downloads $file
        if (Download-Script $dest) {
            Write-Host "  Salvo em: $dest" -ForegroundColor Green
            Write-Host ""
            Write-Host "  Para executar: clique com o botao direito > Executar como administrador" -ForegroundColor Yellow
        }
    }
    "0" { return }
    default {
        Write-Host "  Opcao invalida." -ForegroundColor Red
    }
}

Write-Host ""
