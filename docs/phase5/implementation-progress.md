# Fase 5 — Progresso de implementação (28/10/2026)

## Implementado e verificado
- Migração 0007 (aditiva): `fsrs_configurations`, `fsrs_initializations`, `daily_study_queues`, `daily_queue_members`, `daily_study_attempts`; colunas novas nullable em `user_flashcard_states` (state_revision, fsrs_config_id, fsrs_initialization_id, fsrs_last_computed_at) e `review_events` (operation_id, attempt_id, config_id, origin, state_revision_before/after); RPCs `daily_summary`, `start_daily_queue`, `read_daily_attempt`, `prepare_daily_rating`, `commit_daily_rating` (service_role only); mídia histórica autorizada também para tentativas diárias.
- Hardening: escrita direta legada revogada em `review_events` e `user_study_preferences`; trigger append-only em `review_events`. Verificado no banco real: authenticated=SELECT apenas.
- Migração 0008: privilégios mínimos nas 5 tabelas novas (authenticated=SELECT, service_role=ALL, anon=nada) — verificado no banco real.
- Configuração imutável semeada: ts-fsrs 5.4.2 / FSRS-6.0, retenção 0.9, passos 1m/10m, reaprendizagem 10m, fuzz off, 21 pesos.
- Servidor: `fsrs.server.ts` (adaptador, reconstrução do Card a partir do JSON completo) e `daily.functions.ts` (summary/start/read/rate). Cálculo FSRS apenas no servidor autenticado; commit via papel privilegiado com compare-and-swap de state_revision e idempotência por operation_id.
- UI preservada: seção "Estudo do dia" em Cards (revisões de hoje, atrasadas, iniciar revisão, meta de cards distintos), rota `/daily/$queue` com o mesmo fluxo pergunta → resposta/comentário → avaliação, Dashboard com meta diária e revisões pendentes reais. Modo por tema (Fase 4) intacto e compartilhando o mesmo estado global.

## Evidências
- Navegador (aluno de teste, sessão real): fila criada, card apresentado, resposta revelada, avaliação "Moderado" comitada 3 vezes em execuções distintas; progresso 0/1 → 1/2 → 2/3.
- Banco real: 3 review_events FSRS (origin, config, revisions preenchidos), 3 fsrs_initializations com origem `phase4_unscheduled` e referência ao último learning_event real, 23 learning_events e 1 review_event legado intactos, estados com scheduling_status='scheduled', state_revision=1, estabilidade 2.3065 (peso FSRS-6 de Good em card novo) e vencimento +3 dias.
- Compilação: build OK.

## Pendente (homologação completa — próxima etapa)
Concorrência entre modos/seções, virada de dia, reaprendizagem dentro da sessão, revisões curtas após saída, meta com 30+ revisões, regressões Fases 1–4, celular, e teste do motor no ambiente publicado (requer autorização para publicar).
