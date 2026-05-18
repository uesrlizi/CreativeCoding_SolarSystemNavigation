// ========== 2D MATH UTILITIES ==========

static class Vector2 {
  double x, y;

  Vector2() {
    this.x = 0;
    this.y = 0;
  }

  Vector2(double x, double y) {
    this.x = x;
    this.y = y;
  }

  Vector2 add(Vector2 v) {
    return new Vector2(this.x + v.x, this.y + v.y);
  }

  Vector2 sub(Vector2 v) {
    return new Vector2(this.x - v.x, this.y - v.y);
  }

  Vector2 mul(double s) {
    return new Vector2(this.x * s, this.y * s);
  }

  Vector2 div(double s) {
    return new Vector2(this.x / s, this.y / s);
  }

  double dot(Vector2 v) {
    return this.x * v.x + this.y * v.y;
  }

  double cross(Vector2 v) {
    return this.x * v.y - this.y * v.x;
  }

  double magnitude() {
    return Math.sqrt(x * x + y * y);
  }

  double magnitudeSq() {
    return x * x + y * y;
  }

  Vector2 normalized() {
    double mag = magnitude();
    if (mag < 1e-10) return new Vector2(0, 0);
    return div(mag);
  }

  Vector2 rotate(double angle) {
    double cosA = Math.cos(angle);
    double sinA = Math.sin(angle);
    return new Vector2(
      x * cosA - y * sinA,
      x * sinA + y * cosA
    );
  }

  double distance(Vector2 v) {
    double dx = this.x - v.x;
    double dy = this.y - v.y;
    return Math.sqrt(dx * dx + dy * dy);
  }

  double angle() {
    return Math.atan2(y, x);
  }

  double angleTo(Vector2 v) {
    double dot = this.dot(v);
    double mag1 = this.magnitude();
    double mag2 = v.magnitude();
    if (mag1 < 1e-10 || mag2 < 1e-10) return 0;
    double cosAngle = dot / (mag1 * mag2);
    cosAngle = constrainDouble(cosAngle, -1, 1);
    return Math.acos(cosAngle);
  }

  Vector2 clone() {
    return new Vector2(x, y);
  }

  void set(double x, double y) {
    this.x = x;
    this.y = y;
  }

  void set(Vector2 v) {
    this.x = v.x;
    this.y = v.y;
  }

  String toString() {
    return String.format("(%.2f, %.2f)", x, y);
  }
}

static class Rotation2D {
  double angle;

  Rotation2D() {
    this.angle = 0;
  }

  Rotation2D(double angle) {
    this.angle = angle;
    normalize();
  }

  Rotation2D add(Rotation2D r) {
    return new Rotation2D(this.angle + r.angle);
  }

  Rotation2D sub(Rotation2D r) {
    return new Rotation2D(this.angle - r.angle);
  }

  Rotation2D mul(double s) {
    return new Rotation2D(this.angle * s);
  }

  Vector2 rotate(Vector2 v) {
    return v.rotate(angle);
  }

  Vector2 getForward() {
    return new Vector2(Math.cos(angle), Math.sin(angle));
  }

  Vector2 getRight() {
    return getForward();
  }

  Vector2 getUp() {
    return getForward().rotate(Math.PI / 2);
  }

  Rotation2D normalize() {
    while (angle >= TWO_PI) angle -= TWO_PI;
    while (angle < 0) angle += TWO_PI;
    return this;
  }

  Rotation2D inverse() {
    return new Rotation2D(-angle);
  }

  String toString() {
    return String.format("%.2f rad", angle);
  }
}

// ========== Factory functions ==========
static Vector2 Vector2_zero() { return new Vector2(0, 0); }
static Vector2 Vector2_one() { return new Vector2(1, 1); }
static Vector2 Vector2_right() { return new Vector2(1, 0); }
static Vector2 Vector2_up() { return new Vector2(0, 1); }
static Vector2 Vector2_left() { return new Vector2(-1, 0); }
static Vector2 Vector2_down() { return new Vector2(0, -1); }

static Rotation2D Rotation2D_fromAngle(double angle) {
  return new Rotation2D(angle);
}

static Rotation2D Rotation2D_fromDirection(Vector2 dir) {
  return new Rotation2D(dir.angle());
}

static Rotation2D Rotation2D_lerp(Rotation2D a, Rotation2D b, double t) {
  double diff = b.angle - a.angle;
  while (diff > Math.PI) diff -= TWO_PI;
  while (diff < -Math.PI) diff += TWO_PI;
  return new Rotation2D(a.angle + diff * t);
}
