namespace Quality {
    enum Level { NotComputed = 0, VeryFast = 1, Fast = 2, Default = 3, High = 4, Ultra = 5 }

    CGameEditorPluginMap::EShadowsQuality ToEngine(Level q) {
        switch (q) {
            case Level::VeryFast: return CGameEditorPluginMap::EShadowsQuality::VeryFast;
            case Level::Fast:     return CGameEditorPluginMap::EShadowsQuality::Fast;
            case Level::Default:  return CGameEditorPluginMap::EShadowsQuality::Default;
            case Level::High:     return CGameEditorPluginMap::EShadowsQuality::High;
            case Level::Ultra:    return CGameEditorPluginMap::EShadowsQuality::Ultra;
            default:              return CGameEditorPluginMap::EShadowsQuality::Default;
        }
    }

    string ToString(Level q) {
        switch (q) {
            case Level::VeryFast: return "VeryFast";
            case Level::Fast:     return "Fast";
            case Level::Default:  return "Default";
            case Level::High:     return "High";
            case Level::Ultra:    return "Ultra";
            default:              return "NotComputed";
        }
    }

    Level FromString(const string &in s) {
        string t = s.ToLower();
        if (t == "veryfast") return Level::VeryFast;
        if (t == "fast")     return Level::Fast;
        if (t == "default")  return Level::Default;
        if (t == "high")     return Level::High;
        if (t == "ultra" || t == "ultra2") return Level::Ultra;
        return Level::NotComputed;
    }
}
