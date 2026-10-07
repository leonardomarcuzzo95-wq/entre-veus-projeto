```xml
<?xml version="1.0" encoding="UTF-8"?>
<apresentacao idioma="pt-BR" data="2026-10-07">
  <projeto>Entre Véus — Porto da Memória</projeto>
  <subtitulo>Um RPG 2D autoral sobre exploração, encontros e memórias.</subtitulo>
  <idealizador>Leonardo Marcuzzo</idealizador>
  <inspiracao>Tibia e a experiência de mundos persistentes; projeto independente, sem vínculo oficial com Tibia ou CipSoft.</inspiracao>
  <estado>Protótipo local jogável. Servidor público, economia e moeda em exchange ainda não implementados.</estado>
  <estrutura_societaria natureza="diretriz permanente pretendida; formalização pendente">
    <participacao titular="Leonardo Marcuzzo" percentual="51" />
    <participacao titular="Demais acionistas, em conjunto" percentual="49" />
    <principio>Preservar permanentemente essa divisão na futura sociedade do projeto.</principio>
    <limite>Esta declaração registra a intenção do idealizador; não constitui sociedade nem garante juridicamente a perpetuidade dos percentuais.</limite>
  </estrutura_societaria>
  <moeda estado="proposta futura">
    Estudar uma moeda digital própria com utilidade no jogo e possibilidade de negociação em exchange.
    Não existe token emitido ou listagem comprovada neste projeto.
    Moeda não representa automaticamente ações, dividendos ou direitos sobre o jogo.
    A distribuição de tokens não foi definida e não deve ser confundida com os 51%/49% societários.
  </moeda>
  <conteudo_do_repositorio>Documentação em XML, código próprio do laboratório, ajustes do cliente, scripts de operação e testes. Executáveis, banco, credenciais e recursos herdados não auditados permanecem locais.</conteudo_do_repositorio>
  <desenvolvimento>O trabalho ativo está em jogo/atualizacao-1525; os scripts de apoio usados pela inicialização também estão em jogo/infra. Um clone permite revisar e validar fontes, mas ainda não é um instalador completo do jogo.</desenvolvimento>
  <validacao>GitHub Actions verifica sintaxe e testes independentes dos relatórios. Isso não inicia o jogo nem substitui teste real com Explorador QA.</validacao>
  <documentos>
    <arquivo caminho="projeto.xml">Dossiê completo: conceito, história, produto, participação, moeda, etapas e fontes.</arquivo>
    <arquivo caminho="evidencias.xml">Resumo técnico e hashes dos registros de origem.</arquivo>
    <arquivo caminho="PUBLICAR.xml">Como exportar e organizar este material no GitHub.</arquivo>
    <arquivo caminho="MANIFESTO.xml">Integridade dos arquivos desta versão.</arquivo>
    <arquivo caminho="versionamento/CONEXAO-GITHUB.xml">Fluxo de trabalho, escopo publicado e limites da sincronização.</arquivo>
    <arquivo caminho="versionamento/LICENCAS.xml">Licenças das bases e limites dos recursos publicados.</arquivo>
  </documentos>
  <natureza>Documento de visão e planejamento. Não é oferta de ações ou tokens e não promete rentabilidade.</natureza>
</apresentacao>
```

[Dossiê em XML](projeto.xml) · [Evidências](evidencias.xml) · [Guia de publicação](PUBLICAR.xml) · [Manifesto](MANIFESTO.xml)

[Código do jogo](jogo/atualizacao-1525) · [Conexão e desenvolvimento](versionamento/CONEXAO-GITHUB.xml) · [Licenças](versionamento/LICENCAS.xml) · [Validações automáticas](https://github.com/leonardomarcuzzo95-wq/entre-veus-projeto/actions)
