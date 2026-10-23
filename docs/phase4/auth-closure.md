# Fase 4 — Encerramento da pendência de autenticação

Data: 2026-10-23. Escopo: exclusivamente autenticação. Sem Fase 5, FSRS, pagamentos ou assinaturas.

## Causa raiz

O provedor de e-mail/senha estava desativado na configuração de autenticação do backend (Lovable Cloud). Nenhuma falha de código: o formulário respondia "E-mail ou senha incorretos" porque o provedor rejeitava qualquer tentativa.

## Alteração aplicada

- Provedor e-mail/senha habilitado via configuração gerenciada do backend.
- Confirmação de e-mail permanece ATIVA (padrão): novos cadastros só entram após clicar no link de confirmação. Nenhum auto-confirm foi ativado.
- Nenhum usuário existente foi alterado: identificadores, papéis e históricos preservados. A conta administrativa principal (provedor Google) não teve senha, credenciais ou permissões modificadas.
- Para a conta de aluno de teste (232701a6-e67f-408f-aa42-9118425773fd), foi definida uma senha de homologação via API administrativa, com e-mail confirmado, preservando papel `student` e histórico pedagógico.

## Testes efetivos (navegador, sem restauração de sessão)

| # | Teste | Resultado |
|---|-------|-----------|
| 1 | Acesso sem login a /dashboard | Redirecionado ao login |
| 2 | Login real pelo formulário (aluno de teste) | Sucesso → /dashboard |
| 3 | Área Cards após login | Catálogo e métricas reais |
| 4 | Início de sessão de estudo | Sessão criada e card apresentado |
| 5 | Revelar resposta e avaliar | Registro commitado |
| 6 | Retomada pelo Dashboard ("Continuar estudo") | Mesma sessão (mesmo ID) após sair e voltar |
| 7 | Logout | Retorno ao login |
| 8 | Acesso sem login a /cards | Redirecionado ao login |
| 9 | Segundo login pelo formulário | Sucesso → /dashboard |
| 10 | Senha incorreta | Mensagem "E-mail ou senha incorretos.", sem travar |
| 11 | Recuperação de senha (domínio real temporário) | Aceita pelo backend (HTTP 200); usuário temporário removido |
| 12 | Sessão do editor | Válida, papel `editor` intacto |
| 13 | Conta administrativa principal | Intacta (Google, papel `admin`) |

Observação: o envio de e-mails usa o remetente padrão da plataforma (nenhum domínio de e-mail próprio configurado). Endereços de domínio reservado (.test) são rejeitados pelo servidor de e-mail — limitação do fixture de teste, não do produto.

## Revalidações após a ativação

- 29/29 testes finais de homologação no banco real (concorrência entre seções, rollback integral, mídia histórica, expiração de URL assinada, catálogo futuro, RLS de escrita direta).
- Fixtures sintéticos recriados com marcador único e registrados no manifesto; limpeza arquiva apenas IDs registrados.

## Conclusão

Todos os cenários obrigatórios de autenticação passaram. A pendência impeditiva está resolvida e a Fase 4 está formalmente CONCLUÍDA e HOMOLOGADA.
