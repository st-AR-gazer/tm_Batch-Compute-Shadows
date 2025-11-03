namespace BusyOverlay {
    class State {
        bool active = false;
        string header;
        string sub;
        string detail;
        UI::Texture@ texture;
    }
}

namespace ui {
    void RenderBusyOverlay(BusyOverlay::State@ st) {
        if (st is null || !st.active) return;

        int w = Draw::GetWidth();
        int h = Draw::GetHeight();

        UI::PushStyleVar(UI::StyleVar::WindowRounding, 8.0f);
        UI::PushStyleColor(UI::Col::WindowBg, vec4(0, 0, 0, 0.85));
        UI::SetNextWindowPos(int(w * 0.5f), int(h * 0.2f), UI::Cond::Always, 0.5f, 0.0f);

        if (UI::Begin("###busy-overlay", S_EnabledWindow, UI::WindowFlags::NoTitleBar | UI::WindowFlags::AlwaysAutoResize | UI::WindowFlags::NoInputs)) {
            UI::Text(Icons::Hourglass + " " + st.header);
            if (st.texture !is null) UI::Image(st.texture, vec2(512, 128));
            if (st.sub.Length > 0) UI::Text("\\$bbb" + st.sub);
            if (st.detail.Length > 0) UI::TextDisabled(st.detail);
        }
        UI::End();

        UI::PopStyleColor();
        UI::PopStyleVar();
    }
}
