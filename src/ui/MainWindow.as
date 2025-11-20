namespace PluginState {
    class RunRecord {
        uint startedAtMs = 0;
        uint finishedAtMs = 0;
        string folder;
        string quality;
        string saveMode;
        uint indexed = 0;
        uint queued = 0;
        uint done = 0;
        uint skipped = 0;
        uint failed = 0;

        array<string> openErrorMaps;
        array<string> openErrorMsgs;

        uint durationMs() const { return finishedAtMs > startedAtMs ? (finishedAtMs - startedAtMs) : 0; }
        bool isLive()    const { return finishedAtMs == 0; }
    }

    array<RunRecord@> RunHistory;
    RunRecord@ CurrentRun;
}

bool lastRunning = false;

namespace ui {

    string RelToIndexRoot(const string &in abs) {
        string n = PathUtil::NormalizePath(abs);
        string root = PathUtil::NormalizePath(PluginState::SelectedFolder);
        return n.StartsWith(root) ? n.SubStr(root.Length) : n;
    }

    bool PassesFilter(const string &in text, const string &in filter) {
        if (filter.Length == 0) return true;
        string a = text.ToLower();
        string b = filter.ToLower();
        return a.Contains(b);
    }

    void ApplySelectionToFiltered(bool setTo, const array<uint> &in idxs) {
        for (uint k = 0; k < idxs.Length; ++k) {
            string key = PluginState::IndexedMaps[idxs[k]];
            PluginState::MapSelected.Set(key, setTo);
        }
    }

    void InvertSelectionOnFiltered(const array<uint> &in idxs) {
        for (uint k = 0; k < idxs.Length; ++k) {
            string key = PluginState::IndexedMaps[idxs[k]];
            bool cur = true; PluginState::MapSelected.Get(key, cur);
            PluginState::MapSelected.Set(key, !cur);
        }
    }

    void DrawQualityChoice(Quality::Level q) {
        if (UI::Selectable(Quality::ToString(q), PluginState::TargetQuality == q)) {
            PluginState::TargetQuality = q;
            log("Quality selected: " + Quality::ToString(q), LogLevel::Info, 60, "DrawQualityChoice");
        }
    }

    string BuildSaveModeLabel() {
        if (PluginState::SaveChoice == PluginState::SaveMode::InPlace) { return "InPlace"; }
        string sub = PluginState::ExportFolderRelUnderMaps;
        if (sub.Length == 0) sub = ".";
        return "Export: " + sub + " (preserve: " + (PluginState::PreserveSubdirs ? "on" : "off") + ")";
    }

    string FormatMs(uint ms) {
        uint s = ms / 1000;
        uint h = s / 3600; s %= 3600;
        uint m = s / 60;   s %= 60;
        if (h > 0) return h + "h " + m + "m " + s + "s";
        if (m > 0) return m + "m " + s + "s";
        return s + "s";
    }

    string ShortFolder(const string &in abs) {
        string n = PathUtil::NormalizePath(abs);
        int i2 = n.LastIndexOf("/");
        if (i2 < 0) return n;
        int i1 = n.SubStr(0, i2).LastIndexOf("/");
        if (i1 < 0) return n.SubStr(i2 + 1);
        return n.SubStr(i1 + 1);
    }

    void DrawStatsCompact() {
        if (UI::BeginTable("##live-stats", 5, UI::TableFlags::RowBg | UI::TableFlags::BordersInnerH)) {
            UI::TableSetupColumn("Queued");
            UI::TableSetupColumn("Done");
            UI::TableSetupColumn("Skipped");
            UI::TableSetupColumn("Failed");
            UI::TableSetupColumn("Indexed");
            UI::TableHeadersRow();

            UI::TableNextRow();
            UI::TableNextColumn(); UI::Text("" + PluginState::TotalQueued);
            UI::TableNextColumn(); UI::Text("" + PluginState::Completed);
            UI::TableNextColumn(); UI::Text("" + PluginState::Skipped);
            UI::TableNextColumn(); UI::Text("" + PluginState::Failed);
            UI::TableNextColumn(); UI::Text("" + PluginState::TotalIndexed);
            UI::EndTable();
        }
    }

    void UpdateRunHistoryLive() {
        if (PluginState::CurrentRun !is null && PluginState::IsRunning) {
            PluginState::CurrentRun.indexed = PluginState::TotalIndexed;
            PluginState::CurrentRun.queued  = PluginState::TotalQueued;
            PluginState::CurrentRun.done    = PluginState::Completed;
            PluginState::CurrentRun.skipped = PluginState::Skipped;
            PluginState::CurrentRun.failed  = PluginState::Failed;
        }
        bool nowRunning = PluginState::IsRunning;
        if (lastRunning && !nowRunning) {
            if (PluginState::CurrentRun !is null && PluginState::CurrentRun.finishedAtMs == 0) {
                PluginState::CurrentRun.finishedAtMs = Time::Now;
                PluginState::CurrentRun.indexed = PluginState::TotalIndexed;
                PluginState::CurrentRun.queued  = PluginState::TotalQueued;
                PluginState::CurrentRun.done    = PluginState::Completed;
                PluginState::CurrentRun.skipped = PluginState::Skipped;
                PluginState::CurrentRun.failed  = PluginState::Failed;
            }
        }
        lastRunning = nowRunning;
    }

    void RenderRunHistoryMiniTable(const vec2 &in size = vec2(0, 160)) {
        UpdateRunHistoryLive();

        const int kMaxRowsShown = 8;

        if (UI::BeginTable("##runs-mini", 7, UI::TableFlags::RowBg | UI::TableFlags::Borders | UI::TableFlags::ScrollY, size)) {
            UI::TableSetupColumn("#",    UI::TableColumnFlags::WidthFixed, 22);
            UI::TableSetupColumn("Qual", UI::TableColumnFlags::WidthFixed, 60);
            UI::TableSetupColumn("Q'd",  UI::TableColumnFlags::WidthFixed, 40);
            UI::TableSetupColumn("Done", UI::TableColumnFlags::WidthFixed, 44);
            UI::TableSetupColumn("Skip", UI::TableColumnFlags::WidthFixed, 44);
            UI::TableSetupColumn("Fail", UI::TableColumnFlags::WidthFixed, 44);
            UI::TableSetupColumn("Time", UI::TableColumnFlags::WidthFixed, 70);
            UI::TableHeadersRow();

            int total = int(PluginState::RunHistory.Length);
            int start = Math::Max(0, total - kMaxRowsShown);

            for (int i = total - 1; i >= start; --i) {
                auto r = PluginState::RunHistory[uint(i)];
                UI::TableNextRow();

                UI::TableNextColumn(); UI::Text("" + (i + 1) + (r.isLive() ? "*" : ""));
                UI::TableNextColumn(); UI::Text(r.quality);
                UI::TableNextColumn(); UI::Text("" + r.queued);
                UI::TableNextColumn(); UI::Text("" + r.done);
                UI::TableNextColumn(); UI::Text("" + r.skipped);
                UI::TableNextColumn(); UI::Text("" + r.failed);
                UI::TableNextColumn(); UI::Text(r.isLive() ? "..." : FormatMs(r.durationMs()));
            }
            UI::EndTable();
        }
    }

    void RenderMapPicker() {
        UI::Dummy(vec2(0, 6));
        UI::TextDisabled("Maps to compute");
        UI::Separator();

        UI::PushItemWidth(400);
        PluginState::MapsFilter = UI::InputText("Filter", PluginState::MapsFilter);
        UI::PopItemWidth();

        UI::SameLine();
        PluginState::ShowOnlySelected = UI::Checkbox("Show only selected", PluginState::ShowOnlySelected);

        array<uint> idxs;
        idxs.Reserve(PluginState::IndexedMaps.Length);
        uint selectedTotal = 0;
        for (uint i = 0; i < PluginState::IndexedMaps.Length; ++i) {
            string p = PluginState::IndexedMaps[i];
            bool sel = true; PluginState::MapSelected.Get(p, sel);
            if (sel) selectedTotal++;
            if (!RelToIndexRoot(p).ToLower().Contains(PluginState::MapsFilter.ToLower())) continue;
            if (PluginState::ShowOnlySelected && !sel) continue;
            idxs.InsertLast(i);
        }

        UI::Text("Found: " + PluginState::IndexedMaps.Length + "  |  Filtered view: " + idxs.Length + "  |  Selected: " + selectedTotal);
        if (idxs.Length > 0) {
            if (UI::Button(Icons::CheckSquareO + " Select filtered")) { ApplySelectionToFiltered(true, idxs); }
            UI::SameLine();
            if (UI::Button(Icons::SquareO + " Deselect filtered"))   { ApplySelectionToFiltered(false, idxs); }
            UI::SameLine();
            if (UI::Button(Icons::Exchange + " Invert filtered"))    { InvertSelectionOnFiltered(idxs); }
        }

        UI::Dummy(vec2(0, 4));

        bool opened = UI::BeginChild("##maps-list", vec2(1100, 360), true);
        if (opened) {
            UI::ListClipper clip(idxs.Length);
            while (clip.Step()) {
                for (int i = clip.DisplayStart; i < clip.DisplayEnd; i++) {
                    uint mi = idxs[i];
                    string abs = PluginState::IndexedMaps[mi];
                    string rel = RelToIndexRoot(abs);
                    
                    string displayName = rel.Length > 0 ? rel : abs;
                    if (displayName.Length > 0) { displayName = displayName.SubStr(1); }

                    UI::PushID(abs);
                    bool sel = true; PluginState::MapSelected.Get(abs, sel);
                    bool newSel = UI::Checkbox("##sel", sel);
                    UI::SameLine();
                    UI::Text(displayName);
                    if (newSel != sel) PluginState::MapSelected.Set(abs, newSel);
                    UI::PopID();
                }
            }
        }
        UI::EndChild();
    }

    // Main window
    void RenderMainWindow() {
        if (!S_EnabledWindow) return;
        if (!UI::Begin(Icons::MoonO + " Batch Shadow Compute###BatchShadowCompute", S_EnabledWindow, UI::WindowFlags::AlwaysAutoResize)) { UI::End(); return; }

        if (UI::IsWindowAppearing()) {
            startnew(GameBrowserPath::ApplySelectedFolderAndScanFromGameBrowserCoro);
        }

        UI::TextDisabled("1) Pick a folder with maps (.Map.Gbx)");
        UI::Separator();

        UI::PushItemWidth(900);
        string before = PluginState::SelectedFolder;
        PluginState::SelectedFolder = UI::InputText("Folder", PluginState::SelectedFolder);
        UI::PopItemWidth();
        if (PluginState::SelectedFolder != before) { log("Folder text changed: " + PluginState::SelectedFolder, LogLevel::Debug, 240, "RenderMainWindow"); }

        UI::SameLine();
        if (UI::Button(Icons::FolderOpen + " Browse...")) {
            string startPath = PluginState::SelectedFolder;
            if (startPath.Length == 0 || !IO::FolderExists(startPath)) startPath = IO::FromUserGameFolder("Maps/");
            FileExplorer::fe_Start("BatchMapsFolder", true, "path", vec2(1, 1), startPath, "", { }, { "*" });
            log("Opening FileExplorer at: " + startPath, LogLevel::Info, 247, "RenderMainWindow");
        }

        if (UI::IsItemHovered()) {
            UI::SetNextWindowSize(400, 0, UI::Cond::Appearing);
            UI::BeginTooltip();
            UI::TextWrapped("To select a folder, right click the folder and either select 'quick return', to return only that element, or select 'add to selected elements' to add to the list of selected elements (only one can be selected).");
            UI::EndTooltip();
        }

        {
            auto explorer = FileExplorer::fe_GetExplorerById("BatchMapsFolder");
            if (explorer !is null && explorer.exports.IsSelectionComplete()) {
                auto paths = explorer.exports.GetSelectedPaths();
                if (paths !is null && paths.Length > 0) {
                    string p = PathUtil::NormalizePath(paths[0]);
                    if (!IO::FolderExists(p)) p = Path::GetDirectoryName(p);
                    if (IO::FolderExists(p)) {
                        PluginState::SelectedFolder = p;
                        log("Folder selected via explorer: " + p, LogLevel::Notice, 266, "RenderMainWindow", "select", "\\$0af");
                    }
                }
                explorer.exports.SetSelectionComplete();
            }
        }

        UI::SameLine();
        if (UI::Button(Icons::LocationArrow + " From Game Browser")) {
            if (GameBrowserPath::ApplySelectedFolderFromGameBrowser()) {
                UI::ShowNotification("Batch Shadows", "Folder set from Game Browser:\n" + PluginState::SelectedFolder, 4500);
            } else {
                UI::ShowNotification("Batch Shadows", "Could not read a valid 'My local tracks' path.\nOpen the GAME Map Browser and select a local item.", 6000);
            }
        }
        if (UI::IsItemHovered()) {
            UI::SetNextWindowSize(420, 0, UI::Cond::Appearing);
            UI::BeginTooltip();
            UI::TextWrapped("Reads the in-game Map Browser label at overlay 3 → 0/0/0/0/*/0/0/0/3/0.\n"
                            "If it starts with \"%1%2%3My local tracks/\", the remainder is "
                            "taken as a path under your 'Maps' directory (folder only; the final map name is dropped).");
            UI::EndTooltip();
        }

        UI::SameLine();
        UI::PushStyleColor(UI::Col::Button, vec4(0.1, 0.7, 0.1, 0.5));
        if (UI::Button(Icons::Search + " Scan")) {
            log("Scanning for maps in: " + PluginState::SelectedFolder, LogLevel::Info, 293, "RenderMainWindow", "scan");
            auto maps = Indexer::FindMaps(PluginState::SelectedFolder);
            for (uint i = 0; i < maps.Length; ++i) maps[i] = PathUtil::NormalizePath(maps[i]);
            PluginState::IndexedMaps = maps;
            BatchRunner::ReconcileSelectionsAfterIndex(PluginState::IndexedMaps);
            log("Scan complete. Found " + PluginState::IndexedMaps.Length + " maps.", LogLevel::Notice, 298, "RenderMainWindow", "scan");
        }
        UI::PopStyleColor();

        if (UI::IsItemHovered()) {
            UI::SetNextWindowSize(400, 0, UI::Cond::Appearing);
            UI::BeginTooltip();
            UI::TextWrapped("After setting a folder (manual, Browse..., or From Game Browser), click 'Scan' to index all .Map.Gbx files.");
            UI::EndTooltip();
        }

        UI::Dummy(vec2(0, 6));
        UI::TextDisabled("2) Save / Quality / History / Compute");
        UI::Separator();

        const float kSaveWeight    = 1.0f;
        const float kQualWeight    = 1.0f;
        const float kHistWeight    = 1.4f;
        const float kComputeWeight = 1.0f;

        if (UI::BeginTable("##save-qual-hist-comp",
                           4,
                           UI::TableFlags::RowBg | UI::TableFlags::BordersInnerV | UI::TableFlags::SizingStretchProp))
        {
            UI::TableSetupColumn("##save-col",    UI::TableColumnFlags::WidthStretch, kSaveWeight);
            UI::TableSetupColumn("##qual-col",    UI::TableColumnFlags::WidthStretch, kQualWeight);
            UI::TableSetupColumn("##hist-col",    UI::TableColumnFlags::WidthStretch, kHistWeight);
            UI::TableSetupColumn("##compute-col", UI::TableColumnFlags::WidthStretch, kComputeWeight);

            UI::TableNextRow();

            // Column 1: Save to
            UI::TableNextColumn();
            {
                UI::TextDisabled("Save");
                UI::Separator();

                bool selInPlace = PluginState::SaveChoice == PluginState::SaveMode::InPlace;
                if (UI::RadioButton("Same location as source (if under 'Maps/')", selInPlace)) {
                    PluginState::SaveChoice = PluginState::SaveMode::InPlace;
                    log("Save mode: InPlace", LogLevel::Info, 338, "RenderMainWindow");
                }

                bool selExport = PluginState::SaveChoice == PluginState::SaveMode::Export;
                if (UI::RadioButton("Export to folder under 'Maps'", selExport)) {
                    PluginState::SaveChoice = PluginState::SaveMode::Export;
                    log("Save mode: Export", LogLevel::Info, 344, "RenderMainWindow");
                }

                if (PluginState::SaveChoice == PluginState::SaveMode::Export) {
                    UI::Indent();
                    UI::Text("Subfolder (under 'Maps/'):");
                    UI::PushItemWidth(380);
                    string prev = PluginState::ExportFolderRelUnderMaps;
                    PluginState::ExportFolderRelUnderMaps = PathUtil::StripLeadingMaps(
                        UI::InputText("##exportSubfolder", PluginState::ExportFolderRelUnderMaps)
                    );
                    UI::PopItemWidth();
                    if (PluginState::ExportFolderRelUnderMaps != prev) {
                        log("Export subfolder changed: " + PluginState::ExportFolderRelUnderMaps, LogLevel::Debug, 357, "RenderMainWindow");
                    }

                    UI::SameLine();
                    if (UI::Button(Icons::FolderOpen + " Choose...")) {
                        string start = IO::FromUserGameFolder(Path::Join("Maps", PluginState::ExportFolderRelUnderMaps));
                        if (!IO::FolderExists(start)) start = IO::FromUserGameFolder("Maps/");
                        FileExplorer::fe_Start("BatchSaveFolder", true, "path", vec2(1, 1), start, "", {}, {});
                    }

                    auto saveExplorer = FileExplorer::fe_GetExplorerById("BatchSaveFolder");
                    if (saveExplorer !is null && saveExplorer.exports.IsSelectionComplete()) {
                        auto paths = saveExplorer.exports.GetSelectedPaths();
                        if (paths !is null && paths.Length > 0) {
                            string selected = PathUtil::NormalizePath(paths[0]);
                            if (!IO::FolderExists(selected)) selected = Path::GetDirectoryName(selected);

                            string rel;
                            if (PathUtil::ToMapsRelativeFolder(selected, rel)) {
                                rel = PathUtil::StripLeadingMaps(rel);
                                PluginState::ExportFolderRelUnderMaps = rel;
                                log("Export subfolder selected: " + rel, LogLevel::Notice, 378, "RenderMainWindow", "select", "\\$0af");
                            } else {
                                UI::ShowNotification("Batch Shadows", "Please choose a folder inside your 'Maps' directory.");
                                log("Attempted to select export folder outside 'Maps': " + selected, LogLevel::Warning, 381, "RenderMainWindow");
                            }
                        }
                        saveExplorer.exports.SetSelectionComplete();
                    }

                    PluginState::PreserveSubdirs = UI::Checkbox("Preserve folder structure relative to index root", PluginState::PreserveSubdirs);
                    UI::Unindent();
                }
            }

            // Column 2: Quality + live stats
            UI::TableNextColumn();
            {
                UI::TextDisabled("Quality");
                UI::Separator();

                if (UI::BeginCombo("Shadows Quality", Quality::ToString(PluginState::TargetQuality))) {
                    DrawQualityChoice(Quality::Level::VeryFast);
                    DrawQualityChoice(Quality::Level::Fast);
                    DrawQualityChoice(Quality::Level::Default);
                    DrawQualityChoice(Quality::Level::High);
                    DrawQualityChoice(Quality::Level::Ultra);
                    UI::EndCombo();
                }

                bool prevSkip = PluginState::SkipAlreadyGood;
                PluginState::SkipAlreadyGood = UI::Checkbox("Skip maps already at or above selected quality", PluginState::SkipAlreadyGood);
                if (PluginState::SkipAlreadyGood != prevSkip) {
                    log("SkipAlreadyGood changed: " + (PluginState::SkipAlreadyGood ? "true" : "false"), LogLevel::Debug, 410, "RenderMainWindow");
                }

                UI::Dummy(vec2(0, 8));
            }

            // Column 3: History
            UI::TableNextColumn();
            {
                UI::TextDisabled("History");
                UI::Separator();

                if (UI::Button(Icons::Trash + " Clear")) {
                    PluginState::RunHistory.RemoveRange(0, PluginState::RunHistory.Length);
                    @PluginState::CurrentRun = null;
                }
                UI::SameLine();
                UI::TextDisabled("last runs");

                UI::Dummy(vec2(0, 4));
                RenderRunHistoryMiniTable(vec2(0, 160));
            }

            // Column 4: Compute
            UI::TableNextColumn();
            {
                UI::TextDisabled("Compute");
                UI::Separator();

                uint selCount = 0, estQueue = 0;
                for (uint i = 0; i < PluginState::IndexedMaps.Length; ++i) {
                    string m = PluginState::IndexedMaps[i];
                    bool sel = true; PluginState::MapSelected.Get(m, sel);
                    if (!sel) continue;
                    selCount++;
                    if (PluginState::SkipAlreadyGood && ProgressStore::MeetsOrExceeds(m, PluginState::TargetQuality)) { continue; }
                    estQueue++;
                }

                UI::Text("Selected: " + selCount);
                UI::Text("Est. queue: " + estQueue);

                UI::Dummy(vec2(0, 4));

                if (!PluginState::IsRunning) {
                    UI::BeginDisabled(estQueue == 0);
                    if (UI::ButtonColored(Icons::Play + "  Start compute", 0.33f)) {
                        log("Compute clicked.", LogLevel::Notice, 457, "RenderMainWindow", "start", "\\$0f0");

                        auto rec = PluginState::RunRecord();
                        rec.startedAtMs = Time::Now;
                        rec.folder      = PluginState::SelectedFolder;
                        rec.quality     = Quality::ToString(PluginState::TargetQuality);
                        rec.saveMode    = BuildSaveModeLabel();
                        rec.indexed     = PluginState::IndexedMaps.Length;
                        PluginState::RunHistory.InsertLast(rec);
                        @PluginState::CurrentRun = rec;

                        BatchRunner::Start(PluginState::SelectedFolder, PluginState::TargetQuality, PluginState::SkipAlreadyGood);
                    }
                    UI::EndDisabled();

                    if (estQueue == 0) { UI::TextDisabled("Nothing to compute with current selections."); }
    
                    UI::Dummy(vec2(0, 8));

                    DrawStatsCompact();

                    UI::Dummy(vec2(0, 6));
                    if (PluginState::CurrentRun !is null && PluginState::CurrentRun.openErrorMaps.Length > 0) {
                        UI::Text("\\$fb0" + Icons::ExclamationTriangle + " Open errors: " + PluginState::CurrentRun.openErrorMaps.Length);
                        if (UI::IsItemHovered()) {
                            UI::SetNextWindowSize(520, 0, UI::Cond::Appearing);
                            UI::BeginTooltip();
                            UI::TextDisabled("Maps that showed an open-error dialog:");
                            UI::Separator();
                            for (uint i = 0; i < PluginState::CurrentRun.openErrorMaps.Length; ++i) {
                                string m = PluginState::CurrentRun.openErrorMaps[i];
                                string e = PluginState::CurrentRun.openErrorMsgs[i];

                                if (UI::Selectable("\\$bbb" + m, false)) { IO::SetClipboard(m); }
                                if (e.Length > 0) UI::TextWrapped(e);

                                if (i + 1 < PluginState::CurrentRun.openErrorMaps.Length) UI::Separator();
                            }
                            UI::EndTooltip();
                        }
                    }

                } else {
                    UI::Text("\\$3B9" + Icons::HourglassStart + " Running...");
                    UI::SameLine();
                    if (UI::Button(Icons::Stop + " Stop")) {
                        log("Stop clicked.", LogLevel::Warning, 503, "RenderMainWindow", "stop", "\\$fb0");
                        BatchRunner::Stop();
                    }
                }
            }

            UI::EndTable();
        }

        RenderMapPicker();

        UI::End();
    }
}
