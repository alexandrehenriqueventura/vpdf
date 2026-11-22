# vpdf — Leitor, Editor e Conversor de Arquivos PDF para macOS

<p align="center">
  <img src="Sources/vpdf/Resources/AppIcon.png" width="128" height="128" alt="vpdf App Icon">
</p>

<p align="center">
  <a href="https://github.com/alexandrehenriqueventura/vpdf/actions/workflows/ci.yml">
    <img src="https://github.com/alexandrehenriqueventura/vpdf/actions/workflows/ci.yml/badge.svg" alt="CI Status">
  </a>
  <a href="https://github.com/alexandrehenriqueventura/vpdf/releases/latest">
    <img src="https://img.shields.io/github/v/release/alexandrehenriqueventura/vpdf?color=007AFF&label=Download%20v1.1.0" alt="Download Release">
  </a>
  <img src="https://img.shields.io/badge/macOS-14.0%2B-000000?logo=apple" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-5.9%2B-FA7343?logo=swift" alt="Swift 5.9+">
  <img src="https://img.shields.io/badge/License-MIT-green" alt="MIT License">
</p>

<p align="center">
  <b>Aplicativo nativo para macOS (14.0+ Sonoma / Sequoia) desenvolvido em Swift 5.9+ e SwiftUI.</b><br>
  Leitor e editor de PDFs focado em agilidade, navegação hierárquica por pastas, organização e compressão de páginas e conversão de documentos com estética limpa inspirada nas diretrizes de design do macOS (<i>Apple Human Interface Guidelines</i>).
</p>

<p align="center">
  👉 <b><a href="https://github.com/alexandrehenriqueventura/vpdf/releases/download/v1.1.0/vpdf-macos.zip">Baixar Versão Pré-compilada (macOS 14+ Sonoma / Sequoia)</a></b> 👈<br>
  🍏/💻 <b><a href="./vpdf-universal-macos13.zip">Baixar Versão Universal (macOS 13+ Ventura / Intel & Apple Silicon)</a></b>
</p>

---

## ⚡️ Instalação Rápida (Sem Compilar)

Escolha a versão correspondente ao seu sistema:
- **macOS 14+ (Sonoma / Sequoia - Apple Silicon):** Baixe o **[vpdf-macos.zip](https://github.com/alexandrehenriqueventura/vpdf/releases/download/v1.1.0/vpdf-macos.zip)** na aba de Releases ou utilize o arquivo `vpdf.app` gerado.
- **macOS 13+ (Ventura / Sonoma / Sequoia - Macs Intel e Apple Silicon):** Baixe o arquivo **[`vpdf-universal-macos13.zip`](./vpdf-universal-macos13.zip)** disponível diretamente no repositório.

1. Dê um duplo clique para descompactar o arquivo **`vpdf.app`**.
2. Arraste para a sua pasta **Aplicativos** (`/Applications`) e abra!

> **Dica para o primeiro acesso (macOS Gatekeeper):**
> Por se tratar de um app de código aberto com assinatura local (*ad-hoc*), se o macOS mostrar o aviso de desenvolvedor não identificado, basta clicar com o **botão direito (ou Control + Clique)** sobre o `vpdf.app`, escolher **"Abrir"** e confirmar em **"Abrir"**.

---

## 📸 Capturas de Tela

<p align="center">
  <b>1. Tela Inicial e Ações Rápidas</b><br>
  <i>Ponto de partida do aplicativo: interface limpa com opções diretas para abrir pastas no disco, converter documentos Word (.docx) para PDF e atalhos de navegação.</i><br><br>
  <img src="docs/screenshots/tela-inicial.png" alt="Tela Inicial do vpdf com opções de abertura e conversão" width="850">
</p>

<p align="center">
  <b>2. Navegação Ágil com Árvore de Diretórios Hierárquica</b><br>
  <i>Localização instantânea de documentos através da barra lateral inteligente com filtragem automática de PDFs e carregamento preguiçoso (lazy loading).</i><br><br>
  <img src="docs/screenshots/barra-lateral-arvore-diretorios.png" alt="Barra Lateral com Árvore de Diretórios no vpdf" width="850">
</p>

<p align="center">
  <b>3. Visualização com Anotações, Busca Suspensa e Zoom Flutuante</b><br>
  <i>Ferramentas de seleção e marca-texto (realces em 4 cores, sublinhado, cópia), busca suspensa integrada (⌘F) com contador de ocorrências e controle de zoom glassmorphism com paginação precisa.</i><br><br>
  <img src="docs/screenshots/visualizador-pdf.png" alt="Visualizador de PDF no vpdf com anotações, busca e controle de zoom" width="850">
</p>

<p align="center">
  <b>4. Modo Leitura Sem Distrações (Barra Lateral Ocultada)</b><br>
  <i>Foco total no conteúdo: clique no botão nativo no topo esquerdo da janela ou use o atalho <code>⌃⌘S</code> para recolher a barra lateral e expandir a área de leitura.</i><br><br>
  <img src="docs/screenshots/barra-lateral-oculta.png" alt="Área de leitura expandida com barra lateral oculta" width="850">
</p>

<p align="center">
  <b>5. Painel de Miniaturas e Gerenciamento Estrutural de Páginas (Novo na v1.1)</b><br>
  <i>Acesse todas as páginas na gaveta lateral retrátil: gire páginas individuais, exclua páginas indesejadas, reordene e visualize o número da página ativa com sincronização bidirecional.</i><br><br>
  <img src="docs/screenshots/painel-edicao-paginas.jpg" alt="Painel de Miniaturas e Edição de Páginas no vpdf" width="850">
</p>

<p align="center">
  <b>6. Reordenação e Rotação de Páginas com Controle Total (Novo na v1.1)</b><br>
  <i>Reorganize páginas em tempo recorde utilizando os botões de subir (▲) e descer (▼), menu de contexto (clique direito) ou arrastando e soltando (Drag & Drop) as miniaturas diretamente.</i><br><br>
  <img src="docs/screenshots/reordenacao-e-rotacao-miniaturas.jpg" alt="Controles de Reordenação e Rotação de Páginas" width="400">
</p>

<p align="center">
  <b>7. Compressão Inteligente de Arquivos PDF (Novo na v1.1)</b><br>
  <i>Reduza o tamanho de PDFs para envio por e-mail ou armazenamento em disco com 3 níveis de otimização (Leve, Equilibrada e Forte), estimativa visual em tempo real e opção de substituir ou exportar uma cópia.</i><br><br>
  <img src="docs/screenshots/compressao-pdf.jpg" alt="Modal de Compressão Inteligente de PDF" width="850">
</p>

---

## ✨ Principais Funcionalidades

### 🛠️ Edição e Organização de PDFs (Novidades da v1.1)
- **Gaveta Lateral de Miniaturas de Páginas (`⌥⌘T`)**:
  - Exibe a lista visual de todas as páginas do PDF com indicador de seleção e número da página em tempo real.
  - Sincronização bidirecional com o leitor: clicar em uma miniatura navega instantaneamente para a página correspondente.
- **Reordenação Flexível de Páginas (3 Modos)**:
  - **Botões Rápidos no Card**: Suba (`▲`) ou desça (`▼`) qualquer página com apenas um clique.
  - **Arrastar e Soltar (*Drag & Drop*)**: Reorganize a ordem simplesmente arrastando as miniaturas para a posição desejada.
  - **Menu de Contexto Completo**: Clique com o botão direito para *Mover para Cima* (`⌥↑`), *Mover para Baixo* (`⌥↓`), *Mover para o Início (1ª Página)* ou *Mover para o Fim (Última Página)*.
- **Rotação de Páginas Individuais**:
  - Gire páginas selecionadas em passos de 90° no sentido horário ou anti-horário diretamente no card da miniatura ou pelo menu contextual.
- **Exclusão Segura de Páginas**:
  - Remova páginas desnecessárias com diálogo de confirmação seguro (`NSAlert`), evitando exclusões acidentais.
- **Compressão Inteligente de Arquivos PDF**:
  - Otimização automática do peso de arquivos mantendo a legibilidade tipográfica:
    - **Leve (~150 DPI):** Compressão sutil ideal para impressão de alta qualidade.
    - **Equilibrada (~120 DPI - Recomendada):** Excelente equilíbrio visual e ótima redução para e-mails e visualização em tela.
    - **Forte (~90 DPI):** Máxima compressão para PDFs muito pesados ou arquivamento.
  - Estimativa imediata do tamanho resultante antes de processar.
  - Escolha entre **Substituir o Arquivo Atual** ou **Exportar Nova Cópia**.
- **Salvar Alterações Diretamente (`⌘S`)**:
  - Indicador de alterações pendentes (*isDirty*) com bolinha de status na aba e na barra superior.
  - Salvamento nativo que preserva a estrutura vetorial, notas, anotações e metadados do PDF.

---

### 📖 Leitura e Produtividade
- **Modo Apresentação em Tela Cheia (Slides e Apresentações)**:
  - Modo dedicado para apresentações com exibição em **Página Única (`.singlePage`)**, eliminando rolagens contínuas e respeitando rigorosamente a quebra de cada slide.
  - O slide é automaticamente centralizado e ajustado à tela cheia (`autoScales = true`) com fundo imersivo.
  - Navegação nativa via teclado: Setas (← e →), Espaço e Page Up / Page Down.
  - Painel flutuante discreto com indicador de slide (**`Slide 3 de 20`**), navegação e atalho `Esc` para retornar ao modo padrão.
  - Atalho rápido: **`⇧⌘F`** ou botão na barra superior.
- **Ferramenta de Busca Avançada Integrada**:
  - Barra de busca suspensa moderna (estilo Safari e Pré-Visualização do macOS) acionada por **`⌘F`**.
  - Contador de resultados em tempo real (ex.: **`3 de 15`** ou aviso visual caso não haja ocorrências).
  - Navegação entre ocorrências via botões Anterior (↑) e Próxima (↓) ou teclas `Enter` e `Shift+Enter`.
  - Destaque colorido imediato de todas as ocorrências na página e rolagem suave até a seleção ativa.
- **Barra de Ferramentas de Seleção e Marca-Texto (Anotações)**:
  - Ferramenta de anotação com **Realce em 4 Cores** (Amarelo, Verde, Azul e Rosa), criando marcações nativas no PDF (`PDFAnnotation` persistível).
  - Ferramentas usuais de texto: **Sublinhar**, **Tachar**, **Copiar seleção (`⌘C`)** e **Remover realces**.
  - Acionada pelo botão de marca-texto na barra superior.
- **Menu de Botão Direito (Context Menu) 100% em Português do Brasil**:
  - Subclasse customizada do `PDFView` com tradução completa de todos os comandos do AppKit para pt-BR: *Copiar*, *Selecionar Tudo*, *Página Única (Slide)*, *Rolagem Contínua*, *Ajustar à Janela*, *Realçar com Cor*, *Sublinhar*, *Tachar*, *Consultar no Dicionário*, entre outros.
- **Visualizador Nativo de PDF (PDFKit) com Barra de Zoom e Paginação Elegante**:
  - Renderização vetorial cristalina com suporte a páginas contínuas, zoom fluído e seleção de texto nativa do macOS.
  - **Barra de Zoom e Paginação Flutuante (Glassmorphism)**: Controle em cápsula translúcida (`.ultraThinMaterial`) com:
    - Indicador dinâmico de página atual e total (ex: **`1 de 100`**) em tipografia tabular monospaçada (`monospacedDigit()`), perfeitamente integrado sem deformar o design da barra.
    - Botões de zoom in/out (`⌘+` / `⌘-`), slider contínuo de escala, menu de escalas rápidas (50%, 75%, 100%, 150%, 200%, 300%) e botão de ajuste automático à largura da janela (`⇧⌘0`).
  - Rolagem suave com alta performance, mesmo em documentos com centenas de páginas.
- **Conversão Avançada de PDF para Word (.docx e .doc) Preservando Formatação**:
  - Ao converter de PDF para Word, o motor do `vpdf` extrai a árvore tipográfica rica de cada página (`PDFPage.attributedString`), preservando **tamanhos de fonte originais (títulos, subtítulos, corpo), pesos (negrito/itálico), cores de texto e separação de parágrafos**, sem achatar o conteúdo para texto puro.
  - Normalização inteligente de fontes de sistema para fontes padrão de mercado (como Helvetica/Arial) para total compatibilidade com o Microsoft Word em qualquer plataforma.
- **Conversor Nativo de Documentos Word (.docx e .doc) para PDF**:
  - Conversão instantânea de arquivos Microsoft Word (`.docx` e `.doc`) diretamente para `.pdf` paginado em padrão A4 via `NSAttributedString` e `CoreText`, sem depender de LibreOffice ou bibliotecas externas.
  - Acessível diretamente pelo botão na barra de ferramentas ou na tela inicial do app.
- **Barra Lateral com Árvore de Diretórios e Ocultação com Um Clique (NavigationSplitView)**:
  - **Localização Instantânea de Documentos:** Listagem hierárquica inteligente filtrada **exclusivamente para arquivos PDF e pastas**, eliminando ruídos visuais de arquivos não suportados.
  - **Carregamento Preguiçoso (*Lazy Loading* Assíncrono):** Acesso ultrarrápido a diretórios com centenas de arquivos, carregando subpastas apenas no momento em que são expandidas.
  - **Botão de Ocultação e Atalho (`⌃⌘S`):** Oculte ou exiba a barra lateral instantaneamente pelo botão nativo na barra de título (canto superior esquerdo) ou pelo atalho de teclado **`⌃⌘S`**.
- **Conversão de Documentos (ConversionService)**:
  - Converte documentos entre múltiplos formatos:
    - **Word (.docx)**: Documento do Microsoft Word gerado nativamente via `officeOpenXML`.
    - **TXT**: Texto simples formatado em UTF-8.
    - **RTF**: Documento com cabeçalho RTF válido (`{\rtf1`) via `NSAttributedString`.
    - **HTML5**: Documento autocontido com CSS tipográfico responsivo (*dark/light mode*).
    - **PDF**: Reexportação paginada no padrão A4 via `CoreText` e `PDFKit`.
- **Barra de Rodapé com Metadados**:
  - Exibe em tempo real o número total de páginas do PDF, quebra de linha (`LF`), contagem de palavras e caracteres, e status de salvamento.
- **App Sandbox e Permissões Persistentes**:
  - Conformidade total com os padrões de segurança da Apple.
  - As autorizações concedidas pelo usuário via `NSOpenPanel` são salvas como *Security-Scoped Bookmarks* no `UserDefaults`, restaurando a pasta aberta automaticamente entre reinicializações do app.

---

## 🏛 Arquitetura e Decisões de Design

- **Padrão MVVM com `@Observable`**: Utiliza o framework moderno `Observation` nativo do Swift 5.9 / macOS 14+, garantindo renderizações cirúrgicas de UI sem a sobrecarga do clássico `ObservableObject`.
- **AppKit onde o SwiftUI é insuficiente**:
  - `PDFViewerRepresentable` encapsula o `PDFView` com controle de busca, escalonamento automático e quebra de páginas.
  - `VPDFView` especializa eventos de clique direito, anotações e contexto em pt-BR.
  - `TextEditorRepresentable` encapsula `NSTextView` para edição rápida e busca incremental.
- **Zero Dependências Externas**: Criado 100% com os frameworks nativos da Apple (`SwiftUI`, `AppKit`, `PDFKit`, `CoreText`, `UniformTypeIdentifiers`).
- **Operações Assíncronas (`async/await`)**: Leitura em disco, decodificação e processamento de arquivos são delegados para threads secundárias (`Task.detached`), mantendo a fluidez da interface a 60/120 fps.

---

## 📁 Estrutura do Projeto

```text
vpdf/
├── Package.swift                    # Configuração SPM (Swift Package Manager)
├── build_app.sh                     # Script de compilação e montagem do vpdf.app
├── run_tests.sh                     # Executor da suíte de testes unitários
├── vpdf.xcodeproj/                  # Projeto nativo configurado para o Xcode
│   └── project.pbxproj
├── Sources/
│   └── vpdf/
│       ├── App.swift                # Ponto de entrada do aplicativo (@main)
│       ├── Models/
│       │   ├── AppError.swift       # Erros de aplicação amigáveis
│       │   ├── ConversionFormat.swift # Formatos suportados (PDF, Word DOCX/DOC, TXT, MD, RTF, HTML)
│       │   └── FileItem.swift       # Modelo de arquivo/pasta na árvore
│       ├── Services/
│       │   ├── FileSystemService.swift # Sandboxing, Bookmarks e navegação em disco
│       │   ├── EncodingService.swift   # Detecção precisa de codificação de texto
│       │   └── ConversionService.swift # Motores de conversão (CoreText, Word DOCX, RTF, HTML5)
│       ├── ViewModels/
│       │   └── AppViewModel.swift   # Estado reativo, orquestração MVVM e mutação de páginas
│       ├── Views/
│       │   ├── ContentView.swift    # NavigationSplitView, Toolbar e área de leitura principal
│       │   ├── VPDFView.swift       # Subclasse PDFView com suporte a pt-BR e anotações
│       │   ├── PDFViewerRepresentable.swift # Ponte SwiftUI para o visualizador vetorial
│       │   ├── PDFThumbnailsSidebar.swift # Gaveta lateral com rotação, reordenação e exclusão
│       │   ├── PDFCompressionSheet.swift # Modal de compressão inteligente de arquivos PDF
│       │   ├── PDFNoteEditorSheet.swift # Editor modal para anotações em notas adesivas
│       │   ├── DocumentTabBar.swift # Barra de abas de múltiplos documentos
│       │   ├── PDFZoomControlBar.swift # Barra flutuante translúcida de zoom e paginação
│       │   ├── PDFSearchBar.swift   # Barra de busca flutuante com contador em tempo real
│       │   ├── PDFAnnotationToolbar.swift # Ferramentas de marca-texto e seleção
│       │   ├── PDFPresentationOverlay.swift # Painel flutuante do modo apresentação
│       │   ├── TextEditorRepresentable.swift # Editor de texto nativo com NSTextView
│       │   ├── EmptyStateView.swift # Tela de boas-vindas com botão de conversão rápida
│       │   ├── FileRowView.swift    # Linha de exibição de itens na barra lateral
│       │   └── StatusBarView.swift  # Rodapé com metadados do documento
│       └── Resources/
│           ├── Info.plist           # Metadados e identificação do bundle macOS
│           └── vpdf.entitlements    # Permissões do App Sandbox
└── Tests/
    ├── TestRunner.swift             # Runner com 23 testes unitários via linha de comando
    └── vpdfTests/
        ├── EncodingServiceTests.swift   # Testes de detecção de codificação
        └── ConversionServiceTests.swift # Testes de conversão, paginação A4 e Word DOCX
```

---

## ⌨️ Atalhos de Teclado Nativos

| Atalho | Ação |
| :--- | :--- |
| **`⌥⌘T`** | Exibir / ocultar gaveta lateral de miniaturas de páginas |
| **`⌥⌘C`** | Abrir diálogo de compressão inteligente de PDF |
| **`⌥↑`** / **`⌥↓`** | Mover página selecionada para cima ou para baixo |
| **`⇧⌘F`** | Alternar Modo Apresentação em Tela Cheia (Slides) |
| **`Esc`** | Sair da Apresentação / Fechar Barra de Busca |
| **`⇧⌘O`** | Abrir nova pasta no disco |
| **`⌘S`** | Salvar alterações estruturais do PDF no arquivo original |
| **`⇧⌘E`** | Exportar documento no formato selecionado |
| **`⌘F`** | Abrir barra de busca flutuante no documento |
| **`↵`** / **`⇧↵`** | Próxima / Anterior ocorrência na busca |
| **`⌃⌘S`** | Recolher / expandir barra lateral de diretórios |
| **`⌘+`** / **`⌘=`** | Aumentar zoom do visualizador de PDF |
| **`⌘-`** | Reduzir zoom do visualizador de PDF |
| **`⌘0`** | Redefinir zoom para o tamanho real (100%) |
| **`⇧⌘0`** | Ajustar zoom automaticamente à largura da janela (*Fit*) |

---

## 🚀 Como Compilar e Executar

### 1. Compilação em 1 Clique (Terminal)
Você pode compilar o código-fonte, montar o pacote macOS e assiná-lo com sandbox executando:

```bash
./build_app.sh
```

Para abrir o aplicativo imediatamente após a compilação:
```bash
open vpdf.app
```
*(Ou dê um duplo clique no arquivo `vpdf.app` no Finder ou na sua Área de Trabalho).*

### 2. Abrindo no Xcode
1. Abra o projeto diretamente com o comando:
   ```bash
   xed .
   # ou
   open vpdf.xcodeproj
   ```
2. Selecione o esquema **`vpdf`** e o destino **`My Mac`**.
3. Pressione `⌘R` para executar com depuração interativa.

### 3. Executando os Testes Unitários
O projeto inclui **23 testes unitários automatizados** validando detecção de codificação, paginação A4 vetorial, reconstrução 2D de tabelas, busca, anotações, rotação e reordenação de páginas:

```bash
./run_tests.sh
```

---

## 📄 Licença
Distribuído sob a licença MIT. Consulte o arquivo de licença para mais informações.
