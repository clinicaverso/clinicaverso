# Roadmap

## Fase 4 — Estudo do aluno
- [ ] Atender especificação de finalização: privilégios mínimos, concorrência com escolhas distintas, rollback real controlado, mídia revogada/expirada, catálogo futuro, celular e regressões XLSX/Performance; consolidar evidências
- [x] Revisar migração aditiva e testar funções em PostgreSQL isolado; apresentar proposta para aprovação antes de aplicar
- [x] Aplicar proposta revisada após aprovação da separação learning_events/review_events
- [x] Conferir dependências reais e recuperação transacional; documentar controle por assinatura obrigatório antes da comercialização
- [x] Implementar aprendizagem sem agendamento artificial, avaliação atômica e idempotente
- [x] Implementar sessões persistentes e revalidação de acesso
- [x] Conectar temas, estudo e Dashboard preservando identidade
- [ ] Completar homologação: concorrência entre seções, falha transacional real, mídia após perda de elegibilidade e regressão Admin/login
- [ ] Exibir temas futuros bloqueados com data; confirmar contrato de catálogo sem expor conteúdo
- [ ] Conferir privilégios efetivos de learning_events (RLS impede alterações, mas grants efetivos são mais amplos que o SQL solicitado)
- [ ] Entregar relatório final após todas as verificações; não iniciar Fase 5

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

- [x] Implementar formato XLSX oficial, modelo e validação sem gravações
- [x] Implementar prévia, decisões de duplicatas e confirmação explícita
- [x] Implementar importação autorizada, atômica por linha, idempotente e retomável
- [x] Implementar histórico, relatórios e exportação filtrada
- [x] Inventariar dados temporários e arquivar/desativar somente os comprovados
- [x] Corrigir compensação de mídia e consistência de duplicação
- [x] Homologar cenários solicitados e informar volume realmente testado
- [x] Entregar relatório técnico da Fase 3 sem iniciar Fase 4
