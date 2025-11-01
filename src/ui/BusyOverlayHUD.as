namespace BusyHUD {
    void RenderBusyOverlayHUD(BusyOverlay::State@ st) {
        if (st is null || !st.active) return;

        float sw = float(Draw::GetWidth());
        float sh = float(Draw::GetHeight());
        if (sw <= 0 || sh <= 0) return;

        nvg::BeginPath();
        nvg::Rect(0, 0, sw, sh);
        nvg::FillColor(vec4(0, 0, 0, 0.45));
        nvg::Fill();

        float panelW = Math::Min(700.0f, sw * 0.85f);
        float panelH = 150.0f;
        float px = (sw - panelW) * 0.5f;
        float py = sh * 0.28f;

        nvg::BeginPath();
        nvg::RoundedRect(px, py, panelW, panelH, 12.0f);
        nvg::FillColor(vec4(0.08f, 0.08f, 0.10f, 0.92f));
        nvg::Fill();

        string title = st.header.Length > 0 ? st.header : "Computing shadows...";
        nvg::FillColor(vec4(1, 1, 1, 1));
        nvg::FontSize(28.0f);
        nvg::TextAlign(nvg::Align::Center | nvg::Align::Middle);
        nvg::Text(px + panelW * 0.5f, py + 40.0f, title);

        if (st.sub.Length > 0) {
            nvg::FillColor(vec4(0.95f, 0.95f, 0.98f, 1));
            nvg::FontSize(20.0f);
            nvg::Text(px + panelW * 0.5f, py + 78.0f, st.sub);
        }

        if (st.detail.Length > 0) {
            nvg::FillColor(vec4(0.80f, 0.85f, 0.95f, 1));
            nvg::FontSize(16.0f);
            nvg::Text(px + panelW * 0.5f, py + 110.0f, st.detail);
        }
    }
}
