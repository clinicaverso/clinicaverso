# CLINICAVERSO — Fase 4: relatório consolidado de implementação e homologação

**Data:** 23/10/2026, UTC.  
**Estado final:** estudo implementado e homologação de integridade aprovada nos cenários executados; **homologação integral da Fase 4 ainda não concluída**, porque a entrada bem-sucedida pelo formulário de e-mail/senha está bloqueada pela configuração atual. Não foi iniciada a Fase 5.

## 1. Funcionalidades implementadas

- Catálogo de temas por seção, com contagem real de cards elegíveis e estudados.
- Temas futuros mostram apenas metadados autorizados: nome, área e data, com cadeado e botão desativado. Nenhuma pergunta, resposta, comentário, versão histórica ou mídia futura é exposta.
- A programação semanal controla a primeira liberação, sem expiração ao mudar de semana.
- Estudo por tema com pergunta e resposta revelada; resposta curta, comentário rico, tabela, mídia e referência aparecem na revelação. Quatro avaliações: Errei, Difícil, Moderado e Medular.
- Sessões e filas persistentes, retomada pelo Dashboard e preservação da resposta revelada após recarga.
- Conteúdo e mídia fixados à versão realmente apresentada, com revalidação de elegibilidade na retomada e avaliação.
- Eventos de aprendizagem separados das revisões agendadas. Evento, contadores e conclusão do item gravam na mesma transação, de maneira idempotente.
- Dashboard e Performance usam resultados reais do estudo; indicadores demonstrativos de acerto e sequência foram removidos de Performance. Perfil não foi implementado nesta rodada e permanece fora da homologação pedagógica.
- Identidade visual, rotas e arquitetura existentes preservadas. Sem FSRS, intervalos artificiais, pagamentos, assinatura ou novas funcionalidades da Fase 5.

## 2. Alterações no banco e segurança

### Migração 0005 — aprendizagem não agendada

`drizzle/migrations/0005_student_atomic_unscheduled_learning.sql`: adiciona study_sessions, study_session_items e learning_events; funções de início, leitura/revelação, catálogo, panorama e avaliação; políticas de acesso e preservação de versões. learning_events é separado de review_events. scheduled_next_review de aprendizagem fica NULL; não foram inventados parâmetros FSRS nem reescritos eventos anteriores. scheduling_status distingue aprendizagem nova unscheduled do legado, que permanece NULL.

A função de avaliação bloqueia a operação e o par usuário/card, relê o estado após o bloqueio e grava evento, estado e progresso atomicamente. Alterar somente o vínculo de seção não incrementa versão editorial.

### Migração 0006 — privilégios mínimos e catálogo futuro

`drizzle/migrations/0006_phase4_least_privilege_future_catalog.sql`: restringe learning_events, study_sessions, study_session_items e user_flashcard_states a SELECT para authenticated, sem acesso anon; mantém escrita privilegiada e funções autorizadas. Acrescenta locked e metadados futuros ao catálogo. Restringe acesso direto editorial à mídia e mantém o caminho de autorização de mídia histórica por sessão para alunos.

**Origem dos privilégios amplos confirmada:** pg_default_acl no schema public contém concessões ALL para anon/authenticated em tabelas criadas pelos proprietários postgres e pelo proprietário gerenciado. GRANT SELECT isoladamente não removia INSERT/UPDATE já herdados. A correção revogou explicitamente os privilégios dessas quatro tabelas e concedeu somente SELECT ao aluno; não alterou os padrões gerenciados globais.

Consulta final com has_table_privilege confirmou para as quatro tabelas: authenticated SELECT=true; INSERT/UPDATE/DELETE=false; anon SELECT=false. As quatro funções study_catalog, start_study_session, read_study_session e rate_study_item têm SECURITY DEFINER, search_path vazio, EXECUTE authenticated e nenhum EXECUTE anon. As funções autorizadas continuaram funcionando nos testes reais.

As migrações foram aplicadas pela ferramenta transacional, sem remoção de históricos. Dependências e consumidores foram revisados antes do hardening. Procedimento de recuperação documentado em docs/phase4/recovery.md: reparação aditiva para frente, sem apagar tabelas, eventos ou versões.

## 3. Resultados quantitativos

| Conjunto | Ambiente | Resultado efetivo |
|---|---|---|
| Integração base de estudo | Banco real | 25/25 PASS na reexecução final |
| Homologação complementar | Banco real | 29/29 PASS |
| Regressão XLSX | Banco real | 20/20 PASS, incluindo 10, 50 e 200 cards |
| Regras editoriais | Vitest | 18/18 PASS |
| Schema de estudo | PostgreSQL isolado | 37/37 PASS nesta rodada; não substitui banco real |
| Fluxos visuais | Chromium real | 15 verificações PASS registradas, mais rejeição do formulário confirmada separadamente |
| Login bem-sucedido por formulário | Configuração hospedada atual | BLOQUEADO, não aprovado |

Não somar as verificações acima como cobertura independente: alguns cenários se repetem entre conjuntos. As capturas são evidências visuais, não provas isoladas de integridade.

## 4. Banco real — cenários complementares

1. **PASS** — Second ordinary test student session valid, without changing principal admin.
2. **PASS** — Useful-resolution private synthetic medical image uploaded.
3. **PASS** — Same student pins same card in two active-section sessions.
4. **PASS** — Distinct concurrent cross-section ratings accept exactly one.
5. **PASS** — Cross-section race increments review_count once and lapses only for winner.
6. **PASS** — Losing section skips globally learned card on resume.
7. **PASS** — Four distinct ratings on same operation commit one event.
8. **PASS** — Controlled real failure occurs in state update after event insert.
9. **PASS** — Live rollback leaves no partial event or item completion.
10. **PASS** — Live rollback preserves state and session timestamp exactly.
11. **PASS** — Retry after rollback commits valid rating once.
12. **PASS** — Image card reached in persisted queue.
13. **PASS** — Other ordinary student cannot sign media without corresponding session.
14. **PASS** — Current media accessible in authorized session.
15. **PASS** — Pinned historic media remains available after editorial deactivation.
16. **PASS** — Signed historical image resolves at useful resolution.
17. **PASS** — Eligibility loss blocks new historical media URLs.
18. **PASS** — Previously signed URL remains usable after revocation before expiry.
19. **PASS** — Revoked session cannot load content or evaluate.
20. **PASS** — Previously signed URL rejected after its 120-second expiry.
21. **PASS** — Future catalog returns only authorized locked metadata and zero counts.
22. **PASS** — Future card and historical versions hidden by RLS.
23. **PASS** — Future session rejected without creating empty record.
24. **PASS** — Direct INSERT denied: learning_events.
25. **PASS** — Direct PATCH denied: learning_events.
26. **PASS** — Direct DELETE denied: learning_events.
27. **PASS** — Direct INSERT denied: user_flashcard_states.
28. **PASS** — Direct PATCH denied: user_flashcard_states.
29. **PASS** — Direct DELETE denied: user_flashcard_states.

### Atomicidade e concorrência

O mesmo aluno leu o mesmo card em duas sessões de seções ativas diferentes. Duas avaliações distintas simultâneas produziram exatamente um evento e um incremento de review_count. lapse_count correspondeu somente à avaliação vencedora; a sessão perdedora pulou o card já aprendido. Quatro avaliações diferentes para uma mesma operação também aceitaram só uma. O conjunto base comprovou oito reenvios idênticos retornando o mesmo evento.

A falha transacional real foi provocada apenas num estado sintético marcado: lapse_count=2147483647, review_count=0. A avaliação Errei causa overflow durante a atualização do estado, depois da tentativa de inserção do evento. Confirmados: nenhum evento parcial, item sem conclusão, estado e timestamp da sessão exatamente preservados. Nova avaliação válida posteriormente gravou uma vez. Nenhum trigger global de falha, função de teste permanente ou alteração de registro definitivo foi usado. O estado sintético extremo permanece identificado como teste, não foi reescrito como histórico real.

### Mídia e revogação

Aluno autorizado acessou a imagem histórica da versão fixada mesmo após desativação editorial da mídia atual. Outro aluno comum, sem a sessão correspondente, não emitiu URL. Arquivar o card bloqueou imediatamente novas assinaturas, leitura elegível e avaliação.

**Limitação explicitamente comprovada:** uma URL já assinada continua válida após revogação até expirar. A URL de 120 segundos funcionou após revogação e foi recusada após aguardar efetivamente sua expiração. Não existe revogação instantânea retroativa das URLs já emitidas. A imagem utilizada é um ECG sintético de 1400×600, sem dados de pacientes e sem finalidade diagnóstica.

## 5. Navegador real e responsividade

Viewport móvel 390×844, Chromium headless, com sessões reais dos usuários de teste restauradas antes de navegar. Administração e formulário: 1280×1800.

- **PASS** — Mobile question or persisted revealed state renders.
- **PASS** — Mobile long comment and table render.
- **PASS** — No page-level horizontal overflow with revealed long comment.
- **PASS** — Four mobile rating buttons usable.
- **PASS** — Reload preserves revealed answer.
- **PASS** — Dashboard resumes same persisted session.
- **PASS** — Mobile medical image loads at useful intrinsic resolution.
- **PASS** — Medical image stays within mobile width.
- **PASS** — All four UI ratings commit and complete study.
- **PASS** — Mobile future topic has release date and disabled lock.
- **PASS** — Performance loads without hardcoded accuracy/streak samples.
- **PASS** — Editorial listing reads test cards.
- **PASS** — Browser editorial change saves version.
- **PASS** — Browser XLSX model download/upload/preview works.
- **PASS** — Browser real XLSX export downloads.

O primeiro percurso móvel confirmou pergunta oculta, revelou a resposta, preservou após recarga, retomou a mesma sessão pelo Dashboard e registrou Errei, Difícil, Moderado e Medular, avançando só após gravação. Foram verificadas tabela com palavras longas, comentário extenso, rolagem vertical, ausência de overflow horizontal da página e imagem com naturalWidth=1400. A imagem foi conferida novamente após aguardar o download, mantendo largura dentro do celular. Capturas de resposta e ECG foram inspecionadas visualmente.

Na administração, a listagem exibiu os fixtures. Alteração real de resposta pelo editor visual e publicação salvaram CV-CARD-000831 como versão 2; consulta posterior confirmou duas versões preservadas. Download do modelo, upload XLSX e validação abriram a prévia; exportação real baixou um arquivo válido. A confirmação/processamento/importação durável completa foi revalidada no banco pelo teste XLSX, não registrada como uma importação integral feita por cliques nesta rodada.

**Login:** após aguardar a hidratação, o formulário foi preenchido e submetido; mostrou “E-mail ou senha incorretos”, sem ficar travado. Tentativa de senha no serviço de autenticação retornou email_provider_disabled, conforme a configuração atual. A entrada bem-sucedida por formulário NÃO foi homologada; sessões restauradas não substituem esse teste. Nenhuma configuração de autenticação foi alterada. OAuth não foi homologado nesta rodada.

## 6. Regressões editoriais reais

- **PASS** — Prévia não grava cards.
- **PASS** — 10 novos cards importados.
- **PASS** — Códigos automáticos globais.
- **PASS** — Novo card versão 1 e draft.
- **PASS** — Atualização idêntica ignorada com JSONB reordenado.
- **PASS** — Somente seção mantém versão 1, ID e código.
- **PASS** — Resposta e comentário alterados geram versão 2.
- **PASS** — Versões históricas preservadas.
- **PASS** — Opcionais vazios preservam valores.
- **PASS** — Interrupção deixa 45 linhas pendentes.
- **PASS** — Retomada conclui 50 cards.
- **PASS** — Confirmação repetida retorna mesma operação.
- **PASS** — Reprocessar não duplica.
- **PASS** — Campos e seção inválida reportados nas linhas reais.
- **PASS** — Mistura válidas inválidas importa só 1, reporta 2 erros.
- **PASS** — Duplicata interna sinalizada.
- **PASS** — Modo criação não atualiza código existente.
- **PASS** — Exportação/reimportação preserva conteúdo sem alteração.
- **PASS** — Volume real de 200 cards no banco.
- **PASS** — Falha do executor é isolada e não cria card parcial.

O conjunto base de 25 testes também confirmou manutenção de review_events, resposta oculta, rejeição de avaliação antes de revelar, versões efetivamente vistas, retomada sem cards arquivados e bloqueio de escrita direta. Os 18 testes editoriais preservados foram executados novamente.

## 7. Falhas observadas e tratamento

1. Privilégios amplos herdados: origem auditada e corrigida pela migração 0006; testes diretos e consulta de privilégios finais aprovados.
2. Catálogo não mostrava temas futuros e Performance trazia amostras: corrigidos sem redesign, testados no banco e no navegador.
3. Comentário/tabela com palavras longas: contenção e quebra de texto reforçadas no renderizador; celular sem overflow horizontal.
4. Primeira verificação da imagem ocorreu antes do download terminar: após espera real, a imagem carregou em 1400×600; não era falha de acesso. A captura final confirmou o ECG visível.
5. Primeira reexecução do teste base retomou uma fila contendo fixtures ainda publicados de outra bateria, causando uma asserção de resposta original. Somente os fixtures registrados no manifesto foram arquivados; a reexecução isolada passou 25/25. Não foi confundido esse resultado intermediário com defeito de versionamento.
6. Primeira submissão do formulário ocorreu cedo demais e resetou na hidratação; repetida após espera, confirmou rejeição visível. O sucesso permanece bloqueado pelo provedor desativado.

## 8. Evidências, limpeza e limites

Scripts mantidos no projeto: scripts/phase4-final.integration.py, scripts/phase4-live.integration.py, scripts/phase4-schema.integration.py e scripts/editorial-import.integration.ts. Correções: model.ts, cards.tsx, performance.tsx e study-comment.tsx, além das migrações e recuperação documentadas.

Evidências desta execução foram capturadas em /tmp/browser/phase4-final/: results.json, browser-results.json, regression-live.log, xlsx-regression.log e screenshots/mobile-ecg.png, mobile-answer.png, future-topic.png, performance.png, editor-saved.png e login-denied.png. Esses diretórios também contêm sessões privadas: **não distribuir a pasta integral**, cookies, tokens nem URLs assinadas. Este relatório não contém credenciais.

Arquivados os cinco cards marcados [Homologação final F4 1f6aab35], as programações temporárias e a seção sintética; temas futuros sintéticos desativados. Os testes base e XLSX arquivaram seus próprios cards. Eventos, versões e mídia privada de teste foram preservados. Não foi alterada a conta admin principal. A limpeza não é exclusão de usuários ou de histórico, e não implica apagar todas as taxonomias criadas pelas baterias anteriores.

Build mais recente: OK. Metadados específicos das páginas conferidos. Não houve publicação nesta rodada.

## 9. Pendências e decisão de encerramento

**Pendência impeditiva de homologação integral:** validar entrada bem-sucedida por e-mail/senha. Bloqueio: provedor desativado na configuração atual. É necessária uma decisão explícita sobre disponibilizar esse método; não foi ativado unilateralmente nem foi prometido sucesso com sessões restauradas.

Os cenários de estudo, concorrência, rollback, permissões, mídia histórica e expirada, catálogo futuro, celular, Dashboard, Performance e regressão editorial executados passaram. Não foram identificadas falhas críticas pendentes nesses cenários. Ainda assim, com o requisito obrigatório de login bem-sucedido não testado, **a Fase 4 não é declarada integralmente concluída**.

Controle de acesso permanece por seção ativa, conteúdo publicado e data mínima de liberação, conforme aprovado. Isso **não representa compra, assinatura ou matrícula**. Controle de assinatura/entitlement deve ser implementado e auditado antes da comercialização; não foi construído agora.

**Não realizados:** FSRS, agendamento artificial, pagamentos, assinaturas e funcionalidades da Fase 5. O próximo trabalho é exclusivamente resolver o bloqueio do método de entrada e executar sua homologação, mediante decisão do responsável.
