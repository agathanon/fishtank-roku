' ============================================================
'  DEV-ONLY LOGIN SCREEN
'  Auto-logs in with build-time injected credentials.
'  This file replaces LoginScreen.brs during dev builds.
'  DO NOT COMMIT CREDENTIALS — they are injected via .env
' ============================================================

sub init()
    m.emailText = m.top.findNode("emailText")
    m.passwordText = m.top.findNode("passwordText")
    m.loginButtonText = m.top.findNode("loginButtonText")
    m.errorLabel = m.top.findNode("errorLabel")
    m.statusLabel = m.top.findNode("statusLabel")

    m.email = "__DEV_EMAIL__"
    m.password = "__DEV_PASSWORD__"

    ' Show what's happening on screen
    m.emailText.text = m.email
    m.emailText.color = "#FFFFFF"
    m.passwordText.text = "********"
    m.passwordText.color = "#FFFFFF"
    m.statusLabel.text = "Dev auto-login..."

    ' Auto-login immediately
    doLogin()
end sub

sub doLogin()
    if m.email = "" or m.password = "" or Left(m.email, 2) = "__"
        m.errorLabel.text = "DEV_EMAIL / DEV_PASSWORD not set in .env"
        m.statusLabel.text = ""
        return
    end if

    m.loginButtonText.text = "Logging in..."

    body = FormatJSON({
        email: m.email,
        password: m.password
    })

    task = CreateObject("roSGNode", "ApiTask")
    task.endpoint = "/auth/log-in"
    task.method = "POST"
    task.body = body
    task.observeField("response", "onLoginResponse")
    task.control = "run"
    m.loginTask = task
end sub

sub onLoginResponse()
    response = m.loginTask.response

    m.loginButtonText.text = "Log In"
    m.statusLabel.text = ""

    if response = invalid
        m.errorLabel.text = "Connection failed"
        return
    end if

    if not response.success
        if response.code = 401 or response.code = 400
            m.errorLabel.text = "Invalid dev credentials"
        else
            m.errorLabel.text = "Login failed (error " + response.code.toStr() + ")"
        end if
        return
    end if

    if response.data = invalid or not response.data.DoesExist("session")
        m.errorLabel.text = "Unexpected response from server"
        return
    end if

    session = response.data.session

    result = {
        success: true,
        accessToken: "",
        liveStreamToken: "",
        refreshToken: "",
        cookie: "",
        displayName: "",
        userId: ""
    }

    if session.DoesExist("access_token")
        result.accessToken = session.access_token
    end if

    if session.DoesExist("live_stream_token")
        result.liveStreamToken = session.live_stream_token
    end if

    if session.DoesExist("refresh_token")
        result.refreshToken = session.refresh_token
    end if

    if response.setCookie <> "" and response.setCookie <> invalid
        result.cookie = response.setCookie
    end if

    if session.DoesExist("user") and session.user <> invalid
        user = session.user
        if user.DoesExist("id")
            result.userId = user.id
        end if

        if user.DoesExist("user_metadata") and user.user_metadata <> invalid
            meta = user.user_metadata
            if meta.DoesExist("displayName")
                result.displayName = meta.displayName
            end if
        end if
    end if

    m.top.loginResult = result
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    return false
end function
