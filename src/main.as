Meta::Plugin@ pluginMeta = Meta::ExecutingPlugin();
const string  pluginNameHash = Crypto::MD5(pluginMeta.Name);
const string  menuIconColor = "\\$" + pluginNameHash.SubStr(0, 3);
const string  pluginIcon = _Text::GetRandomIcon(pluginNameHash); // Replace with an apropriate specific icon
const string  menuTitle = menuIconColor + pluginIcon + "\\$z " + pluginMeta.Name;


// ----- //

namespace PluginState {
    bool ShowWindow = true;
    bool IsRunning = false;
    string SelectedFolder = IO::FromUserGameFolder("Maps/");
    Quality::Level TargetQuality = Quality::Level::High;
    bool SkipAlreadyGood = true;
    bool StopRequested = false;

    uint TotalIndexed = 0, TotalQueued = 0, Completed = 0, Skipped = 0, Failed = 0;

    BusyOverlay::State Busy;

    array<string> IndexedMaps;
    dictionary    MapSelected;
    string        MapsFilter = "";
    bool          ShowOnlySelected = false;

    enum SaveMode { InPlace = 0, Export = 1 }
    SaveMode SaveChoice = SaveMode::InPlace;
    string   ExportFolderRelUnderMaps = "BatchShadowCompute";
    bool     PreserveSubdirs = true;
}

void Main() {
    EditorMonitor::Run();
    ProgressStore::Load();
}

void RenderInterface() {
    if (!S_Enabled || (S_HideWithGame && !UI::IsGameUIVisible()) || (S_HideWithOP && !UI::IsOverlayShown())) { return; }
 
    RenderWindow();
}

void Render() {
    BusyHUD::RenderBusyOverlayHUD(PluginState::Busy);
}

const string kMenuTitle = Icons::MoonO + " Batch Shadow Compute";
void RenderMenu() {
    if (UI::MenuItem(kMenuTitle, "", PluginState::ShowWindow)) {
        PluginState::ShowWindow = !PluginState::ShowWindow;
    }
}


// ----- //

void RenderWindow() {
    FILE_EXPLORER_BASE_RENDERER();
    ui::RenderMainWindow();
    ui::RenderBusyOverlay(PluginState::Busy);
}