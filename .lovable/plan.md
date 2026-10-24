# Fase 5 — FSRS e fila diária inteligente

## Escopo e aprovação
**Apenas plano técnico.** Sem migrações, dependências ou funcionalidades executadas; aguardar aprovação. Preservar identidade, autenticação, CMS e pergunta → resposta/comentário → avaliação. Sem pagamentos, assinaturas, IA, treinamento personalizado de parâmetros ou gamificação.

Base examinada: migrações 0005/0006, tipos, funções, sessões e encerramento da Fase 4. Leitura do repositório não comprova o estado do banco real. Todos os testes desta proposta ainda deverão ser executados.

## 1. Algoritmo
- Fixar **ts-fsrs@5.4.2**, MIT, **FSRS-6.0**; versão estável verificada no registro em 23/10/2026. Sem beta ou atualização automática.
- Errei/Again=1, Difícil/Hard=2, Moderado/Good=3, Medular/Easy=4. Estados: new, learning, review e relearning.
- Parâmetros propostos: retenção-alvo 90%, curto prazo ativo, aprendizagem 1/10 minutos, reaprendizagem 10 minutos, fuzz desativado, intervalo máximo 36.500 dias. São propostas para aprovação, não configuração implantada.
- Configuração imutável contém pacote, algoritmo, 21 pesos completos, retenção, passos, intervalo máximo, fuzz e versão do adaptador. Toda avaliação referencia a configuração utilizada; futuras mudanças não alteram eventos nem reagendam cards automaticamente.
- `next(card, instant, rating)` calcula estado, estabilidade, dificuldade e próxima revisão. `repeat` pode oferecer prévias não vinculantes. Persistir entrada/saída completas, unidades explícitas e timestamp exato.
- Retenção estimada varia com o tempo: calcular com `get_retrievability(..., instant, false)`, não armazenar como constante. Sem inicialização, exibir “Ainda não estimada”.
- Scheduler JavaScript sem dependências de produção; declaração Node ≥20 não certifica o ambiente publicado. Compatibilidade real será gate de liberação.

## 2. Tratamento da Fase 4
`learning_events` e `review_events` continuam distintos e intactos. Não reproduzir avaliações passadas com novos pesos, inventar intervalos ou datas retroativas.

Política conservadora proposta:
1. Nunca estudado: inicializar FSRS na primeira avaliação real da Fase 5.
2. Estudado sem agenda: grupo **“Iniciar revisão”**, sem vencimento artificial. Na primeira avaliação atual, iniciar estado técnico FSRS como New, registrando origem `phase4_unscheduled` e referência ao último evento real. Não contar como novo para o aluno.
3. Preservar contadores históricos; separar `reps/lapses` do motor dos totais acumulados. Again da Fase 4 já contou como lapso; FSRS segue a definição da biblioteca, sem corrigir o passado.
4. `scheduling_status=NULL`, payload desconhecido ou datas incoerentes: inventariar/classificar; não resetar nem incluir como novos silenciosamente. Agendamento reconhecido só continua após validação.

Proveniência de inicialização registra instante atual, origem e configuração; não representa avaliação histórica. Inicialização e primeira avaliação FSRS efetiva concluem na mesma transação.

## 3. Fila e organização pedagógica
**Meta proposta: pelo menos 25 cards distintos avaliados por dia; nunca limite máximo.** Repetições necessárias contam como respostas, não novamente como cards da meta. Mostrar ambas as métricas.

Prioridades:
1. Review atrasados e previstos para hoje, com atrasados primeiro e ordenação por vencimento.
2. Learning/Relearning disponíveis (`due <= agora`), reaprendizagem primeiro. Etapas futuras aguardam horário; não antecipar passos curtos.
3. Inicializações pendentes da Fase 4, identificadas separadamente.
4. Novos para completar meta; depois, permitir continuar sem teto. Revisões restantes nunca são escondidas ao atingir 25.

Fuso **America/Fortaleza**, preservando a Fase 4; UTC `timestamptz` no banco. Dia definido por limites locais IANA, não soma fixa de 24h. Atrasado: Review anterior ao início do dia. Em Review, previstos até o fim do dia podem ser estudados hoje; aprendizagem só quando disponível.

Escopo inicial é seção selecionada, hoje R1CM; não habilitar R+CM/TECM por este plano. Seção filtra elegibilidade, mas estado e agenda são globais `(user_id, flashcard_id)`.

Novos agrupados pelo tema escolhido; revisões misturam temas com desempate determinístico dentro das prioridades. Vencimento prevalece sobre mistura. Atualizar disponibilidade entre avaliações sem reordenar a pergunta apresentada.

Deduplicar membros por fila/card e seleções por usuário/dia/card entre seções. Cada apresentação é tentativa distinta vinculada à revisão do estado: passos reais podem repetir card, não membro/evento. Fila persistente com extensão incremental, sem capar backlog pela meta. Abandono não bloqueia card indefinidamente; retomada reutiliza tentativa ativa, conflitos consomem no máximo uma revisão do estado.

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

JSON FSRS versionado guarda representação completa (passos, reps/lapses e precisão); colunas numéricas são projeções de consulta, não entrada truncada do cálculo seguinte. Não confundir `last_review` recém-inicializado com datas históricas.

Índices: usuário/vencimento, fila/dia, tentativas pendentes. Unicidade usuário/operação em eventos novos por índice parcial; considerar usuário/card/revisão anterior para impedir consumo duplicado. FKs vinculam tentativa, configuração e versão editorial. Sem novas FKs para tabelas gerenciadas de autenticação.

Migrações em etapas:
1. Auditoria real de colunas, ACLs, owners, triggers, consumidores e estados legados; backup e plano de recuperação.
2. Criar tabelas/colunas opcionais, índices, funções e políticas na ordem de dependência; sem remover constraints ou alterar históricos.
3. Fechar escritas antigas após mapear consumidores, instalar append-only em `review_events` e habilitar caminho novo só após testes. Sem backfill de eventos fictícios.

Toda tabela pública: CREATE → GRANT explícito → RLS → políticas. Aluno lê próprios registros, nunca escreve diretamente estados/eventos/tentativas/inicializações. Configurações autorizadas são somente leitura; roles atuais preservados.

O repositório indica INSERT autenticado antigo em `review_events`, fora do hardening da Fase 4: confirmar privilégios efetivos no banco e fechar esse caminho. Isso não é vulnerabilidade live já confirmada. Auditoria e proteção de imutabilidade não modificam eventos existentes.

## 6. Funções, confiança e concorrência
PostgreSQL não executa npm: **servidor autenticado calcula; banco comita atomicamente**.
1. RPC prepara tentativa, deriva usuário, valida acesso/liberação, revelação, versão fixada, configuração e revisão do estado; gera recibo persistente e instante UTC em ms.
2. Função TanStack autenticada calcula com biblioteca fixada. Navegador envia apenas tentativa/operação/nota, nunca pesos, usuário autoritativo, intervalos ou horário.
3. Commit interno inacessível a `anon/authenticated`; cliente privilegiado gerado somente dentro do handler, após verificação pelo cliente do usuário. Não criar/expor credencial nova.
4. Transação revalida recibo/dono/eligibilidade/configuração/revisão; locks em ordem consistente e lock global usuário/card. Insere evento, atualiza estado/contadores/revisão, conclui tentativa e inicialização juntas.
5. Retry mesma operação/nota retorna resultado original; outra nota é rejeitada. Duas sessões consumindo mesma revisão: um vencedor, outro conflito/recarregamento, nunca reaplicação silenciosa ao estado novo.

CAS não prova cálculo matemático: confiança reside no servidor autenticado. Banco valida recibo, faixas, coerência e monotonicidade. Recibo expirado sem commit exige preparação nova; reenvio válido usa instante original. Erro antes de commit não conclui card; resposta perdida após commit retorna evento existente.

RPCs: resumo, criar/retomar fila, ler/revelar tentativa, preparar avaliação, commit interno restrito. Queries incluem seção/modo/dia, sem limite heurístico dos últimos 50 registros. Contagens deduplicam cards/operações entre os dois históricos. Fila gerada sob demanda, sem necessidade de tarefa agendada ou avaliações offline.

## 7. Compatibilidade, mídia e recuperação
- Preservar IDs/URLs/RPCs antigas. Novos IDs resolvem modo diário na experiência atual; não tornar `topic_id` nullable nem reinterpretar `event_id` legado.
- Novas sessões usam FSRS após ativação. Antigas pendentes podem concluir sem agenda e depois inicializar; se outro modo já agendou card, antiga exclui/recarrega, nunca sobrescreve. Retry commitado permanece válido.
- Versão fixada na apresentação, mídia histórica autorizada apenas para dono/tentativa pendente/versão/elegibilidade; resposta/comentário só após revelar. Revogação impede novas assinaturas; URLs já emitidas duram até expirar (120s atuais).
- Virada do dia preserva tentativa apresentada; avaliação conta no dia do instante preparado. Nova fila referencia estado atualizado, sem duplicar tentativa ativa; antigas preservam progresso.
- Ativação controlada por chave interna e usuários de teste. Em falha, suspender entrada no motor e reparar adiante: não apagar dados nem voltar a gravar Fase 4 sobre cards agendados. Rollback de transação incompleta é integral; rollback funcional preserva eventos já comitados.

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
Aprovação deve cobrir inicialização conservadora, meta por cards distintos, fuso, prioridade e parâmetros propostos. Riscos: runtime, privilégios legados, precisão, backlog sem agenda e corridas entre modos; gates acima precedem liberação. Assinatura segue obrigatória antes da comercialização, fora desta fase.

## Fontes
- https://registry.npmjs.org/ts-fsrs/5.4.2
- https://github.com/open-spaced-repetition/ts-fsrs/tree/v5.4.2
- https://github.com/open-spaced-repetition/fsrs4anki/wiki/The-Algorithm#fsrs-6
