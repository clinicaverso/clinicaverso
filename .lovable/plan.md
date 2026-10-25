# Fase 5 — Plano final consolidado (aguardando aprovação para executar)

Arquitetura aprovada com 10 ajustes obrigatórios, todos incorporados abaixo. **Nenhuma implementação iniciada**; este documento é a versão final para aprovação explícita.

## 1. Compatibilidade confirmada (verificação real do pacote)
Pacote ts-fsrs@5.4.2 inspecionado diretamente: identifica-se como **"v5.4.2 using FSRS-6.0"**. Parâmetros padrão reais conferidos: retenção-alvo 0.9; intervalo máximo 36.500 dias; 21 pesos FSRS-6; fuzz desativado; curto prazo ativo; passos de aprendizagem ["1m","10m"] e reaprendizagem ["10m"] em strings de minutos. Unidades: datas como Date/ISO UTC; estabilidade, scheduled_days e elapsed_days em dias; card vazio tem state=New, reps/lapses=0. Os parâmetros propostos correspondem exatamente aos padrões da versão fixada — nenhuma divergência.

## 2. Configuração versionada
Retenção-alvo inicial 90% com configuração imutável persistida (pacote, algoritmo, 21 pesos, retenção, passos, máximo, fuzz, versão do adaptador). Ajustes futuros criam nova configuração: eventos históricos e agendamentos existentes nunca são reescritos nem reagendados automaticamente.

## 3. Meta diária
Mínimo de 25 **cards distintos avaliados** por dia, sem teto máximo. Repetições do mesmo card no dia (passos de aprendizagem/reaprendizagem) contam como respostas, mas não inflam a meta. Dashboard mostra respostas e cards distintos separadamente; progresso pode superar 25.

## 4. Dois modos de estudo, um único estado
- **Estudo diário inteligente**: fila priorizando revisões e depois novos (regras da seção 6).
- **Estudo por tema**: o aluno escolhe um assunto; mantém o fluxo atual de temas liberados, incluindo primeiras exposições agrupadas por tema.
Ambos compartilham o mesmo estado FSRS global `(user_id, flashcard_id)`: avaliação em qualquer modo passa pelo mesmo commit transacional idempotente, com lock usuário/card e operação única. Impossível gerar eventos ou agendamentos duplicados: unicidade usuário/operação e consumo único da revisão do estado (compare-and-swap) no banco.

## 5. Transição da Fase 4
`learning_events` e `review_events` permanecem intactos e distintos. Cards estudados na Fase 4 preservam eventos e contadores integralmente; entram no grupo **"Iniciar revisão"** (nunca apresentados como nunca estudados, sem vencimento fictício). A inicialização FSRS ocorre prospectivamente na próxima avaliação real: estado técnico inicia como New com origem `phase4_unscheduled` e referência ao último evento real, sem datas ou intervalos retroativos. Totais históricos preservados; `reps/lapses` do motor são separados. Registros com payload desconhecido ou datas incoerentes são classificados explicitamente, sem reset silencioso.

## 6. Comportamento da fila (casos exigidos)
- **Mais de 25 revisões pendentes**: todas entram na fila; a meta não capa o backlog. Revisões atrasadas primeiro, depois as do dia; novos só após as revisões disponíveis.
- **Menos de 25 elegíveis**: mostra o resultado real; nenhuma avaliação artificial é criada para completar a meta.
- **Meta atingida e aluno quer continuar**: estudo continua sem teto; revisões restantes nunca são escondidas.
- **Card entra em reaprendizagem durante a sessão**: próximo passo (10 min) é agendado; se ficar disponível ainda na sessão, o card reaparece como nova tentativa do mesmo estado atualizado, sem duplicar membro da fila nem evento.
- **Revisão curta fica disponível após o aluno sair**: permanece elegível; na próxima entrada ou atualização da fila, aparece como disponível. Nenhum passo é antecipado nem perdido por sair da página.

Ordem da fila diária: Review atrasados → Review do dia → Learning/Relearning disponíveis (reaprendizagem primeiro) → "Iniciar revisão" (Fase 4) → novos até completar a meta. Regra pedagógica preservada: novos agrupados por tema escolhido; revisões espaçadas misturadas entre temas com desempate estável, sem violar prioridade/vencimento. Fuso America/Fortaleza; datas UTC; limites do dia por fuso IANA.

## 7. Confiança, transações e concorrência
Cálculo FSRS somente em servidor autenticado (biblioteca fixada); o navegador envia apenas tentativa/operação/nota — nunca pesos, intervalos, horário ou usuário. Fluxo: RPC prepara tentativa com recibo persistente e instante UTC → servidor calcula → commit interno restrito (inacessível a anon/authenticated) revalida recibo, dono, elegibilidade, configuração e revisão esperada, com locks consistentes. Retry idêntico retorna o evento original; nota diferente na mesma operação é rejeitada; duas sessões concorrentes: um vencedor, outro recebe conflito e recarrega. Falha antes do commit não conclui o card; resposta perdida após commit retorna o evento existente. Rollback de transação incompleta é integral.

## 8. Migrações previstas (aditivas, transacionais)
1. Auditoria real de ACLs/triggers/consumidores; backup e plano de recuperação.
2. Novas tabelas: `fsrs_configurations`, `fsrs_initializations`, `daily_study_queues`, `daily_queue_members`, `daily_study_attempts` — cada uma com GRANT explícito, RLS e políticas (aluno lê os próprios dados, nunca escreve diretamente).
3. Colunas novas nullable em `user_flashcard_states` (revisão monotônica, configuração, inicialização, instante FSRS) e `review_events` (operação, tentativa, configuração, origem, revisões antes/depois). Índices usuário/vencimento, fila/dia, tentativas pendentes; UNIQUE parcial usuário/operação.
4. Mapear consumidores, fechar escrita direta legada em `review_events`, instalar proteção append-only; ativar o novo caminho só após testes. Sem eventos fictícios, sem remover constraints, sem alterar históricos. Sessões da Fase 4 continuam válidas e concluem no modo sem agenda antes da inicialização.

## 9. Preservação das Fases 1–4
Identidade visual (cinzas/verde, minimalista), autenticação, CMS, importação/exportação XLSX, programação semanal, Dashboard, Performance, mídia privada com URLs assinadas (120s), versionamento editorial e RLS permanecem intactos. Interface: indicadores de revisões/atrasados/novos/meta, "Estudar hoje"/"Retomar", temas para estudo por assunto; fluxo pergunta → resposta/comentário → avaliação inalterado. Regressões das fases anteriores fazem parte da homologação.

## 10. Critérios de homologação
- Vetores oficiais FSRS-6: quatro notas, todos os estados, intervalos e retenção; resultados determinísticos com tolerância numérica explícita.
- 20 retries idênticos = 1 evento/1 incremento; concorrência entre seções/modos = 1 vencedor/conflito, sem consumo duplicado.
- Falha induzida após INSERT = rollback integral, apenas em fixtures sintéticos registrados.
- Recarga/logout/login e resposta de rede perdida: retomada sem duplicar commit.
- Edição editorial durante o estudo mantém versão/mídia apresentadas; conteúdo futuro/arquivado e de outro usuário inacessíveis.
- Meta: 24 rejeitada, 25 aceita, 30+ revisões disponíveis; repetição não infla meta; escassez não gera avaliações artificiais.
- Virada de dia 23:59/00:00 Fortaleza sem perda/duplicação.
- Históricos das Fases 1–4 idênticos antes/depois; regressões de login, Cards, Dashboard, Performance, CMS, versões, programação e XLSX.
- RLS/ACLs negam escrita direta e commit interno; mídia revogada e URLs expiradas verificadas; testes em desktop e celular.
- Fixture PostgreSQL isolada e banco real reportados separadamente. Aceite: todos os obrigatórios passam, zero falhas críticas, limpeza por IDs registrados, relatório com versões e evidências.

## Fontes
- https://registry.npmjs.org/ts-fsrs/5.4.2
- https://github.com/open-spaced-repetition/ts-fsrs/tree/v5.4.2
- https://github.com/open-spaced-repetition/fsrs4anki/wiki/The-Algorithm#fsrs-6
