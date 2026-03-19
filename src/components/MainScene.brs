sub init()
    ' ============================================================
    '  CONSTANTS
    ' ============================================================
    m.REGISTRY_SECTION = "fishtank_auth"
    m.POLL_INTERVAL = 30
    m.REFRESH_INTERVAL = 600

    ' ============================================================
    '  STATE
    ' ============================================================
    m.accessToken = ""
    m.liveStreamToken = ""
    m.refreshToken = ""
    m.authCookie = ""
    m.seasonPass = false
    m.seasonPassXL = false
    m.basementPass = false
    m.displayName = ""
    m.userId = ""

    m.cameras = []
    m.loadBalancerMap = {}
    m.statusMap = {}
    m.currentCam = -1
    m.isPaused = false
    m.initialLoadDone = false

    ' Panel state
    m.panelOpen = false
    m.panelAnimating = false

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
    m.nowPlayingBg = m.top.findNode("nowPlayingBg")
    m.logoImage = m.top.findNode("logoImage")
    m.statusBar = m.top.findNode("statusBar")
    m.helpText = m.top.findNode("helpText")
    m.offlineOverlay = m.top.findNode("offlineOverlay")
    m.offlineText = m.top.findNode("offlineText")
    m.pauseIndicator = m.top.findNode("pauseIndicator")
    m.pauseBg = m.top.findNode("pauseBg")
    m.focusTrap = m.top.findNode("focusTrap")

    ' Panel and animations
    m.panelGroup = m.top.findNode("panelGroup")
    m.panelSlideIn = m.top.findNode("panelSlideIn")
    m.panelSlideOut = m.top.findNode("panelSlideOut")

    ' Observe animation completion
    m.panelSlideIn.observeField("state", "onSlideInComplete")
    m.panelSlideOut.observeField("state", "onSlideOutComplete")

    ' Camera selection observer
    m.cameraList.observeField("itemSelected", "onCameraSelected")

    ' Login result observer
    m.loginScreen.observeField("loginResult", "onLoginResult")

    ' Video player state observer
    m.videoPlayer.observeField("state", "onVideoStateChanged")

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
    sec.Write("seasonPass", iif(m.seasonPass, "true", "false"))
    sec.Write("seasonPassXL", iif(m.seasonPassXL, "true", "false"))
    sec.Write("basementPass", iif(m.basementPass, "true", "false"))
    sec.Flush()
    print "Session saved to registry"
end sub

function iif(condition as Boolean, trueVal as String, falseVal as String) as String
    if condition then return trueVal
    return falseVal
end function

sub loadSession()
    sec = CreateObject("roRegistrySection", m.REGISTRY_SECTION)
    m.accessToken = sec.Read("accessToken")
    m.liveStreamToken = sec.Read("liveStreamToken")
    m.refreshToken = sec.Read("refreshToken")
    m.authCookie = sec.Read("authCookie")
    m.displayName = sec.Read("displayName")
    m.userId = sec.Read("userId")
    m.seasonPass = (sec.Read("seasonPass") = "true")
    m.seasonPassXL = (sec.Read("seasonPassXL") = "true")
    m.basementPass = (sec.Read("basementPass") = "true")
end sub

sub clearSession()
    sec = CreateObject("roRegistrySection", m.REGISTRY_SECTION)
    keys = ["accessToken", "liveStreamToken", "refreshToken", "authCookie", "displayName", "userId", "seasonPass", "seasonPassXL", "basementPass"]
    for each key in keys
        sec.Delete(key)
    end for
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
        loadSession()
        showLoading("Welcome back, " + m.displayName + "...")
        refreshTokens()
    else
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

    m.accessToken = result.accessToken
    m.liveStreamToken = result.liveStreamToken
    m.refreshToken = result.refreshToken
    m.authCookie = result.cookie
    m.displayName = result.displayName
    m.userId = result.userId

    saveSession()

    showLoading("Fetching profile...")
    fetchProfile()
end sub


' ============================================================
'  PROFILE (access levels)
' ============================================================

sub fetchProfile()
    if m.userId = "" or m.userId = invalid
        print "No userId — skipping profile fetch"
        fetchLiveStreams()
        return
    end if

    task = CreateObject("roSGNode", "ApiTask")
    task.endpoint = "/profile/" + m.userId
    task.method = "GET"
    task.accessToken = m.accessToken
    task.observeField("response", "onProfileResponse")
    task.control = "run"
    m.profileTask = task
end sub

sub onProfileResponse()
    response = m.profileTask.response

    if response <> invalid and response.success and response.data <> invalid
        data = response.data

        if data.DoesExist("profile") and data.profile <> invalid
            profile = data.profile

            if profile.DoesExist("seasonPass")
                m.seasonPass = profile.seasonPass
            end if
            if profile.DoesExist("seasonPassXL")
                m.seasonPassXL = profile.seasonPassXL
            end if
            if profile.DoesExist("basementPass")
                m.basementPass = profile.basementPass
            end if
            if profile.DoesExist("displayName")
                m.displayName = profile.displayName
            end if

            print "Profile loaded: seasonPass=" + iif(m.seasonPass, "true", "false") + " XL=" + iif(m.seasonPassXL, "true", "false")
        end if
    else
        print "Profile fetch failed — using defaults"
    end if

    saveSession()

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
        print "Token refresh failed"
        if response <> invalid and (response.code = 401 or response.code = 403)
            clearSession()
            showLogin()
            return
        end if
        if m.accessToken <> "" and m.liveStreamToken <> ""
            fetchProfile()
        else
            clearSession()
            showLogin()
        end if
        return
    end if

    session = response.data.session

    if session.DoesExist("access_token")
        m.accessToken = session.access_token
    end if
    if session.DoesExist("live_stream_token")
        m.liveStreamToken = session.live_stream_token
    end if
    if session.DoesExist("refresh_token")
        m.refreshToken = session.refresh_token
    end if

    if response.setCookie <> "" and response.setCookie <> invalid
        m.authCookie = response.setCookie
    end if

    if session.DoesExist("user") and session.user <> invalid
        user = session.user
        if user.DoesExist("id")
            m.userId = user.id
        end if
        if user.DoesExist("user_metadata") and user.user_metadata <> invalid
            meta = user.user_metadata
            if meta.DoesExist("displayName")
                m.displayName = meta.displayName
            end if
        end if
    end if

    saveSession()
    print "Tokens refreshed successfully"

    if m.cameraView.visible = false
        fetchProfile()
    end if
end sub

sub onRefreshTimer()
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
            if stream.hidden = true
                goto skipStream
            end if

            if stream.name = "???" and stream.goesLiveAt <> invalid
                goto skipStream
            end if

            cam = {
                id: stream.id,
                name: stream.name,
                access: stream.access,
                excludeFromGrid: stream.excludeFromGrid
            }

            if m.statusMap.DoesExist(stream.id)
                cam.online = (m.statusMap[stream.id] = "online")
            else
                cam.online = false
            end if

            cam.accessible = canAccess(stream.access)

            if m.loadBalancerMap.DoesExist(stream.id)
                cam.host = m.loadBalancerMap[stream.id]
            else
                cam.host = "streams-f.fishtank.live"
            end if

            m.cameras.push(cam)

            skipStream:
        end for
    end if

    if not m.initialLoadDone
        sortCameras()
        m.initialLoadDone = true
    end if

    populateCameraList()

    showCameraView()

    ' Update user label
    accessLabel = ""
    if m.seasonPassXL
        accessLabel = " [XL]"
    else if m.seasonPass
        accessLabel = " [PASS]"
    end if
    m.userLabel.text = m.displayName + accessLabel

    updateStatusBar()

    ' On first load: open panel, auto-play, focus list
    if m.currentCam = -1
        autoPlayFirst()
        slidePanel(true)
        m.cameraList.setFocus(true)
    end if

    m.pollTimer.control = "start"
    m.refreshTimer.control = "start"
end sub

function canAccess(streamAccess as String) as Boolean
    if streamAccess = "normal"
        return true
    end if
    if streamAccess = "season_pass"
        return (m.seasonPass or m.seasonPassXL)
    end if
    if streamAccess = "season_pass_xl"
        return m.seasonPassXL
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
    savedFocus = m.cameraList.itemFocused

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
        item.addField("isPlaying", "boolean", false)
        item.isPlaying = (cam.id = getCurrentCamId())
    end for

    m.cameraList.content = content

    if savedFocus >= 0 and savedFocus < m.cameras.count()
        m.cameraList.jumpToItem = savedFocus
    end if
end sub

function getCurrentCamId() as String
    if m.currentCam >= 0 and m.currentCam < m.cameras.count()
        return m.cameras[m.currentCam].id
    end if
    return ""
end function

sub updateStatusBar()
    onlineCount = 0
    for each cam in m.cameras
        if cam.online then onlineCount++
    end for
    m.statusBar.text = onlineCount.toStr() + "/" + m.cameras.count().toStr() + " online"
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
        showNowPlaying(cam.name + " is offline")
        return
    end if

    if not cam.accessible
        showAccessDeniedDialog(cam.access)
        return
    end if

    playCamera(selected)

    ' Close the panel after selection
    slidePanel(false)
end sub

sub showAccessDeniedDialog(accessLevel as String)
    dialog = CreateObject("roSGNode", "StandardMessageDialog")
    dialog.title = "Access Required"

    if accessLevel = "season_pass"
        dialog.message = ["This camera is only available", "to Season Pass holders."]
    else if accessLevel = "season_pass_xl"
        dialog.message = ["This camera is only available", "to Season Pass XL holders."]
    else
        dialog.message = ["This camera requires", "a higher access level."]
    end if

    dialog.buttons = ["OK"]
    dialog.observeField("buttonSelected", "onAccessDialogClosed")
    dialog.observeField("wasClosed", "onAccessDialogClosed")

    m.top.dialog = dialog
end sub

sub onAccessDialogClosed()
    m.top.dialog = invalid
    m.cameraList.setFocus(true)
end sub

sub playCamera(index as Integer)
    if index < 0 or index >= m.cameras.count()
        return
    end if

    m.currentCam = index
    m.isPaused = false
    m.pauseIndicator.visible = false
    m.pauseBg.visible = false
    m.offlineOverlay.visible = false
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

    showNowPlaying("Now Playing: " + cam.name)

    populateCameraList()

    print "Playing: " + cam.name + " @ " + cam.host
end sub

sub showNowPlaying(text as String)
    m.nowPlaying.text = text
    m.nowPlaying.visible = true
    m.nowPlayingBg.visible = true
    m.statusBar.visible = true

    ' Auto-hide the now playing bar after 4 seconds
    if m.nowPlayingTimer <> invalid
        m.nowPlayingTimer.control = "stop"
    else
        m.nowPlayingTimer = m.top.createChild("Timer")
        m.nowPlayingTimer.duration = 4
        m.nowPlayingTimer.repeat = false
        m.nowPlayingTimer.observeField("fire", "onNowPlayingTimeout")
    end if
    m.nowPlayingTimer.control = "start"
end sub

sub onNowPlayingTimeout()
    ' Only hide if panel is closed
    if not m.panelOpen
        m.nowPlaying.visible = false
        m.nowPlayingBg.visible = false
        m.statusBar.visible = false
    end if
end sub


' ============================================================
'  VIDEO STATE / OFFLINE DETECTION
' ============================================================

sub onVideoStateChanged()
    state = m.videoPlayer.state

    print "Video state: " + state

    if state = "error"
        if m.currentCam >= 0 and m.currentCam < m.cameras.count()
            cam = m.cameras[m.currentCam]
            m.offlineOverlay.visible = true
            m.offlineText.text = cam.name + " - Camera Offline"
            showNowPlaying(cam.name + " (offline)")
        end if
    else if state = "playing"
        m.offlineOverlay.visible = false
    end if
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

    currentCamId = getCurrentCamId()
    currentCamWasOnline = false
    if currentCamId <> ""
        for each cam in m.cameras
            if cam.id = currentCamId and cam.online
                currentCamWasOnline = true
                exit for
            end if
        end for
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

    ' Check if current cam just went offline
    if currentCamId <> "" and currentCamWasOnline
        for each cam in m.cameras
            if cam.id = currentCamId and not cam.online
                m.offlineOverlay.visible = true
                m.offlineText.text = cam.name + " - Camera Offline"
                showNowPlaying(cam.name + " (offline)")
                exit for
            end if
        end for
    end if

    ' Check if current cam came back online
    if currentCamId <> "" and m.offlineOverlay.visible
        for each cam in m.cameras
            if cam.id = currentCamId and cam.online
                m.offlineOverlay.visible = false
                playCamera(m.currentCam)
                exit for
            end if
        end for
    end if

    updateStatusBar()
    populateCameraList()
end sub


' ============================================================
'  SLIDING PANEL
' ============================================================

sub slidePanel(show as Boolean)
    if m.panelAnimating then return
    if show = m.panelOpen then return

    m.panelAnimating = true

    if show
        m.panelGroup.visible = true
        m.panelSlideIn.control = "start"
    else
        m.panelSlideOut.control = "start"
    end if
end sub

sub onSlideInComplete()
    if m.panelSlideIn.state = "stopped"
        m.panelOpen = true
        m.panelAnimating = false
        m.cameraList.setFocus(true)

        if m.currentCam >= 0
            m.nowPlaying.visible = true
            m.nowPlayingBg.visible = true
            m.statusBar.visible = true
        end if
    end if
end sub

sub onSlideOutComplete()
    if m.panelSlideOut.state = "stopped"
        m.panelOpen = false
        m.panelAnimating = false
        m.panelGroup.visible = false
        m.focusTrap.setFocus(true)

        ' Start auto-hide timer for now playing bar
        if m.nowPlayingTimer <> invalid
            m.nowPlayingTimer.control = "start"
        end if
    end if
end sub


' ============================================================
'  DIALOGS
' ============================================================

sub showExitConfirmation()
    dialog = CreateObject("roSGNode", "StandardMessageDialog")
    dialog.title = "Exit Fishtank"
    dialog.message = ["Are you sure you want to exit?"]
    dialog.buttons = ["Exit", "Cancel"]
    dialog.observeField("buttonSelected", "onExitDialogButton")
    dialog.observeField("wasClosed", "onExitDialogClosed")
    m.top.dialog = dialog
end sub

sub onExitDialogButton()
    dialog = m.top.dialog
    if dialog <> invalid and dialog.buttonSelected = 0
        m.top.dialog = invalid
        m.videoPlayer.control = "stop"
        m.pollTimer.control = "stop"
        m.refreshTimer.control = "stop"
        m.top.exitApp = true
    else
        m.top.dialog = invalid
        restoreFocusAfterDialog()
    end if
end sub

sub onExitDialogClosed()
    m.top.dialog = invalid
    restoreFocusAfterDialog()
end sub

sub showOptionsMenu()
    dialog = CreateObject("roSGNode", "StandardMessageDialog")
    dialog.title = "Options"
    dialog.message = ["Logged in as " + m.displayName]
    dialog.buttons = ["Log Out", "Cancel"]
    dialog.observeField("buttonSelected", "onOptionsButton")
    dialog.observeField("wasClosed", "onOptionsClosed")
    m.top.dialog = dialog
end sub

sub onOptionsButton()
    dialog = m.top.dialog
    if dialog <> invalid and dialog.buttonSelected = 0
        m.top.dialog = invalid
        m.videoPlayer.control = "stop"
        m.pollTimer.control = "stop"
        m.refreshTimer.control = "stop"
        clearSession()
        m.currentCam = -1
        m.initialLoadDone = false
        m.panelOpen = false
        m.panelAnimating = false
        showLogin()
    else
        m.top.dialog = invalid
        restoreFocusAfterDialog()
    end if
end sub

sub onOptionsClosed()
    m.top.dialog = invalid
    restoreFocusAfterDialog()
end sub

sub restoreFocusAfterDialog()
    if m.panelOpen
        m.cameraList.setFocus(true)
    else
        m.focusTrap.setFocus(true)
    end if
end sub


' ============================================================
'  NAVIGATION
' ============================================================

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if not m.cameraView.visible then return false

    print "Key pressed: " + key

    ' Pause / Play toggle
    if key = "play"
        if m.isPaused
            m.videoPlayer.control = "resume"
            m.isPaused = false
            m.pauseIndicator.visible = false
            m.pauseBg.visible = false
        else
            m.videoPlayer.control = "pause"
            m.isPaused = true
            m.pauseIndicator.visible = true
            m.pauseBg.visible = true
        end if
        return true
    end if

    if key = "back"
        if m.panelOpen
            slidePanel(false)
            return true
        end if
        showExitConfirmation()
        return true
    end if

    ' Panel closed — any directional or OK opens it
    if not m.panelOpen
        if key = "left" or key = "OK" or key = "up" or key = "down"
            slidePanel(true)
            return true
        end if
    end if

    ' Panel open — right closes it
    if key = "right" and m.panelOpen
        slidePanel(false)
        return true
    end if

    ' Log out — replay button (↻) or options (*)
    if key = "replay" or key = "options"
        showOptionsMenu()
        return true
    end if

    return false
end function
