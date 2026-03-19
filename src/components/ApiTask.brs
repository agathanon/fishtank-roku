sub init()
    m.top.functionName = "executeRequest"
end sub

sub executeRequest()
    url = "https://api.fishtank.live/v1" + m.top.endpoint
    method = m.top.method
    body = m.top.body
    accessToken = m.top.accessToken
    cookie = m.top.cookie

    port = CreateObject("roMessagePort")

    request = CreateObject("roUrlTransfer")
    request.SetMessagePort(port)
    request.SetUrl(url)
    request.SetCertificatesFile("common:/certs/ca-bundle.crt")
    request.InitClientCertificates()
    request.AddHeader("Content-Type", "application/json")
    request.AddHeader("Accept", "application/json")
    request.AddHeader("Origin", "https://www.fishtank.live")
    request.AddHeader("Referer", "https://www.fishtank.live/")
    request.AddHeader("User-Agent", "FishtankRoku/2.0.0 (contact: fishtank-roku.z9hbc@addy.io)")
    request.RetainBodyOnError(true)

    ' Auth: Bearer token or Cookie
    if accessToken <> "" and accessToken <> invalid
        request.AddHeader("Authorization", "Bearer " + accessToken)
    end if

    if cookie <> "" and cookie <> invalid
        request.AddHeader("Cookie", "sb-wcsaaupukpdmqdjcgaoo-auth-token=" + cookie)
    end if

    result = {
        success: false,
        code: 0,
        data: invalid,
        setCookie: ""
    }

    ' Send request async
    sent = false
    if method = "POST"
        sent = request.AsyncPostFromString(body)
    else
        sent = request.AsyncGetToString()
    end if

    if not sent
        print "Failed to send request to: " + url
        m.top.response = result
        return
    end if

    ' Wait for response (30 second timeout)
    msg = wait(30000, port)

    if type(msg) <> "roUrlEvent"
        print "Request timed out: " + url
        m.top.response = result
        return
    end if

    result.code = msg.GetResponseCode()
    result.success = (result.code >= 200 and result.code < 300)
    responseStr = msg.GetString()

    ' Extract Set-Cookie from response headers
    responseHeaders = msg.GetResponseHeaders()
    if responseHeaders <> invalid
        if responseHeaders.DoesExist("set-cookie")
            rawCookie = responseHeaders["set-cookie"]
            cookieName = "sb-wcsaaupukpdmqdjcgaoo-auth-token="
            namePos = Instr(1, rawCookie, cookieName)
            if namePos > 0
                valueStart = namePos + Len(cookieName)
                remaining = Mid(rawCookie, valueStart)
                semiPos = Instr(1, remaining, ";")
                if semiPos > 0
                    result.setCookie = Left(remaining, semiPos - 1)
                else
                    result.setCookie = remaining
                end if
            end if
        end if
    end if

    if result.success and responseStr <> "" and responseStr <> invalid
        parsed = ParseJSON(responseStr)
        if parsed <> invalid
            result.data = parsed
        end if
    end if

    print "API " + method + " " + m.top.endpoint + " -> " + result.code.toStr()

    m.top.response = result
end sub
