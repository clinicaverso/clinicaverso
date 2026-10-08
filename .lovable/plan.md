# Fase 3 — Importação e exportação XLSX

## Objetivo
Adicionar **Importar cards** ao grupo Conteúdo para administradores e editores, sem reconstruir o CMS nem modificar as páginas do aluno.

## Experiência administrativa
- Fluxo: selecionar XLSX → validar → conferir prévia → decidir duplicatas → confirmar → acompanhar lotes → consultar relatório.
- Modos explícitos **Criar novos cards** e **Criar e atualizar**.
- Prévia com totais, operações por linha, erros bloqueantes, avisos, duplicatas, taxonomia proposta e distribuições por seção/área/status.
- Filtro de linhas problemáticas e download de relatório; confirmação com números exatos de criações e atualizações.
- Histórico persistente com responsável, arquivo, data, andamento, resultados e retomada de importações interrompidas.
- Exportação no formato oficial com filtros por seção, área, tema, subtema e status.

## Formato e regras editoriais
- Aba `Cards` com as 12 colunas da especificação; aba `Instruções` excluída da leitura, com exemplos fictícios de Cardiologia, Endocrinologia e Gastroenterologia.
- Seções e tags separadas por `;`. Status vazio em novos cards = `draft`; dificuldade vazia em novos cards = `medium`.
- Códigos vazios criam cards; códigos conhecidos atualizam apenas no modo correspondente; códigos desconhecidos bloqueiam a linha. Nunca gerar código fora do banco.
- Normalizar espaços e maiúsculas/minúsculas para reconhecer taxonomia, sempre respeitando os pais. Propor novas áreas, temas, subtemas e tags; seção desconhecida bloqueia a linha.
- Na atualização, células opcionais vazias preservam os valores atuais. Marcador explícito `[LIMPAR]` limpa somente campos opcionais que aceitam vazio; campos obrigatórios não podem ser limpos.
- Comentários simples viram documento rico seguro; exportar comentário estruturado em JSON para permitir ida e volta sem perder formatação. Documentar formato, limites e tratamento de mídia, que não será importada pela planilha.
- Perguntas idênticas ou semelhantes são avisos que exigem decisão de importar/ignorar, nunca identidade automática. Atualizações idênticas são ignoradas sem gravação; alterações só de seção preservam a versão do conteúdo.

## Segurança e recuperação
- Validar extensão, estrutura, aba, cabeçalhos, linhas, tipos, fórmulas, limites e conteúdo inesperado no servidor. Não executar fórmulas nem aceitar HTML/scripts como comentário rico.
- Limite inicial explícito: arquivo de até 20 MB e até 5.000 linhas; verificar também tamanho descompactado e limites das células para evitar arquivos abusivos.
- Upload/validação/prévia não gravam dados. Somente a confirmação cria o registro persistente da importação.
- Cada linha confirmada grava card, taxonomia, seções e tags em transação; falha isolada reverte essa linha, sem corromper as demais.
- Identificador da operação e chave por linha impedem duplicação em tentativas repetidas. Lotes pequenos com progresso, resultado persistido e retomada; revalidar permissões e conflitos antes de gravar.
- Corrigir compensação quando upload de mídia falhar ao salvar o registro e quando duplicação falhar após copiar arquivos; manter objetos privados independentes e evitar versões artificiais na cópia inicial quando viável.

## Dados de homologação
- Inventariar os cards citados, registros `[Teste]`, tag `Teste editor`, programações de 28/09 e 05/10 e contas temporárias, incluindo dependências.
- Arquivar/desativar apenas registros comprovadamente temporários. Não apagar versões, auditoria ou eventos; não alterar a conta principal. Registros duvidosos ficam intactos e serão apresentados para decisão.

## Detalhes técnicos
- Reutilizar autenticação, funções protegidas, componentes, tokens e tabelas existentes.
- Adicionar apenas tabelas de operações/linhas de importação, índices, permissões/RLS e funções transacionais necessárias, por migração aditiva.
- Separar leitura/escrita XLSX, normalização/validação e execução protegida para permitir testes isolados e manter compatibilidade com o ambiente publicado.
- Documentar decisões estruturais em `AGENTS.md` e manter os testes no projeto.

## Homologação e entrega
- Executar os 15 cenários solicitados, incluindo arquivos de 10 e 50 cards, erros mistos, duplicatas, atualização real/sem alteração/só seção, interrupção e repetição, editor/aluno, exportação e reimportação e preservação de histórico.
- Testar volume maior dentro dos recursos disponíveis e informar o número efetivamente executado, sem extrapolar.
- Conferir o fluxo real pela interface com sessão autorizada e verificar regressões das telas existentes.
- Entregar relatório com funcionalidades, alterações do banco, arquivos principais, formato e semântica XLSX, segurança, resultados reais, limitações e pendências. Encerrar na Fase 3.