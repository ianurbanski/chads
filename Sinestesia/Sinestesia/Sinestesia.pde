import spout.*;


import oscP5.*;
import netP5.*;


// Variables de física
final float SPRING = 0.04f;
final float GRAVITY = 0.01f;
final float FRICTION = -0.7f;
final int NUM_BALLS = 75;
final float HAND_RADIUS = 80.0f;
final float HALF_DEPTH = 150.0f;

// Variables globales
Ball3D[] balls = new Ball3D[NUM_BALLS];
PShape model3D = null;

PVector hand1Position = new PVector(0, 0, 0); // Mano 1 (derecha)
PVector hand2Position = new PVector(0, 0, 0); // Mano 2 (izquierda)

// Contador de colisiones en el frame actual
int collisionCount = 0;

// Variables OSC
OscP5 oscP5;
NetAddress myRemoteLocation;

Spout spout;

float lastHand1X = 0.5f;
float lastHand1Y = 0.5f;
float lastHand2X = 0.5f;
float lastHand2Y = 0.5f;

final int OSC_RECEIVE_PORT = 7002; // TD → Processing
final int OSC_SEND_PORT = 7000;    // Processing → TD

// Control de debug
boolean showDebug = false;

void settings() {
  size(1280, 720, P3D);
}

void setup() {
  colorMode(HSB, 360, 100, 100, 100);
  perspective();
  
  spout = new Spout(this);
  spout.createSender("chads");

  // Cargar modelo 3D
  try {
    model3D = loadShape("esfera1.obj");
    println("✓ Modelo 3D cargado: esfera1.obj");
  }
  catch (Exception e) {
    println("⚠ No se pudo cargar el modelo 3D, usando esferas");
    println("  Error: " + e.getMessage());
  }

  // Inicializar partículas
  for (int i = 0; i < NUM_BALLS; i++) {
    balls[i] = new Ball3D(
      random(-width/2, width/2),
      random(-height/2, height/2),
      random(-HALF_DEPTH, HALF_DEPTH),
      random(15, 30),
      i,
      balls,
      this
    );
  }

  // Inicializar OSC
  initOSCConnection();

  println("✓ Simulación 3D iniciada");
  println("  Partículas: " + NUM_BALLS);
  println("  Puerto OSC escucha: " + OSC_RECEIVE_PORT);
  println("  Puerto OSC envío: " + OSC_SEND_PORT);
  println("\n📋 CONTROLES:");
  println("  R - Resetear simulación");
  println("  D - Toggle debug visual");
  println("  H - Mostrar ayuda");
}

void draw() {
  background(0, 0, 0);

  // 1. INICIALIZAR EL CONTEO DE COLISIONES
  collisionCount = 0;

  // Configurar cámara 3D
  translate(width / 2.0f, height / 2.0f, 0);
  float cameraZoom = -150;
  translate(0, 0, cameraZoom);

  // Iluminación
  ambientLight(0, 0, 150);
  directionalLight(255, 255, 255, 0.5f, 0.5f, -1);
  pointLight(255, 255, 255, 0, -200, 400);

  // Dibujar cubo contenedor
  if (showDebug) {
    pushMatrix();
    stroke(255, 255, 255, 100);
    strokeWeight(1);
    noFill();
    box(width, height, HALF_DEPTH * 2);
    popMatrix();
  }

  // 2. SIMULAR, RENDERIZAR Y CONTAR COLISIONES
  for (Ball3D ball : balls) {
    // Colisión con MANO 1
    if (ball.collideWithHand(hand1Position, HAND_RADIUS)) {
      collisionCount++;
    }

    // Colisión con MANO 2
    if (ball.collideWithHand(hand2Position, HAND_RADIUS)) {
      collisionCount++;
    }

    // Colisión entre partículas
    ball.collide(SPRING, NUM_BALLS);

    // Física y movimiento
    ball.move(this, GRAVITY, FRICTION, HALF_DEPTH);

    // Renderizar
    ball.display(model3D, HALF_DEPTH);
  }

  // Debug: dibujar posiciones de las manos
  if (showDebug) {
    drawHandMarker(hand1Position, 0); // Mano 1 (color 0 = cyan)
    drawHandMarker(hand2Position, 180); // Mano 2 (color 180 = magenta)
  }

  // 3. ENVIAR CONTEO DE COLISIONES a TouchDesigner
  if (frameCount % 3 == 0) {
    sendCollisionData(collisionCount);
  }

  // Estadísticas en consola cada 2 segundos
  if (frameCount % 120 == 0) {
    println("💥 Colisiones/Frame: " + collisionCount);
  }
 spout.sendTexture();
}

// ====================================================================
// FUNCIONES OSC
// ====================================================================

void initOSCConnection() {
  try {
    oscP5 = new OscP5(this, OSC_RECEIVE_PORT);
    myRemoteLocation = new NetAddress("127.0.0.1", OSC_SEND_PORT);
    println("✓ OSC inicializado correctamente");
  }
  catch (Exception e) {
    println("✗ Error al inicializar OSC: " + e.getMessage());
  }
}

// Recibir mensajes OSC
void oscEvent(OscMessage theOscMessage) {
  String address = theOscMessage.addrPattern();

  // Ignorar mensajes de sistema
  if (address.equals("/_samplerate")) {
    return;
  }

  try {
    // ========== MANO 1 (Derecha) - Solo X, Y ==========
    if (address.equals("/Mano1_ejeX")) {
      if (theOscMessage.arguments().length >= 1) {
        lastHand1X = theOscMessage.get(0).floatValue();
        updateHandPosition(1, lastHand1X, lastHand1Y);
      }
    } else if (address.equals("/Mano1_ejeY")) {
      if (theOscMessage.arguments().length >= 1) {
        lastHand1Y = theOscMessage.get(0).floatValue();
        updateHandPosition(1, lastHand1X, lastHand1Y);
      }
    }

    // ========== MANO 2 (Izquierda) - Solo X, Y ==========
    else if (address.equals("/Mano2_ejeX")) {
      if (theOscMessage.arguments().length >= 1) {
        lastHand2X = theOscMessage.get(0).floatValue();
        updateHandPosition(2, lastHand2X, lastHand2Y);
      }
    } else if (address.equals("/Mano2_ejeY")) {
      if (theOscMessage.arguments().length >= 1) {
        lastHand2Y = theOscMessage.get(0).floatValue();
        updateHandPosition(2, lastHand2X, lastHand2Y);
      }
    }

    // Reset de simulación
    else if (address.equals("/simulation/reset")) {
      resetSimulation();
    }
  }
  catch (Exception e) {
    println("✗ Error procesando OSC: " + address);
    println("  " + e.getMessage());
  }
}

// Actualizar posición de la mano desde datos normalizados (solo X, Y)
void updateHandPosition(int handID, float normX, float normY) {
  // Mapear de [0,1] a espacio 3D
  float x = map(normX, 0, 1, -width/2, width/2);
  float y = map(normY, 0, 1, height/2, -height/2); // Y invertido en 3D
  float z = 0; // Z fijo en el centro

  // Actualizar la mano correspondiente
  if (handID == 1) {
    hand1Position.set(x, y, z);
  } else if (handID == 2) {
    hand2Position.set(x, y, z);
  }
}

// Envía el conteo de colisiones
void sendCollisionData(int count) {
  if (oscP5 == null || myRemoteLocation == null) {
    return;
  }

  try {
    OscMessage msg = new OscMessage("/ableton/hit_count");
    msg.add((float)count);
    oscP5.send(msg, myRemoteLocation);
  }
  catch (Exception e) {
    println("✗ Error enviando datos OSC: " + e.getMessage());
  }
}

// Resetear simulación
void resetSimulation() {
  for (Ball3D ball : balls) {
    ball.x = random(-width/2, width/2);
    ball.y = random(-height/2, height/2);
    ball.z = random(-HALF_DEPTH, HALF_DEPTH);
    ball.vx = 0;
    ball.vy = 0;
    ball.vz = 0;
  }

  // Resetear posiciones de las manos
  hand1Position.set(0, 0, 0);
  hand2Position.set(0, 0, 0);

  println("↻ Simulación reseteada");
}

// Dibujar marcador de la mano (debug)
void drawHandMarker(PVector handPos, float hueOffset) {
  pushMatrix();
  translate(handPos.x, handPos.y, handPos.z);

  // Esfera de interacción (semi-transparente)
  noFill();
  stroke(hueOffset, 100, 100, 50);
  strokeWeight(2);
  sphere(HAND_RADIUS / 2);

  // Punto central (más brillante según profundidad)
  float depthBrightness = map(handPos.z, -HALF_DEPTH, HALF_DEPTH, 100, 40);
  fill(hueOffset, 100, depthBrightness, 80);
  noStroke();
  sphere(20);

  // Ejes de referencia (X, Y, Z)
  strokeWeight(3);

  // Eje X (rojo)
  stroke(0, 100, 100, 80);
  line(-30, 0, 0, 30, 0, 0);

  // Eje Y (verde)
  stroke(120, 100, 100, 80);
  line(0, -30, 0, 0, 30, 0);

  // Eje Z (azul)
  stroke(240, 100, 100, 80);
  line(0, 0, -30, 0, 0, 30);

  popMatrix();
}

// ====================================================================
// CONTROLES
// ====================================================================

void keyPressed() {
  if (key == 'r' || key == 'R') {
    resetSimulation();
  }

  if (key == 'd' || key == 'D') {
    showDebug = !showDebug;
    println("🔧 Debug visual: " + (showDebug ? "ON" : "OFF"));
  }

  if (key == 'h' || key == 'H') {
    println("\n═══════════════════════════════════");
    println("CONTROLES:");
    println("  R - Resetear simulación");
    println("  D - Toggle debug visual");
    println("  H - Mostrar ayuda");
    println("\nESTADO:");
    println("  FPS: " + round(frameRate));
    println("  Partículas: " + balls.length);
    println("  Colisiones/Frame: " + collisionCount);
    println("  Puertos OSC:");
    println("    - Recibe: " + OSC_RECEIVE_PORT);
    println("    - Envía: " + OSC_SEND_PORT);
    println("═══════════════════════════════════\n");
  }
}
