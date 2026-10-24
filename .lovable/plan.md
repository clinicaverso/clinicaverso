# Fase 5 — FSRS e fila diária inteligente

## Escopo e aprovação
**Plano somente; aguardar aprovação.** Sem código, migrações ou instalação de biblioteca. Preservar identidade/CMS/fluxo. Sem pagamentos, assinaturas, IA ou gamificação.

Base: repositório/Fase 4; banco real exige auditoria. Testes propostos.

## 1. Algoritmo
- Fixar **ts-fsrs@5.4.2**, MIT, **FSRS-6.0**; versão estável verificada no registro em 23/10/2026. Sem beta ou atualização automática.
- Errei/Again=1, Difícil/Hard=2, Moderado/Good=3, Medular/Easy=4. Estados: new, learning, review e relearning.
- Parâmetros propostos: retenção-alvo 90%, curto prazo ativo, aprendizagem 1/10 minutos, reaprendizagem 10 minutos, fuzz desativado, intervalo máximo 36.500 dias. São propostas para aprovação, não configuração implantada.
- Configuração imutável: pacote/algoritmo, 21 pesos, retenção, passos, máximo, fuzz e adaptador. Evento referencia configuração; mudanças futuras não alteram histórico nem reagendam automaticamente.
- `next` calcula estado/estabilidade/dificuldade/próxima revisão; `repeat` só prévias. Persistir entrada/saída completas, unidades e instante exato.
- Retenção estimada varia com o tempo: calcular com `get_retrievability(..., instant, false)`, não armazenar como constante. Sem inicialização, exibir “Ainda não estimada”.
- JavaScript sem dependências de produção; compatibilidade no ambiente publicado ainda será testada.

## 2. Tratamento da Fase 4
`learning_events` e `review_events` continuam distintos e intactos. Não reproduzir avaliações passadas com novos pesos, inventar intervalos ou datas retroativas.

Política conservadora proposta:
1. Nunca estudado: inicializar FSRS na primeira avaliação real da Fase 5.
2. Sem agenda: **“Iniciar revisão”**, sem vencimento fictício. Primeira avaliação atual inicia FSRS técnico New, com origem `phase4_unscheduled`/último evento; não conta como novo.
3. Preservar totais históricos, separar `reps/lapses` FSRS; lapsos Fase 4 e motor seguem suas definições, sem corrigir passado.
4. NULL/payload desconhecido/datas incoerentes: classificar, sem reset silencioso. Agenda reconhecida só continua após validação.

Inicialização junto da avaliação atual, sem passado fictício.

## 3. Fila e organização pedagógica
**Meta proposta: pelo menos 25 cards distintos avaliados por dia; nunca limite máximo.** Repetições necessárias contam como respostas, não novamente como cards da meta. Mostrar ambas as métricas.

Prioridades:
1. Review atrasados e previstos para hoje, com atrasados primeiro e ordenação por vencimento.
2. Learning/Relearning disponíveis (`due <= agora`), reaprendizagem primeiro. Etapas futuras aguardam horário; não antecipar passos curtos.
3. Inicializações pendentes da Fase 4, identificadas separadamente.
4. Novos para completar meta; depois, permitir continuar sem teto. Revisões restantes nunca são escondidas ao atingir 25.

Fuso **America/Fortaleza**; UTC `timestamptz`. Limites locais IANA, não 24h fixas. Review antes do início do dia = atrasado; previstos até fim do dia entram hoje. Passos curtos só quando disponíveis.

Escopo inicial R1CM, sem habilitar seções futuras. Elegibilidade por seção; estado/agenda globais `(user_id, flashcard_id)`.

Novos por tema; revisões misturadas, prioridade/vencimento preservados. Atualizar entre avaliações, não pergunta apresentada.

Membro único por fila/card, deduplicação entre seções; tentativas distintas permitem passos reais repetidos. Fila persistente/incremental sem teto de meta; retomada reutiliza tentativa ativa, abandono não bloqueia permanentemente.

## 4. Interface preservada
Dashboard/Cards: revisões hoje, atrasados, novos, inicialização e meta/progresso real; “Estudar hoje”/“Retomar”. Temas continuam para primeiras exposições; produto Teoria não muda.
Sessão mantém pergunta/resposta/comentário/mídia/referências/quatro notas; próxima revisão após commit. Conclusão distingue meta, fila disponível concluída e etapas futuras, nunca “Em dia” com atrasados. Preservar cinzas/verde, foco/teclado, tabelas/imagens/celular; sem redesign.

## 5. Detalhes técnicos — modelo de dados
Proposta aditiva, sem SQL aplicado:

| Objeto | Finalidade/mudança |
|---|---|
| `fsrs_configurations` nova | Configuração imutável, hash e versão; escrita interna |
| `fsrs_initializations` nova | Proveniência única usuário/card, sem substituir eventos |
| `daily_study_queues` nova | Usuário, seção, dia, fuso, política, situação; criação idempotente |
| `daily_queue_members` nova | Card único por fila, origem, prioridade, ordem persistente |
| `daily_study_attempts` nova | Fila/card, versão vista, revelação, revisão esperada, operação, instante e evento; suporta passos repetidos |
| `user_flashcard_states` | Adicionar revisão monotônica, configuração, inicialização e instante FSRS; reutilizar estado/data/estabilidade/dificuldade |
| `review_events` | Adicionar operação, tentativa, configuração, origem, revisões antes/depois e snapshots; nullable no legado, obrigatórios na nova função |

JSON completo/versionado preserva passos/reps/lapses/precisão; colunas são projeções. `last_review` FSRS não substitui datas históricas.

Índices usuário/vencimento/fila/dia/tentativas; UNIQUE parcial usuário/operação e usuário/card/revisão. FKs tentativa/configuração/versão; sem FK nova à autenticação gerenciada.

Migrações em etapas:
1. Auditoria real de colunas, ACLs, owners, triggers, consumidores e estados legados; backup e plano de recuperação.
2. Criar tabelas/colunas opcionais/índices/funções/políticas por dependência; preservar constraints/históricos.
3. Mapear consumidores, fechar escrita direta, instalar append-only em `review_events`; ativar após testes. Sem eventos fictícios.

CREATE → GRANT → RLS → políticas. Aluno lê próprios dados, sem escrita direta; configurações somente leitura, roles preservados.

Auditar INSERT autenticado legado em `review_events` e fechar acesso direto; indício do repositório, não falha live confirmada. Instalar append-only sem alterar eventos.

## 6. Funções, confiança e concorrência
PostgreSQL não executa npm: **servidor autenticado calcula; banco comita atomicamente**.
1. RPC deriva usuário, valida acesso/revelação/versão/configuração/revisão; prepara recibo persistente e instante UTC em ms.
2. TanStack autenticado calcula; navegador envia tentativa/operação/nota, nunca usuário autoritativo, pesos, intervalos ou horário.
3. Commit vedado a `anon/authenticated`; cliente privilegiado gerado dentro do handler, após verificar caller pelo cliente autenticado. Sem credencial nova/exposta.
4. Transação valida recibo/dono/acesso/configuração/revisão, locks consistentes usuário/card; evento/estado/contadores/tentativa/inicialização comitam juntos.
5. Mesma operação/nota retorna original; outra nota falha. Mesma revisão em duas sessões: um vencedor/conflito, sem reaplicar ao estado novo.

CAS não prova FSRS: cálculo confiável no servidor; banco valida recibo/faixas/monotonicidade. Retry usa instante original; recibo expirado exige nova preparação. Sem commit não há conclusão; resposta perdida retorna evento existente.

RPCs: resumo, fila, ler/revelar, preparar e commit restrito. Queries seção/modo/dia, sem limite de 50 sessões. Deduplicar métricas dos históricos. Fila sob demanda, sem cron ou avaliações offline.

## 7. Compatibilidade, mídia e recuperação
- Preservar IDs/URLs/RPCs antigas; novos IDs resolvem modo diário. Sem alterar `topic_id` obrigatório ou `event_id` legado.
- Antigas concluem sem agenda e depois inicializam; card agendado em outro modo é excluído/recarregado, não sobrescrito. Retry commitado continua válido.
- Fixar versão na apresentação; mídia exige dono/tentativa/versão/elegibilidade e revelação quando aplicável. Revogação impede novas URLs; emitidas expiram em 120s atuais.
- Virada do dia preserva tentativa/progresso; avaliação conta no dia do instante preparado. Nova fila usa estado atual sem duplicar tentativa ativa.
- Habilitação interna/test users. Em falha, suspender motor e reparar adiante, sem apagar dados ou gravar Fase 4 sobre agendados. Rollback incompleto integral; eventos comitados preservados.

## 8. Homologação objetiva
- Vetores oficiais fixos para quatro notas/todos os estados, intervalos/retenção; tolerância numérica explícita, datas exatas em ms e reprodução por snapshots/configuração.
- 20 retries = 1 evento/1 incremento; notas distintas simultâneas entre seções/modos = 1 vencedor/conflito. Nenhum consumo duplicado do estado.
- Falha após INSERT: rollback de evento/estado/inicialização/tentativa, só em fixtures registrados.
- Recarga/logout/login e resposta de rede perdida preservam revelação/posição e não duplicam commit.
- Edição mantém versão/mídia vistas; conteúdo futuro/arquivado e usuário alheio inacessíveis.
- Meta 24 rejeitada/25 aceita; 30 revisões continuam disponíveis; repetição não infla meta, falta de novos não inventa avaliações.
- Prioridade correta, novos por tema, revisões misturadas, passos futuros bloqueados.
- 23:59/00:00 Fortaleza e fuso com horário de verão: limites/recibos/retomada sem perda ou duplicação.
- Históricos iguais antes/depois, sessões legadas válidas, nenhuma revisão retroativa.
- RLS/ACLs negam REST direto/commit interno; mídia revogada e URLs expiradas verificadas.
- Desktop/celular, login real, Dashboard/Cards/Performance, CMS/versões/programação/XLSX; motor publicado só com autorização para publicar.

Fixture PostgreSQL isolada ≠ integração real. Aceite: todos os obrigatórios passam, zero falhas críticas, limpeza por IDs registrados e relatório com versões/evidências/recuperação. Nunca homologar teste não executado.

## Decisões para aprovação e riscos
Aprovar inicialização/meta/fuso/prioridade/parâmetros. Riscos: runtime/ACLs/precisão/backlog/corridas. Assinaturas fora da fase, necessárias antes da venda.

## Fontes
- https://registry.npmjs.org/ts-fsrs/5.4.2
- https://github.com/open-spaced-repetition/ts-fsrs/tree/v5.4.2
- https://github.com/open-spaced-repetition/fsrs4anki/wiki/The-Algorithm#fsrs-6
