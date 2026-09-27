# Painel administrativo de conteúdo do ClinicaVerso

## Objetivo

Transformar o admin atual em uma ferramenta funcional para administrar cards, taxonomia, mídia, programação semanal e papéis, usando o banco existente e preservando integralmente Dashboard e Performance do aluno.

## Entregas

### Navegação e permissões
- Reorganizar a sidebar administrativa em Visão geral, Conteúdo, Currículo e Gestão.
- Permitir que `admin` e `editor` acessem o painel; editor verá somente Cards, Seções, Áreas, Temas, Subtemas, Tags e Mídia.
- Manter Programação semanal e Usuários disponíveis apenas para `admin`.
- Revalidar permissões dentro de todas as operações de leitura e escrita, além da proteção visual das páginas.

### Dashboard administrativo
- Substituir métricas mockadas por totais reais de cards, taxonomia e programação da semana atual.
- Adicionar ações rápidas para novo card, novo tema e programação semanal, sem gráficos decorativos.

### Cards
- Criar listagem escalável com busca, filtros dependentes, ordenação e paginação no servidor.
- Exibir código, pergunta, seções, área, tema, subtema, status, versão e atualização.
- Implementar editar, duplicar e arquivar; não haverá exclusão definitiva.
- Criar editor dedicado em duas colunas no desktop e empilhado no mobile.
- Implementar seleção múltipla de seções e tags, dependência Área → Tema → Subtema, estados de salvamento e ações de rascunho/publicação/arquivamento.
- Usar editor estruturado para comentário com parágrafos, negrito, itálico, listas, links, tabelas simples e imagens, persistindo o documento JSON aceito pelo schema.
- Exibir prévia fiel e interativa do card, com pergunta, resposta, comentário, referência, mídia e botões de avaliação apenas visuais.
- Duplicar como novo card rascunho, versão 1, novo código, sem copiar histórico pedagógico.

### Mídia
- Implementar upload para o bucket privado existente, preview por URL temporária e registros em `flashcard_media`.
- Permitir imagem/documento, posição, legenda, texto alternativo, ordenação e desativação.
- Integrar imagens ao editor/preview conforme a posição escolhida e preservar o versionamento de conteúdo existente.
- Criar página de Mídia para localizar e administrar os arquivos vinculados.

### Taxonomia
- Criar páginas separadas para Seções, Áreas, Temas, Subtemas e Tags.
- Permitir criar, editar e ativar/desativar, respeitando vínculos existentes e sem exclusão destrutiva.
- Em Temas, mostrar área, quantidade de cards e status; no detalhe, descrição, subtemas, cards e seções relacionadas.

### Programação semanal
- Criar visão por seção com navegação entre semanas passadas e futuras.
- Editar os três slots da V1 — segunda, quarta e sexta — com Área → Tema dependente.
- Criar rascunho, publicar e arquivar, exibindo claramente o status e os erros das regras existentes.
- Não permitir alteração silenciosa de programação publicada.

### Usuários
- Criar listagem básica com nome, e-mail, papel e cadastro.
- Permitir somente ao `admin` alterar entre student, editor e admin.
- Validar o papel atual antes de operações privilegiadas; e-mail será lido somente no servidor.

## Detalhes técnicos

- Centralizar operações em funções autenticadas no servidor, sempre usando a sessão real e as políticas atuais; acesso privilegiado será usado apenas para listar identidade e alterar papéis após validar `admin`.
- Usar TanStack Query para cache, invalidação e estados de carregamento; filtros e paginação ficarão na URL com validação tipada.
- Criar componentes administrativos reutilizáveis para tabela, filtros, status, formulário de taxonomia, editor rico, mídia e preview.
- Preservar o schema atual; qualquer ajuste de banco só será feito se um bloqueio real for encontrado e será limitado ao mínimo necessário.
- Não implementar XLSX, FSRS, fila diária, scheduling real, IA, gamificação, ranking, analytics avançado ou pagamentos.

## Validação

- Testar o fluxo completo de criar rascunho, adicionar mídia, visualizar, publicar e editar card publicado.
- Testar duplicação e arquivamento sem histórico pedagógico copiado.
- Testar criação/edição/desativação de cada item de taxonomia.
- Testar programação R1CM com três temas diferentes em segunda/quarta/sexta e publicação.
- Testar alteração de papéis apenas por admin e bloqueio dessas ações para editor.
- Verificar versionamento, auditoria, RLS, armazenamento privado, console, telas existentes e responsividade em desktop e mobile.
