# Fase 5 — FSRS e fila diária inteligente

## Escopo e aprovação
**Apenas plano técnico.** Sem migrações, dependências ou funcionalidades executadas; aguardar aprovação. Preservar identidade, autenticação, CMS e pergunta → resposta/comentário → avaliação. Sem pagamentos, assinaturas, IA, treinamento personalizado de parâmetros ou gamificação.

Base: migrações, contratos, sessões e fechamento da Fase 4; banco real ainda exige auditoria. Testes abaixo são propostos.

## 1. Algoritmo
- Fixar **ts-fsrs@5.4.2**, MIT, **FSRS-6.0**; versão estável verificada no registro em 23/10/2026. Sem beta ou atualização automática.
- Errei/Again=1, Difícil/Hard=2, Moderado/Good=3, Medular/Easy=4. Estados: new, learning, review e relearning.
- Parâmetros propostos: retenção-alvo 90%, curto prazo ativo, aprendizagem 1/10 minutos, reaprendizagem 10 minutos, fuzz desativado, intervalo máximo 36.500 dias. São propostas para aprovação, não configuração implantada.
- Configuração imutável contém pacote, algoritmo, 21 pesos completos, retenção, passos, intervalo máximo, fuzz e versão do adaptador. Toda avaliação referencia a configuração utilizada; futuras mudanças não alteram eventos nem reagendam cards automaticamente.
- `next(card, instant, rating)` calcula estado, estabilidade, dificuldade e próxima revisão. `repeat` pode oferecer prévias não vinculantes. Persistir entrada/saída completas, unidades explícitas e timestamp exato.
- Retenção estimada varia com o tempo: calcular com `get_retrievability(..., instant, false)`, não armazenar como constante. Sem inicialização, exibir “Ainda não estimada”.
- JavaScript sem dependências de produção; compatibilidade no ambiente publicado ainda será testada.

## 2. Tratamento da Fase 4
`learning_events` e `review_events` continuam distintos e intactos. Não reproduzir avaliações passadas com novos pesos, inventar intervalos ou datas retroativas.

Política conservadora proposta:
1. Nunca estudado: inicializar FSRS na primeira avaliação real da Fase 5.
2. Estudado sem agenda: grupo **“Iniciar revisão”**, sem vencimento artificial. Na primeira avaliação atual, iniciar estado técnico FSRS como New, registrando origem `phase4_unscheduled` e referência ao último evento real. Não contar como novo para o aluno.
3. Preservar contadores históricos; separar `reps/lapses` do motor dos totais acumulados. Again da Fase 4 já contou como lapso; FSRS segue a definição da biblioteca, sem corrigir o passado.
4. `scheduling_status=NULL`, payload desconhecido ou datas incoerentes: inventariar/classificar; não resetar nem incluir como novos silenciosamente. Agendamento reconhecido só continua após validação.

Inicialização registra origem/configuração atuais e comita junto da avaliação real, sem evento histórico fictício.

## 3. Fila e organização pedagógica
**Meta proposta: pelo menos 25 cards distintos avaliados por dia; nunca limite máximo.** Repetições necessárias contam como respostas, não novamente como cards da meta. Mostrar ambas as métricas.

Prioridades:
1. Review atrasados e previstos para hoje, com atrasados primeiro e ordenação por vencimento.
2. Learning/Relearning disponíveis (`due <= agora`), reaprendizagem primeiro. Etapas futuras aguardam horário; não antecipar passos curtos.
3. Inicializações pendentes da Fase 4, identificadas separadamente.
4. Novos para completar meta; depois, permitir continuar sem teto. Revisões restantes nunca são escondidas ao atingir 25.

Fuso **America/Fortaleza**; UTC `timestamptz`. Limites locais IANA, não 24h fixas. Review antes do início do dia = atrasado; previstos até fim do dia entram hoje. Passos curtos só quando disponíveis.

Escopo inicial R1CM, sem habilitar seções futuras. Elegibilidade por seção; estado/agenda globais `(user_id, flashcard_id)`.

Novos por tema escolhido; revisões misturadas com desempate estável, preservando prioridade/vencimento. Atualizar fila entre avaliações, não a pergunta apresentada.

Membro único por fila/card, deduplicação entre seções; tentativas distintas permitem passos reais repetidos. Fila persistente/incremental sem teto de meta; retomada reutiliza tentativa ativa, abandono não bloqueia permanentemente.

## 4. Interface preservada
- Dashboard/Cards: “Para revisar hoje”, “Atrasados”, “Novos disponíveis”, “Iniciar revisão”, meta e progresso real, inclusive acima de 25.
- “Estudar hoje”/“Retomar estudo”; temas continuam disponíveis para primeiras exposições. Não renomear o produto Teoria.
- Sessão mantém pergunta, resposta, comentário, mídia, referências e quatro avaliações; próxima revisão aparece após commit. Prévias, se usadas, são estimativas.
- Conclusão distingue meta atingida, fila disponível concluída e próxima etapa aguardando. Nunca “Em dia” com pendências disponíveis; falta de novos não gera avaliações artificiais.
- Preservar cinzas/verde, componentes atuais, foco/teclado, celular e leitura de tabelas/imagens; falhas recuperáveis, sem redesign.

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

JSON FSRS completo/versionado preserva passos, reps/lapses e precisão; colunas são projeções, sem truncar próximo cálculo. `last_review` do motor não substitui datas históricas.

Índices: usuário/vencimento, fila/dia, tentativas pendentes; UNIQUE parcial usuário/operação e usuário/card/revisão anterior nos eventos FSRS. FKs para tentativa/configuração/versão, sem novas referências à autenticação gerenciada.

Migrações em etapas:
1. Auditoria real de colunas, ACLs, owners, triggers, consumidores e estados legados; backup e plano de recuperação.
2. Criar tabelas/colunas opcionais, índices, funções e políticas na ordem de dependência; sem remover constraints ou alterar históricos.
3. Fechar escritas antigas após mapear consumidores, instalar append-only em `review_events` e habilitar caminho novo só após testes. Sem backfill de eventos fictícios.

CREATE → GRANT → RLS → políticas. Aluno lê próprios dados, sem escrita direta; configurações somente leitura, roles preservados.

Auditar INSERT autenticado legado em `review_events` e fechar acesso direto; indício do repositório, não falha live confirmada. Instalar append-only sem alterar eventos.

## 6. Funções, confiança e concorrência
PostgreSQL não executa npm: **servidor autenticado calcula; banco comita atomicamente**.
1. RPC prepara tentativa, deriva usuário, valida acesso/liberação, revelação, versão fixada, configuração e revisão do estado; gera recibo persistente e instante UTC em ms.
2. Função TanStack autenticada calcula com biblioteca fixada. Navegador envia apenas tentativa/operação/nota, nunca pesos, usuário autoritativo, intervalos ou horário.
3. Commit interno inacessível a `anon/authenticated`; cliente privilegiado gerado somente dentro do handler, após verificação pelo cliente do usuário. Não criar/expor credencial nova.
4. Transação revalida recibo/dono/eligibilidade/configuração/revisão; locks em ordem consistente e lock global usuário/card. Insere evento, atualiza estado/contadores/revisão, conclui tentativa e inicialização juntas.
5. Retry mesma operação/nota retorna resultado original; outra nota é rejeitada. Duas sessões consumindo mesma revisão: um vencedor, outro conflito/recarregamento, nunca reaplicação silenciosa ao estado novo.

CAS não prova FSRS: cálculo confiável no servidor; banco valida recibo/faixas/monotonicidade. Retry usa instante original; recibo expirado exige nova preparação. Sem commit não há conclusão; resposta perdida retorna evento existente.

RPCs: resumo, fila, ler/revelar, preparar e commit restrito. Queries seção/modo/dia, sem limite de 50 sessões. Deduplicar métricas dos históricos. Fila sob demanda, sem cron ou avaliações offline.

## 7. Compatibilidade, mídia e recuperação
- Preservar IDs/URLs/RPCs antigas; novos IDs resolvem modo diário. Sem alterar `topic_id` obrigatório ou `event_id` legado.
- Antigas concluem sem agenda e depois inicializam; card agendado em outro modo é excluído/recarregado, não sobrescrito. Retry commitado continua válido.
- Fixar versão na apresentação; mídia exige dono/tentativa/versão/elegibilidade e revelação quando aplicável. Revogação impede novas URLs; emitidas expiram em 120s atuais.
- Virada do dia preserva tentativa/progresso; avaliação conta no dia do instante preparado. Nova fila usa estado atual sem duplicar tentativa ativa.
- Habilitação interna/test users. Em falha, suspender motor e reparar adiante, sem apagar dados ou gravar Fase 4 sobre agendados. Rollback incompleto integral; eventos comitados preservados.

## 8. Homologação objetiva
1. Vetores oficiais fixos: quatro notas/todos os estados, passos e intervalos longos; resultados determinísticos, tolerância numérica explícita e datas exatas em ms.
2. Configuração/snapshots reproduzem transições; serialização preserva precisão e reps/lapses.
3. 20 retries iguais = 1 evento/1 incremento; notas distintas, seções/modos paralelos = 1 vencedor/conflito, sem perda.
4. Falha após INSERT = rollback de evento/estado/inicialização/tentativa, apenas em fixtures sintéticos registrados.
5. Recarga/logout/login retomam pergunta/revelação/posição; perda de resposta após commit não duplica.
6. Edição mantém versão/mídia vistas; futuro/arquivado/usuário alheio não expõem conteúdo.
7. Meta 24 rejeitada, 25 aceita; 30 revisões disponíveis; mesmo card repetido não infla meta, falta de novos não inventa avaliações.
8. Ordem da fila e bloqueio de passos futuros; novos por tema, revisões misturadas sem violar vencimento.
9. 23:59/00:00 Fortaleza, UTC e recibos entre dias sem perda/duplicação; validar cálculo de limites com fuso que tenha horário de verão.
10. Históricos iguais antes/depois; legado e inicialização sem reviews retroativos.
11. Negar REST direto/commit interno, conferir RLS/ACLs/roles/mídia revogada e expiração real.
12. Desktop/celular, login real, Dashboard/Cards/Performance, CMS/versões/programação/XLSX e motor no ambiente publicado, com autorização para publicar.

Fixture PostgreSQL isolada e banco real terão resultados separados. Aceite: todos os obrigatórios passam, nenhuma falha crítica, limpeza só por IDs registrados, relatório com versões/evidências e recuperação validada. Não homologar cenários não executados.

## Decisões para aprovação e riscos
Aprovar inicialização, meta distinta, fuso, prioridade e parâmetros. Riscos: runtime, ACLs legadas, precisão, backlog e concorrência; testes bloqueiam liberação. Assinaturas antes da comercialização, fora da fase.

## Fontes
- https://registry.npmjs.org/ts-fsrs/5.4.2
- https://github.com/open-spaced-repetition/ts-fsrs/tree/v5.4.2
- https://github.com/open-spaced-repetition/fsrs4anki/wiki/The-Algorithm#fsrs-6
