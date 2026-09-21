# Fundação de dados do ClinicaVerso Cards

## Objetivo

Criar a base escalável de conteúdo, currículo e histórico pedagógico sem alterar a interface, as rotas ou os fluxos atuais.

## O que será implementado

- Taxonomia normalizada e reutilizável: `sections`, `areas`, `topics` e `subtopics`.
- Conteúdo editorial: `flashcards`, `flashcard_media`, `tags` e `flashcard_tags`.
- Histórico editorial append-only: versões anteriores do card e log de alterações, mantendo `id` e `code` estáveis.
- Currículo: programação semanal por seção, com três temas e liberação segunda/quarta/sexta.
- Aprendizagem: estado individual por aluno e card, mais eventos imutáveis de revisão preparados para FSRS.
- Papéis `student`, `editor` e `admin`, com permissões aplicadas no banco; administradores mantêm a área administrativa atual.
- Dados iniciais para R1CM, R+CM, TECM e as áreas médicas indicadas.

## Regras de integridade

- Slugs únicos no escopo correto; código editorial globalmente único e indexado.
- Área compartilhada entre seções; a seção pertence ao flashcard, evitando duplicação da taxonomia.
- Chaves compostas garantem que tema pertença à área e subtema pertença ao tema informados no card.
- Exclusões físicas de taxonomia ou cards referenciados ficam bloqueadas; arquivamento é o caminho editorial.
- Comentário rico será JSON estruturado, validado como documento, nunca HTML arbitrário.
- Mídia guarda caminho de armazenamento, tipo, posição, legenda, texto alternativo e ordem; múltiplos arquivos por card são permitidos.
- Mudanças de conteúdo ou mídia incrementam a versão e registram auditoria, mas não alteram o agendamento do aluno.
- Uma programação por seção/semana, iniciada na segunda-feira, com três temas distintos.
- Um estado por usuário+card; cada avaliação gera um novo evento, sem sobrescrever o histórico.

## Permissões

- Alunos leem apenas cards publicados e seus próprios estados/eventos.
- Editores gerenciam taxonomia, cards, mídia e tags, mas não usuários nem programação.
- Administradores gerenciam conteúdo, programação e papéis.
- Logs e versões são gravados pelo banco e não podem ser alterados por usuários da aplicação.
- A proteção atual de `/admin` continua exigindo papel administrativo; a interface existente não será redesenhada.

## Validação

- Aplicar uma única migração versionada e atualizar automaticamente os tipos do projeto.
- Executar verificação de segurança e revisar políticas, índices, constraints e relacionamentos redundantes.
- Confirmar que login, dashboard, Cards e área administrativa continuam carregando como antes.
