# Refinamento visual do ClinicaVerso

## Objetivo
Polir a interface existente para que pareça um produto SaaS educacional médico premium, preservando a arquitetura, as rotas, as funcionalidades e a identidade minimalista em preto, branco, cinzas e verde ClinicaVerso.

## Escopo de implementação

### 1. Estrutura global e navegação
- Refinar a sidebar preta existente: reduzir discretamente largura e logo, ajustar alinhamentos, ritmo vertical e espaçamento entre grupos.
- Manter somente a rota atual com fundo destacado; itens inativos ficam transparentes e secundários.
- Preservar os badges pequenos de “Em breve” em Revisões e Aulas, sem transformar esses itens em blocos destacados.
- Manter recolhimento no desktop, drawer no mobile e área do usuário no rodapé, com transições e focos discretos.
- Limitar e centralizar o conteúdo principal em aproximadamente 1280px, com margens responsivas consistentes.
- Simplificar o header mobile e alinhar logo, menu e conteúdo.

### 2. Dashboard e hierarquia
- Reduzir o espaço vertical após “Olá, Nícolas.” e manter a saudação existente.
- Reordenar o conteúdo para: saudação → Continuar estudando → Seus produtos → Resumo de estudos.
- Dar prioridade ao card horizontal de continuidade, preservando especialidade, tema, pendências e CTA.
- Incluir uma barra fina de progresso, com detalhe verde sutil e sem gradientes.

### 3. Produtos
- Criar cards compactos em 3 colunas no desktop, 2 no tablet e 1 no mobile.
- Restaurar o nome correto “ClinicaVerso Revisões” e os textos solicitados para os três produtos.
- Exibir ícone, nome, descrição, status e ação apenas quando disponível.
- No Cards, apresentar status “Ativo”, progresso de 42% e CTA “Acessar”; manter Revisões e Aulas como “Em breve”.
- Eliminar alturas mínimas e espaços vazios desnecessários.

### 4. Métricas e consistência compartilhada
- Transformar o resumo em quatro cards pequenos: Cards estudados, Revisões hoje, Sequência e Progresso R1CM.
- Preservar os números atuais e adicionar apenas a barra fina informativa no progresso.
- Refinar o componente compartilhado de métricas para que a página Desempenho e as telas administrativas permaneçam visualmente consistentes, sem novos gráficos ou analytics.
- Aplicar bordas suaves, raio discreto, fundos neutros e estados interativos leves nos elementos relevantes.

### 5. Design system e interações
- Consolidar os tokens semânticos `brand-primary`, `brand-primary-hover` e `brand-primary-soft` já existentes, ajustando seu uso consistente.
- Refinar superfícies, bordas, contraste, foco e feedback de clique sem cores fixas nos componentes.
- Manter sombras mínimas, sem glassmorphism, glow ou gradientes pesados.
- Respeitar redução de movimento e garantir áreas de toque confortáveis no mobile.

## Validação
- Conferir desktop, tablet e mobile, incluindo sidebar aberta/recolhida e menu móvel.
- Verificar que nenhuma rota ou funcionalidade existente foi removida.
- Validar dashboard, Desempenho e uma tela administrativa para confirmar consistência dos componentes compartilhados.
- Confirmar ausência de sobreposição, cortes de texto, tela branca e erros no console.

## Detalhes técnicos
- Alterações concentradas no shell compartilhado, dashboard, componentes de cabeçalho/métrica, botão e tokens globais.
- Nenhuma mudança de banco de dados, autenticação, regras de acesso, arquitetura de rotas ou lógica dos produtos.
