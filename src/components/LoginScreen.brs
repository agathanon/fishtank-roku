sub init()
    m.email = ""
    m.password = ""
    m.focusIndex = 0  ' 0 = email, 1 = password, 2 = login button
    m.keyboardOpen = false

    ' UI references
    m.emailText = m.top.findNode("emailText")
    m.passwordText = m.top.findNode("passwordText")
    m.emailFieldFocus = m.top.findNode("emailFieldFocus")
    m.passwordFieldFocus = m.top.findNode("passwordFieldFocus")
    m.loginButtonFocus = m.top.findNode("loginButtonFocus")
    m.loginButtonBgTop = m.top.findNode("loginButtonBgTop")
    m.loginButtonText = m.top.findNode("loginButtonText")
    m.errorLabel = m.top.findNode("errorLabel")
    m.statusLabel = m.top.findNode("statusLabel")

    ' Get reference to the scene for dialog management
    m.scene = m.top.getScene()

    ' Placeholder text
    m.emailText.text = "Press OK to enter email"
    m.emailText.color = "#666666"
    m.passwordText.text = "Press OK to enter password"
    m.passwordText.color = "#666666"

    updateFocus()
end sub


sub updateFocus()
    m.emailFieldFocus.visible = (m.focusIndex = 0)
    m.passwordFieldFocus.visible = (m.focusIndex = 1)
    m.loginButtonFocus.visible = (m.focusIndex = 2)

    if m.focusIndex = 2
        m.loginButtonBgTop.color = "#DD4444"
    else
        m.loginButtonBgTop.color = "#CC3333"
    end if
end sub


sub showKeyboard(fieldName as String)
    m.activeField = fieldName
    m.keyboardOpen = true

    dialog = CreateObject("roSGNode", "StandardKeyboardDialog")

    if fieldName = "email"
        dialog.title = "Enter Email"
        dialog.text = m.email
    else
        dialog.title = "Enter Password"
        dialog.text = m.password
        dialog.secureMode = true
    end if

    dialog.buttons = ["OK", "Cancel"]

    ' Observe dialog events
    dialog.observeField("buttonSelected", "onKeyboardButton")
    dialog.observeField("wasClosed", "onKeyboardClosed")

    ' Set as scene dialog — this is the proper Roku way
    m.scene.dialog = dialog
end sub


sub onKeyboardButton()
    dialog = m.scene.dialog
    if dialog = invalid then return

    buttonIndex = dialog.buttonSelected
    if buttonIndex = 0  ' OK
        text = dialog.text

        if m.activeField = "email"
            m.email = text
            if text <> ""
                m.emailText.text = text
                m.emailText.color = "#FFFFFF"
            else
                m.emailText.text = "Press OK to enter email"
                m.emailText.color = "#666666"
            end if
        else
            m.password = text
            if text <> ""
                masked = ""
                for i = 1 to Len(text)
                    masked = masked + "*"
                end for
                m.passwordText.text = masked
                m.passwordText.color = "#FFFFFF"
            else
                m.passwordText.text = "Press OK to enter password"
                m.passwordText.color = "#666666"
            end if
        end if
    end if

    ' Close the dialog and return focus
    m.scene.dialog = invalid
    m.keyboardOpen = false
    m.top.setFocus(true)
end sub


sub onKeyboardClosed()
    m.scene.dialog = invalid
    m.keyboardOpen = false
    m.top.setFocus(true)
end sub


sub doLogin()
    if m.email = "" or m.password = ""
        m.errorLabel.text = "Enter your email and password"
        return
    end if

    m.errorLabel.text = ""
    m.statusLabel.text = "Logging in..."
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
            m.errorLabel.text = "Invalid email or password"
        else if response.code = 429
            m.errorLabel.text = "Too many attempts. Try later."
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

    ' Build the result
    result = {
        success: true,
        accessToken: "",
        liveStreamToken: "",
        refreshToken: "",
        cookie: "",
        seasonPass: false,
        seasonPassXl: false,
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

    ' Extract cookie from Set-Cookie header
    if response.setCookie <> "" and response.setCookie <> invalid
        result.cookie = response.setCookie
    end if

    ' Extract user metadata
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
            if meta.DoesExist("seasonPass")
                result.seasonPass = meta.seasonPass
            end if
            if meta.DoesExist("seasonPassXl")
                result.seasonPassXl = meta.seasonPassXl
            end if
        end if
    end if

    ' Pass result up to MainScene
    m.top.loginResult = result
end sub


function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    ' Don't handle keys if keyboard is open
    if m.keyboardOpen then return false

    if key = "down"
        if m.focusIndex < 2
            m.focusIndex = m.focusIndex + 1
            updateFocus()
        end if
        return true
    end if

    if key = "up"
        if m.focusIndex > 0
            m.focusIndex = m.focusIndex - 1
            updateFocus()
        end if
        return true
    end if

    if key = "OK"
        if m.focusIndex = 0
            showKeyboard("email")
        else if m.focusIndex = 1
            showKeyboard("password")
        else if m.focusIndex = 2
            doLogin()
        end if
        return true
    end if

    return false
end function
