namespace UINavEx {

    // ---------------- Root & path parsing ----------------

    CControlFrame@ RootAtOverlay(uint overlay = 16) {
        CGameCtnApp@ app = GetApp();
        if (app is null || app.Viewport is null) return null;

        CDx11Viewport@ vp = cast<CDx11Viewport>(app.Viewport);
        if (vp is null) return null;
        if (overlay >= vp.Overlays.Length) return null;

        CHmsZoneOverlay@ ov = cast<CHmsZoneOverlay>(vp.Overlays[overlay]);
        if (ov is null || ov.UserData is null) return null;

        CSceneSector@ sector = cast<CSceneSector>(ov.UserData);
        if (sector is null || sector.Scene is null) return null;

        CScene2d@ scene = cast<CScene2d>(sector.Scene);
        if (scene.Mobils.Length == 0 || scene.Mobils[0] is null) return null;

        CControlFrameStyled@ rootStyled = cast<CControlFrameStyled>(scene.Mobils[0]);
        if (rootStyled !is null) return cast<CControlFrame>(rootStyled);

        CControlFrame@ rootFrame = cast<CControlFrame>(scene.Mobils[0]);
        if (rootFrame !is null) return rootFrame;

        return null;
    }

    void _ParsePath(const string &in spec, array<int> &out parts, array<bool> &out wildcards) {
        parts.Resize(0); wildcards.Resize(0);
        string[] tokens = spec.Split("/");
        for (uint i = 0; i < tokens.Length; ++i) {
            string s = tokens[i].Trim();
            if (s.Length == 0 || s == "*") { parts.InsertLast(0); wildcards.InsertLast(true); }
            else                            { parts.InsertLast(Text::ParseInt(s)); wildcards.InsertLast(false); }
        }
    }

    // --------------- Generic container helpers ---------------

    uint _ChildrenLen(CControlBase@ node) {
        if (node is null) return 0;
        CControlFrame@ f = cast<CControlFrame>(node);
        if (f !is null) return f.Childs.Length;
        CControlListCard@ lc = cast<CControlListCard>(node);
        if (lc !is null) return lc.Childs.Length;
        CControlGrid@ g = cast<CControlGrid>(node);
        if (g !is null) return g.Childs.Length;
        return 0;
    }

    CControlBase@ _ChildAt(CControlBase@ node, uint idx) {
        if (node is null) return null;
        CControlFrame@ f = cast<CControlFrame>(node);
        if (f !is null) { if (idx < f.Childs.Length) return f.Childs[idx]; return null; }
        CControlListCard@ lc = cast<CControlListCard>(node);
        if (lc !is null) { if (idx < lc.Childs.Length) return lc.Childs[idx]; return null; }
        CControlGrid@ g = cast<CControlGrid>(node);
        if (g !is null) { if (idx < g.Childs.Length) return g.Childs[idx]; return null; }
        return null;
    }

    // ---------------- Path resolve / click / text ----------------

    CControlBase@ ResolvePath(const string &in spec, uint overlay = 16, CControlBase@ start = null) {
        CControlBase@ cur = start;
        if (cur is null) {
            CControlFrame@ root = RootAtOverlay(overlay);
            if (root is null) return null;
            @cur = root;
        }

        array<int> idx; array<bool> wc;
        _ParsePath(spec, idx, wc);

        for (uint i = 0; i < idx.Length; ++i) {
            if (wc[i]) {
                uint len = _ChildrenLen(cur);
                bool advanced = false;
                for (uint c = 0; c < len; ++c) {
                    CControlBase@ ch = _ChildAt(cur, c);
                    if (ch is null) continue;
                    @cur = ch;
                    advanced = true;
                    break;
                }
                if (!advanced) return null;
            } else {
                int k = idx[i];
                if (k < 0) return null;
                uint uk = uint(k);
                uint len = _ChildrenLen(cur);
                if (uk >= len) return null;
                CControlBase@ ch = _ChildAt(cur, uk);
                if (ch is null) return null;
                @cur = ch;
            }
        }
        return cur;
    }

    bool ClickPath(const string &in spec, uint overlay = 16) {
        CControlBase@ n = ResolvePath(spec, overlay);
        if (n is null) return false;

        CControlQuad@ q = cast<CControlQuad>(n);
        if (q !is null) { q.OnAction(); return true; }

        CControlButton@ b = cast<CControlButton>(n);
        if (b !is null) { b.OnAction(); return true; }

        CGameControlCardGeneric@ card = cast<CGameControlCardGeneric>(n);
        if (card !is null) { card.OnAction(); return true; }

        uint len = _ChildrenLen(n);
        for (uint i = 0; i < len; ++i) {
            CControlBase@ ch = _ChildAt(n, i);
            if (ch is null) continue;
            CControlQuad@ q0 = cast<CControlQuad>(ch);
            if (q0 !is null) { q0.OnAction(); return true; }
            CControlButton@ b0 = cast<CControlButton>(ch);
            if (b0 !is null) { b0.OnAction(); return true; }
            CGameControlCardGeneric@ cg0 = cast<CGameControlCardGeneric>(ch);
            if (cg0 !is null) { cg0.OnAction(); return true; }
        }
        return false;
    }

    bool SetTextPath(const string &in spec, const string &in text, uint overlay = 16) {
        CControlBase@ n = ResolvePath(spec, overlay);
        if (n is null) return false;

        CControlEntry@ e = cast<CControlEntry>(n);
        if (e !is null) {
            CGameManialinkEntry@ ml = cast<CGameManialinkEntry>(e.Nod);
            if (ml is null) return false;
            ml.SetText(text, true);
            return true;
        }

        CControlFrame@ f = cast<CControlFrame>(n);
        if (f !is null) {
            CControlEntry@ e2 = cast<CControlEntry>(f.Nod);
            if (e2 !is null) {
                CGameManialinkEntry@ ml2 = cast<CGameManialinkEntry>(e2.Nod);
                if (ml2 is null) return false;
                ml2.SetText(text, true);
                return true;
            }
        }
        return false;
    }

    // ---------------- Existence / wait / label search ----------------

    bool Exists(const string &in spec, uint overlay = 16) {
        return ResolvePath(spec, overlay) !is null;
    }

    bool WaitForPath(const string &in spec, uint overlay = 16, int timeoutMs = 4000, int pollMs = 33) {
        uint until = Time::Now + uint(timeoutMs);
        while (Time::Now < until) {
            if (Exists(spec, overlay)) return true;
            yield(pollMs);
        }
        return false;
    }

    bool SubtreeHasLabel(CControlBase@ node, const string &in txt) {
        if (node is null) return false;

        CControlLabel@ lbl = cast<CControlLabel>(node);
        if (lbl !is null && lbl.Label == txt) return true;

        uint len = _ChildrenLen(node);
        for (uint i = 0; i < len; ++i) {
            CControlBase@ ch = _ChildAt(node, i);
            if (SubtreeHasLabel(ch, txt)) return true;
        }
        return false;
    }

    string ReadText(CControlBase@ n) {
        if (n is null) return "";

        CControlEntry@ e = cast<CControlEntry>(n);
        if (e !is null) {
            return e.String;
        }

        CControlFrame@ f = cast<CControlFrame>(n);
        if (f !is null) {
            CControlEntry@ e2 = cast<CControlEntry>(f.Nod);
            if (e2 !is null) {
                return e2.String;
            }
        }

        CControlLabel@ lbl = cast<CControlLabel>(n);
        if (lbl !is null) return lbl.Label;

        return "";
    }

}
