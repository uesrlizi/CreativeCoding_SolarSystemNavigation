class SaveDataManager {
  String saveFilePath;

  SaveDataManager() {
    saveFilePath = sketchPath("solarsystem_save.json");
  }

  void save(double simTime, double timeWarp, int warpIndex) {
    try {
      JSONObject json = new JSONObject();
      json.setFloat("simTime", (float)simTime);
      json.setFloat("timeWarp", (float)timeWarp);
      json.setInt("warpIndex", warpIndex);
      saveJSONObject(json, saveFilePath);
    } catch (Exception e) {
      println("Save failed: " + e.getMessage());
    }
  }

  SaveData load() {
    try {
      JSONObject json = loadJSONObject(saveFilePath);
      if (json == null) return null;

      SaveData data = new SaveData();
      data.simTime = json.getFloat("simTime");
      data.timeWarp = json.getFloat("timeWarp");
      data.warpIndex = json.getInt("warpIndex");
      return data;
    } catch (Exception e) {
      println("Load failed: " + e.getMessage());
      return null;
    }
  }
}

class SaveData {
  double simTime = 0;
  double timeWarp = 1.0;
  int warpIndex = 5;
}
