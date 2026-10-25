# Clinicaverso

Quero criar o primeiro protótipo de uma plataforma de educação médica chamada CLINICAVERSO.

Este é o início de um produto real e escalável. Neste primeiro momento, quero construir a fundação visual, a arquitetura da aplicação e as principais telas de navegação. Não tente implementar todas as funcionalidades futuras de uma vez.

Utilize as logos e elementos de identidade visual que estou fornecendo como referência oficial da marca.

==================================================

1. SOBRE O CLINICAVERSO

==================================================

ClinicaVerso é uma plataforma digital de educação médica.

A proposta é reunir diferentes produtos educacionais dentro de um mesmo ecossistema.

Inicialmente existirão três áreas principais:

1. ClinicaVerso Cards

2. ClinicaVerso Revisões

3. ClinicaVerso Aulas

Neste MVP, o principal produto será:

CLINICAVERSO CARDS R1CM

O ClinicaVerso Cards R1CM será uma plataforma de flashcards voltada para revisão de Clínica Médica.

ClinicaVerso Revisões e ClinicaVerso Aulas devem aparecer na plataforma, mas ainda não precisam possuir funcionalidades completas.

Apresente esses dois produtos com indicação discreta de "Em breve".

A arquitetura deve permitir adicionar novos produtos no futuro sem precisar reconstruir a aplicação.

==================================================

2. PRINCÍPIO DE ARQUITETURA

==================================================

Considere:

CLINICAVERSO = ecossistema/plataforma principal

CLINICAVERSO CARDS = um produto dentro do ecossistema

CLINICAVERSO REVISÕES = outro produto

CLINICAVERSO AULAS = outro produto

Portanto, não construa a aplicação inteira como se fosse apenas o ClinicaVerso Cards.

A navegação global pertence ao ClinicaVerso.

Cada produto poderá posteriormente possuir identidade visual secundária e funcionalidades próprias.

==================================================

3. IDENTIDADE VISUAL

==================================================

Utilize os assets de logo fornecidos.

Não tente recriar a logo com fontes ou texto HTML.

A identidade principal do ClinicaVerso utiliza:

- preto

- branco

- verde vibrante

- verde/turquesa como cores de destaque

O verde é a principal cor institucional da marca.

A identidade também possui gradientes vibrantes, mas eles devem ser utilizados com moderação.

O ClinicaVerso Cards possui identidade secundária baseada em:

- azul

- ciano

- turquesa

Essas cores identificam o produto Cards, mas não substituem a identidade verde principal do ClinicaVerso.

==================================================

4. DIREÇÃO DE DESIGN

==================================================

Quero uma interface:

- clean

- minimalista

- premium

- moderna

- tecnológica

- elegante

- extremamente organizada

- com bastante espaço negativo

- altamente legível

- responsiva

O produto é destinado a médicos e estudantes de Medicina.

A interface NÃO deve parecer:

- prontuário eletrônico

- sistema hospitalar

- site de clínica

- cursinho preparatório tradicional

- plataforma infantil

- aplicativo excessivamente gamificado

- dashboard corporativo genérico

- interface gamer/neon

Quero a sensação de um produto SaaS educacional premium.

A personalidade forte e colorida da logo deve contrastar com uma interface muito limpa.

==================================================

5. CORES DA INTERFACE

==================================================

Utilize modo claro como padrão.

Background:

off-white muito suave ou branco.

Surfaces:

branco.

Texto principal:

preto ou grafite muito escuro.

Texto secundário:

cinza neutro.

Borders:

cinza muito claro e discreto.

Utilize o verde ClinicaVerso principalmente para:

- CTA principal

- estado ativo

- links selecionados

- progressos

- pequenos indicadores

- ícones ativos

- focus states

- detalhes da marca

NÃO transforme toda a interface em verde.

NÃO utilize grandes blocos verdes sem necessidade.

Utilize gradientes apenas em elementos especiais.

Evite excesso de sombras.

Prefira bordas sutis, espaço negativo e hierarquia tipográfica.

==================================================

6. DESIGN SYSTEM

==================================================

Antes de construir os componentes, estabeleça um design system consistente.

Crie tokens semânticos para:

--background

--surface

--surface-secondary

--text-primary

--text-secondary

--text-muted

--border

--border-strong

--brand-primary

--brand-primary-hover

--brand-primary-soft

--success

--warning

--error

Também prepare tokens específicos para produtos:

--product-cards

--product-cards-soft

Estruture também:

- typography scale

- spacing scale

- border radius

- shadows

- icon sizing

- container widths

Utilize componentes reutilizáveis.

==================================================

7. TIPOGRAFIA

==================================================

A logo possui tipografia própria e expressiva.

Não tente utilizar a tipografia da logo na interface.

Utilize uma sans-serif contemporânea, limpa e extremamente legível para a UI.

A tipografia deve transmitir:

precisão

modernidade

clareza

sofisticação

Utilize poucos pesos tipográficos.

Crie boa hierarquia entre:

- page title

- section title

- body

- caption

- labels

- métricas

==================================================

8. ESTRUTURA DA APLICAÇÃO

==================================================

Neste primeiro protótipo, crie:

1. Login

2. Dashboard principal do aluno

3. Estrutura inicial do ClinicaVerso Cards

4. Estrutura do painel administrativo

Não desenvolva ainda todas as funcionalidades internas.

==================================================

9. LOGIN

==================================================

Crie uma tela de login extremamente limpa.

Utilize a logo oficial ClinicaVerso.

Campos:

E-mail

Senha

CTA:

"Entrar"

Adicionar:

"Esqueci minha senha"

Não é necessário criar uma landing page comercial neste momento.

A experiência deve parecer entrada em uma plataforma premium.

==================================================

10. LAYOUT DA ÁREA LOGADA

==================================================

Desktop-first, mas totalmente responsivo.

Utilize sidebar lateral.

No topo da sidebar, utilize a identidade ClinicaVerso.

Preferencialmente utilize uma versão compacta da marca quando necessário.

Itens:

Início

PRODUTOS

- Cards

- Revisões

- Aulas

OUTROS

- Desempenho

- Perfil

Na parte inferior:

avatar

nome do usuário

menu de conta

Exemplo:

Nícolas

Aluno

Permitir sidebar recolhida no desktop.

Quando recolhida, utilizar ícones e/ou símbolo da marca.

No mobile, adaptar a navegação adequadamente.

Não simplesmente comprimir a sidebar.

==================================================

11. DASHBOARD PRINCIPAL

==================================================

Esta deve ser a principal tela criada neste primeiro momento.

Quero um dashboard muito limpo.

Header:

"Olá, Nícolas."

"Vamos continuar seus estudos?"

Evite frases motivacionais genéricas.

Logo abaixo, criar uma seção:

"Seus produtos"

Apresentar três cards:

CLINICAVERSO CARDS

Produto ativo.

Utilizar discretamente azul/ciano como accent do produto.

Mostrar uma pequena informação de progresso e CTA:

"Continuar estudando"

CLINICAVERSO REVISÕES

Status:

"Em breve"

CLINICAVERSO AULAS

Status:

"Em breve"

Os cards devem ser sofisticados e minimalistas.

Não utilizar grandes gradientes coloridos nos cards.

==================================================

12. CONTINUAR ESTUDANDO

==================================================

Após os produtos, criar uma seção com prioridade visual:

"Continuar estudando"

Exemplo de conteúdo mockado:

Clínica Médica

Cardiologia

Síndrome Coronariana Aguda

12 cards pendentes

CTA:

"Continuar revisão"

Essa área deve ser visualmente simples e imediatamente compreensível.

==================================================

13. RESUMO DE ESTUDOS

==================================================

Criar uma pequena seção de métricas.

Exemplos:

Cards estudados

248

Revisões hoje

18

Sequência

7 dias

Progresso geral

42%

Não transformar isso em um dashboard cheio de gráficos.

Preferir números grandes, pequenos labels e visual limpo.

==================================================

14. CLINICAVERSO CARDS

==================================================

Ao clicar em Cards, criar uma página inicial simples do produto.

Header:

ClinicaVerso Cards

R1CM

Adicionar identificação visual discreta azul/ciano.

Mostrar:

- Cards para hoje

- Novos cards

- Revisões pendentes

- Progresso geral

CTA principal:

"Começar revisão"

Criar navegação interna preparada para:

- Estudar

- Baralhos

- Revisões

- Favoritos

- Desempenho

Neste primeiro momento, não implemente algoritmo complexo de repetição espaçada.

Crie apenas a estrutura visual e de navegação.

==================================================

15. PAINEL ADMINISTRATIVO

==================================================

Criar uma área administrativa separada da experiência do aluno.

Ela deve possuir rota/layout próprios.

Preparar arquitetura para dois tipos de usuário:

student

admin

Somente admin pode acessar o painel administrativo.

IMPORTANTE:

Não proteja o painel apenas escondendo links da interface.

A arquitetura deve prever autorização real baseada na role do usuário.

Para este protótipo, pode utilizar autenticação/dados mockados caso backend ainda não esteja configurado.

==================================================

16. ADMIN DASHBOARD

==================================================

Criar sidebar administrativa própria.

Itens:

Dashboard

Flashcards

Organização

Usuários

Métricas

O dashboard administrativo pode mostrar:

Total de flashcards

Publicados

Rascunhos

Arquivados

Usuários

Também criar CTA:

"+ Novo flashcard"

==================================================

17. FLASHCARDS — ESTRUTURA DE DADOS

==================================================

Prepare a arquitetura conceitual dos flashcards seguindo:

Especialidade

Tema

Subtema

Flashcard

Exemplo:

Clínica Médica

Cardiologia

Síndrome Coronariana Aguda

Flashcard

Cada flashcard deve estar preparado para conter:

- pergunta

- resposta

- explicação

- especialidade

- tema

- subtema

- tags

- dificuldade

- referência

- autor

- status

- data de criação

- data de atualização

Status:

draft

published

archived

Não é necessário implementar toda a persistência agora caso ainda não exista backend.

==================================================

18. TELA "NOVO FLASHCARD"

==================================================

Criar um protótipo funcional da tela administrativa.

Campos:

Especialidade

Tema

Subtema

Pergunta

Resposta

Explicação

Tags

Dificuldade:

- Fácil

- Média

- Difícil

Referência

Status:

- Rascunho

- Publicado

Ações:

"Salvar rascunho"

"Publicar"

A interface deve ser otimizada para alguém que criará muitos flashcards.

Evite formulários visualmente pesados.

==================================================

19. RESPONSIVIDADE

==================================================

A aplicação deve funcionar adequadamente em:

desktop

notebook

tablet

smartphone

Desktop é a experiência principal.

No mobile, reorganize os componentes.

Não apenas reduza tudo proporcionalmente.

==================================================

20. ACESSIBILIDADE

==================================================

Garanta:

- contraste adequado

- focus states

- labels nos inputs

- navegação por teclado

- áreas clicáveis adequadas

- hierarquia semântica

- feedback visual de ações

Não dependa exclusivamente da cor para comunicar estados.

==================================================

21. IMPORTANTE PARA ESTE PRIMEIRO BUILD

==================================================

Priorize:

1. identidade visual

2. arquitetura

3. dashboard principal

4. navegação

5. componentes reutilizáveis

6. responsividade

7. estrutura inicial do admin

NÃO tente construir neste momento:

- algoritmo avançado de repetição espaçada

- pagamentos

- assinatura

- gamificação complexa

- ranking

- IA

- notificações complexas

- analytics avançado

- landing page comercial extensa

Use dados mockados apenas para demonstrar a experiência.

Quero primeiro validar visualmente a fundação do produto.

O resultado deve parecer um software real em estágio inicial, e não uma coleção de telas desconectadas.

This project was built with [Lovable](https://lovable.dev).

## Build with Lovable

Continue developing this project in the [Lovable editor](https://lovable.dev/projects/e117972f-eab7-44ed-b08b-441b4e37e3a4).

- **Ship faster**: describe what you want to build and Lovable handles the code.
- **Stay in sync**: every change made in Lovable is committed straight to this repository.
- **Full ownership**: this code is yours. Push to `main` on GitHub and your changes sync back into Lovable, ready for your next prompt.

## Development

Prefer working locally? You need Node.js and npm — [install with nvm](https://github.com/nvm-sh/nvm#installing-and-updating).

```sh
git clone <this-repository-url>
cd <repository-name>
npm i
npm run dev
```
