
namespace GameBrowserPath {
    const uint   kOverlay   = 3;
    const string kLabelPath = "0/0/0/0/21/0/0/0/3/0";

    const string kPrefix = "%1%2%3My local tracks/";

    bool TryReadRawLabel(string &out label) {
        label = "";
        auto node = UINavEx::ResolvePath(kLabelPath, kOverlay);
        if (node is null) {
            log("GameBrowserPath: label node not found at overlay=3, path=" + kLabelPath, LogLevel::Debug, 12, "TryReadRawLabel");
            return false;
        }
        label = UINavEx::ReadText(node);
        if (label.Length == 0) {
            log("GameBrowserPath: label empty.", LogLevel::Debug, 17, "TryReadRawLabel");
            return false;
        }
        return true;
    }

    bool TryExtractLocalTracksRel(string &out rel, string &out rawLabel) {
        rel = "";
        if (!TryReadRawLabel(rawLabel)) return false;
        if (!rawLabel.StartsWith(kPrefix)) {
            log("GameBrowserPath: label does not start with expected prefix. label='" + rawLabel + "'", LogLevel::Debug, 27, "TryExtractLocalTracksRel");
            return false;
        }

        string rest = rawLabel.SubStr(kPrefix.Length);

        rest = rest.Replace("/", "/");
        rest = rest.Replace("", "");
        rest = rest.Replace("", "");
        rest = rest.Replace("\\", "/");
        rest = rest.Trim();

        while (rest.StartsWith("/")) rest = rest.SubStr(1);
        while (rest.EndsWith("/"))   rest = rest.SubStr(0, rest.Length - 1);

        if (rest.Length == 0) return false;
        rel = rest;
        return true;
    }

    bool ApplySelectedFolderFromGameBrowser() {
        string rel, raw;
        if (!TryExtractLocalTracksRel(rel, raw)) return false;

        string folderRel = rel;
        int lastSlash = folderRel.LastIndexOf("/");
        if (lastSlash >= 0) folderRel = folderRel.SubStr(0, lastSlash);
        else folderRel = "";

        string abs = IO::FromUserGameFolder(folderRel.Length > 0 ? Path::Join("Maps", folderRel) : "Maps");
        abs = PathUtil::NormalizePath(abs);
        PluginState::SelectedFolder = abs;

        log("GameBrowserPath: SelectedFolder set from GAME Map Browser. raw='" + raw + "' rel='" + rel + "' finalFolderRel='" + folderRel + "' abs='" + abs + "'", LogLevel::Notice, 60, "ApplySelectedFolderFromGameBrowser", "autofolder", "\\$0af");

        return true;
    }
}
