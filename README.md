# TerlineT BubblesChain

Jogo de Tetris em estilo CyberPunk, com peças-bolha, fundo em vídeo e controle
opcional por gestos de mão.

## Executar

```shell
flutter pub get
flutter run -d chrome
```

Para usar a câmera, abra a versão Web em `localhost` ou em um endereço HTTPS e
permita o acesso quando o navegador solicitar. A detecção de mãos usa MediaPipe
carregado do jsDelivr; portanto, requer conexão com a internet. Mantenha uma
pinça entre o polegar e o indicador para mover a peça, suba a mão
para girá-la e abra a pinça para encaixá-la. As peças não descem sozinhas.
Os controles na tela também podem ser usados.

No Android, o jogo funciona com controles de toque; o rastreamento por câmera
está disponível somente na versão Web.

## Recursos

- `assets/videos/BubblesChain.mp4`: vídeo de fundo da tela inicial.
- `assets/videos/pengu-pudgy.gif`: animação da tela inicial.
