namespace Api {
    bool UploadingReplay = false;
    // Workaround method for checkServer to ensure checkServer is only called when webId and playerLogin are not the equal
    void checkServerWaitForValidWebId() {
        while (g_dojo.network.PlayerInfo.Login == g_dojo.network.PlayerInfo.WebServicesUserId) {
            sleep(50);
            yield();
        }

        startnew(Api::checkServer);
    }

    void checkServer() {
        g_dojo.checkingServer = true;
        g_dojo.playerName = g_dojo.network.PlayerInfo.Name;
        g_dojo.playerLogin = g_dojo.network.PlayerInfo.Login;
        g_dojo.webId = g_dojo.network.PlayerInfo.WebServicesUserId;

        Net::HttpRequest@ auth = Net::HttpGet(ApiUrl + "/auth?name=" + g_dojo.playerName + "&login=" + g_dojo.playerLogin + "&webid=" + g_dojo.webId + "&sessionId=" + SessionId + "&pluginVersion=" + g_dojo.version);
        while (!auth.Finished()) {
            yield();
            sleep(50);
        }
        if (auth.String().get_Length() > 0) {
            Json::Value json = Json::Parse(auth.String());

            if (json.GetType() != Json::Type::Null) {
                print("HasKey authUrl: " + json.HasKey("authURL"));
                print("HasKey authSuccess: " + json.HasKey("authSuccess"));

                if (json.HasKey("authURL")) {
                    try {
                        g_dojo.pluginAuthUrl = json["authURL"];
                        ClientCode = json["clientCode"];
                        SessionId = "";
                        UI::ShowNotification("TMDojo", "Plugin needs authentication!\n\nF3 → Scripts → TMDojo → Authenticate Plugin", 10000);
                    } catch {
                        error("checkServer json error");
                    }
                }
                if (json.HasKey("authSuccess")) {
                    g_dojo.pluginAuthed = true;
                    UI::ShowNotification("TMDojo", "Plugin is authenticated!", SUCCESS_COLOR);
                }
            } else {
                UI::ShowNotification("TMDojo", "checkServer() Error: Json response is null", ERROR_COLOR);
            }
            
            g_dojo.serverAvailable = true;
        } else {
            g_dojo.serverAvailable = false;
        }
        g_dojo.checkingServer = false;
    }

    void logout() {
        string logoutBody = "{\"sessionId\":\"" + SessionId + "\"}";
        Net::HttpRequest@ req = Net::HttpPost(ApiUrl + "/logout?pluginVersion=" + g_dojo.version, logoutBody, "application/json");
        while (!req.Finished()) {
            yield();
            sleep(50);
        }
        
        int status = req.ResponseCode();
        if (status == 200) {
            UI::ShowNotification("TMDojo", "Plugin logged out!", SUCCESS_COLOR);
            SessionId = "";
            g_dojo.pluginAuthed = false;
            startnew(Api::checkServerWaitForValidWebId);
        } else {
            UI::ShowNotification("TMDojo", "Failed to logout, please try again!", ERROR_COLOR);
        }
    }

    void authenticatePlugin() {
        OpenBrowserURL(g_dojo.pluginAuthUrl);
        startnew(getPluginAuth);
    }

    void getPluginAuth() {
        g_dojo.isAuthenticating = true;
        while (g_dojo.checkSessionIdCount < MAX_CHECK_SESSION_ID) {
            sleep(1000);
            g_dojo.checkSessionIdCount++;
            Net::HttpRequest@ auth = Net::HttpGet(ApiUrl + "/auth/pluginSecret?clientCode=" + ClientCode+ "&pluginVersion=" + g_dojo.version);
            while (!auth.Finished()) {
                yield();
                sleep(50);
            }
            try {
                Json::Value json = Json::Parse(auth.String());
                SessionId = json["sessionId"];
                UI::ShowNotification("TMDojo", "Plugin is authenticated!", SUCCESS_COLOR, 10000);
                g_dojo.pluginAuthed = true;
                g_dojo.checkSessionIdCount = 0;
                ClientCode = "";
                break;
            } catch {
                
            }
        }
        g_dojo.isAuthenticating = false;
        if (g_dojo.checkSessionIdCount >= MAX_CHECK_SESSION_ID) {
            UI::ShowNotification("TMDojo", "Plugin authentication took too long, please try again", ERROR_COLOR, 10000);
            g_dojo.checkSessionIdCount = 0;
        }
    }

    // Parse list of uint values as a string joined by a comma delimiter
    // [1,2,3,4,5] -> "1,2,3,4,5"
    string SectorTimesToString(array<uint> times) {
        string result = "";
        for (uint i = 0; i < times.Length; i++) {
            result += times[i] + "";
            if (i < times.Length - 1) {
                result += ",";
            }
        }
        return result;
    }

    void PostRecordedData(ref @handle) {

        // Copy databuffer so TMDojo can keep recording with a clean state
        g_dojo.membuff.Seek(0);
        string dataBase64 = g_dojo.membuff.ReadToBase64(g_dojo.membuff.GetSize());
        uint64 bufferSize = g_dojo.membuff.GetSize();

        g_dojo.Reset();

        // Abort if server isn't available
        if (!g_dojo.serverAvailable) {
            print("[TMDojo]: Abort upload, server not available");
            return;
        }

        // Abort if plugin is disabled
        if (!Enabled) {
            print("[TMDojo]: Abort upload, plugin disabled");
            return;
        } 
        
        // Abort save if buffer is too small
        if (bufferSize < 10000) {
            print("[TMDojo]: Not saving file, too little data");
            return;
        }

        FinishHandle @fh = cast<FinishHandle>(handle);

        // Abort save if replays contains respawns and settings is enabled to not upload replays with respawns
        if (!SaveReplaysWithRespawns && fh.respawns > 0) {
            print("[TMDojo]: Not saving file, replay contains respawns");
            return;
        }
       
        // Setup variables for upload
        bool finished = fh.finished;
        CSmScriptPlayer@ smScript = fh.smScript;
        CGamePlaygroundUIConfig@ uiConfig = fh.uiConfig;
        CGameCtnChallenge@ rootMap = fh.rootMap;
        CTrackManiaNetwork@ network = fh.network;
        int endRaceTime = fh.endRaceTime;
        array<uint> sectorTimes = fh.sectorTimes;

        print("[TMDojo]: Saving game data (size: " + bufferSize / 1024 + " kB)");

        // Setup request URL
        string mapNameClean = Regex::Replace(rootMap.MapInfo.NameForUi, "\\$([0-9a-fA-F]{1,3}|[iIoOnNmMwWsSzZtTgG<>]|[lLhHpP](\\[[^\\]]+\\])?)", "").Replace(" ", "%20");
        string reqUrl = ApiUrl + "/replays" +
                            "?mapName=" + Net::UrlEncode(mapNameClean) +
                            "&mapUId=" + rootMap.MapInfo.MapUid +
                            "&authorName=" + rootMap.MapInfo.AuthorNickName +
                            "&playerName=" + network.PlayerInfo.Name +
                            "&playerLogin=" + network.PlayerInfo.Login +
                            "&webId=" + network.PlayerInfo.WebServicesUserId +
                            "&endRaceTime=" + endRaceTime +
                            "&raceFinished=" + (finished ? "1" : "0") +
                            "&pluginVersion=" + g_dojo.version;
        
        // If sector times are available, add them to the request URL
        if (sectorTimes.Length > 0) {
            reqUrl += "&sectorTimes=" + SectorTimesToString(sectorTimes);
        }

        // Build request instance
        Net::HttpRequest req;
        req.Method = Net::HttpMethod::Post;
        req.Url = reqUrl;

        // Set body to base64 encoded memory buffer
        req.Body = dataBase64;

        // Build headers
        dictionary@ Headers = dictionary();
        Headers["Authorization"] = "dojo " + SessionId;
        Headers["Content-Type"] = "application/octet-stream";
        @req.Headers = Headers;

        // Start and wait until request is finished
        UploadingReplay = true;
        
        req.Start();
        while (!req.Finished()) {
            yield();
        }

        UploadingReplay = false;

        // Handle error status codes
        int status = req.ResponseCode();
        if (status == 401) {
            UI::ShowNotification("TMDojo", "Upload failed. Not authorized, please log in if you are not logged in.", ERROR_COLOR);
        } else if (status != 200) {
            UI::ShowNotification("TMDojo", "Upload failed, status code: " + status, ERROR_COLOR);
        } else {
            UI::ShowNotification("TMDojo", "Uploaded replay successfully!", SUCCESS_COLOR);
        }
    }
}
