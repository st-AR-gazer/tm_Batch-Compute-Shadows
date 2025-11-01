namespace EditorMonitor {
    bool lastPresent = false;

    void Run() {
        log("EditorMonitor started (poll=150ms).", LogLevel::Debug, 5, "Run");

        while (true) {
            yield(150);

            auto edBase = GetApp().Editor;
            bool present = edBase !is null;

            if (present && !lastPresent) {
                log("Editor instance detected. Waiting for PluginMapType...", LogLevel::Notice, 14, "Run");
                startnew(WaitEditorReadyAndSignal);
            }

            if (!present && lastPresent) {
                log("Editor instance closed/unloaded.", LogLevel::Notice, 19, "Run");
                BatchRunner::SignalEditorClosed();
            }

            lastPresent = present;
        }
    }

    void WaitEditorReadyAndSignal() {
        uint t0 = Time::Now;
        uint until = t0 + S_SignalingWindow; // 20s
        while (Time::Now < until) {
            auto ed = cast<CGameCtnEditorFree>(GetApp().Editor);
            if (ed !is null && ed.PluginMapType !is null) {
                log("Editor ready (PluginMapType available) after " + (Time::Now - t0) + " ms.", LogLevel::Info, 33, "WaitEditorReadyAndSignal");
                BatchRunner::SignalEditorReady();
                return;
            }
            yield(33);
        }
        log("Editor never became ready within " + S_SignalingWindow + " ms window. Signaling closed.", LogLevel::Warning, 39, "WaitEditorReadyAndSignal");
        BatchRunner::SignalEditorClosed();
    }
}
