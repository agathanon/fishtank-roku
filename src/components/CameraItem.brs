sub init()
    m.nameLabel = m.top.findNode("nameLabel")
    m.statusDot = m.top.findNode("statusDot")
    m.playingIndicator = m.top.findNode("playingIndicator")
end sub

sub onContentChanged()
    content = m.top.itemContent
    if content = invalid then return

    camName = content.title
    isOnline = content.getField("online")
    isAccessible = content.getField("accessible")
    isPlaying = content.getField("isPlaying")

    if isOnline = invalid then isOnline = true
    if isAccessible = invalid then isAccessible = true
    if isPlaying = invalid then isPlaying = false

    m.nameLabel.text = camName

    ' Status dot
    if isOnline
        m.statusDot.blendColor = "#44CC44"
    else
        m.statusDot.blendColor = "#CC4444"
    end if

    ' Now playing indicator
    m.playingIndicator.visible = isPlaying

    ' Name color based on status
    if isPlaying
        m.nameLabel.color = "#CC3333"
    else if not isOnline
        m.nameLabel.color = "#444444"
    else if not isAccessible
        m.nameLabel.color = "#555555"
    else
        m.nameLabel.color = "#AAAAAA"
    end if
end sub

sub onFocusChanged()
    content = m.top.itemContent
    if content = invalid then return

    isOnline = content.getField("online")
    isAccessible = content.getField("accessible")
    isPlaying = content.getField("isPlaying")
    if isOnline = invalid then isOnline = true
    if isAccessible = invalid then isAccessible = true
    if isPlaying = invalid then isPlaying = false

    focused = (m.top.focusPercent > 0.5)

    if focused
        if isPlaying
            m.nameLabel.color = "#FF5555"
        else if not isOnline
            m.nameLabel.color = "#666666"
        else if not isAccessible
            m.nameLabel.color = "#888888"
        else
            m.nameLabel.color = "#FFFFFF"
        end if
    else
        if isPlaying
            m.nameLabel.color = "#CC3333"
        else if not isOnline
            m.nameLabel.color = "#444444"
        else if not isAccessible
            m.nameLabel.color = "#555555"
        else
            m.nameLabel.color = "#AAAAAA"
        end if
    end if
end sub
