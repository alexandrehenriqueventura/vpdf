# vpdf — Leitor e Conversor de Arquivos PDF para macOS

<p align="center">
  <b>Aplicativo nativo para macOS (14.0+ Sonoma / Sequoia) desenvolvido em Swift 5.9+ e SwiftUI.</b><br>
  Leitor de PDFs focado em agilidade, navegação hierárquica por pastas e conversão de documentos com estética limpa inspirada nas diretrizes de design do macOS (<i>Apple Human Interface Guidelines</i>).
</p>

---

## ✨ Principais Funcionalidades

- **Visualizador Nativo de PDF (PDFKit)**:
  - Renderização vetorial cristalina com suporte a páginas contínuas, zoom fluído e seleção de texto nativa do macOS.
  - Rolagem suave com alta performance, mesmo em documentos com centenas de páginas.
  - Busca de termos integrada no PDF com salto automático para a primeira ocorrência e destaque de resultados.
- **Barra Lateral com Árvore de Diretórios (NavigationSplitView)**:
  - Listagem inteligente filtrada **exclusivamente para arquivos PDF e pastas**, eliminando ruídos visuais de mídias ou arquivos não suportados.
  - Carregamento preguiçoso (*lazy loading* assíncrono) que carrega o conteúdo de subpastas apenas quando o usuário as expande.
  - Suporte ao atalho nativo do macOS para recolher/expandir a barra lateral (`⌃⌘S`).
- **Conversão de Documentos (ConversionService)**:
  - Converte o conteúdo textual extraído do PDF aberto para outros formatos:
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
│       │   ├── ConversionFormat.swift # Formatos suportados (PDF, TXT, MD, RTF, HTML)
│       │   └── FileItem.swift       # Modelo de arquivo/pasta na árvore
│       ├── Services/
│       │   ├── FileSystemService.swift # Sandboxing, Bookmarks e navegação em disco
│       │   ├── EncodingService.swift   # Detecção precisa de codificação de texto
│       │   └── ConversionService.swift # Motores de conversão (CoreText, RTF, HTML5)
│       ├── ViewModels/
│       │   └── AppViewModel.swift   # Estado reativo e orquestração MVVM
│       ├── Views/
│       │   ├── ContentView.swift    # NavigationSplitView, Toolbar e área de leitura
│       │   ├── PDFViewerRepresentable.swift # Ponte para o PDFView nativo
│       │   ├── TextEditorRepresentable.swift# Ponte para NSTextView
│       │   ├── EmptyStateView.swift # Tela de boas-vindas quando nenhum PDF está aberto
│       │   ├── FileRowView.swift    # Linha de exibição de itens na barra lateral
│       │   └── StatusBarView.swift  # Rodapé com metadados do documento
│       └── Resources/
│           ├── Info.plist           # Metadados e identificação do bundle macOS
│           └── vpdf.entitlements    # Permissões do App Sandbox
└── Tests/
    ├── TestRunner.swift             # Runner de testes via linha de comando
    └── vpdfTests/
        ├── EncodingServiceTests.swift   # Testes de detecção de codificação
        └── ConversionServiceTests.swift # Testes de conversão e paginação A4
```

---

## ⌨️ Atalhos de Teclado Nativos

| Atalho | Ação |
| :--- | :--- |
| **`⇧⌘O`** | Abrir nova pasta no disco |
| **`⌘S`** | Salvar alterações |
| **`⇧⌘E`** | Exportar documento no formato selecionado |
| **`⌘F`** | Buscar termo no documento PDF |
| **`⌃⌘S`** | Recolher / expandir barra lateral |

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
*(Ou dê um duplo clique no arquivo `vpdf.app` no Finder).*

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
O projeto inclui 12 testes unitários automatizados validando codificação e conversão de formatos:

```bash
./run_tests.sh
```

**Resultado esperado:**
```text
========================================
INICIANDO SUÍTES DE TESTES UNITÁRIOS
========================================
▶ Testando EncodingService...
  ✓ testEmptyData passou
  ✓ testUTF8WithoutBOM passou
  ✓ testUTF8WithBOM passou
  ✓ testUTF16LEWithBOM passou
  ✓ testUTF16BEWithBOM passou
  ✓ testWindows1252Encoding passou
  ✓ testISO88591Latin1Encoding passou

▶ Testando ConversionService...
  ✓ testPlainTextConversion passou
  ✓ testRTFConversion passou
  ✓ testHTMLConversion passou
  ✓ testPDFConversion (1 página) passou
  ✓ testMultiPagePDFConversion (9 páginas) passou

========================================
TODOS OS 12 TESTES PASSARAM COM SUCESSO! 🎉
========================================
```

---

## 📄 Licença
Distribuído sob a licença MIT. Consulte o arquivo de licença para mais informações.
