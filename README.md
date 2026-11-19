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
para ouvir as instruções novamente. Ative o ícone de mão na tela inicial e
permita o acesso à câmera: depois disso, aponte e empurre o indicador para
clicar ou feche a pinça para clicar, segurar e mover. O cursor acompanha a mão
em todas as telas.

No Coordenar, feche a pinça sobre uma peça, mova a mão até o espaço apontado
pela seta e abra a pinça para encaixá-la. Também é possível usar mouse ou toque.

No Bubbles Tetris, mantenha a pinça fechada para mover a peça, suba a mão para
girá-la e abra a pinça para encaixá-la. As peças não descem sozinhas; os
controles na tela também podem ser usados.

No Android, o jogo funciona com controles de toque; o rastreamento por câmera
está disponível somente na versão Web.

## Recursos

- `assets/videos/BubblesChain.mp4`: vídeo de fundo da tela inicial.
- `assets/videos/pengu-pudgy.gif`: animação da tela inicial.
- `assets/videos/TerlineT_Video_*.webm`: vídeo clips acessíveis pela bolha
  “Links Úteis” na tela inicial.
