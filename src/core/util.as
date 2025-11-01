namespace PathUtil {
    string NormalizePath(const string &in p) {
        string r = "";
        for (uint i = 0; i < uint(p.Length); ++i) {
            string ch = p.SubStr(i, 1);
            r += (ch == "\\" ? "/" : ch);
        }
        return r;
    }

    string MapsRootAbs() {
        return NormalizePath(IO::FromUserGameFolder("Maps/"));
    }

    bool ToMapsRelative(const string &in abs, string &out relUnderMaps) {
        string base = MapsRootAbs();
        string s = NormalizePath(abs);
        if (s.StartsWith(base)) {
            relUnderMaps = s.SubStr(base.Length);
            return true;
        }
        relUnderMaps = "";
        return false;
    }

    bool ToMapsRelativeFolder(const string &in absFolder, string &out relFolderUnderMaps) {
        return ToMapsRelative(absFolder, relFolderUnderMaps);
    }

    string StripLeadingMaps(const string &in maybeWithMaps) {
        string s = NormalizePath(maybeWithMaps);
        return s.StartsWith("Maps/") ? s.SubStr(5) : s;
    }

    string Join2(const string &in a, const string &in b) {
        if (a.EndsWith("/")) return a + b;
        return a + "/" + b;
    }

    bool EnsureMapsSubfolderExists(const string &in relUnderMaps) {
        string relDir = Path::GetDirectoryName(relUnderMaps);
        string absDir = IO::FromUserGameFolder(Path::Join("Maps", relDir));
        if (!IO::FolderExists(absDir)) IO::CreateFolder(absDir, true);
        return IO::FolderExists(absDir);
    }
}
