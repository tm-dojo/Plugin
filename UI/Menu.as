string CheckMarkIcon(bool checked)
{
    return checked
        ? Icons::CheckSquareO
        : Icons::SquareO;
}

string CheckMarkWithLabel(bool checked, string label)
{
    return CheckMarkIcon(checked) + "  " + label;
}

void RenderMenu()
{
    string menuTitle = "";
    if (g_dojo.checkingServer) {
        menuTitle = ORANGE + Icons::Wifi + "\\$z TMDojo";
    } else {
        menuTitle = (g_dojo.serverAvailable ? GREEN : RED) + Icons::Wifi + "\\$z TMDojo";
    }

    if (UI::BeginMenu(menuTitle)) {
		if (UI::MenuItem(Enabled ? "Turn OFF" : "Turn ON", "", false, true)) {
            Enabled = !Enabled;
            if (Enabled) {
                startnew(Api::authenticatePluginWaitForValidWebId);
            }
		}

        string otherApi = ApiUrl == LOCAL_API ? REMOTE_API : LOCAL_API;
        string otherUi = ApiUrl == LOCAL_API ? REMOTE_UI : LOCAL_UI;
        if (DevMode && UI::MenuItem("Switch to " + otherApi + " " + otherUi , "", false, true)) {
            ApiUrl = otherApi;
            UiUrl = otherUi;
            startnew(Api::authenticatePluginWaitForValidWebId);
		}

        if (UI::MenuItem(CheckMarkWithLabel(OverlayEnabled, "Overlay"), "", false, true)) {
            OverlayEnabled = !OverlayEnabled;
		}

        if (DevMode && UI::MenuItem(CheckMarkWithLabel(DebugOverlayEnabled, "Debug Overlay"), "", false, true)) {
            DebugOverlayEnabled = !DebugOverlayEnabled;
		}

        if (UI::MenuItem(CheckMarkWithLabel(SaveReplaysWithRespawns, "Save replays with respawns") , "", false, true)) {
            SaveReplaysWithRespawns = !SaveReplaysWithRespawns;
		}

        if (!g_dojo.serverAvailable && !g_dojo.checkingServer) {
            if (UI::MenuItem("Check server", "", false, true)) {
                startnew(Api::authenticatePluginWaitForValidWebId);
            }
        }

        if (g_dojo.pluginAuthed) {
            if (UI::MenuItem(GREEN + Icons::Plug + " Plugin Authenticated")) {
                g_dojo.authWindowOpened = true;
            }
            if (UI::MenuItem(ORANGE + Icons::SignOut + " Logout")) {
               startnew(Api::logout);
            }
        } else {
            if (UI::MenuItem(ORANGE + Icons::Plug + " Authenticate Plugin")) {
                g_dojo.authWindowOpened = true;
            }
        }

		UI::EndMenu();
	}
}