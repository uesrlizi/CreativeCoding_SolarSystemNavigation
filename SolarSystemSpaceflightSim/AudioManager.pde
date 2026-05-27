// ========== AUDIO MANAGER ==========
class AudioManager {
  // === 音频文件 ===
  SoundFile bgm;
  SoundFile burnSound;

  // === 状态 ===
  boolean bgmPlaying;
  boolean burnSoundPlaying;
  float burnSoundVolume;

  // === 主程序引用 ===
  PApplet parent;

  // === 构造函数 ===
  AudioManager() {
    this.parent = SolarSystemSpaceflightSim.this;
    this.bgmPlaying = false;
    this.burnSoundPlaying = false;
    this.burnSoundVolume = 0.5f;
  }

  // === 初始化 ===
  void setup() {
    // 加载音频文件
    try {
      bgm = new SoundFile(parent, "Nebula Circuitry.mp3");
      burnSound = new SoundFile(parent, "burning.mp3");
      println("Audio files loaded successfully");
    } catch (Exception e) {
      println("Error loading audio files: " + e.getMessage());
    }
  }

  // === BGM控制 ===
  void playBGM() {
    if (bgm != null && !bgmPlaying) {
      bgm.loop();
      bgm.amp(0.1f); // 10%音量
      bgmPlaying = true;
    }
  }

  void pauseBGM() {
    if (bgm != null && bgmPlaying) {
      bgm.pause();
      bgmPlaying = false;
    }
  }

  void stopBGM() {
    if (bgm != null) {
      bgm.stop();
      bgmPlaying = false;
    }
  }

  void setBGMVolume(float volume) {
    if (bgm != null) {
      bgm.amp(constrain(volume, 0, 1));
    }
  }

  // === 燃烧音效控制 ===
  void playBurnSound() {
    if (burnSound != null && !burnSoundPlaying) {
      burnSound.loop();
      burnSound.amp(burnSoundVolume);
      burnSoundPlaying = true;
    }
  }

  void stopBurnSound() {
    if (burnSound != null && burnSoundPlaying) {
      burnSound.stop();
      burnSoundPlaying = false;
    }
  }

  void setBurnSoundVolume(float volume) {
    burnSoundVolume = constrain(volume, 0, 1);
    if (burnSound != null && burnSoundPlaying) {
      burnSound.amp(burnSoundVolume);
    }
  }

  // === 根据油门更新燃烧音效 ===
  void updateBurnSound(float throttle) {
    if (throttle > 0.01f) {
      if (!burnSoundPlaying) {
        playBurnSound();
      }
    } else {
      if (burnSoundPlaying) {
        stopBurnSound();
      }
    }
  }

  // === 清理 ===
  void dispose() {
    if (bgm != null) bgm.stop();
    if (burnSound != null) burnSound.stop();
  }
}
