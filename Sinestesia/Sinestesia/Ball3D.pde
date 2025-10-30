import processing.core.*;

// Clase Ball3D
class Ball3D {
  // Variables de estado
  float x, y, z;
  float vx, vy, vz;
  float diameter;
  public int id;
  float mass;

  // Variables de rotación
  float rotX, rotY, rotZ;
  float rotSpeedX, rotSpeedY, rotSpeedZ;

  // Color
  float hue;

  // Referencias
  PApplet p;
  Ball3D[] others;

  // Constructor
  Ball3D(float xin, float yin, float zin, float din, int idin, Ball3D[] oin, PApplet parent) {
    this.p = parent;

    this.x = xin;
    this.y = yin;
    this.z = zin;
    this.vx = 0;
    this.vy = 0;
    this.vz = 0;
    this.diameter = din;
    this.id = idin;
    this.others = oin;
    this.mass = din * 0.1f;

    // Rotación
    this.rotX = parent.random(parent.TWO_PI);
    this.rotY = parent.random(parent.TWO_PI);
    this.rotZ = parent.random(parent.TWO_PI);
    this.rotSpeedX = parent.random(-0.03f, 0.03f);
    this.rotSpeedY = parent.random(-0.03f, 0.03f);
    this.rotSpeedZ = parent.random(-0.03f, 0.03f);  // ✅ CORREGIDO

    // Color único por partícula
    this.hue = parent.random(360);
  }

  // COLISIÓN CON MANO: Devuelve TRUE si hubo choque
  boolean collideWithHand(PVector handPos, float handRadius) {
    boolean collided = false;

    // Calcular distancia SOLO en X e Y (colisión cilíndrica)
    float dx = this.x - handPos.x;
    float dy = this.y - handPos.y;
    float distance = PApplet.sqrt(dx * dx + dy * dy);

    // Distancia mínima para repulsión
    float minDist = handRadius / 2 + this.diameter / 2;

    if (distance < minDist) {
      collided = true;

      // Caso especial: partícula en el centro exacto
      if (distance < 1.0f) {
        this.x += p.random(-30, 30);
        this.y += p.random(-30, 30);
        this.vx += p.random(-5, 5);
        this.vy += p.random(-5, 5);
        return collided;
      }

      // Normalizar vector dirección (solo X, Y)
      float nx = dx / distance;
      float ny = dy / distance;

      // Fuerza proporcional a la penetración
      float penetration = minDist - distance;
      float forceMagnitude = penetration * 0.4f;

      // Aplicar velocidad SOLO en X, Y (Z no se ve afectado)
      this.vx += nx * forceMagnitude;
      this.vy += ny * forceMagnitude;

      // Teletransporte instantáneo fuera de la colisión (solo X, Y)
      this.x = handPos.x + nx * minDist;
      this.y = handPos.y + ny * minDist;
    }
    return collided;
  }

  // Colisión entre partículas
  void collide(float spring, int numBalls) {
    for (int i = this.id + 1; i < numBalls; i++) {
      if (others[i] == null) continue;

      float dx = others[i].x - this.x;
      float dy = others[i].y - this.y;
      float dz = others[i].z - this.z;
      float distance = PApplet.sqrt(dx * dx + dy * dy + dz * dz);
      float minDist = others[i].diameter / 2 + this.diameter / 2;

      if (distance < minDist && distance > 0) {
        float factor = (minDist - distance) * spring;
        float nx = dx / distance;
        float ny = dy / distance;
        float nz = dz / distance;

        this.vx -= nx * factor;
        this.vy -= ny * factor;
        this.vz -= nz * factor;
        others[i].vx += nx * factor;
        others[i].vy += ny * factor;
        others[i].vz += nz * factor;
      }
    }
  }

  // Movimiento y física
  void move(PApplet p, float gravity, float friction, float halfDepth) {
    final float THRESHOLD = 0.01f;

    // 1. APLICAR GRAVEDAD
    this.vy += gravity;

    // 2. APLICAR VELOCIDAD
    this.x += this.vx;
    this.y += this.vy;
    this.z += this.vz;

    // 3. COLISIÓN CON LÍMITES DEL ESPACIO 3D
    float margin = this.diameter / 2.0f;
    float halfWidth = p.width / 2.0f;
    float halfHeight = p.height / 2.0f;

    // Límites X
    if (this.x > halfWidth - margin) {
      this.x = halfWidth - margin;
      this.vx *= friction;
      if (PApplet.abs(this.vx) < THRESHOLD) this.vx = 0;
    } else if (this.x < -halfWidth + margin) {
      this.x = -halfWidth + margin;
      this.vx *= friction;
      if (PApplet.abs(this.vx) < THRESHOLD) this.vx = 0;
    }

    // Límites Y
    if (this.y > halfHeight - margin) {
      this.y = halfHeight - margin;
      this.vy *= friction;
      if (PApplet.abs(this.vy) < THRESHOLD) this.vy = 0;
    } else if (this.y < -halfHeight + margin) {
      this.y = -halfHeight + margin;
      this.vy *= friction;
      if (PApplet.abs(this.vy) < THRESHOLD) this.vy = 0;
    }

    // Límites Z
    if (this.z > halfDepth - margin) {
      this.z = halfDepth - margin;
      this.vz *= friction;
      if (PApplet.abs(this.vz) < THRESHOLD) this.vz = 0;
    } else if (this.z < -halfDepth + margin) {
      this.z = -halfDepth + margin;
      this.vz *= friction;
      if (PApplet.abs(this.vz) < THRESHOLD) this.vz = 0;
    }

    // 4. ACTUALIZAR ROTACIÓN
    this.rotX += this.rotSpeedX;
    this.rotY += this.rotSpeedY;
    this.rotZ += this.rotSpeedZ;
  }

  // Renderizar en 3D con efecto de profundidad
  void display(PShape model, float halfDepthLimit) {
    p.pushMatrix();
    p.translate(this.x, this.y, this.z);

    // Rotación
    p.rotateX(this.rotX);
    p.rotateY(this.rotY);
    p.rotateZ(this.rotZ);

    // Color basado en velocidad
    float speed = PApplet.sqrt(this.vx * this.vx + this.vy * this.vy + this.vz * this.vz);
    float brightness = PApplet.map(speed, 0, 15, 40, 100);
    float saturation = PApplet.map(speed, 0, 15, 60, 100);

    // Efecto de profundidad
    float depthFactor = PApplet.map(this.z, -halfDepthLimit, halfDepthLimit, 100, 50);
    brightness *= depthFactor / 100.0f;

    float depthAlpha = PApplet.map(this.z, -halfDepthLimit, halfDepthLimit, 100, 40);

    if (model != null) {
      p.fill(this.hue, saturation, brightness, depthAlpha);
      p.noStroke();
      float scale = this.diameter / 5.0f;
      p.scale(scale);
      p.shape(model);
    } else {
      p.fill(this.hue, saturation, brightness, depthAlpha);
      p.noStroke();
      p.sphere(this.diameter / 2);
    }

    p.popMatrix();
  }
}
