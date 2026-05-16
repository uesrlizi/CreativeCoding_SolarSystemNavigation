// ============================================================
//  Celestial Body Renderer
//  SHAPES ONLY! Fixed overlapping!
// ============================================================

class CelestialBodyRenderer {
  float time;

  CelestialBodyRenderer() {
    time = 0;
  }

  void update(float dt) {
    time += dt;
  }

  // ============================================================
  //  扫描线 LOD
  // ============================================================
  void drawScanlineLOD(CelestialBody body, double cx, double cy, double r) {
    noStroke();
    float rSq = (float)(r * r);
    float startY = max(0, (float)(cy - r));
    float endY = min(height, (float)(cy + r));

    for (int py = (int)startY; py < (int)endY; py++) {
      float dy = py - (float)cy;
      float dxSq = rSq - dy * dy;
      if (dxSq <= 0) continue;
      float dx = sqrt(dxSq);
      float sx = max(0, (float)cx - dx);
      float ex = min(width, (float)cx + dx);
      if (sx >= ex) continue;

      if (body.type == BodyType.SUN) {
        for (int px = (int)sx; px < (int)ex; px++) {
          float dnx = (px - (float)cx) / (float)r;
          float dny = dy / (float)r;
          float dist = sqrt(dnx*dnx + dny*dny);
          float n = noise(px * 0.02f, py * 0.02f, time * 0.5f);
          float bright = 0.65f + (1 - dist) * 0.45f + n * 0.2f;
          fill(255, (int)(200 * bright + 55), (int)(80 * bright + 30));
          rect(px, py, 1, 1);
        }
      } else {
        float ny = dy / (float)r;
        float shade = 0.7f + (1 - abs(ny)) * 0.35f;
        fill((int)(red(body.col) * shade), (int)(green(body.col) * shade), (int)(blue(body.col) * shade));
        rect(sx, py, ex - sx, 1);
      }
    }

    if (body.hasAtmosphere && r < max(width, height)) {
      drawAtmosphereEdgeOnly(body, (float)cx, (float)cy, (float)r);
    }
  }

  // ============================================================
  //  LOD 0
  // ============================================================
  void drawLOD0(CelestialBody body, double cx, double cy, double r) {
    noStroke();
    if (body.type == BodyType.SUN) drawSunGlowSimple((float)cx, (float)cy, (float)r);
    fill(body.col);
    ellipse((float)cx, (float)cy, (float)(r * 2), (float)(r * 2));
  }

  // ============================================================
  //  LOD 1 - 用形状，但形状要重叠！
  // ============================================================
  void drawLOD1(CelestialBody body, double cx, double cy, double r) {
    noStroke();
    float fr = (float)r;

    if (body.type == BodyType.SUN) {
      drawSunWithShapes((float)cx, (float)cy, fr, 8);
    } else {
      drawPlanetWithShapes(body, (float)cx, (float)cy, fr, 8);
    }

    if (body.hasRing && r > 40) drawRingSimple(body, (float)cx, (float)cy, (float)r);
    if (body.hasAtmosphere) drawAtmosphereEdgeOnly(body, (float)cx, (float)cy, (float)r);
  }

  // ============================================================
  //  LOD 2
  // ============================================================
  void drawLOD2(CelestialBody body, double cx, double cy, double r) {
    noStroke();
    float fr = (float)r;

    if (body.type == BodyType.SUN) {
      drawSunWithShapes((float)cx, (float)cy, fr, 12);
    } else {
      drawPlanetWithShapes(body, (float)cx, (float)cy, fr, 12);
    }

    if (body.hasRing) drawRingSimple(body, (float)cx, (float)cy, (float)r);
    if (body.hasAtmosphere) drawAtmosphereEdgeOnly(body, (float)cx, (float)cy, (float)r);
  }

  // ============================================================
  //  LOD 3
  // ============================================================
  void drawLOD3(CelestialBody body, double cx, double cy, double r) {
    noStroke();
    float fr = (float)r;

    if (body.type == BodyType.SUN) {
      drawSunWithShapes((float)cx, (float)cy, fr, 16);
      drawSolarProminences((float)cx, (float)cy, fr);
    } else {
      drawPlanetWithShapes(body, (float)cx, (float)cy, fr, 16);
      if (body.name.equals("Jupiter")) drawRedSpot((float)cx, (float)cy, fr, body.rotation);
    }

    if (body.hasRing) drawRingDetailed(body, (float)cx, (float)cy, (float)r);
    if (body.hasAtmosphere) drawAtmosphereEdgeOnly(body, (float)cx, (float)cy, (float)r);
  }

  // ============================================================
  //  LOD 4
  // ============================================================
  void drawLOD4(CelestialBody body, double cx, double cy, double r) {
    if (body.type == BodyType.SUN) drawSunFullScreen();
    else drawScanlineLOD(body, cx, cy, r);
  }

  // ============================================================
  //  太阳 - 用同心扇形/饼块形状！
  // ============================================================
  void drawSunGlowSimple(float cx, float cy, float r) {
    for (int i = 3; i > 0; i--) {
      float k = i / 3.0f;
      float gr = r * (1 + k * 0.6f);
      fill(255, 200, 100, (int)(25 * (1 - k)));
      ellipse(cx, cy, gr * 2, gr * 2);
    }
  }

  void drawSunWithShapes(float cx, float cy, float r, int seg) {
    drawSunGlowSimple(cx, cy, r);
    pushMatrix();
    translate(cx, cy);
    for (int i = 0; i < seg; i++) {
      float a1 = TWO_PI * i / seg;
      float a2 = TWO_PI * (i + 1) / seg;
      beginShape(TRIANGLE_FAN);
      vertex(0, 0);
      for (int j = 0; j <= 32; j++) {
        float a = lerp(a1, a2, j / 32.0f);
        float x = cos(a) * r;
        float y = sin(a) * r;
        float n = noise(x * 0.02f + time * 0.1f, y * 0.02f);
        float bright = 0.75f + n * 0.35f;
        fill(255, (int)(200 * bright + 55), (int)(80 * bright + 30));
        vertex(x, y);
      }
      endShape(CLOSE);
    }
    popMatrix();
  }

  void drawSolarProminences(float cx, float cy, float r) {
    int num = 5;
    for (int i = 0; i < num; i++) {
      float angle = i * TWO_PI / num + time * 0.02f;
      float ph = r * (0.06f + 0.08f * noise(i * 10, time * 0.05f));
      float px = cx + cos(angle) * (r + ph * 0.3f);
      float py = cy + sin(angle) * (r + ph * 0.3f);
      fill(255, 150, 80, 70);
      ellipse(px, py, ph * 0.7f, ph * 1.3f);
    }
  }

  void drawSunFullScreen() {
    for (int y = 0; y < height; y += 2) {
      for (int x = 0; x < width; x += 2) {
        float n = noise(x * 0.008f, y * 0.008f, time * 0.3f);
        float bright = 0.7f + n * 0.45f;
        fill(255, (int)(200 * bright + 55), (int)(80 * bright + 30));
        rect(x, y, 2, 2);
      }
    }
  }

  // ============================================================
  //  行星 - 像Jupiter LOD3那样！形状要重叠！
  // ============================================================
  void drawPlanetWithShapes(CelestialBody body, float cx, float cy, float r, int bands) {
    pushMatrix();
    translate(cx, cy);
    rotate(body.rotation * 0.1f);

    for (int i = -bands; i <= bands; i++) {
      float yCenter = i * r / bands;
      float halfBand = r / bands * 1.2f; // 1.2倍宽度，保证重叠！
      float y1 = yCenter - halfBand;
      float y2 = yCenter + halfBand;

      color c = getPlanetBandColor(body, i, yCenter / r);
      fill(c);

      beginShape();
      // 上半圈
      for (float a = 0; a <= PI; a += 0.05f) {
        float px = cos(a) * r;
        float py = sin(a) * r;
        if (py >= y1 && py <= y2) vertex(px, py);
      }
      // 下半圈反向
      for (float a = PI; a >= 0; a -= 0.05f) {
        float px = cos(a) * r;
        float py = -sin(a) * r;
        if (py >= y1 && py <= y2) vertex(px, py);
      }
      endShape(CLOSE);
    }
    popMatrix();
  }

  color getPlanetBandColor(CelestialBody body, int bandIndex, float lat) {
    if (body.name.equals("Earth")) {
      float n = noise(bandIndex * 0.5f, lat * 4f);
      return n > 0.55f ? color(75, 135, 65) : color(35, 105, 185);
    } else if (body.name.equals("Mars")) {
      float variation = 0.75f + noise(bandIndex * 0.6f) * 0.45f;
      return color((int)(190 * variation), (int)(90 * variation), (int)(55 * variation));
    } else if (body.type == BodyType.GAS_GIANT || body.type == BodyType.ICE_GIANT) {
      float variation = 0.7f + abs(sin(lat * 9 + bandIndex * 0.6f)) * 0.4f;
      color base = getBandColor(body, bandIndex);
      return color((int)(red(base) * variation), (int)(green(base) * variation), (int)(blue(base) * variation));
    } else {
      float shade = 0.7f + (1 - abs(lat)) * 0.4f;
      return color((int)(red(body.col) * shade), (int)(green(body.col) * shade), (int)(blue(body.col) * shade));
    }
  }

  color getBandColor(CelestialBody body, int bandIndex) {
    if (body.name.equals("Jupiter")) {
      if (bandIndex % 3 == 0) return color(205, 175, 140);
      else if (bandIndex % 3 == 1) return color(175, 135, 95);
      else return color(145, 100, 65);
    } else if (body.name.equals("Saturn")) {
      float s = 0.9f - abs(bandIndex) / 10.0f * 0.25f;
      return color((int)(220 * s), (int)(195 * s), (int)(150 * s));
    } else {
      float s = 0.85f - abs(bandIndex) / 10.0f * 0.2f;
      return color((int)(red(body.col) * s), (int)(green(body.col) * s), (int)(blue(body.col) * s));
    }
  }

  void drawRedSpot(float cx, float cy, float r, float rot) {
    float sx = cx + r * 0.28f;
    float sy = cy + r * 0.32f;
    float sr = r * 0.14f;
    fill(175, 75, 40);
    ellipse(sx, sy, sr * 2, sr * 1.35f);
    fill(195, 95, 55, 120);
    ellipse(sx - sr * 0.15f, sy - sr * 0.1f, sr * 1.6f, sr * 1.1f);
  }

  // ============================================================
  //  光环
  // ============================================================
  void drawRingSimple(CelestialBody body, float cx, float cy, float r) {
    pushMatrix();
    translate(cx, cy);
    rotate(body.ringTilt);
    float inR = r * body.ringInnerRadius;
    float outR = r * body.ringOuterRadius;
    noStroke();
    fill(body.ringColor);
    ellipse(0, 0, outR * 2, outR * 0.42f);
    fill(0, 0);
    ellipse(0, 0, inR * 2, inR * 0.42f);
    popMatrix();
  }

  void drawRingDetailed(CelestialBody body, float cx, float cy, float r) {
    pushMatrix();
    translate(cx, cy);
    rotate(body.ringTilt + time * 0.01f);
    float inR = r * body.ringInnerRadius;
    float outR = r * body.ringOuterRadius;
    int layers = 12;
    noStroke();
    for (int i = 0; i < layers; i++) {
      float k1 = i / (float)layers;
      float k2 = (i + 1) / (float)layers;
      float r1 = inR + (outR - inR) * k1;
      float r2 = inR + (outR - inR) * k2;
      float alpha = 60 + noise(i * 0.6f, time * 0.08f) * 110;
      float variation = 0.78f + noise(i * 2.2f) * 0.44f;
      fill((int)(200 * variation), (int)(180 * variation), (int)(140 * variation), (int)alpha);
      beginShape(QUAD_STRIP);
      for (float a = 0; a <= TWO_PI; a += 0.18f) {
        float x1 = cos(a) * r1;
        float y1 = sin(a) * r1 * 0.42f;
        float x2 = cos(a) * r2;
        float y2 = sin(a) * r2 * 0.42f;
        vertex(x1, y1);
        vertex(x2, y2);
      }
      endShape(CLOSE);
    }
    popMatrix();
  }

  // ============================================================
  //  大气 - 仅边缘光晕
  // ============================================================
  void drawAtmosphereEdgeOnly(CelestialBody body, float cx, float cy, float r) {
    color atmos = body.atmosphereColor;
    int layers = 4;
    for (int i = layers; i > 0; i--) {
      float k = i / (float)layers;
      float ar = r * (1 + k * 0.13f);
      fill(red(atmos), green(atmos), blue(atmos), (int)(35 * (1 - k) * (1 - k)));
      ellipse(cx, cy, ar * 2, ar * 2);
    }
    blendMode(ADD);
    fill(red(atmos), green(atmos), blue(atmos), 18);
    ellipse(cx, cy, r * 2.15f, r * 2.15f);
    blendMode(BLEND);
  }
}
