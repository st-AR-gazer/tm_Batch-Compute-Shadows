namespace Indexer {
    array<string> FindMaps(const string &in folderAbs) {
        uint t0 = Time::Now;
        array<string> results;
        if (!IO::FolderExists(folderAbs)) { log("Folder not found: " + folderAbs, LogLevel::Error, 5, "FindMaps"); return results; }

        log("Indexing folder: " + folderAbs, LogLevel::Info, 7, "FindMaps");
        auto listing = IO::IndexFolder(folderAbs, true);
        for (uint i = 0; i < listing.Length; i++) {
            auto p = listing[i];
            if (p.EndsWith(".Map.Gbx") || p.EndsWith(".map.gbx")) results.InsertLast(p);
        }

        log("Indexing complete: " + results.Length + " *.Map.Gbx in " + (Time::Now - t0) + " ms.", LogLevel::Info, 14, "FindMaps");
        return results;
    }
}
