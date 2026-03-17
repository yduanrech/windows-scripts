# WinKit

Toolkit de pós-instalação para Windows 10/11. Instala programas, aplica otimizações, realiza manutenção e faz diagnósticos — tudo em um único script com menu interativo.

## Como usar

### Opção 1 — Online (recomendado)

Execute no PowerShell como Administrador:

```powershell
irm https://raw.githubusercontent.com/yduanrech/windows-scripts/main/install.ps1 | iex
```

### Opção 2 — Offline

Baixe o [WinKit.bat](https://raw.githubusercontent.com/yduanrech/windows-scripts/main/WinKit.bat) e execute como Administrador.

---

## O que o script faz

### Programas
| Opção | Descrição |
|---|---|
| `[1]` Normal | Instala 8 programas essenciais via winget |
| `[2]` Devs | Tudo do Normal + 9 ferramentas de desenvolvimento |

**Normal:** Google Chrome, 7-Zip, Bitwarden, Ente Auth, Microsoft PowerToys, Adobe Acrobat Reader, MPC-HC, WizTree

**Dev (extras):** VS Code, Notepad++, NVM, HeidiSQL, Git, GitHub Desktop, PuTTY, WinSCP, OpenVPN

---

### Sistema
| Opção | Descrição |
|---|---|
| `[3]` Tweaks | Aplica 12 ajustes de registro e configurações |
| `[4]` Atualização semanal | Cria tarefa agendada para `winget upgrade` toda segunda-feira |

**Tweaks incluídos:**
- Mostrar extensões de arquivo
- Mostrar arquivos ocultos
- Ocultar barra de idiomas
- Suprimir notificações de apps na inicialização
- Plano de energia: Alto Desempenho
- Habilitar histórico da área de transferência (Win+V)
- Desabilitar hibernação e Fast Startup
- Desabilitar pesquisa Bing no menu Iniciar
- Desabilitar sugestões online no File Explorer
- Menu de contexto clássico *(Win11)*
- Windows Terminal como padrão *(Win11)*
- Mostrar porcentagem de bateria na barra de tarefas *(Win11 24H2+)*

> Tweaks incompatíveis com a versão do Windows são detectados e ignorados automaticamente.

---

### Manutenção
| Opção | Descrição |
|---|---|
| `[5]` Manutenção do sistema | DISM (reparo e limpeza do WinSxS) + SFC |
| `[6]` Limpeza de temporários | Remove arquivos temporários de ~15 categorias |

**Limpeza cobre:** Temp do usuário/sistema, prefetch, Windows Update cache, Minidumps, logs do Event Viewer, caches do Chrome/Edge/Firefox/Brave/TeamViewer, entre outros.

---

### Drivers
| Opção | Descrição |
|---|---|
| `[7]` Backup de drivers | Exporta todos os drivers de terceiros instalados para uma pasta |
| `[8]` Restore de drivers | Instala drivers a partir de uma pasta de backup |

---

### Rede
| Opção | Descrição |
|---|---|
| `[9]` Status Wi-Fi | Exibe status atual das interfaces (rede, sinal, velocidade) |
| `[10]` Relatório Wi-Fi | Gera relatório HTML completo de diagnóstico WLAN |