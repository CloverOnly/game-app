import 'package:flame_forge2d/flame_forge2d.dart';

import '../constants.dart';
import '../models.dart';

class Marble extends BodyComponent {
  Marble({
    required Vector2 position,
    required this.playerId,
  }) : super(
         renderBody: false,
         bodyDef: BodyDef()
           ..type = BodyType.dynamic
           ..position = position
           ..linearDamping = PhysicsConfig.linearDamping,
         fixtureDefs: [
           FixtureDef(
             CircleShape()..radius = GameConfig.marbleRadius,
             restitution: PhysicsConfig.restitution,
             friction: PhysicsConfig.friction,
             density: PhysicsConfig.density,
           ),
         ],
       );

  PlayerId playerId;
  bool placementPreview = false;

  Vector2 get velocity => body.linearVelocity;
  double get speed => velocity.length;

  void launch(Vector2 impulse) {
    body.linearVelocity = impulse;
    body.angularVelocity = 0;
  }

  void stop() {
    body.linearVelocity = Vector2.zero();
    body.angularVelocity = 0;
  }

  void dampen(double factor) {
    body.linearVelocity *= factor;
    body.angularVelocity = 0;
  }

  void moveTo(Vector2 position) {
    body.setTransform(position, 0);
    stop();
  }
}
