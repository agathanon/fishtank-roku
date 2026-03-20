sub init()
    m.top.functionName = "sendEvent"
end sub

sub sendEvent()
    event = m.top.event
    if event = invalid then return

    TELEMETRY_URL = "__TELEMETRY_URL__"
    TELEMETRY_TOKEN = "__TELEMETRY_TOKEN__"

    ' Skip if telemetry is not configured
    if TELEMETRY_URL = "" or Left(TELEMETRY_URL, 2) = "__" then return

    deviceId = getOrCreateDeviceId()

    deviceInfo = CreateObject("roDeviceInfo")
    osVer = deviceInfo.GetOSVersion()

    payload = {
        device_id: deviceId,
        event: event.name,
        app_version: "__VERSION__",
        roku_model: deviceInfo.GetModelDisplayName(),
        firmware: osVer.major + "." + osVer.minor + "." + osVer.build,
        display_mode: deviceInfo.GetDisplayMode(),
        timestamp: CreateObject("roDateTime").ToISOString()
    }

    if event.DoesExist("data") and event.data <> invalid
        payload.data = event.data
    end if

    body = FormatJSON(payload)

    port = CreateObject("roMessagePort")

    request = CreateObject("roUrlTransfer")
    request.SetMessagePort(port)
    request.SetUrl(TELEMETRY_URL)
    request.SetCertificatesFile("common:/certs/ca-bundle.crt")
    request.InitClientCertificates()
    request.AddHeader("Content-Type", "application/json")
    request.AddHeader("User-Agent", "FishtankRoku/__VERSION__")
    request.AddHeader("Authorization", "Bearer " + TELEMETRY_TOKEN)
    request.RetainBodyOnError(true)

    sent = request.AsyncPostFromString(body)

    if sent
        msg = wait(5000, port)
        if msg <> invalid and type(msg) = "roUrlEvent"
            print "Telemetry sent: " + event.name + " -> " + msg.GetResponseCode().toStr()
        else
            print "Telemetry timeout: " + event.name
        end if
    else
        print "Telemetry send failed: " + event.name
    end if
end sub

function getOrCreateDeviceId() as String
    sec = CreateObject("roRegistrySection", "fishtank_telemetry")
    deviceId = sec.Read("device_id")

    if deviceId = "" or deviceId = invalid
        deviceId = generateUUID()
        sec.Write("device_id", deviceId)
        sec.Flush()
        print "Generated new telemetry device ID: " + deviceId
    end if

    return deviceId
end function

function generateUUID() as String
    hexChars = "0123456789abcdef"
    uuid = ""
    sections = [8, 4, 4, 4, 12]

    for si = 0 to sections.count() - 1
        if si > 0 then uuid = uuid + "-"
        for i = 1 to sections[si]
            uuid = uuid + Mid(hexChars, Rnd(16), 1)
        end for
    end for

    return uuid
end function
