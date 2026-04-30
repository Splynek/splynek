# Splynek

> **Versão portuguesa abreviada.** Para a documentação completa, consulta [README.md](README.md) (em inglês).

Splynek é um gestor de transferências para macOS que junta todas as ligações de rede do teu Mac — Wi-Fi, Ethernet, partilha do iPhone — para transferir ficheiros mais depressa do que qualquer ligação isolada permite.

## O que faz Splynek diferente

- **Mais rápido** — agrega o débito de todas as redes a que estás ligado em simultâneo. Em testes, vê-se 1,8× a 3,5× mais rápido que o Safari numa única rede.
- **Honesto** — cada transferência é verificada contra a soma de controlo do editor. Nada se guarda no disco antes de a integridade ser confirmada.
- **Privado** — nada sai do teu Mac. Sem conta. Sem telemetria. Sem registos.
- **Soberano** — vê de onde vêm as apps no teu Mac, e quais têm alternativas europeias ou de código aberto.

## Os separadores principais

| Separador | O que faz |
|----------|-----------|
| **Transferências** | URL, soma de controlo opcional, escolhe as redes a usar, transfere. |
| **Torrents** | Suporte BitTorrent v1+v2 nativo (DHT, PEX, magnet, multi-ficheiro). |
| **Ao Vivo** | Vê o débito por rede em tempo real enquanto transfere. |
| **Soberania** | Analisa as apps instaladas e mostra alternativas europeias / código aberto. Local; nada sai do dispositivo. |
| **Confiança** | Auditoria de registo público das tuas apps — etiquetas de privacidade da App Store, multas regulamentares, CVEs, violações HIBP. Sem editorial. Cada afirmação cita a fonte. |
| **Agentes** | Servidor MCP — permite que o Claude, ChatGPT ou outros agentes IA conduzam o Splynek. Desligado por predefinição. |
| **Fila** | Fila persistente de URLs para transferir mais tarde. |
| **Frota** | Coordenação entre vários Macs na mesma rede local. |
| **Histórico** | Tudo o que já transferiste. Pesquisável, pesquisável pelo Spotlight. |

## Como instalar

**Mac App Store** (em revisão para a v1.0): https://apps.apple.com/app/splynek

**DMG diretamente** (gratuito, assinatura Developer ID, notarizado):
- [GitHub Releases](https://github.com/Splynek/splynek/releases) — descarrega o `.dmg` mais recente

**Homebrew**:
```bash
brew tap Splynek/splynek
brew install --cask splynek
```

## Privacidade — o contrato

- Splynek **nunca** envia dados para servidores nossos. Não temos servidores.
- Splynek **nunca** abre o conteúdo das tuas apps. As análises Soberania e Confiança lêem apenas a lista de pacotes instalados — o mesmo que o Spotlight.
- Splynek **nunca** carrega o teu histórico ou lista de apps para a nuvem.
- O servidor web local (que usa o Splynek para mostrar progresso ou para integração com extensões do navegador) escuta apenas em `127.0.0.1` por predefinição.

## Línguas suportadas

Splynek está disponível em **inglês**, **português (Portugal)**, **espanhol**, **francês**, **alemão** e **italiano**. Vê [LOCALIZATION.md](LOCALIZATION.md) para o fluxo de contribuição (PRs com traduções são bem-vindos).

## Contribuir

- O catálogo Soberania (1100+ apps, alternativas europeias / OSS) é mantido em [`Scripts/sovereignty-catalog.json`](Scripts/sovereignty-catalog.json) — vê [SOVEREIGNTY-CONTRIBUTING.md](SOVEREIGNTY-CONTRIBUTING.md).
- O catálogo Confiança (60 apps, com fontes primárias) é mantido em [`Scripts/trust-catalog.json`](Scripts/trust-catalog.json).
- Bugs, sugestões: [github.com/Splynek/splynek/issues](https://github.com/Splynek/splynek/issues).

## Licença

[BSD 3-Clause](LICENSE).
