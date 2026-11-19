# TerlineT BubblesChain

Aplicativo TerlineT BubblesChain com o jogo Bubbles Tetris e o Coordenar, um
desafio de encaixe de formas em uma ilha voxel/isométrica. O controle por mãos
usa gestos de pinça na versão Web. Cada fase troca o cenário entre deserto,
floresta, montanhas nevadas e vulcão, com cores e elementos próprios.

## Executar

```shell
flutter pub get
flutter run -d chrome
```

Para usar a câmera, abra a versão Web em `localhost` ou em um endereço HTTPS e
permita o acesso quando o navegador solicitar. A detecção de mãos usa MediaPipe
carregado do jsDelivr; portanto, requer conexão com a internet.

Ao abrir o app, uma voz em português apresenta a navegação por gestos. A voz
feminina é selecionada quando disponível no dispositivo; use o botão de áudio
para ouvir as instruções novamente. Na tela inicial, ative o ícone de mão e
permita o acesso à câmera; aponte e empurre o indicador para clicar nas bolhas.
Os gestos de navegação da tela inicial não são enviados para dentro dos jogos.
A tela permanece ativa enquanto o app estiver em primeiro plano e volta a
permitir o bloqueio automático quando o app vai para segundo plano.

No Coordenar, feche a pinça sobre uma peça, mova a mão até o espaço apontado
pela seta e abra a pinça para encaixá-la. Ative a câmera no próprio jogo ou use
mouse e toque.

No Bubbles Tetris, mantenha a pinça fechada para mover a peça, suba a mão para
girá-la e abra a pinça para encaixá-la. As peças não descem sozinhas; os
controles na tela também podem ser usados. Ative a câmera no próprio jogo.

No Android, o jogo funciona com controles de toque; o rastreamento por câmera
está disponível somente na versão Web.

## Recursos

- `assets/videos/BubblesChain.mp4`: vídeo de fundo da tela inicial.
- `assets/videos/pengu-pudgy.gif`: animação da tela inicial.
- `assets/videos/TerlineT_Video_*.webm`: vídeo clips acessíveis pela bolha
  “Links Úteis” na tela inicial.
