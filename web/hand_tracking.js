(() => {
  let cameraStream = null;
  let handDetector = null;
  let frameTimer = null;
  let processingFrame = false;
  let lastPinching = false;
  let callback = null;

  window.bubblesStartHandTracking = async (video, onPose) => {
    if (cameraStream) return;
    if (!navigator.mediaDevices?.getUserMedia) {
      throw new Error('Este navegador não oferece acesso à câmera.');
    }
    if (typeof window.Hands !== 'function') {
      throw new Error('O rastreador de mãos não carregou. Verifique a conexão.');
    }

    callback = onPose;
    cameraStream = await navigator.mediaDevices.getUserMedia({
      audio: false,
      video: {
        facingMode: 'user',
        width: { ideal: 640 },
        height: { ideal: 480 },
        frameRate: { ideal: 24 },
      },
    });

    try {
      video.srcObject = cameraStream;
      await video.play();

      handDetector = new window.Hands({
        locateFile: (file) =>
          `https://cdn.jsdelivr.net/npm/@mediapipe/hands/${file}`,
      });
      handDetector.setOptions({
        maxNumHands: 1,
        modelComplexity: 1,
        minDetectionConfidence: 0.6,
        minTrackingConfidence: 0.5,
      });
      handDetector.onResults((results) => {
        const landmarks = results.multiHandLandmarks?.[0];
        if (!landmarks) {
          lastPinching = false;
          callback?.(-1, 0, false, false);
          return;
        }

        const thumb = landmarks[4];
        const index = landmarks[8];
        const distance = Math.hypot(thumb.x - index.x, thumb.y - index.y);
        const pinching = lastPinching ? distance < 0.085 : distance < 0.065;
        lastPinching = pinching;
        callback?.(1 - index.x, index.y, pinching, true);
      });

      frameTimer = window.setInterval(async () => {
        if (processingFrame || !handDetector || video.readyState < 2) return;
        processingFrame = true;
        try {
          await handDetector.send({ image: video });
        } catch (error) {
          console.error('Hand tracking frame failed:', error);
        } finally {
          processingFrame = false;
        }
      }, 50);
    } catch (error) {
      window.bubblesStopHandTracking();
      throw error;
    }
  };

  window.bubblesStopHandTracking = async () => {
    if (frameTimer !== null) {
      window.clearInterval(frameTimer);
      frameTimer = null;
    }
    cameraStream?.getTracks().forEach((track) => track.stop());
    cameraStream = null;
    if (handDetector) {
      await handDetector.close();
      handDetector = null;
    }
    processingFrame = false;
    lastPinching = false;
    callback = null;
  };
})();
