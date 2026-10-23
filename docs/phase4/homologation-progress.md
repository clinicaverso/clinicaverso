# ClinicaVerso — Fase 4: relatório parcial de implementação e homologação

**Relatório parcial histórico, substituído por `homologation-final.md` em 23/10/2026. As pendências abaixo descrevem a rodada anterior, não o estado atual.**

## Alterações efetivamente realizadas

- Migração aditiva aplicada em `drizzle/migrations/0005_student_atomic_unscheduled_learning.sql`, usando a ferramenta transacional; tipos regenerados.
- Criadas sessões persistentes, itens de fila e `learning_events`, separados dos `review_events` anteriores. Os eventos têm operação única por usuário, versão editorial vista e estados anterior/posterior explícitos.
- Adicionada classificação nullable `scheduling_status`: legado permanece NULL; aprendizagem nova é `unscheduled`. Não foram criados intervalos, datas de revisão ou parâmetros FSRS artificiais.
- Funções autenticadas de catálogo, início, leitura/revelação e avaliação; a avaliação grava evento, contadores e progresso na mesma transação.
- Versão do conteúdo fixada na primeira leitura. Resposta, comentário, referências e mídia histórica seguem essa versão, mesmo se o editor atualizar o card depois.
- Interface de estudo com dois estados e avaliações Errei, Difícil, Moderado e Medular; Cards e Dashboard conectados a dados reais e retomada.
- Documento de recuperação em `docs/phase4/recovery.md`: reparar para frente; não apagar tabelas, versões ou eventos históricos.
- Nenhum FSRS, pagamento ou recurso da Fase 5 foi implementado. Performance e Perfil permanecem com seus dados demonstrativos anteriores; não são relatórios pedagógicos reais nesta fase.

## Resultados efetivos — banco real

O script `scripts/phase4-live.integration.py` executou **25 verificações PASS** na última execução, com editor e aluno de teste autorizados. Não usa credenciais administrativas nem altera a conta admin principal.

1. Editor envia imagem privada.
2. Quatro inícios concorrentes retomam a mesma sessão.
3. Pergunta não revela resposta/comentário.
4. Avaliar antes de revelar é rejeitado.
5. Ler não conclui o card.
6. Outro usuário não lê a sessão por função.
7. RLS esconde itens da sessão de outro usuário.
8. Rascunho não é lido pelo aluno.
9. Atualização editorial real mantém a versão fixada na sessão.
10. Desativação da mídia atual mantém a mídia histórica na versão apresentada.
11. Mídia histórica pode ser assinada na sessão pendente autorizada.
12. Editor não lê a linha de sessão pertencente ao aluno (não equivale a bloqueio de mídia para editor: gestores têm acesso editorial legítimo).
13. Oito avaliações simultâneas da mesma operação retornam um evento único.
14. Evento, review_count=1 e lapse_count=1 após Errei.
15. Evento mantém versão vista e estado inicial new.
16. Estado mantém next_review_at, estabilidade e dificuldade nulos; classificação unscheduled.
17. Repetir a operação com outra avaliação é rejeitado.
18. Nova assinatura da mídia histórica é negada após concluir o item.
19. Arquivar card apresentado impede sua avaliação.
20. Retomada exclui card arquivado sem perder eventos anteriores.
21. Escrita direta de contadores é negada.
22. Tentativa de alterar evento pelo aluno não altera sua avaliação.
23. Tentativa de excluir evento pelo aluno preserva o registro.
24. Tema inexistente não cria sessão válida/vazia.
25. Quantidade de review_events do aluno permanece inalterada.

**Falha encontrada no teste e corrigida:** uma primeira execução marcou tentativa de alterar evento como FAIL porque esperava erro HTTP. A operação retornava sucesso sem afetar linhas, devido à política de acesso. Foi verificado que a avaliação permaneceu `again`; o teste passou a conferir o registro real depois da tentativa, em vez de inferir alteração pelo código HTTP. Nenhuma alteração de histórico foi observada.

**Observação de segurança pendente:** a leitura dos privilégios efetivos encontrou INSERT/UPDATE para authenticated em learning_events, apesar da migração pedir apenas SELECT. RLS sem políticas de escrita e trigger de imutabilidade protegem os registros nos testes feitos, mas a origem desses privilégios amplos e sua normalização precisam de auditoria antes do encerramento.

## Navegador real

Em execução anterior desta homologação, com o aluno de teste:
- Abriu tema com cinco cards publicados.
- Revelou resposta; recarregou e preservou o estado revelado.
- Registrou as quatro avaliações, avançando somente após gravar.
- Saiu e retomou a mesma sessão pelo Dashboard.
- Finalizou a sessão; os cinco eventos foram lidos no banco, com versões corretas e event_kind=unscheduled_learning.

Uma captura feita imediatamente após mudar o tamanho mostrou conteúdo estreito no celular. Reproduzido depois com espera pela transição, a largura foi correta: computador 1280 com conteúdo 1048px e margem 232px; tablet 790 e celular 390 com margem zero e largura integral. Sem excesso horizontal. Captura de Cards a 390px foi inspecionada visualmente. Ainda falta repetir o estudo revelado no celular com espera pela transição e verificar a imagem em dimensões úteis; a mídia sintética de 1px valida acesso, não legibilidade de uma imagem médica.

## Regressões e fixture isolada

- 18 testes editoriais existentes passaram (`bunx vitest run src/lib/editorial/model.test.ts`).
- Logs mais recentes da aplicação: build OK.
- A proposta anterior teve 37 verificações numa fixture PostgreSQL isolada. Esse resultado não substitui integração real; a fixture não é dump integral da produção e não foi reexecutada nesta última rodada.

## Pendências antes de declarar conclusão

- Concorrência do mesmo usuário/card em sessões de seções diferentes. A função lê o estado após o lock user+card e rejeita review_count>0; a auditoria sugeriu reforço adicional, mas o cenário cruzado ainda não foi executado no banco real. Não há pares user/card duplicados na consulta feita.
- Falha real entre inserção do evento e atualização do estado: atomicidade foi testada anteriormente apenas na fixture isolada, não por falha induzida no banco real.
- Mídia após perda de elegibilidade, URL já assinada durante seus 120 segundos de validade e tentativa de acesso por outro aluno sem poderes editoriais.
- Catálogo de temas futuros com cadeado/data: a implementação atual só devolve temas liberados. Não expõe conteúdo futuro, mas essa parte visual do escopo permanece ausente.
- Regressão completa de login por formulário, Admin e Performance nesta rodada; navegar com sessão restaurada não homologa o formulário de login nem configurações hospedadas de autenticação.
- Revisar permissões efetivas de learning_events e finalizar relatório consolidado após solucionar as pendências.

## Acesso por seção e comercialização

Nesta fase mantém-se o modelo aprovado: usuário autenticado pode estudar conteúdo publicado/liberado de seção ativa. Não há autorização por assinatura. **O controle de assinatura/entitlement deve ser implementado e auditado antes da comercialização**, sem confundir seção ativa com compra ou matrícula.

## Dados de teste

Os cards criados pelos testes reproduzíveis são identificados e arquivados em finally. Os sete cards iniciais de homologação também foram arquivados nesta rodada, sem excluir eventos, versões, mídia ou histórico. Mídias de teste permanecem privadas e preservadas; não foi feita limpeza destrutiva. A conta principal não foi alterada.
