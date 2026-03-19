sub init()
    ' ============================================================
    '  CONSTANTS
    ' ============================================================
    m.REGISTRY_SECTION = "fishtank_auth"
    m.POLL_INTERVAL = 30            ' seconds between status polls
    m.REFRESH_INTERVAL = 600        ' seconds between token refresh (10 min)

    ' ============================================================
    '  STATE
    ' ============================================================
    m.accessToken = ""
    m.liveStreamToken = ""
    m.refreshToken = ""
    m.authCookie = ""
    m.seasonPass = false
    m.seasonPassXl = false
    m.displayName = ""
    m.userId = ""

    m.cameras = []
    m.loadBalancerMap = {}
    m.statusMap = {}
    m.currentCam = 0
    m.listVisible = true

    ' ============================================================
    '  UI REFERENCES
    ' ============================================================
    m.loginScreen = m.top.findNode("loginScreen")
    m.loadingView = m.top.findNode("loadingView")
    m.cameraView = m.top.findNode("cameraView")
    m.loadingLabel = m.top.findNode("loadingLabel")
    m.userLabel = m.top.findNode("userLabel")

    m.cameraList = m.top.findNode("cameraList")
    m.videoPlayer = m.top.findNode("videoPlayer")
    m.nowPlaying = m.top.findNode("nowPlaying")
    m.listBackground = m.top.findNode("listBackground")
    m.cameraHeader = m.top.findNode("cameraHeader")
    m.logoImage = m.top.findNode("logoImage")
    m.statusBar = m.top.findNode("statusBar")
    m.helpText = m.top.findNode("helpText")

    ' Camera selection observer
    m.cameraList.observeField("itemSelected", "onCameraSelected")

    ' Login result observer
    m.loginScreen.observeField("loginResult", "onLoginResult")

    ' Setup timers
    m.pollTimer = m.top.createChild("Timer")
    m.pollTimer.duration = m.POLL_INTERVAL
    m.pollTimer.repeat = true
    m.pollTimer.observeField("fire", "onPollTimer")

    m.refreshTimer = m.top.createChild("Timer")
    m.refreshTimer.duration = m.REFRESH_INTERVAL
    m.refreshTimer.repeat = true
    m.refreshTimer.observeField("fire", "onRefreshTimer")

    ' Check for saved session
    checkSavedSession()
end sub


' ============================================================
'  REGISTRY / PERSISTENT STORAGE
' ============================================================

sub saveSession()
    sec = CreateObject("roRegistrySection", m.REGISTRY_SECTION)
    sec.Write("accessToken", m.accessToken)
    sec.Write("liveStreamToken", m.liveStreamToken)
    sec.Write("refreshToken", m.refreshToken)
    sec.Write("authCookie", m.authCookie)
    sec.Write("displayName", m.displayName)
    sec.Write("userId", m.userId)
    if m.seasonPass
        sec.Write("seasonPass", "true")
    else
        sec.Write("seasonPass", "false")
    end if
    if m.seasonPassXl
        sec.Write("seasonPassXl", "true")
    else
        sec.Write("seasonPassXl", "false")
    end if
    sec.Flush()
    print "Session saved to registry"
end sub

sub loadSession()
    sec = CreateObject("roRegistrySection", m.REGISTRY_SECTION)
    m.accessToken = sec.Read("accessToken")
    m.liveStreamToken = sec.Read("liveStreamToken")
    m.refreshToken = sec.Read("refreshToken")
    m.authCookie = sec.Read("authCookie")
    m.displayName = sec.Read("displayName")
    m.userId = sec.Read("userId")
    m.seasonPass = (sec.Read("seasonPass") = "true")
    m.seasonPassXl = (sec.Read("seasonPassXl") = "true")
end sub

sub clearSession()
    sec = CreateObject("roRegistrySection", m.REGISTRY_SECTION)
    sec.Delete("accessToken")
    sec.Delete("liveStreamToken")
    sec.Delete("refreshToken")
    sec.Delete("authCookie")
    sec.Delete("displayName")
    sec.Delete("userId")
    sec.Delete("seasonPass")
    sec.Delete("seasonPassXl")
    sec.Flush()
    print "Session cleared"
end sub

function hasSavedSession() as Boolean
    sec = CreateObject("roRegistrySection", m.REGISTRY_SECTION)
    cookie = sec.Read("authCookie")
    return (cookie <> "" and cookie <> invalid)
end function


' ============================================================
'  AUTH FLOW
' ============================================================

sub checkSavedSession()
    if hasSavedSession()
        ' We have a saved session — try to refresh it
        loadSession()
        showLoading("Welcome back, " + m.displayName + "...")
        refreshTokens()
    else
        ' No session — show login
        showLogin()
    end if
end sub

sub showLogin()
    m.loginScreen.visible = true
    m.loadingView.visible = false
    m.cameraView.visible = false
    m.loginScreen.setFocus(true)
end sub

sub showLoading(message as String)
    m.loginScreen.visible = false
    m.loadingView.visible = true
    m.cameraView.visible = false
    m.loadingLabel.text = message
end sub

sub showCameraView()
    m.loginScreen.visible = false
    m.loadingView.visible = false
    m.cameraView.visible = true
end sub

sub onLoginResult()
    result = m.loginScreen.loginResult
    if result = invalid or not result.success
        return
    end if

    ' Store tokens
    m.accessToken = result.accessToken
    m.liveStreamToken = result.liveStreamToken
    m.refreshToken = result.refreshToken
    m.authCookie = result.cookie
    m.displayName = result.displayName
    m.userId = result.userId
    m.seasonPass = result.seasonPass
    m.seasonPassXl = result.seasonPassXl

    ' Save to registry for next launch
    saveSession()

    ' Proceed to loading cameras
    showLoading("Loading cameras...")
    fetchLiveStreams()
end sub


' ============================================================
'  TOKEN REFRESH
' ============================================================

sub refreshTokens()
    if m.authCookie = "" or m.authCookie = invalid
        print "No cookie for refresh — showing login"
        showLogin()
        return
    end if

    task = CreateObject("roSGNode", "ApiTask")
    task.endpoint = "/auth"
    task.method = "GET"
    task.cookie = m.authCookie
    task.observeField("response", "onRefreshResponse")
    task.control = "run"
    m.refreshTask = task
end sub

sub onRefreshResponse()
    response = m.refreshTask.response

    if response = invalid or not response.success or response.data = invalid
        print "Token refresh failed (code: " + response.code.toStr() + ")"
        ' If refresh fails, session is dead — go back to login
        if response <> invalid and (response.code = 401 or response.code = 403)
            clearSession()
            showLogin()
            return
        end if
        ' Might be a network issue — try to proceed with existing tokens
        if m.accessToken <> "" and m.liveStreamToken <> ""
            fetchLiveStreams()
        else
            clearSession()
            showLogin()
        end if
        return
    end if

    session = response.data.session

    ' Update tokens
    if session.DoesExist("access_token")
        m.accessToken = session.access_token
    end if
    if session.DoesExist("live_stream_token")
        m.liveStreamToken = session.live_stream_token
    end if
    if session.DoesExist("refresh_token")
        m.refreshToken = session.refresh_token
    end if

    ' Update cookie if a new one was set
    if response.setCookie <> "" and response.setCookie <> invalid
        m.authCookie = response.setCookie
    end if

    ' Update user metadata
    if session.DoesExist("user") and session.user <> invalid
        user = session.user
        if user.DoesExist("user_metadata") and user.user_metadata <> invalid
            meta = user.user_metadata
            if meta.DoesExist("displayName")
                m.displayName = meta.displayName
            end if
            if meta.DoesExist("seasonPass")
                m.seasonPass = meta.seasonPass
            end if
            if meta.DoesExist("seasonPassXl")
                m.seasonPassXl = meta.seasonPassXl
            end if
        end if
    end if

    ' Persist updated session
    saveSession()

    print "Tokens refreshed successfully"

    ' If we're still on the loading screen, proceed to cameras
    if m.cameraView.visible = false
        showLoading("Loading cameras...")
        fetchLiveStreams()
    end if
end sub

sub onRefreshTimer()
    ' Periodic token refresh while app is running
    print "Periodic token refresh..."
    refreshTokens()
end sub


' ============================================================
'  LIVE STREAMS / CAMERAS
' ============================================================

sub fetchLiveStreams()
    task = CreateObject("roSGNode", "ApiTask")
    task.endpoint = "/live-streams"
    task.method = "GET"
    task.accessToken = m.accessToken
    task.observeField("response", "onLiveStreamsResponse")
    task.control = "run"
    m.liveStreamsTask = task
end sub

sub onLiveStreamsResponse()
    response = m.liveStreamsTask.response

    if response = invalid or not response.success or response.data = invalid
        if response <> invalid and (response.code = 401 or response.code = 403)
            ' Token might be bad — try refresh
            showLoading("Refreshing session...")
            refreshTokens()
            return
        end if
        m.loadingLabel.text = "Failed to load cameras"
        print "Live streams fetch failed"
        return
    end if

    processLiveStreams(response.data)
end sub

sub processLiveStreams(data as Object)
    if data.DoesExist("loadBalancer")
        m.loadBalancerMap = data.loadBalancer
    end if

    if data.DoesExist("liveStreamStatus")
        m.statusMap = data.liveStreamStatus
    end if

    m.cameras = []

    if data.DoesExist("liveStreams")
        for each stream in data.liveStreams
            ' Skip hidden streams
            if stream.hidden = true
                goto skipStream
            end if

            ' Skip mystery/future cams that aren't live yet
            if stream.name = "???" and stream.goesLiveAt <> invalid
                goto skipStream
            end if

            cam = {
                id: stream.id,
                name: stream.name,
                access: stream.access,
                excludeFromGrid: stream.excludeFromGrid
            }

            ' Online status
            if m.statusMap.DoesExist(stream.id)
                cam.online = (m.statusMap[stream.id] = "online")
            else
                cam.online = false
            end if

            ' Access check
            cam.accessible = canAccess(stream.access)

            ' Load balanced host
            if m.loadBalancerMap.DoesExist(stream.id)
                cam.host = m.loadBalancerMap[stream.id]
            else
                cam.host = "streams-f.fishtank.live"
            end if

            m.cameras.push(cam)

            skipStream:
        end for
    end if

    sortCameras()
    populateCameraList()

    ' Show camera view
    showCameraView()

    ' Update user label
    accessLabel = ""
    if m.seasonPassXl
        accessLabel = " [XL]"
    else if m.seasonPass
        accessLabel = " [PASS]"
    end if
    m.userLabel.text = m.displayName + accessLabel

    ' Update status bar
    updateStatusBar()

    ' Focus camera list
    m.cameraList.setFocus(true)

    ' Auto-play first available camera
    autoPlayFirst()

    ' Start timers
    m.pollTimer.control = "start"
    m.refreshTimer.control = "start"
end sub

function canAccess(streamAccess as String) as Boolean
    if streamAccess = "normal"
        return true
    end if
    if streamAccess = "season_pass"
        return (m.seasonPass or m.seasonPassXl)
    end if
    if streamAccess = "season_pass_xl"
        return m.seasonPassXl
    end if
    return true
end function

sub sortCameras()
    n = m.cameras.count()
    for i = 0 to n - 2
        for j = 0 to n - 2 - i
            a = m.cameras[j]
            b = m.cameras[j + 1]
            if getCamSortScore(a) > getCamSortScore(b)
                m.cameras[j] = b
                m.cameras[j + 1] = a
            end if
        end for
    end for
end sub

function getCamSortScore(cam as Object) as Integer
    if cam.online and cam.accessible
        return 0
    else if cam.online and not cam.accessible
        return 1
    else
        return 2
    end if
end function

sub populateCameraList()
    content = CreateObject("roSGNode", "ContentNode")

    for each cam in m.cameras
        item = content.createChild("ContentNode")
        item.title = cam.name
        item.addField("online", "boolean", false)
        item.online = cam.online
        item.addField("accessible", "boolean", false)
        item.accessible = cam.accessible
        item.addField("accessTier", "string", false)
        item.accessTier = cam.access
    end for

    m.cameraList.content = content
end sub

sub updateStatusBar()
    onlineCount = 0
    for each cam in m.cameras
        if cam.online then onlineCount++
    end for
    m.statusBar.text = onlineCount.toStr() + "/" + m.cameras.count().toStr() + " cameras online"
end sub

sub autoPlayFirst()
    for i = 0 to m.cameras.count() - 1
        cam = m.cameras[i]
        if cam.online and cam.accessible
            playCamera(i)
            return
        end if
    end for
    m.nowPlaying.text = "No cameras available"
end sub


' ============================================================
'  PLAYBACK
' ============================================================

sub onCameraSelected()
    selected = m.cameraList.itemSelected
    if selected < 0 or selected >= m.cameras.count()
        return
    end if

    cam = m.cameras[selected]

    if not cam.online
        m.nowPlaying.text = cam.name + " is offline"
        return
    end if

    playCamera(selected)
    toggleListVisibility(false)
    m.videoPlayer.setFocus(true)
end sub

sub playCamera(index as Integer)
    if index < 0 or index >= m.cameras.count()
        return
    end if

    m.currentCam = index
    cam = m.cameras[index]

    streamUrl = "https://" + cam.host + "/hls/live+" + cam.id + "/index.m3u8?jwt=" + m.liveStreamToken + "&video=2.5mbps"

    content = CreateObject("roSGNode", "ContentNode")
    content.url = streamUrl
    content.title = cam.name
    content.streamformat = "hls"
    content.live = true

    m.videoPlayer.control = "stop"
    m.videoPlayer.content = content
    m.videoPlayer.control = "play"

    m.nowPlaying.text = "Now Playing: " + cam.name

    print "Playing: " + cam.name + " @ " + cam.host
end sub


' ============================================================
'  STATUS POLLING
' ============================================================

sub onPollTimer()
    task = CreateObject("roSGNode", "ApiTask")
    task.endpoint = "/live-streams"
    task.method = "GET"
    task.accessToken = m.accessToken
    task.observeField("response", "onPollResponse")
    task.control = "run"
    m.pollTask = task
end sub

sub onPollResponse()
    response = m.pollTask.response
    if response = invalid or not response.success or response.data = invalid
        return
    end if

    data = response.data

    if data.DoesExist("liveStreamStatus")
        m.statusMap = data.liveStreamStatus
    end if
    if data.DoesExist("loadBalancer")
        m.loadBalancerMap = data.loadBalancer
    end if

    for i = 0 to m.cameras.count() - 1
        cam = m.cameras[i]
        if m.statusMap.DoesExist(cam.id)
            cam.online = (m.statusMap[cam.id] = "online")
        else
            cam.online = false
        end if
        if m.loadBalancerMap.DoesExist(cam.id)
            cam.host = m.loadBalancerMap[cam.id]
        end if
        m.cameras[i] = cam
    end for

    updateStatusBar()
    populateCameraList()
end sub


' ============================================================
'  UI / NAVIGATION
' ============================================================

sub toggleListVisibility(show as Boolean)
    m.listVisible = show
    m.cameraList.visible = show
    m.listBackground.visible = show
    m.cameraHeader.visible = show
    m.logoImage.visible = show
    m.helpText.visible = show
    m.userLabel.visible = show

    if show
        m.videoPlayer.translation = [440, 85]
        m.videoPlayer.width = 1440
        m.videoPlayer.height = 810
        m.nowPlaying.translation = [440, 908]
        m.nowPlaying.width = 1440
        m.nowPlaying.visible = true
        m.statusBar.visible = true
    else
        m.videoPlayer.translation = [0, 0]
        m.videoPlayer.width = 1920
        m.videoPlayer.height = 1080
        m.nowPlaying.visible = false
        m.statusBar.visible = false
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    ' Only handle keys when camera view is active
    if not m.cameraView.visible then return false

    if key = "back"
        if not m.listVisible
            toggleListVisibility(true)
            m.cameraList.setFocus(true)
            return true
        end if
        return false
    end if

    if key = "left" and not m.listVisible
        toggleListVisibility(true)
        m.cameraList.setFocus(true)
        return true
    end if

    if key = "OK" and not m.listVisible
        toggleListVisibility(true)
        m.cameraList.setFocus(true)
        return true
    end if

    ' Options button (*) — could add logout here later
    if key = "options"
        ' Future: show options menu with logout
        return true
    end if

    return false
end function
