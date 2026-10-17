# Fase 4 — Proposta revisada antes da execução

## Aprovação necessária
Adotar aprendizagem sem agenda em `learning_events`, preservando `review_events` e seus campos obrigatórios. Nenhuma coluna/constraint histórica será removida; nenhum intervalo, data de revisão ou parâmetro FSRS será inventado. A proposta SQL completa e o relatório de validação estão anexados à conversa.

## Ajustes revisados
- Estado anterior `new` explícito quando não houver estado do aluno.
- `again` incrementa lapsos uma única vez, mantendo contadores anteriores.
- Avaliação e conclusão do item em transação idempotente com locks e operação única.
- Sessões persistentes, sem criação vazia, com acesso revalidado e versão/mídia histórica fixadas.
- Catálogo somente de temas liberados, sem bypass administrativo.
- Acesso por seção conforme o modelo atual: autenticado + seção ativa; não existe matrícula individual por curso.
- Escrita direta dos contadores revogada; permissões e histórico de revisões existentes preservados.

## Validação já realizada
37 verificações SQL passaram em PostgreSQL isolado e 18 testes editoriais passaram. Não houve alteração do banco da aplicação. A fixture não substitui homologação real nem valida todos os triggers atuais.

## Implementação após aprovação
Aplicar a migração revisada, construir Cards por tema, sessão de estudo e Dashboard real preservando a identidade atual; homologar versões, mídia, RLS, concorrência, retomada e celular com usuários reais de teste.

## Detalhes técnicos
Três novas tabelas: `study_sessions`, `study_session_items`, `learning_events`; coluna nullable `user_flashcard_states.scheduling_status`; funções autenticadas, RLS, trigger append-only e autorização estreita de mídia histórica. O futuro motor deve ler aprendizagem e revisões como históricos distintos, sem reescrever eventos.

## Limites
Não implementar FSRS ou iniciar Fase 5. URLs privadas já assinadas continuam válidas até sua expiração. Testes end-to-end reais e homologação final ficam para depois da aplicação.
