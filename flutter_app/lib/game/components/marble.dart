import 'dart:ui';

import 'package:flame_forge2d/flame_forge2d.dart';

import '../constants.dart';
import '../models.dart';
import 'wall.dart';

class Marble extends BodyComponent with ContactCallbacks {
  Marble({
    required Vector2 position,
    required this.playerId,
    this.onWallBounce,
  }) : _radius = GameConfig.marbleRadius,
       super(
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

  final double _radius;
  PlayerId playerId;
  final VoidCallback? onWallBounce;

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

  void moveTo(Vector2 position) {
    body.setTransform(position, 0);
    stop();
  }

  @override
  void beginContact(Object other, Contact contact) {
    if (other is Wall) {
      onWallBounce?.call();
    }
  }

  @override
  void render(Canvas canvas) {
    final center = Offset.zero;
    final r = _radius;

    canvas.drawCircle(
      center.translate(2, 2),
      r,
      Paint()..color = const Color(0x40000000),
    );
    canvas.drawCircle(center, r, Paint()..color = const Color(0xFFF0F0F0));
    canvas.drawCircle(
      center.translate(-4, -4),
      r * 0.35,
      Paint()..color = const Color(0xB3FFFFFF),
    );
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = Color(players[playerId]!.color)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
}
