import 'hand_tracking_stub.dart'
    if (dart.library.html) 'hand_tracking_web.dart'
    as platform;
import 'hand_tracking_types.dart';

export 'hand_tracking_types.dart';

HandTrackingController createHandTrackingController({
  required HandPoseCallback onPose,
  required HandStatusCallback onStatus,
}) => platform.createHandTrackingController(onPose: onPose, onStatus: onStatus);
