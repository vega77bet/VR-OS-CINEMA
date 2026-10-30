# VR-OS Cinema · Sala Aurora

Aplicativo iOS independente para VR Box: sala Aurora, poltronas Orion, telão
curvo e reprodução local 2D/3D estereoscópica. Versão 0.2.0, build 4.

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
- Botão Filme: escolhe um vídeo do app Arquivos, projeta-o no telão curvo nos dois
  olhos e permite reproduzir/pausar com áudio pelo próprio iPhone.
- 3D: Half/Full SBS e Half/Full cima-baixo, recorte independente por olho,
  troca dos olhos, proporção original ou manual e pequeno ajuste de alinhamento.
- Um AVPlayerItemVideoOutput fornece o mesmo frame Metal aos dois materiais;
  as câmeras usam máscaras exclusivas para evitar vazamento entre olhos.
- Barra de progresso, saltos de 10 segundos, volume, repetição após o fim,
  substituição/fechamento de filme e tratamento de erros e interrupções de áudio.
- Clássico, Portal (telão 10% maior), Sala escura, luz ambiente suave baseada
  na cor real dos frames, telão plano/curvo, brilho, distância e IPD de 58–72 mm.
- Teste 3D original de 30 segundos gerado por projeção estereoscópica no build.
- A sugestão de formato usa tags explícitas do nome (FSBS, HSBS, HOU etc.);
  arquivos sem indicação abrem em 2D e pedem confirmação manual em Filme e 3D.
- Texturas e arte Aurora originais geradas em código, funcionamento inteiramente offline.
- Ícone próprio, respeito a Reduzir Movimento e renderização sob demanda: a sala
  estática não mantém um relógio de animação ativo. O render também para ao sair do aplicativo.

## Limites desta etapa

O botão Iniciar sessão demonstra o escurecimento quando não há filme carregado. O
player atual reproduz vídeos locais escolhidos pelo app Arquivos; ele ainda não baixa
catálogo pela internet nem implementa streaming. Câmera, Joy-Con, seleção por olhar,
calibração óptica/distorção das lentes ficam para outra etapa. O
movimento implementado é rotacional (3DoF): o VR Box não fornece deslocamento físico
pela sala. O alinhamento e o conforto dependem de validação no aparelho real.

O 3D vem das duas perspectivas gravadas no arquivo. Este player não converte
filmes 2D para 3D, não decodifica discos Blu-ray MVC/ISO e não acrescenta
objetos/partículas à cena do filme. O quanto algo parece sair da tela depende
da estereoscopia da fonte. Formatos/4K/HDR dependem da decodificação do iPhone;
a saída atual solicita SDR do AVFoundation, sem promessa de HDR nativo.

Para usar: Filme e 3D → Abrir filme em Arquivos (ou Teste 3D) → confirmar formato
→ Concluir → Reproduzir → colocar no VR Box e Centralizar. Os ajustes de filme
são feitos no telefone; seleção por olhar/controle ainda não está implementada.

## Compilar

Requisitos: macOS, Xcode 16.4 e XcodeGen. Deployment target iOS 16.

```sh
swift Tools/MakeIcon.swift
swift Tools/MakeDemo.swift
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

## Verificação automática

O CI compila Release para iPhone e executa testes de geometria/iluminação,
renderização de cada olho com amostras de cor SBS/OU e olhos invertidos,
proporção, orientação, cancelamento de carregamento, arquivo inválido,
decodificação real da demonstração, pausa, busca, fim/replay e navegação UIKit.
As execuções e evidências ficam em GitHub Actions; um build compilado sozinho
não comprova a reprodução ou o conforto no hardware.

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
- `Cinema/MoviePlayer.swift`: AVFoundation, áudio e frames Metal compartilhados.
- `Cinema/VideoProjection.swift`: layouts, recortes, orientação e proporção.
- `Cinema/MovieSettingsViewController.swift`: arquivo, formato e ajustes do cinema.
- `Tools/MakeDemo.swift`: demonstração estereoscópica original, sem assets externos.
- `Cinema/SceneDelegate.swift`: janela vinculada à cena e dimensionamento em paisagem.
- `Tests/` e `UITests/`: verificações e galeria nativa.

## Verificação no aparelho

Depois do CI, conferir visual no iPhone e dentro do VR Box, legibilidade dos
controles, altura do observador, recorte do telão, estabilidade térmica após uma
sessão longa e consumo de bateria. Build/testes de simulador não comprovam esses
resultados. Nenhuma versão recebe garantia de zero bugs.
