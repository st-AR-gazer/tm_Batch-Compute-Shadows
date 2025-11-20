namespace GameBrowserPath {
    const uint kOverlay = 3;

    const string kLabelPathSpec = "0/0/0/*<20><21><22><23>/0/0/0/3/0";
    const string kNeedle        = "My local tracks";
    const string kPrefix        = "%1%2%3My local tracks/";


    string _NormalizeLabel(const string &in s) {
        string r = UINavEx::CleanUiFormatting(s);
        r = r.Replace("%1", "").Replace("%2", "").Replace("%3", "");
        r = r.Replace("\\", "/");
        while (r.Contains("//")) r = r.Replace("//", "/");
        return r.Trim();
    }

    string _AbsUnderMapsFromRel(const string &in rel) {
        return PathUtil::NormalizePath(IO::FromUserGameFolder(Path::Join("Maps", rel)));
    }

    void _ComputeBestFolderForRel(const string &in rel, string &out bestAbs, string &out lastSeg) {
        lastSeg = "";

        if (rel.Length == 0) {
            bestAbs = PathUtil::NormalizePath(IO::FromUserGameFolder("Maps/"));
            return;
        }

        int sl = rel.LastIndexOf("/");
        lastSeg = (sl >= 0) ? rel.SubStr(sl + 1) : rel;

        string absCandidate = _AbsUnderMapsFromRel(rel);
        if (IO::FolderExists(absCandidate)) {
            bestAbs = absCandidate;
            return;
        }

        string parentRel = (sl >= 0) ? rel.SubStr(0, sl) : "";
        string absParent = IO::FromUserGameFolder(parentRel.Length > 0 ? Path::Join("Maps", parentRel) : "Maps");
        bestAbs = PathUtil::NormalizePath(absParent);
    }


    bool TryReadRawLabel(string &out label) {
        label = "";

        {
            int[] prefix = {0,0,0,0};
            int[] hop    = {20,21,22,23};
            int[] suffix = {0,0,0,3,0};
            CControlBase@ n = UINavEx::ResolveWithHopAnyRoot(prefix, hop, suffix, kOverlay, kNeedle, 24);
            if (n !is null) {
                string s = UINavEx::ReadText(n);
                if (s.Length > 0) { label = s; return true; }
            }
        }

        {
            CControlBase@ n = UINavEx::ResolvePathAnyRoot(kLabelPathSpec, kOverlay, 24);
            if (n !is null) {
                string s = UINavEx::ReadText(n);
                if (s.Length > 0) { label = s; return true; }
            }
        }

        return false;
    }


    bool TryReadRawLabelCoro(string &out label, int timeoutMs = 3500) {
        label = "";

        if (TryReadRawLabel(label)) return true;

        uint deadline = Time::Now + uint(timeoutMs);

        string found;
        CControlLabel@ lbl = UINavEx::FindLabelStartsWithBudgeted(kNeedle, found, kOverlay, 18, 500, deadline);
        if (lbl is null)
            @lbl = UINavEx::FindLabelContainsBudgeted(kNeedle, found, kOverlay, 18, 500, deadline);

        if (lbl !is null) {
            label = lbl.Label;
            return true;
        }

        return false;
    }

    bool TryExtractLocalTracksRelFromRaw(const string &in rawLabel, string &out rel) {
        rel = "";
        string flat = _NormalizeLabel(rawLabel);
        const string anchor = kNeedle + "/";

        int pos = flat.ToLower().IndexOf(anchor.ToLower());
        if (pos >= 0) {
            string rest = flat.SubStr(pos + anchor.Length).Trim();
            while (rest.StartsWith("/")) rest = rest.SubStr(1);
            while (rest.EndsWith("/"))   rest = rest.SubStr(0, rest.Length - 1);
            if (rest.Length == 0) return false;
            rel = rest;
            return true;
        }

        if (!rawLabel.StartsWith(kPrefix)) return false;

        string rest2 = rawLabel.SubStr(kPrefix.Length);
        rest2 = rest2.Replace("/", "/").Replace("", "").Replace("", "");
        rest2 = rest2.Replace("\\", "/").Trim();
        while (rest2.StartsWith("/")) rest2 = rest2.SubStr(1);
        while (rest2.EndsWith("/"))   rest2 = rest2.SubStr(0, rest2.Length - 1);
        if (rest2.Length == 0) return false;

        rel = rest2;
        return true;
    }

    bool ApplySelectedFolderFromGameBrowser() {
        string raw, rel;
        if (!TryReadRawLabel(raw)) return false;
        if (!TryExtractLocalTracksRelFromRaw(raw, rel)) return false;

        string abs, lastSeg;
        _ComputeBestFolderForRel(rel, abs, lastSeg);
        PluginState::SelectedFolder = abs;
        if (lastSeg.Length > 0) {
            PluginState::MapsFilter = lastSeg;
        }
        return true;
    }

    void ApplySelectedFolderFromGameBrowserCoro() {
        string raw;
        if (!TryReadRawLabelCoro(raw, 3500)) {
            UI::ShowNotification("Batch Shadows", "Could not read a valid 'My local tracks' path.\nOpen the GAME Map Browser and select a local item.", 6000);
            return;
        }

        string rel;
        if (!TryExtractLocalTracksRelFromRaw(raw, rel)) {
            UI::ShowNotification("Batch Shadows", "Found label, but couldn't parse a Maps/ relative path.", 6000);
            return;
        }

        string abs, lastSeg;
        _ComputeBestFolderForRel(rel, abs, lastSeg);
        PluginState::SelectedFolder = abs;
        if (lastSeg.Length > 0) PluginState::MapsFilter = lastSeg;

        UI::ShowNotification("Batch Shadows", "Folder set from Game Browser:\n" + PluginState::SelectedFolder, 4500);
    }

    void ApplySelectedFolderAndScanFromGameBrowserCoro() {
        string raw;
        if (!TryReadRawLabelCoro(raw, 2000)) return;

        string rel;
        if (!TryExtractLocalTracksRelFromRaw(raw, rel)) return;

        string abs, lastSeg;
        _ComputeBestFolderForRel(rel, abs, lastSeg);
        PluginState::SelectedFolder = abs;
        if (lastSeg.Length > 0) PluginState::MapsFilter = lastSeg;

        auto maps = Indexer::FindMaps(PluginState::SelectedFolder);
        for (uint i = 0; i < maps.Length; ++i)
            maps[i] = PathUtil::NormalizePath(maps[i]);

        PluginState::IndexedMaps = maps;
        BatchRunner::ReconcileSelectionsAfterIndex(PluginState::IndexedMaps);

    }
}
