# Entre Veus: trabalho versionado

- Esta pasta e a copia de trabalho de `leonardomarcuzzo95-wq/entre-veus-projeto`. Edite os arquivos reais em `jogo/atualizacao-1525`, nao uma copia em `exportar-github`.
- `exportar-github/` conserva pacotes documentais historicos; nao e a fonte do desenvolvimento atual.
- A lista `versionamento/arquivos-publicos.xml` define exatamente o que pode ser versionado. Novos arquivos exigem revisao de conteudo/licenca e inclusao explicita nessa lista e no `.gitignore`. Nunca use `git add -f` para contornar exclusoes.
- Antes de commit/envio, rode `pwsh -NoProfile -File versionamento/Verificar-Repositorio.ps1 -CheckIndex` depois de preparar o index e atualizar MANIFESTO.xml com o script correspondente. Confira `git diff --cached`.
- Credenciais, configuracoes privadas, backups SQL, banco, logs, binarios, dependencias extraidas e recursos herdados sem procedencia comprovada ficam fora do Git. Os runtimes privados ficam em AppData; nunca copie seus dados para relatorios publicos.
- Nao executar inicializacao, geracao de mundo, login ou testes de missao apenas para verificar sintaxe. CI nao constitui teste de ponta a ponta.
- Em teste real de conteudo, usar Explorador QA e preservar Viajante. Mapa, IDs 62000-62012, chave 110020 e recompensa unica de 100 XP continuam invariantes ate autorizacao especifica para mudar conteudo.
- Preservar os testes reais e seus horarios; reexecutar um teste unitario com fixture historica nao cria evidencia nova de gameplay.
- Canary e OTClient completos permanecem dependencias externas nas revisoes registradas. Siga os AGENTS.md dessas bases antes de altera-las.
- Commits devem descrever alteracao e verificacao. Ferramentas autenticadas pela conta do usuario podem aparecer como essa conta; registrar o uso de assistente na mensagem, sem inventar autoria humana de terceiros.
- Nao abrir portas, publicar servidor ou iniciar integracao financeira como parte de commit ou sincronizacao Git.
