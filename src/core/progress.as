namespace ProgressStore {
    dictionary MapQuality;

    void Load() { MapQuality.DeleteAll(); }
    void Clear() { MapQuality.DeleteAll(); }

    bool MeetsOrExceeds(const string &in path, Quality::Level target) {
        string s;
        if (!MapQuality.Get(path, s)) return false;
        return int(Quality::FromString(s)) >= int(target);
    }

    void Update(const string &in path, Quality::Level q) {
        MapQuality.Set(path, Quality::ToString(q));
        log("Mem progress: >= " + Quality::ToString(q) + " for " + path, LogLevel::Debug, 15, "Update");
    }
}
