import 'package:flame_forge2d/flame_forge2d.dart';

class Wall extends BodyComponent {
  Wall({
    required this.topLeft,
    required this.size,
  });

  final Vector2 topLeft;
  final Vector2 size;

  @override
  Body createBody() {
    final bodyDef = BodyDef()
      ..type = BodyType.static
      ..position = topLeft + size / 2;

    final shape = PolygonShape()
      ..setAsBoxXY(size.x / 2, size.y / 2);

    final fixtureDef = FixtureDef(shape)
      ..restitution = 0.32
      ..friction = 0.18;

    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }
}
