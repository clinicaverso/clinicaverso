# Roadmap

- [x] Refinar sidebar e estrutura global responsiva
- [x] Reorganizar e polir o dashboard
- [x] Compactar produtos e métricas
- [x] Harmonizar tokens, botões e microinterações
- [x] Validar desktop, tablet e mobile

## Fundação ClinicaVerso Cards

- [x] Criar taxonomia compartilhada entre seções
- [x] Criar flashcards, conteúdo rico, mídia, tags e histórico editorial
- [x] Criar programação semanal e dados curriculares iniciais
- [x] Criar estado aluno-card e eventos imutáveis de revisão
- [x] Implementar papéis student, editor e admin com políticas no banco
- [x] Revisar integridade, índices, segurança e funcionamento da aplicação

## Painel administrativo de conteúdo

- [ ] Reorganizar navegação e permissões de admin/editor
- [ ] Conectar dashboard administrativo aos dados reais
- [ ] Implementar listagem, criação, edição, duplicação e arquivamento de cards
- [ ] Implementar rich text, mídia privada e preview do card
- [ ] Implementar gestão de seções, áreas, temas, subtemas e tags
- [ ] Implementar programação semanal
- [ ] Implementar gestão de usuários e papéis
- [ ] Validar RLS, versionamento, auditoria, responsividade e regressões

## Homologação do Admin

- [ ] Gerar código editorial CV-CARD-000001 automaticamente e de forma concorrente no banco; exibir após salvar e duplicar sem solicitar código
- [ ] Homologar criação, publicação, edição e versionamento do card, inclusive mudança apenas de seção
- [ ] Homologar upload privado, prévia, reabertura e mídia independente após duplicação
- [ ] Homologar programação de segunda, quarta e sexta com três temas e liberação permanente
- [ ] Homologar permissões de editor/aluno, RLS, auditoria, arquivamento e histórico imutável
- [ ] Entregar relatório PASSOU/FALHOU de cada teste, sem avançar para novas funcionalidades

## Fase 3 — Escala Editorial

- [x] Retomar a especificação reenviada e verificar implementação, banco e testes existentes

- [ ] Implementar formato XLSX oficial, modelo e validação sem gravações
- [ ] Implementar prévia, decisões de duplicatas e confirmação explícita
- [ ] Implementar importação autorizada, atômica por linha, idempotente e retomável
- [ ] Implementar histórico, relatórios e exportação filtrada
- [ ] Inventariar dados temporários e arquivar/desativar somente os comprovados
- [ ] Corrigir compensação de mídia e consistência de duplicação
- [ ] Homologar cenários solicitados e informar volume realmente testado
- [ ] Entregar relatório técnico da Fase 3 sem iniciar Fase 4
