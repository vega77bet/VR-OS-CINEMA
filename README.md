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
- Vistas da poltrona, sala e detalhe Orion; arraste para olhar, toque para ocultar/mostrar controles.
- Botão Altura alterna a elevação do observador; Centralizar retorna ao ponto inicial.
- Prévia binocular com câmeras paralelas separadas por 64 mm e HUD dentro de cada olho.
- Texturas e arte Aurora originais geradas em código, funcionamento inteiramente offline.
- Ícone próprio, respeito a Reduzir Movimento e suspensão do render ao sair do aplicativo.

## Limites desta etapa

O botão Iniciar sessão demonstra o escurecimento e troca a arte do telão. **Ainda não
reproduz filmes.** Câmera, Joy-Con, rastreamento da cabeça, seleção por olhar,
calibração óptica/distorção das lentes e ajustes de distância entre olhos ficam
para a próxima etapa funcional. A visão binocular atual é uma prévia visual por toque.
O alinhamento e o conforto no VR Box dependem de validação no aparelho real.

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

## Organização

- `Cinema/CinemaScene.swift`: sala, luzes, telão e câmeras.
- `Cinema/ChairFactory.swift`: geometria original das poltronas.
- `Cinema/Materials.swift`: materiais e texturas procedurais.
- `Cinema/VisualState.swift`: escala e transições reversíveis.
- `Cinema/CinemaViewController.swift`: render, ciclo de vida e navegação visual.
- `Cinema/CinemaHUD.swift`: controles de prévia, com versão por olho.
- `Tests/` e `UITests/`: verificações e galeria nativa.

## Verificação no aparelho

Depois do CI, conferir visual no iPhone e dentro do VR Box, legibilidade dos
controles, altura do observador, recorte do telão, estabilidade térmica após uma
sessão longa e consumo de bateria. Build/testes de simulador não comprovam esses
resultados. Nenhuma versão recebe garantia de zero bugs.
