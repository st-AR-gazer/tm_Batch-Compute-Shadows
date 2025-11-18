namespace BatchRunner {

    class ComputeJob {
        string mapAbs;
        string saveRelUnderMaps;
        Quality::Level target;
        uint idx;
        uint total;

        bool opened = false;
        bool started = false;
        bool success = false;
        bool failed  = false;
        uint tStartOpen = 0;
        uint tStartCompute = 0;
        uint tFinishCompute = 0;

        bool finished() const { return success || failed; }
    }

    enum Outcome { Success = 0, Skipped = 1, Failed = 2 }

    const uint   kOpenErrOverlay   = 8;
    const string kOpenErrLabelPath = "1/0/2/0";
    const string kOpenErrClickPath = "1/0/2/1/1/0";

    ComputeJob@ gJob = null;

    string ComputeSaveRelUnderMaps(const string &in absFile) {
        string nameOnly = Path::GetFileName(absFile);
        string relUnderMapsSrc;
        bool srcInMaps = PathUtil::ToMapsRelative(absFile, relUnderMapsSrc);

        if (PluginState::SaveChoice == PluginState::SaveMode::InPlace && !srcInMaps) { log("Source not under 'Maps/'. Falling back to Export.", LogLevel::Warning, 34, "ComputeSaveRelUnderMaps"); }

        if (PluginState::SaveChoice == PluginState::SaveMode::InPlace && srcInMaps) { return relUnderMapsSrc; }

        string exportRoot = PathUtil::StripLeadingMaps(PluginState::ExportFolderRelUnderMaps);
        if (exportRoot.EndsWith("/")) exportRoot = exportRoot.SubStr(0, exportRoot.Length - 1);

        string relPiece;
        if (PluginState::PreserveSubdirs) {
            string idxRoot = PathUtil::NormalizePath(PluginState::SelectedFolder);
            string fileAbs = PathUtil::NormalizePath(absFile);
            if (fileAbs.StartsWith(idxRoot)) {
                relPiece = fileAbs.SubStr(idxRoot.Length);
            } else if (srcInMaps) {
                relPiece = relUnderMapsSrc;
            } else {
                relPiece = nameOnly;
            }
        } else {
            relPiece = nameOnly;
        }

        if (relPiece.StartsWith("/")) relPiece = relPiece.SubStr(1);
        return PathUtil::Join2(exportRoot, relPiece);
    }

    void ReconcileSelectionsAfterIndex(const array<string> &in newMaps) {
        dictionary newSel;
        for (uint i = 0; i < newMaps.Length; ++i) {
            string k = PathUtil::NormalizePath(newMaps[i]);
            bool prev; bool had = PluginState::MapSelected.Get(k, prev);
            newSel.Set(k, had ? prev : true);
        }
        PluginState::MapSelected.DeleteAll();
        auto keys = newSel.GetKeys();
        for (uint i = 0; i < keys.Length; ++i) {
            bool v; newSel.Get(keys[i], v);
            PluginState::MapSelected.Set(keys[i], v);
        }
    }

    void Start(const string &in folder, Quality::Level target, bool skipAlreadyGood) {
        if (PluginState::IsRunning) { log("Start called but a batch is already running.", LogLevel::Warning, 76, "Start"); return; }

        ProgressStore::Clear();

        log("Starting batch. folder='" + folder + "', target=" + Quality::ToString(target) + ", skipAlreadyGood=" + (skipAlreadyGood ? "true" : "false"), LogLevel::Info, 80, "Start");

        PluginState::SelectedFolder = folder;
        PluginState::TargetQuality = target;
        PluginState::SkipAlreadyGood = skipAlreadyGood;
        PluginState::StopRequested = false;

        PluginState::TotalIndexed = PluginState::TotalQueued = 0;
        PluginState::Completed = PluginState::Skipped = PluginState::Failed = 0;

        {
            string dummy;
            if (PluginState::SaveChoice == PluginState::SaveMode::InPlace
                && !PathUtil::ToMapsRelativeFolder(PluginState::SelectedFolder, dummy))
            {
                PluginState::SaveChoice = PluginState::SaveMode::Export;
                log("Index root is not inside 'Maps/'. Switching Save mode to Export.", LogLevel::Warning, 96, "Start");
            }
        }

        startnew(Coroutine_RunBatch);
    }

    void Stop() { PluginState::StopRequested = true; log("Stop requested by user.", LogLevel::Notice, 103, "Stop"); }

    void Coroutine_RunBatch() {
        PluginState::IsRunning = true;

        array<string> maps;
        if (PluginState::IndexedMaps.Length > 0) {
            maps = PluginState::IndexedMaps;
            log("Using pre-indexed list: " + maps.Length + " maps.", LogLevel::Info, 111, "Coroutine_RunBatch");
        } else {
            uint t0 = Time::Now;
            maps = Indexer::FindMaps(PluginState::SelectedFolder);
            PluginState::IndexedMaps = maps;
            log("Index complete. Found " + maps.Length + " candidate files in " + (Time::Now - t0) + " ms.", LogLevel::Info, 116, "Coroutine_RunBatch");
            ReconcileSelectionsAfterIndex(maps);
        }
        PluginState::TotalIndexed = maps.Length;

        array<string> queue;
        uint selectedCount = 0;
        for (uint i = 0; i < maps.Length; i++) {
            string m = PathUtil::NormalizePath(maps[i]);
            bool sel = true;
            PluginState::MapSelected.Get(m, sel);
            if (!sel) continue;

            selectedCount++;
            if (PluginState::SkipAlreadyGood && ProgressStore::MeetsOrExceeds(m, PluginState::TargetQuality)) {
                PluginState::Skipped++;
                continue;
            }
            queue.InsertLast(m);
        }
        PluginState::TotalQueued = queue.Length;

        log("Queue built. selected=" + selectedCount + " / " + maps.Length + ", queued=" + PluginState::TotalQueued + ", skippedByMem=" + PluginState::Skipped, LogLevel::Info, 138, "Coroutine_RunBatch");

        for (uint i = 0; i < queue.Length; i++) {
            if (PluginState::StopRequested) { log("Batch aborted by user.", LogLevel::Warning, 141, "Coroutine_RunBatch"); break; }

            Outcome oc = ProcessOne(queue[i], PluginState::TargetQuality, i, queue.Length);
            if (oc == Outcome::Success) {
                PluginState::Completed++;
            } else if (oc == Outcome::Skipped) {
                PluginState::Skipped++;
            } else {
                PluginState::Failed++;
            }
        }

        log("Batch finished. done=" + PluginState::Completed + ", filtered=" + (selectedCount - queue.Length + PluginState::Skipped) + ", failed=" + PluginState::Failed, LogLevel::Notice, 153, "Coroutine_RunBatch");

        UI::ShowNotification("Batch Shadows", "Run finished - Done: " + PluginState::Completed + ", Skipped: " + PluginState::Skipped + ", Failed: " + PluginState::Failed, 4500);

        if (PluginState::CurrentRun !is null) {
            int oe = int(PluginState::CurrentRun.openErrorMaps.Length);
            if (oe > 0) {
                UI::ShowNotification("Batch Shadows", "Skipped due to open errors: " + oe + " (hover the latest History row for details)", 8000);
            }
        }

        PluginState::IsRunning = false;
        PluginState::Busy.active = false;
    }

    Outcome ProcessOne(const string &in mapAbs, Quality::Level target, uint idx, uint total) {
        log("Begin map: " + mapAbs + " (" + (idx + 1) + "/" + total + "), target=" + Quality::ToString(target), LogLevel::Info, 169, "Coroutine_RunBatch");
        if (!Permissions::OpenAdvancedMapEditor()) { log("Insufficient access tier to open editor. Aborting this map.", LogLevel::Error, 170, "Coroutine_RunBatch"); return Outcome::Failed; }
        if (PluginState::SkipAlreadyGood && ProgressStore::MeetsOrExceeds(mapAbs, target)) { log("Skip (mem says already >= target).", LogLevel::Notice, 171, "Coroutine_RunBatch", "skip"); return Outcome::Skipped; }
        string destRel = ComputeSaveRelUnderMaps(mapAbs);
        log("Save target (rel under Maps): " + destRel, LogLevel::Debug, 173, "Coroutine_RunBatch");
        if (gJob !is null) { log("Internal error: gJob already set.", LogLevel::Critical, 174, "Coroutine_RunBatch"); return Outcome::Failed; }

        @gJob = ComputeJob();
        gJob.mapAbs           = mapAbs;
        gJob.saveRelUnderMaps = destRel;
        gJob.target           = target;
        gJob.idx              = idx;
        gJob.total            = total;

        ReturnToMenu(true);

        auto app = cast<CGameManiaPlanet>(GetApp());
        if (app is null || app.ManiaTitleControlScriptAPI is null) {
            log("TitleControlScriptAPI unavailable; cannot EditMap.", LogLevel::Error, 187, "Coroutine_RunBatch");
            gJob.failed = true; @gJob = null; return Outcome::Failed;
        }

        log("EditMap (ABS) attempt: " + mapAbs, LogLevel::Debug, 191, "Coroutine_RunBatch", "open");
        gJob.tStartOpen = Time::Now;
        app.ManiaTitleControlScriptAPI.EditMap(mapAbs, "", "");
        gJob.opened = true;

        string openErr;
        if (DetectMapOpenErrorDialog(openErr)) {
            RecordOpenError(mapAbs, openErr);
            BackToMenuNoWait();
            if (gJob !is null) { gJob.failed = false; gJob.started = false; gJob.success = false; }
            @gJob = null;
            return Outcome::Skipped;
        }

        if (!WaitEditorReadyBlocking(60000)) {
            if (gJob !is null) gJob.failed = true;
            log("Editor did not become ready within 60s. Aborting this map.", LogLevel::Warning, 207, "Coroutine_RunBatch");
            @gJob = null;
            return Outcome::Failed;
        } else {
            DoComputeAndSave(gJob);
        }

        bool ok = gJob.success;
        @gJob = null;
        return ok ? Outcome::Success : Outcome::Failed;
    }

    bool WaitEditorReadyBlocking(uint timeoutMs) {
        uint t0 = Time::Now;
        uint until = t0 + timeoutMs;

        while (Time::Now < until && !PluginState::StopRequested) {
            auto ed = cast<CGameCtnEditorFree>(GetApp().Editor);
            if (ed !is null && ed.PluginMapType !is null) { log("Editor ready after " + (Time::Now - t0) + " ms.", LogLevel::Info, 225, "WaitEditorReadyBlocking"); return true; }
            yield(50);
        }
        return false;
    }

    bool WaitForShadowsFinish(CGameCtnEditorFree@ ed,
                              Quality::Level target,
                              uint hardTimeoutMs = S_HardTimeoutMinutes * 60 * 1000,
                              uint stableMs      = 1500,
                              uint pollMs        = 150)
    {
        if (ed is null || ed.PluginMapType is null) return false;

        const int want = int(Quality::ToEngine(target));
        uint t0 = Time::Now;
        uint lastChange = t0;
        uint nextLog = t0 + 5000;

        int lastQ = int(ed.PluginMapType.CurrentShadowsQuality);
        log("WaitForShadowsFinish: start (current=" + lastQ + ", target=" + want + ")", LogLevel::Debug, 245, "WaitEditorReadyBlocking");

        PluginState::Busy.showTimer    = true;
        PluginState::Busy.timerPrefix  = "Target: " + Quality::ToString(target) + " · waiting… ";
        PluginState::Busy.timerStartMs = t0;

        while (Time::Now - t0 < hardTimeoutMs && !PluginState::StopRequested) {
            auto edNow = cast<CGameCtnEditorFree>(GetApp().Editor);
            if (edNow is null || edNow.PluginMapType is null) {
                log("Editor disappeared while waiting for shadows.", LogLevel::Warning, 254, "WaitEditorReadyBlocking");
                return false;
            }

            int cur = int(edNow.PluginMapType.CurrentShadowsQuality);
            if (cur != lastQ) {
                log("Shadows quality changed: " + lastQ + " -> " + cur, LogLevel::Debug, 260, "WaitEditorReadyBlocking");
                lastQ = cur;
                lastChange = Time::Now;
            }

            bool reachedTarget = cur >= want;
            bool stableEnough  = (Time::Now - lastChange) >= stableMs;

            if (reachedTarget && stableEnough) {
                log("WaitForShadowsFinish: done (quality=" + cur + ", elapsed=" + (Time::Now - t0) + " ms)", LogLevel::Info, 269, "WaitEditorReadyBlocking");
                return true;
            }

            if (Time::Now >= nextLog) {
                log("Waiting for shadows… current=" + cur + ", target=" + want + " (" + ((Time::Now - t0) / 1000) + "s)", LogLevel::Debug, 274, "WaitEditorReadyBlocking");
                nextLog += 5000;
            }

            yield(pollMs);
        }

        log("WaitForShadowsFinish: timed out after " + (Time::Now - t0) + " ms", LogLevel::Warning, 281, "WaitEditorReadyBlocking");
        return false;
    }

    void DoComputeAndSave(ComputeJob@ job) {
        if (job is null) { log("DoComputeAndSave: null job.", LogLevel::Error, 286, "DoComputeAndSave"); return; }

        auto ed = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (ed is null || ed.PluginMapType is null) {
            log("DoComputeAndSave called but editor not ready; aborting.", LogLevel::Warning, 290, "DoComputeAndSave");
            job.failed = true;
            return;
        }

        yield(); yield();

        auto curQ = ed.PluginMapType.CurrentShadowsQuality;
        log("Current map quality (before): " + int(curQ), LogLevel::Debug, 298, "DoComputeAndSave");
        if (PluginState::SkipAlreadyGood && int(curQ) >= int(Quality::ToEngine(job.target))) {
            log("Already >= target; skipping compute.", LogLevel::Notice, 300, "DoComputeAndSave", "skip");
            ProgressStore::Update(job.mapAbs, job.target);
            BackToMenuNoWait();
            job.started = true;
            job.success = true;
            return;
        }

        PluginState::Busy.active       = true;
        PluginState::Busy.header       = "Computing shadows...";
        PluginState::Busy.sub          = Path::GetFileName(job.mapAbs) + "  (" + (job.idx + 1) + " / " + job.total + ")";
        PluginState::Busy.detail       = "";
        PluginState::Busy.showTimer    = true;
        PluginState::Busy.timerPrefix  = "Target: " + Quality::ToString(job.target) + " · computing… ";
        PluginState::Busy.timerStartMs = Time::Now;

        yield();

        job.started = true;
        job.tStartCompute = Time::Now;
        log("ComputeShadows1 started at target=" + Quality::ToString(job.target), LogLevel::Info, 320, "DoComputeAndSave", "compute");
        ed.PluginMapType.ComputeShadows1(Quality::ToEngine(job.target));

        PluginState::Busy.timerPrefix  = "Target: " + Quality::ToString(job.target) + " · waiting… ";
        PluginState::Busy.timerStartMs = Time::Now;

        bool finished = WaitForShadowsFinish(ed, job.target);
        if (!finished) { log("Shadows did not report finished in time; attempting to save anyway.", LogLevel::Warning, 327, "DoComputeAndSave", "compute"); }

        job.tFinishCompute = Time::Now;
        log("ComputeShadows1 finished. New quality: " + int(ed.PluginMapType.CurrentShadowsQuality), LogLevel::Info, 330, "DoComputeAndSave", "compute");

        if (!PathUtil::EnsureMapsSubfolderExists(job.saveRelUnderMaps)) {
            log("Could not create folders for: " + job.saveRelUnderMaps, LogLevel::Error, 333, "DoComputeAndSave", "save");
            PluginState::Busy.showTimer = false;
            PluginState::Busy.active = false;
            BackToMenuNoWait();
            job.failed = true;
            return;
        }

        ed.PluginMapType.SaveMap(job.saveRelUnderMaps);
        log("Map saved (under Maps/): " + job.saveRelUnderMaps, LogLevel::Notice, 342, "DoComputeAndSave", "save");

        ProgressStore::Update(job.mapAbs, job.target);

        PluginState::Busy.showTimer = false;
        PluginState::Busy.active = false;

        BackToMenuNoWait();

        job.success = finished;
    }

    void ReturnToMenu(bool yieldTillReady = false) {
        auto app = cast<CGameManiaPlanet>(GetApp());
        if (app is null) { log("ReturnToMenu: app null", LogLevel::Error, 356, "ReturnToMenu"); return; }

        if (app.Network !is null && app.Network.PlaygroundClientScriptAPI !is null
         && app.Network.PlaygroundClientScriptAPI.IsInGameMenuDisplayed
         && app.Network.PlaygroundInterfaceScriptHandler !is null)
        {
            log("Closing in-game menu via handler...", LogLevel::Debug, 362, "ReturnToMenu");
            app.Network.PlaygroundInterfaceScriptHandler.CloseInGameMenu(CGameScriptHandlerPlaygroundInterface::EInGameMenuResult::Quit);
        }

        app.BackToMainMenu();
        log("BackToMainMenu called.", LogLevel::Debug, 367, "ReturnToMenu");

        if (yieldTillReady) {
            uint t0 = Time::Now;
            while (app.ManiaTitleControlScriptAPI is null || !app.ManiaTitleControlScriptAPI.IsReady) yield();
            log("TitleControl IsReady after " + (Time::Now - t0) + " ms.", LogLevel::Debug, 372, "ReturnToMenu");
        }
    }

    void BackToMenuNoWait() {
        auto app = cast<CGameManiaPlanet>(GetApp());
        if (app is null) return;
        app.BackToMainMenu();
        log("BackToMainMenu (no wait).", LogLevel::Debug, 380, "BackToMenuNoWait");
    }

    void SignalEditorReady() { log("SignalEditorReady received (monitor).", LogLevel::Debug, 383, "SignalEditorReady"); }

    void SignalEditorClosed() {
        if (gJob !is null && !gJob.started) {
            gJob.failed = true;
            log("Editor closed before compute could start; marking job as failed.", LogLevel::Warning, 388, "SignalEditorClosed");
        }
        PluginState::Busy.active = false;
    }

    void RecordOpenError(const string &in mapAbs, const string &in msg) {
        log("Open-error dialog for map: " + mapAbs + " — skipping. Message: " + msg, LogLevel::Warning, 394, "RecordOpenError");
        if (PluginState::CurrentRun !is null) {
            PluginState::CurrentRun.openErrorMaps.InsertLast(mapAbs);
            PluginState::CurrentRun.openErrorMsgs.InsertLast(msg);
        }
    }

    bool DetectMapOpenErrorDialog(string &out dialogText, int timeoutMs = 6000, int pollMs = 33) {
        dialogText = "";
        if (!UINavEx::WaitForPath(kOpenErrLabelPath, kOpenErrOverlay, timeoutMs, pollMs)) return false;

        CControlBase@ n = UINavEx::ResolvePath(kOpenErrLabelPath, kOpenErrOverlay);
        dialogText = UINavEx::ReadText(n);

        bool clicked = UINavEx::ClickPath(kOpenErrClickPath, kOpenErrOverlay);
        if (!clicked) { log("Open-error dialog present but click failed (path=" + kOpenErrClickPath + ")", LogLevel::Warning, 409, "DetectMapOpenErrorDialog"); }
        yield(50);
        return true;
    }
}
