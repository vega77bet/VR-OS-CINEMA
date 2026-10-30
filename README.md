# VR-OS Cinema · Sala Aurora

Aplicativo iOS independente. Esta primeira etapa é a **sala 3D visual**: arquitetura,
poltronas originais Orion, telão curvo e iluminação de início de sessão.

## O que esta versão entrega

- Sala em escala de metros com 42 poltronas em seis fileiras elevadas.
- Poltronas azul-petróleo, casco grafite, inserto matelassê, acabamento de cobre,
  apoio lombar, descanso de pernas e dois porta-copos com aro iluminado.
- Telão curvo de 19,6 × 7,6 m; a curvatura faz parte da malha 3D.
- Painéis acústicos, frisos, teto pontilhado e dois corredores com degraus luminosos.
- Prévia de sessão de 3,6 segundos: frente, teto e laterais escurecem em sequência.
  Os guias dos degraus permanecem visíveis. A transição pode ser revertida durante o movimento.
- Vistas da poltrona, sala e detalhe Orion; movimento de cabeça pelo giroscópio no iPhone,
  arraste como fallback, toque para ocultar/mostrar controles.
- Botão Altura alterna a elevação do observador; Centralizar retorna ao ponto inicial.
- Prévia binocular com câmeras paralelas separadas por 64 mm e HUD dentro de cada olho.
- No modo VR Box, o celular acompanha yaw, pitch e roll (3DoF), e o botão Centralizar
  define a direção atual como frente.
- Texturas e arte Aurora originais geradas em código, funcionamento inteiramente offline.
- Ícone próprio, respeito a Reduzir Movimento e renderização sob demanda: a sala
  estática não mantém um relógio de animação ativo. O render também para ao sair do aplicativo.

## Limites desta etapa

O botão Iniciar sessão demonstra o escurecimento e troca a arte do telão. **Ainda não
reproduz filmes.** Câmera, Joy-Con, seleção por olhar, calibração óptica/distorção das
lentes e ajustes de distância entre olhos ficam para a próxima etapa funcional. O
movimento implementado é rotacional (3DoF): o VR Box não fornece deslocamento físico
pela sala. O alinhamento e o conforto dependem de validação no aparelho real.

## Compilar

Requisitos: macOS, Xcode 16.4 e XcodeGen. Deployment target iOS 16.

```sh
swift Tools/MakeIcon.swift
xcodegen generate
xcodebuild -project VROSCinema.xcodeproj -scheme VROSCinema \
  -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
```

O workflow `Cinema - build and native visual tests` compila o app para iPhone,
roda testes de geometria, luzes e interface no simulador e exporta cinco vistas
usando **a mesma CinemaScene do aplicativo**. As prévias não são imagens conceituais.
O IPA só é empacotado se build, testes e exportação passarem. Ele não é assinado;
a instalação exige assinatura por uma ferramenta apropriada, como SideStore.

## Validação da prévia 0.1.1 (build 2)

[Execução aprovada](https://github.com/vega77bet/VR-OS-CINEMA/actions/runs/40980378056),
referente ao código `681a66afbd6da2f75aafd7948820cbffc0b5017e`:
build Release para iPhone, oito testes nativos e um teste de navegação completos,
sem falhas no simulador iPhone 16. A validação cobre o mapeamento de movimento
nos dois landscapes, a pose 3DoF e o fallback de toque do simulador, além de
preservar o horizonte, verificar os controles e a separação entre os dois olhos.

As capturas `full-display` do artefato de interface mostram a tela completa.
O recorte de `XCUIApplication.screenshot()` pode ficar incorreto em paisagem;
para revisão visual, usar as capturas de `XCUIScreen.main` (`full-display`).
Essa limitação do arquivo de captura não é um recorte do aplicativo.

## Organização

- `Cinema/CinemaScene.swift`: sala, luzes, telão e câmeras.
- `Cinema/ChairFactory.swift`: geometria original das poltronas.
- `Cinema/Materials.swift`: materiais e texturas procedurais.
- `Cinema/VisualState.swift`: escala e transições reversíveis.
- `Cinema/HeadMotion.swift`: Core Motion, calibração e mapeamento landscape para 3DoF.
- `Cinema/CinemaViewController.swift`: render, ciclo de vida, movimento e navegação visual.
- `Cinema/CinemaHUD.swift`: controles de prévia, com versão por olho.
- `Cinema/SceneDelegate.swift`: janela vinculada à cena e dimensionamento em paisagem.
- `Tests/` e `UITests/`: verificações e galeria nativa.

## Verificação no aparelho

Depois do CI, conferir visual no iPhone e dentro do VR Box, legibilidade dos
controles, altura do observador, recorte do telão, estabilidade térmica após uma
sessão longa e consumo de bateria. Build/testes de simulador não comprovam esses
resultados. Nenhuma versão recebe garantia de zero bugs.
