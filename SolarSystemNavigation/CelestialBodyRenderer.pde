// ============================================================
//  Celestial Body Renderer
//  Procedural textures & detailed rendering for all bodies
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
  //  LOD 0 - Far: simple circle with basic glow
  // ============================================================
  void drawLOD0(CelestialBody body, double cx, double cy, double r) {
    noStroke();
    if (body.type == BodyType.SUN) {
      drawSunGlow((float)cx, (float)cy, (float)r, 0.5f);
    }
    fill(body.col);
    ellipse((float)cx, (float)cy, (float)(r * 2), (float)(r * 2));
  }

  // ============================================================
  //  LOD 1 - Medium: gradient + basic features
  // ============================================================
  void drawLOD1(CelestialBody body, double cx, double cy, double r) {
    noStroke();
    switch (body.type) {
      case SUN:
        drawSunLOD1((float)cx, (float)cy, (float)r);
        break;
      case TERRESTRIAL:
        drawTerrestrialLOD1(body, (float)cx, (float)cy, (float)r);
        break;
      case GAS_GIANT:
      case ICE_GIANT:
        drawGasGiantLOD1(body, (float)cx, (float)cy, (float)r);
        break;
    }
    if (body.hasRing && r > 20) {
      drawRingSimple(body, (float)cx, (float)cy, (float)r);
    }
  }

  // ============================================================
  //  LOD 2 - Near: detailed textures
  // ============================================================
  void drawLOD2(CelestialBody body, double cx, double cy, double r) {
    noStroke();
    switch (body.type) {
      case SUN:
        drawSunLOD2((float)cx, (float)cy, (float)r);
        break;
      case TERRESTRIAL:
        drawTerrestrialLOD2(body, (float)cx, (float)cy, (float)r);
        break;
      case GAS_GIANT:
      case ICE_GIANT:
        drawGasGiantLOD2(body, (float)cx, (float)cy, (float)r);
        break;
    }
    if (body.hasRing) {
      drawRingDetailed(body, (float)cx, (float)cy, (float)r);
    }
  }

  // ============================================================
  //  LOD 3 - Close-up: full detail + atmosphere
  // ============================================================
  void drawLOD3(CelestialBody body, double cx, double cy, double r) {
    noStroke();
    switch (body.type) {
      case SUN:
        drawSunLOD3((float)cx, (float)cy, (float)r);
        break;
      case TERRESTRIAL:
        drawTerrestrialLOD3(body, (float)cx, (float)cy, (float)r);
        break;
      case GAS_GIANT:
      case ICE_GIANT:
        drawGasGiantLOD3(body, (float)cx, (float)cy, (float)r);
        break;
    }
    if (body.hasRing) {
      drawRingDetailed(body, (float)cx, (float)cy, (float)r);
    }
    if (body.hasAtmosphere) {
      drawAtmosphere(body, (float)cx, (float)cy, (float)r);
    }
  }

  // ============================================================
  //  LOD 4 - Fills screen
  // ============================================================
  void drawLOD4(CelestialBody body, double cx, double cy, double r) {
    if (body.type == BodyType.SUN) {
      drawSunSurface();
    } else {
      fill(body.col);
      rect(0, 0, width, height);
    }
  }

  // ============================================================
  //  SUN RENDERING
  // ============================================================
  void drawSunGlow(float cx, float cy, float r, float intensity) {
    int layers = 8;
    for (int i = layers; i > 0; i--) {
      float k = i / (float)layers;
      float glowR = r * (1 + k * 0.8f);
      int alpha = (int)(30 * (1 - k) * intensity);
      fill(255, 200, 100, alpha);
      ellipse(cx, cy, glowR * 2, glowR * 2);
    }
  }

  void drawSunLOD1(float cx, float cy, float r) {
    drawSunGlow(cx, cy, r, 1.0f);
    // Radial gradient core
    for (int i = 20; i > 0; i--) {
      float k = i / 20.0f;
      float rr = r * k;
      fill(255, (int)(230 * k + 30), (int)(80 * k + 20));
      ellipse(cx, cy, rr * 2, rr * 2);
    }
  }

  void drawSunLOD2(float cx, float cy, float r) {
    drawSunGlow(cx, cy, r, 1.2f);
    // Sun with granulation-like noise
    drawSunWithNoise(cx, cy, r, 0.3f);
  }

  void drawSunLOD3(float cx, float cy, float r) {
    drawSunGlow(cx, cy, r, 1.5f);
    drawSunWithNoise(cx, cy, r, 0.5f);
    // Add prominences
    drawSolarProminences(cx, cy, r);
  }

  void drawSunWithNoise(float cx, float cy, float r, float noiseAmount) {
    pushMatrix();
    translate(cx, cy);
    int detail = max(32, (int)(r / 3));
    for (int i = 0; i <= detail; i++) {
      float a1 = TWO_PI * i / detail;
      float a2 = TWO_PI * (i + 1) / detail;
      beginShape(TRIANGLE_FAN);
      vertex(0, 0);
      for (int j = 0; j <= detail / 2; j++) {
        float b = map(j, 0, detail / 2, a1, a2);
        float rad = r;
        float n = noise(cos(b) * 3 + time * 0.1f, sin(b) * 3, j * 0.1f);
        rad *= 0.95f + n * 0.1f * noiseAmount;
        float x = cos(b) * rad;
        float y = sin(b) * rad;
        float bright = 0.85f + n * 0.3f;
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
      float baseR = r * 1.02f;
      float prominenceHeight = r * (0.05f + 0.1f * noise(i * 10, time * 0.05f));
      float bx = cx + cos(angle) * baseR;
      float by = cy + sin(angle) * baseR;
      float tx = cx + cos(angle) * (baseR + prominenceHeight);
      float ty = cy + sin(angle) * (baseR + prominenceHeight);
      fill(255, 150, 80, 80);
      ellipse(tx, ty, prominenceHeight * 0.8f, prominenceHeight * 1.5f);
    }
  }

  void drawSunSurface() {
    // Close-up sun surface with dynamic noise
    for (int y = 0; y < height; y += 3) {
      for (int x = 0; x < width; x += 3) {
        float n = noise(x * 0.01f, y * 0.01f, time * 0.2f);
        float bright = 0.7f + n * 0.5f;
        fill(255, (int)(200 * bright + 55), (int)(80 * bright + 30));
        rect(x, y, 3, 3);
      }
    }
  }

  // ============================================================
  //  TERRESTRIAL PLANET RENDERING
  // ============================================================
  void drawTerrestrialLOD1(CelestialBody body, float cx, float cy, float r) {
    if (body.name.equals("Earth")) {
      drawEarthLOD1(cx, cy, r, body.rotation);
    } else {
      drawSimpleGradient(body.col, cx, cy, r);
    }
  }

  void drawTerrestrialLOD2(CelestialBody body, float cx, float cy, float r) {
    if (body.name.equals("Earth")) {
      drawEarthLOD2(cx, cy, r, body.rotation);
    } else if (body.name.equals("Mars")) {
      drawMarsLOD2(cx, cy, r, body.rotation);
    } else {
      drawSimpleGradient(body.col, cx, cy, r);
    }
  }

  void drawTerrestrialLOD3(CelestialBody body, float cx, float cy, float r) {
    if (body.name.equals("Earth")) {
      drawEarthLOD3(cx, cy, r, body.rotation);
    } else if (body.name.equals("Mars")) {
      drawMarsLOD3(cx, cy, r, body.rotation);
    } else {
      drawSimpleGradient(body.col, cx, cy, r);
    }
  }

  // Earth
  void drawEarthLOD1(float cx, float cy, float r, float rot) {
    drawSimpleGradient(color(70, 130, 230), cx, cy, r);
  }

  void drawEarthLOD2(float cx, float cy, float r, float rot) {
    drawEarthBase(cx, cy, r, rot);
    drawEarthClouds(cx, cy, r, rot);
  }

  void drawEarthLOD3(float cx, float cy, float r, float rot) {
    drawEarthBase(cx, cy, r, rot);
    drawEarthClouds(cx, cy, r, rot);
    drawEarthAtmosphereGlow(cx, cy, r);
  }

  void drawEarthBase(float cx, float cy, float r, float rot) {
    pushMatrix();
    translate(cx, cy);
    rotate(rot);
    int detail = max(24, (int)(r / 4));
    for (int i = 0; i <= detail; i++) {
      float lon = map(i, 0, detail, -PI, PI);
      float lon2 = map(i + 1, 0, detail, -PI, PI);
      beginShape(TRIANGLE_STRIP);
      for (int j = 0; j <= detail / 2; j++) {
        float lat = map(j, 0, detail / 2, -HALF_PI, HALF_PI);
        float x1 = cos(lat) * sin(lon);
        float y1 = sin(lat);
        float x2 = cos(lat) * sin(lon2);
        float y2 = sin(lat);
        float px1 = x1 * r;
        float py1 = y1 * r;
        float px2 = x2 * r;
        float py2 = y2 * r;
        color c = getEarthColor(lon, lat);
        fill(c);
        vertex(px1, py1);
        vertex(px2, py2);
      }
      endShape();
    }
    popMatrix();
  }

  color getEarthColor(float lon, float lat) {
    float n = noise(lon * 2, lat * 3, 0);
    float continentNoise = noise(lon * 1.5f + 100, lat * 2);
    boolean isLand = continentNoise > 0.52f;
    if (abs(lat) > 1.3f) {
      float t = (abs(lat) - 1.3f) / 0.27f;
      return lerpColor(color(70, 130, 220), color(240, 245, 255), t);
    }
    if (isLand) {
      float greenVar = n * 40;
      return color(60 + greenVar, 120 + greenVar, 50 + greenVar * 0.5f);
    } else {
      float blueVar = n * 20;
      return color(20, 80 + blueVar, 180 + blueVar);
    }
  }

  void drawEarthClouds(float cx, float cy, float r, float rot) {
    pushMatrix();
    translate(cx, cy);
    rotate(rot * 1.1f);
    noStroke();
    int detail = max(16, (int)(r / 5));
    for (int i = 0; i <= detail; i++) {
      float lon = map(i, 0, detail, -PI, PI);
      float lon2 = map(i + 1, 0, detail, -PI, PI);
      beginShape(TRIANGLE_STRIP);
      for (int j = 0; j <= detail / 2; j++) {
        float lat = map(j, 0, detail / 2, -HALF_PI, HALF_PI);
        float cloud = noise(lon * 3, lat * 2, time * 0.02f);
        if (cloud > 0.6f) {
          float alpha = map(cloud, 0.6f, 1.0f, 30, 180);
          float x1 = cos(lat) * sin(lon);
          float y1 = sin(lat);
          float x2 = cos(lat) * sin(lon2);
          float y2 = sin(lat);
          fill(255, 255, 255, (int)alpha);
          vertex(x1 * r * 1.01f, y1 * r * 1.01f);
          vertex(x2 * r * 1.01f, y2 * r * 1.01f);
        }
      }
      endShape();
    }
    popMatrix();
  }

  void drawEarthAtmosphereGlow(float cx, float cy, float r) {
    int layers = 6;
    for (int i = layers; i > 0; i--) {
      float k = i / (float)layers;
      float ar = r * (1 + k * 0.15f);
      fill(100, 180, 255, (int)(40 * (1 - k)));
      ellipse(cx, cy, ar * 2, ar * 2);
    }
  }

  // Mars
  void drawMarsLOD2(float cx, float cy, float r, float rot) {
    drawMarsSurface(cx, cy, r, rot);
  }

  void drawMarsLOD3(float cx, float cy, float r, float rot) {
    drawMarsSurface(cx, cy, r, rot);
    drawThinAtmosphere(cx, cy, r, color(255, 200, 180));
  }

  void drawMarsSurface(float cx, float cy, float r, float rot) {
    pushMatrix();
    translate(cx, cy);
    rotate(rot * 0.5f);
    int detail = max(20, (int)(r / 5));
    for (int i = 0; i <= detail; i++) {
      float lon = map(i, 0, detail, -PI, PI);
      float lon2 = map(i + 1, 0, detail, -PI, PI);
      beginShape(TRIANGLE_STRIP);
      for (int j = 0; j <= detail / 2; j++) {
        float lat = map(j, 0, detail / 2, -HALF_PI, HALF_PI);
        float n = noise(lon * 2, lat * 3);
        float x1 = cos(lat) * sin(lon);
        float y1 = sin(lat);
        float x2 = cos(lat) * sin(lon2);
        float y2 = sin(lat);
        int rCol = (int)(180 + n * 60);
        int g = (int)(80 + n * 40);
        int b = (int)(50 + n * 20);
        fill(rCol, g, b);
        vertex(x1 * r, y1 * r);
        vertex(x2 * r, y2 * r);
      }
      endShape();
    }
    popMatrix();
  }

  // ============================================================
  //  GAS GIANT RENDERING
  // ============================================================
  void drawGasGiantLOD1(CelestialBody body, float cx, float cy, float r) {
    drawSimpleGradient(body.col, cx, cy, r);
  }

  void drawGasGiantLOD2(CelestialBody body, float cx, float cy, float r) {
    if (body.name.equals("Jupiter")) {
      drawJupiterLOD2(cx, cy, r, body.rotation);
    } else if (body.name.equals("Saturn")) {
      drawSaturnLOD2(cx, cy, r, body.rotation);
    } else {
      drawGasGiantBands(body.col, cx, cy, r, body.rotation);
    }
  }

  void drawGasGiantLOD3(CelestialBody body, float cx, float cy, float r) {
    if (body.name.equals("Jupiter")) {
      drawJupiterLOD3(cx, cy, r, body.rotation);
    } else if (body.name.equals("Saturn")) {
      drawSaturnLOD3(cx, cy, r, body.rotation);
    } else {
      drawGasGiantBands(body.col, cx, cy, r, body.rotation);
    }
  }

  // Jupiter
  void drawJupiterLOD2(float cx, float cy, float r, float rot) {
    drawJupiterBands(cx, cy, r, rot, false);
  }

  void drawJupiterLOD3(float cx, float cy, float r, float rot) {
    drawJupiterBands(cx, cy, r, rot, true);
  }

  void drawJupiterBands(float cx, float cy, float r, float rot, boolean withSpot) {
    pushMatrix();
    translate(cx, cy);
    rotate(rot * 0.3f);
    int bands = 12;
    for (int i = -bands; i <= bands; i++) {
      float y = i * r / bands;
      float bandHeight = r / bands * 1.5f;
      float bandLat = y / r;
      color c = getJupiterBandColor(bandLat, i);
      fill(c);
      noStroke();
      beginShape();
      for (float a = 0; a <= TWO_PI; a += 0.1f) {
        float x0 = cos(a) * r;
        float y0 = sin(a) * r;
        float dist = abs(y0 - y);
        if (dist < bandHeight) {
          vertex(x0, y0);
        }
      }
      endShape(CLOSE);
    }
    if (withSpot) {
      float spotX = r * 0.3f;
      float spotY = r * 0.3f;
      float spotR = r * 0.15f;
      fill(180, 80, 40);
      ellipse(spotX, spotY, spotR * 2, spotR * 1.3f);
      fill(200, 100, 60, 150);
      ellipse(spotX - spotR * 0.1f, spotY - spotR * 0.1f, spotR * 1.5f, spotR);
    }
    popMatrix();
  }

  color getJupiterBandColor(float lat, int bandIndex) {
    float t = abs(lat);
    if (bandIndex % 3 == 0) {
      return color(210, 180, 140);
    } else if (bandIndex % 3 == 1) {
      return color(180, 140, 100);
    } else {
      return color(150, 100, 70);
    }
  }

  // Saturn
  void drawSaturnLOD2(float cx, float cy, float r, float rot) {
    drawSaturnBody(cx, cy, r, rot);
  }

  void drawSaturnLOD3(float cx, float cy, float r, float rot) {
    drawSaturnBody(cx, cy, r, rot);
  }

  void drawSaturnBody(float cx, float cy, float r, float rot) {
    pushMatrix();
    translate(cx, cy);
    rotate(rot * 0.2f);
    int bands = 8;
    for (int i = -bands; i <= bands; i++) {
      float y = i * r / bands;
      float bandHeight = r / bands * 1.5f;
      float shade = 1 - abs(i) / (float)bands * 0.3f;
      fill((int)(220 * shade), (int)(200 * shade), (int)(150 * shade));
      noStroke();
      beginShape();
      for (float a = 0; a <= TWO_PI; a += 0.1f) {
        float x0 = cos(a) * r;
        float y0 = sin(a) * r;
        float dist = abs(y0 - y);
        if (dist < bandHeight) {
          vertex(x0, y0);
        }
      }
      endShape(CLOSE);
    }
    popMatrix();
  }

  // Generic gas giant
  void drawGasGiantBands(color baseColor, float cx, float cy, float r, float rot) {
    pushMatrix();
    translate(cx, cy);
    rotate(rot * 0.2f);
    int bands = 8;
    for (int i = -bands; i <= bands; i++) {
      float y = i * r / bands;
      float bandHeight = r / bands * 1.5f;
      float shade = 1 - abs(i) / (float)bands * 0.25f;
      fill((int)(red(baseColor) * shade), (int)(green(baseColor) * shade), (int)(blue(baseColor) * shade));
      noStroke();
      beginShape();
      for (float a = 0; a <= TWO_PI; a += 0.1f) {
        float x0 = cos(a) * r;
        float y0 = sin(a) * r;
        float dist = abs(y0 - y);
        if (dist < bandHeight) {
          vertex(x0, y0);
        }
      }
      endShape(CLOSE);
    }
    popMatrix();
  }

  // ============================================================
  //  RINGS
  // ============================================================
  void drawRingSimple(CelestialBody body, float cx, float cy, float r) {
    pushMatrix();
    translate(cx, cy);
    rotate(body.ringTilt);
    float innerR = r * body.ringInnerRadius;
    float outerR = r * body.ringOuterRadius;
    noStroke();
    fill(body.ringColor);
    ellipse(0, 0, outerR * 2, outerR * 0.4f);
    fill(0, 0);
    ellipse(0, 0, innerR * 2, innerR * 0.4f);
    popMatrix();
  }

  void drawRingDetailed(CelestialBody body, float cx, float cy, float r) {
    pushMatrix();
    translate(cx, cy);
    rotate(body.ringTilt + time * 0.01f);
    float innerR = r * body.ringInnerRadius;
    float outerR = r * body.ringOuterRadius;
    int ringLayers = 20;
    noStroke();
    for (int i = 0; i < ringLayers; i++) {
      float k1 = i / (float)ringLayers;
      float k2 = (i + 1) / (float)ringLayers;
      float r1 = innerR + (outerR - innerR) * k1;
      float r2 = innerR + (outerR - innerR) * k2;
      float alpha = 80 + noise(i * 0.5f, time * 0.1f) * 120;
      float variation = 0.8f + noise(i * 2) * 0.4f;
      fill((int)(200 * variation), (int)(180 * variation), (int)(140 * variation), (int)alpha);
      beginShape(QUAD_STRIP);
      for (float a = 0; a <= TWO_PI; a += 0.15f) {
        float cx1 = cos(a) * r1;
        float cy1 = sin(a) * r1 * 0.4f;
        float cx2 = cos(a) * r2;
        float cy2 = sin(a) * r2 * 0.4f;
        vertex(cx1, cy1);
        vertex(cx2, cy2);
      }
      endShape(CLOSE);
    }
    popMatrix();
  }

  // ============================================================
  //  ATMOSPHERE
  // ============================================================
  void drawAtmosphere(CelestialBody body, float cx, float cy, float r) {
    drawThinAtmosphere(cx, cy, r, body.atmosphereColor);
  }

  void drawThinAtmosphere(float cx, float cy, float r, color atmosColor) {
    int layers = 8;
    for (int i = layers; i > 0; i--) {
      float k = i / (float)layers;
      float ar = r * (1 + k * 0.12f);
      fill(red(atmosColor), green(atmosColor), blue(atmosColor), (int)(50 * (1 - k)));
      ellipse(cx, cy, ar * 2, ar * 2);
    }
  }

  // ============================================================
  //  UTILITIES
  // ============================================================
  void drawSimpleGradient(color c, float cx, float cy, float r) {
    int layers = 12;
    for (int i = layers; i > 0; i--) {
      float k = i / (float)layers;
      float rr = r * k;
      float shade = 0.6f + k * 0.5f;
      fill((int)(red(c) * shade), (int)(green(c) * shade), (int)(blue(c) * shade));
      ellipse(cx, cy, rr * 2, rr * 2);
    }
  }
}
