# Entre Véus — Porto da Memória

**Atualizado em 02/10/2026:** cliente e servidor funcionando no protocolo **15.25**, com entrada automática e um primeiro recorte de conteúdo próprio. O jogo está disponível neste computador; ainda não está publicado na internet.

## Como jogar

1. Na pasta principal, abra **`Jogar.cmd`**. Ele prepara banco, login e servidor, abre o cliente atualizado e entra automaticamente como **Viajante**.
2. Use as setas para andar. Procure **Maia**, a personagem dourada ao norte da praça central. A posição anterior do Viajante foi preservada; se estiver no lado oeste da vila, siga para a praça.
3. Perto de Maia, diga **`oi`**. Na conversa com ela, digite **`missao`**. Ela entrega uma bolsa e explica como recuperar o fragmento azul a leste.
4. Caminhe sobre o fragmento, volte até Maia e diga **`oi`**, depois **`missao`** na conversa. A recompensa é uma lembrança do porto e **100 pontos de experiência**, concedidos uma vez por personagem.
5. Para encerrar, faça logout e abra **`Encerrar-servidor.cmd`**. Os serviços salvam antes de fechar. Se alguém estiver conectado, o encerramento pede que saia primeiro.

Se precisar consultar a senha, abra **`Ver-acesso.cmd`**. A conta e a senha continuam as mesmas. Use os atalhos da pasta principal para que os serviços e o preenchimento automático sejam preparados.

## O que mudou

| Área | Versão anterior | Versão atual |
| --- | --- | --- |
| Protocolo | 15.11 | **15.25** |
| Servidor | Canary estável 3.6.1 | Canary da revisão de 27/09/2026, com executável correspondente |
| Cliente | OTClient 4.1 | OTClient da revisão de 01/10/2026, com executável correspondente |
| Mundo | Mapa de teste 31 × 31 | **Porto da Memória, 61 × 41**, com praça, casas, costa, árvores, farol e fragmento |
| Arte própria | 3 sprites simples | **18 sprites** de protótipo, desenhados por código |
| Conteúdo | Deslocamento | **Maia**, **Eco Errante**, bolsa, lembrança e primeira missão |

As revisões atuais são **compilações de desenvolvimento**, fixadas por commit e verificadas por hash. Não representam uma nova release estável. **15.25 é a versão compatível do Canary verificada nesta atualização; não foi confirmado que seja a versão mais recente do Tibia oficial.**

O mapa, os novos pixels, nomes e diálogos são próprios. A interface ainda possui elementos herdados e a arte é inicial, sem animação final nem áudio próprio. Mais sistemas, ícones e recursos serão substituídos ou revisados antes de distribuição pública.

## Dados preservados e versão anterior

A atualização usa uma cópia independente do banco original. O personagem Viajante, sua conta e sua posição foram preservados; a inicialização não redefine personagens existentes.

- **Atual:** `atualizacao-1525/servidor`, `atualizacao-1525/cliente` e banco `entreveus_1525`.
- **Anterior:** `servidor`, `cliente` e banco `entreveus`. Abra **`Jogar-versao-anterior.cmd`** para acessá-la.
- O progresso realizado após a cópia **não é sincronizado** entre as duas versões. Não copie tabelas isoladas de volta para o banco antigo.
- Os ZIPs originais e as referências em `bases/` permanecem preservados.

| Dados | Local |
| --- | --- |
| Banco MariaDB portátil compartilhado | `%LOCALAPPDATA%\EntreVeus` |
| Configuração, segredos e logs da atualização | `%LOCALAPPDATA%\EntreVeus1525` |
| Backup SQL anterior à migração | `%LOCALAPPDATA%\EntreVeus1525\backups` |
| Preferências e capturas do novo cliente | `%APPDATA%\entreveus\entreveus1525\entreveus1525` |
| Relatórios sem credenciais | `../avaliacao/atualizacao-1525` |

O banco e os segredos ficam fora do OneDrive. A pasta do projeto não contém um backup completo da instalação. Não distribua `credentials.json`, arquivos de conexão ou backups SQL com credenciais e contas.

O servidor novo usa portas **7271/7272/7273**, login HTTP **8090** e MariaDB **3307**, somente em **127.0.0.1**. A versão anterior usa 7171/7172/7173 e 8088. O atalho de encerramento fecha ambos os servidores antes de desligar o banco compartilhado.

## Validação

Foram verificados com o cliente real: carregamento dos recursos 15.25, login, caminhada, saída/reconexão, diálogo com Maia, coleta do fragmento, entrega da recompensa e rejeição de uma segunda recompensa. O banco confirmou uma bolsa, uma lembrança, 100 pontos de experiência e o estado final da missão para o personagem de teste separado **Explorador QA**.

Servidor e banco também foram reiniciados. O atalho normal voltou a conectar o Viajante automaticamente, preservando sua posição. A missão e o inventário do personagem de teste continuaram salvos.

Resultados históricos de **02/10/2026**: [relatório de verificação](../avaliacao/atualizacao-1525/verificacao.json), [captura da missão](../avaliacao/atualizacao-1525/missao.png) e [captura da entrada automática](../avaliacao/atualizacao-1525/entrada-automatica.png). Esses arquivos permanecem intactos. Detalhes e comandos estão em [ATUALIZACAO-15.25.md](../avaliacao/ATUALIZACAO-15.25.md).

### Relatórios com eventos — revisão de 06/10/2026

O formato 2 registra `runId`, horários ISO-8601 UTC, sequência e milissegundos decorridos em cada evento. `success` continua disponível por compatibilidade e representa o resultado da verificação; `result` delimita seu escopo e conclusão. `state` descreve a última conexão observada, com horário. Um login confirmado pode ser seguido por desconexão: isso não apaga o resultado nem oculta o evento posterior.

`eventSummary.errorOrder` indica se houve erro antes, depois, dos dois lados do sucesso ou nenhum erro observado. Eventos no mesmo segundo são ordenados por `sequence`. **Erro antes do sucesso não prova sozinho uma segunda tentativa.** O erro antigo não tinha horário próprio; sua ordem permanece indeterminada.

`Test-Content.ps1` produz uma execução identificada, somente com **Explorador QA**, e observa seu login no modo `qa-observer`. Não testa a entrada automática interativa do Viajante. O verificador exige **experiência persistida do QA exatamente igual a 100 XP**, além de uma bolsa, uma lembrança e estado final 2. JSONs de runs diferentes, antigos ou sem eventos válidos são rejeitados; a leitura do banco não repete a missão.

Os resultados novos ficam em `avaliacao/atualizacao-1525/execucoes/<runId>/`; [ultimo-relatorio.json](../avaliacao/atualizacao-1525/ultimo-relatorio.json) aponta para a última verificação. Cada verificação possui nome próprio para preservar as anteriores. As cópias históricas idênticas estão em `avaliacao/atualizacao-1525/historico/2026-10-02/`, com `isHistorical: true` no manifesto. Os JSONs antigos não foram editados.

## Limites atuais

Este é um protótipo local. Ainda faltam teste com dois jogadores, balanceamento de combate, revisão completa de recursos herdados, áudio e arte final. Os sistemas herdados de criatura/chefe destacado ainda registram mensagens por não haver um catálogo apropriado no pacote próprio; esses sistemas não fazem parte da missão validada.

A publicação externa exigirá preparar hospedagem, autenticação pública, contas individuais, HTTPS, recuperação de backup e o pacote de recursos distribuível. Nenhuma hospedagem foi contratada nem porta externa foi aberta nesta atualização.

## Fontes e atribuições

- [Compilação Canary utilizada](https://github.com/opentibiabr/canary/actions/runs/36341321558), revisão `04b83b512114bfd888000d6e1433ed8ecaec7c5b`. Licença preservada em `atualizacao-1525/servidor/LICENSE`.
- [Compilação OTClient utilizada](https://github.com/opentibiabr/otclient/actions/runs/36897053359), revisão `396f0b396741bdd4469f27cf9376103930712cff`. Licença preservada em `atualizacao-1525/cliente/LICENSE`.
- [MariaDB 11.4.13](https://archive.mariadb.org/mariadb-11.4.13/winx64-packages/), mantido da instalação anterior.
- [Versões e hashes](atualizacao-1525/infra/dependencies.lock.json); [origem dos recursos próprios](atualizacao-1525/infra/lab-assets.json).

Entre Véus é um projeto independente, sem afiliação à CipSoft.
