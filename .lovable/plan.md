# Fase 5 — FSRS e fila diária inteligente

## Escopo e aprovação
**Somente planejamento.** Nenhuma migração, dependência ou funcionalidade foi executada. Implementação depende da aprovação deste plano. Preservar identidade, autenticação, CMS, históricos e fluxo pergunta → resposta/comentário → avaliação; sem pagamentos, assinaturas, IA, otimização personalizada ou gamificação.

Base examinada: migrações 0005/0006, contratos e funções de estudo, tipos e encerramento da Fase 4. A leitura do repositório não substitui auditoria do banco real. Os testes abaixo são propostos, não resultados obtidos.

## 1. Algoritmo e política proposta
- Fixar **ts-fsrs@5.4.2**, licença MIT, algoritmo **FSRS-6.0**; versão estável verificada no registro em 23/10/2026. Não usar beta nem atualização automática.
- Mapear Errei/Again=1, Difícil/Hard=2, Moderado/Good=3, Medular/Easy=4; estados new/learning/review/relearning correspondem a New/Learning/Review/Relearning da biblioteca.
- Proposta inicial: retenção-alvo 90%; curto prazo ativo; passos de aprendizagem 1 e 10 minutos, reaprendizagem 10 minutos; fuzz desativado; intervalo máximo 36.500 dias, conforme padrão da versão. Estes valores são propostas para aprovação, não regras já implantadas.
- Persistir configuração imutável: pacote, algoritmo, 21 pesos completos, retenção-alvo, passos, intervalo máximo, fuzz e versão do adaptador. Cada avaliação referencia a configuração efetivamente usada. Atualizações futuras criam outra configuração, sem alterar eventos anteriores.
- Usar `next(card, instant, rating)` para cálculo efetivo; `repeat` apenas para prévias não vinculantes. Registrar estabilidade, dificuldade, estado e próxima revisão, com entrada/saída completas e unidades explícitas.
- Retenção estimada é probabilidade variável com o tempo, calculada por `get_retrievability(..., instant, false)`. Não é nota nem constante armazenada; para cards sem inicialização, exibir “Ainda não estimada”, não uma falsa certeza.
- Biblioteca em JavaScript sem dependências de produção; declaração de suporte Node ≥20 não comprova compatibilidade com o ambiente publicado. Teste no ambiente real é condição de liberação.

## 2. Aprendizagem da Fase 4 e transição
`learning_events` permanecem intactos e separados de `review_events`. Não reproduzir suas avaliações no passado com pesos novos, inventar intervalos ou preencher datas retroativas.

Política conservadora proposta:
1. Card nunca estudado: inicializar FSRS na primeira avaliação real da Fase 5.
2. Card estudado sem agendamento: entrar em grupo **“Iniciar revisão”**, sem data vencida fictícia. Na primeira avaliação real atual, iniciar o estado técnico FSRS como New, registrando origem `phase4_unscheduled` e vínculo com o último evento real. Isso não redefine o card como novo para o aluno.
3. Preservar contadores históricos; separar `reps/lapses` do motor dos contadores acumulados do produto. Na Fase 4, Again já contou como lapso; no FSRS, os lapsos seguem a biblioteca. Documentar essa diferença, sem corrigir o passado.
4. Registros com `scheduling_status=NULL`, FSRS desconhecido ou datas incoerentes: inventariar e colocar em classificação pendente; não reinicializar nem incluir silenciosamente como novos. Agendamentos reconhecidos só continuam após validação do adaptador.

Auditoria de inicialização registra momento atual, origem, referência histórica, configuração e estado inicial, sem fingir que é avaliação. Inicialização só se conclui na transação da avaliação real. Nenhum histórico é apagado.

## 3. Regras da fila diária
**Meta: mínimo 25 cards distintos avaliados no dia, sem teto de estudo.** Repetições necessárias de aprendizagem contam como respostas, mas não aumentam novamente o número de cards distintos da meta. Mostrar ambos separadamente.

Ordem proposta:
1. Cards em Review atrasados e previstos para hoje; atrasados primeiro, ordenados por vencimento e desempate estável.
2. Learning/Relearning disponíveis (`due <= agora`), priorizando reaprendizagem. Etapas futuras aguardam o horário correto; nunca avançar um passo só porque pertence ao mesmo dia.
3. Inicializações pendentes da Fase 4, identificadas separadamente.
4. Novos cards para completar a meta; após alcançá-la, permitir continuar com novos, sem esconder revisões restantes.

“Hoje” usa **America/Fortaleza**, como a Fase 4. Datas são UTC `timestamptz`; início/fim do dia são calculados pelo fuso IANA, não por somar 24 horas fixas. Atrasados: revisão anterior ao início do dia. Em Review, itens previstos até o fim do dia podem ser estudados hoje; passos curtos só quando disponíveis.

Escopo inicial: seção selecionada, hoje R1CM. Não habilitar R+CM/TECM apenas por este plano. Seções futuras filtram elegibilidade, nunca criam outro agendamento. Identidade global é `(user_id, flashcard_id)`.

Primeiras exposições mantêm blocos por tema escolhido, sem intercalar temas a cada card. Revisões misturam temas por ordenação determinística dentro das prioridades. Prioridade de vencimento prevalece sobre mistura. Recalcular disponibilidade entre avaliações para inserir passos que ficaram disponíveis, sem reordenar a pergunta já apresentada.

Não reservar exclusivamente um card até o usuário terminar: abandono não pode bloquear estudo. Deduplicar membros da fila por usuário/dia/card; cada apresentação é uma tentativa distinta vinculada à revisão do estado. Etapas reais podem repetir o mesmo card, sem duplicar membro ou evento.

## 4. Experiência do aluno
Sem novas páginas de marketing ou mudança de navegação global:
- Dashboard/Cards: indicadores “Para revisar hoje”, “Atrasados”, “Novos disponíveis”, “Iniciar revisão” e “Meta diária”; progresso pode superar 25.
- Ação principal “Estudar hoje”; “Retomar estudo” quando há tentativa pendente; temas continuam acessíveis para primeiras exposições.
- Sessão mantém pergunta, resposta curta, comentário, mídia e referências, com os quatro botões atuais. Após gravar, apresentar próxima revisão; prévias nos botões, se usadas, são estimativas, não compromissos.
- Conclusão distingue meta atingida, fila disponível concluída e próxima etapa aguardando horário. Nunca afirmar “Em dia” se há revisões disponíveis ou atrasadas.
- Ao faltar conteúdo para atingir 25, mostrar resultado real; não repetir avaliações artificiais para completar meta.
- Preservar cinzas/verde, componentes existentes, leitura de tabelas/imagens, celular, teclado, foco e mensagens de falha recuperáveis. “Teoria” permanece nome do produto, sem renomear a navegação para “Revisões”.

## 5. Detalhes técnicos — modelo e migrações
Proposta aditiva, sem SQL aplicado e sem remover constraints existentes:

| Objeto | Mudança proposta |
|---|---|
| `fsrs_configurations` — nova | Configurações imutáveis e identificador/hash; leitura somente das configurações autorizadas, escrita interna |
| `fsrs_initializations` — nova | Proveniência de inicialização por usuário/card, única, sem substituir eventos |
| `daily_study_queues` — nova | Usuário, seção, dia local, fuso, versão da política e situação; criação concorrente idempotente |
| `daily_queue_members` — nova | Card único por fila, origem, prioridade e ordem estável; sem cópia do histórico pedagógico |
| `daily_study_attempts` — nova | Apresentação persistente, fila/card, versão vista, revelação, revisão esperada do estado, operação, horário de cálculo e evento final; permite passos repetidos |
| `user_flashcard_states` | Acrescentar revisão monotônica, configuração, inicialização e último instante FSRS; reutilizar estado/data/estabilidade/dificuldade existentes |
| `review_events` | Acrescentar operação, tentativa, configuração, origem, revisão antes/depois e snapshots opcionais; campos novos nullable para compatibilidade, obrigatórios na função nova |

JSON FSRS versionado guarda representação completa, incluindo progresso dos passos, reps/lapses e precisão da biblioteca; colunas numéricas são projeções para consulta, não entrada truncada do próximo cálculo. Não misturar timestamps históricos com `last_review` do motor recém-inicializado.

Índices: usuário/data/fila, tentativas pendentes, estados agendados por usuário/vencimento e unicidade usuário/operação nos novos eventos, com índice parcial para não exigir valores nos eventos legados. FKs preservam versão editorial e vínculos com tentativa/configuração. Considerar UNIQUE por usuário/card/revisão anterior nos eventos FSRS para impedir dois consumos do mesmo estado.

Cada tabela pública seguirá CREATE → GRANT explícito → RLS → políticas. Alunos leem só os próprios registros; não escrevem estados, tentativas, inicializações ou eventos diretamente. Papéis não mudam. Configuração do algoritmo não é um campo livre editável pelo aluno.

Auditar privilégios **efetivos**, defaults, owners, triggers e consumidores antes da migração: o repositório indica INSERT autenticado antigo em `review_events`, fora do hardening das quatro tabelas da Fase 4. Confirmar no banco real, fechar esse caminho e adicionar proteção append-only sem alterar eventos. Não declarar vulnerabilidade real confirmada apenas por leitura de arquivos.

## 6. Funções, confiança e idempotência
PostgreSQL não executa a biblioteca npm. Cálculo fica em função autenticada TanStack; banco garante commit atômico.

Fluxo:
1. RPC autenticada prepara tentativa: deriva usuário, valida seção/card/liberação, pergunta revelada, versão fixada, configuração e revisão do estado. Retorna snapshot e recibo persistente com horário UTC normalizado em milissegundos.
2. Servidor calcula com biblioteca fixada. Navegador envia apenas tentativa/operação e avaliação, nunca pesos, intervalos, usuário autoritativo ou data.
3. Commit interno restrito, inacessível a `anon/authenticated`, recebe recibo e cálculo. Usar cliente privilegiado gerado somente dentro do handler, após autenticação e verificação pelo cliente do usuário; não criar nem expor credencial nova.
4. Transação revalida recibo, dono, elegibilidade, versão/configuração e estado esperado; lock global usuário/card e ordem consistente de locks. Insere evento, atualiza estado/revisão/contadores, conclui tentativa e registra inicialização quando necessária.
5. Mesma operação + mesma escolha retorna evento original; escolha diferente é rejeitada. Duas sessões com a mesma revisão: uma vence, outra recebe conflito e recarrega, sem reaplicar a escolha ao estado novo.

Compare-and-swap não prova correção matemática: a confiança é o cálculo no servidor autenticado. Validar faixas, coerência e recibos no banco; grants mínimos nas funções. Mesmo reenvio usa instante preparado; recibos expirados sem commit exigem nova preparação. Falha após commit retorna resultado já gravado na repetição; falha antes dele não conclui o card. Sem avaliações offline nesta versão.

Novas RPCs: resumo diário, criar/retomar fila, ler/revelar tentativa, preparar avaliação e commit interno. Queries incluem seção/modo/dia, sem heurística limitada aos últimos 50 registros. Métricas deduplicam cards e operações entre os dois históricos.

## 7. Sessões antigas, mídia e recuperação
- Manter IDs, URLs e assinatura das RPCs da Fase 4. Novos IDs resolvem o modo diário na mesma experiência de estudo; não tornar `topic_id` nullable nem reinterpretar `event_id` antigo.
- Novas sessões usam FSRS após ativação; sessões antigas pendentes podem concluir no caminho sem agenda e depois entrar na inicialização explícita. Se card foi agendado em outra sessão, a antiga não sobrescreve estado: exclui/recarrega com aviso recuperável. Retry já commitado continua retornando o resultado antigo.
- Mídia histórica requer dono + tentativa pendente + elegibilidade + versão vista, inclusive no caminho diário; resposta/comentário só depois de revelar. Arquivamento ou perda de acesso bloqueiam leitura e novas assinaturas. URLs já emitidas duram até expirar (atualmente 120 segundos).
- Virada do dia preserva tentativa já apresentada; avaliação conta no dia do horário efetivo preparado. Nova fila referencia estado atualizado e não duplica tentativa ativa. Filas antigas preservam progresso e histórico.
- Migrações transacionais e additive-first; inventário e backup/recuperação antes. Ativação controlada com usuários de teste e chave de habilitação interna. Em falha, desativar entrada no motor e corrigir adiante: nunca apagar tabelas/eventos nem voltar a gravar Fase 4 sobre cards já agendados.

## 8. Homologação e critérios objetivos
1. Vetores oficiais fixos da versão: quatro notas, todos os estados, intervalos curtos/longos e retenção; comparação determinística, tolerância numérica explícita, datas exatas em ms.
2. Configuração e snapshots reproduzem cada transição; precisão e reps/lapses mantidos após serialização.
3. Mesmo clique repetido 20 vezes: um evento e um incremento. Escolhas concorrentes distintas/cross-seção/cross-modo: um vencedor, conflito explícito, nenhum estado perdido.
4. Falha controlada após INSERT do evento: rollback integral de evento, estado, inicialização e tentativa, só em registros sintéticos marcados.
5. Recarga/logout/novo login retomam pergunta/revelação/posição; perda de resposta de rede depois do commit não duplica avaliação.
6. Mudança editorial mantém versão/mídia apresentadas; conteúdo bloqueado, futuro e usuário alheio nunca vazam.
7. Meta 24 rejeitada/25 aceita; 30 revisões continuam disponíveis; repetições do mesmo card não inflam meta; falta de novos não gera estudo artificial.
8. Ordem atraso → hoje → passos disponíveis → inicialização → novos; tema agrupado nos novos, mistura nas revisões, nenhum passo antecipado.
9. 23:59/00:00 Fortaleza, datas UTC, recibos e retomada entre dias: sem duplicação nem perda; testar fuso com horário de verão para validar método.
10. Históricos anteriores iguais antes/depois, sem eventos retroativos; sessões legadas e estados desconhecidos tratados explicitamente.
11. Negar REST direto e execução do commit interno; conferir RLS, ACLs, roles, mídia revogada e expiração real.
12. Navegador desktop/celular, login real, Cards/Dashboard/Performance, CMS, versionamento, programação e XLSX; teste do motor no ambiente publicado autorizado.

Separar resultados da fixture PostgreSQL isolada dos testes no banco real. Aceite: todos os casos obrigatórios passam, sem falhas críticas, inventário/limpeza por IDs registrados, relatório com versões, evidências e recuperação validada. Não liberar com teste obrigatório não executado.

## Aprovações e riscos
A aprovação deve cobrir política de inicialização conservadora, meta por cards distintos, fuso Fortaleza, prioridade da fila e parâmetros propostos. Riscos: compatibilidade do runtime, privilégios legados, precisão de números, backlog sem agenda e corridas entre modos; todos têm testes e gates acima. Mudança de parâmetros posterior não reagenda cards existentes automaticamente. Controle por assinatura continua obrigatório antes da comercialização, fora desta fase.

## Fontes
- Biblioteca/versionamento: https://registry.npmjs.org/ts-fsrs/5.4.2
- Fonte fixada: https://github.com/open-spaced-repetition/ts-fsrs/tree/v5.4.2
- Algoritmo: https://github.com/open-spaced-repetition/fsrs4anki/wiki/The-Algorithm#fsrs-6
