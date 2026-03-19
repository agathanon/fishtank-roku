sub init()
    m.nameLabel = m.top.findNode("nameLabel")
    m.accessBadge = m.top.findNode("accessBadge")
    m.statusDot = m.top.findNode("statusDot")
end sub

sub onContentChanged()
    content = m.top.itemContent
    if content = invalid then return

    camName = content.title
    isOnline = content.getField("online")
    isAccessible = content.getField("accessible")
    accessTier = content.getField("accessTier")

    if isOnline = invalid then isOnline = true
    if isAccessible = invalid then isAccessible = true

    m.nameLabel.text = camName

    ' Status dot
    if isOnline
        m.statusDot.blendColor = "#44CC44"
    else
        m.statusDot.blendColor = "#CC4444"
    end if

    ' Name color based on status
    if not isOnline
        m.nameLabel.color = "#444444"
    else if not isAccessible
        m.nameLabel.color = "#666666"
    else
        m.nameLabel.color = "#AAAAAA"
    end if

    ' Access badge
    if accessTier = "season_pass"
        m.accessBadge.text = "PASS"
        m.accessBadge.color = "#CC9933"
    else if accessTier = "season_pass_xl"
        m.accessBadge.text = "XL"
        m.accessBadge.color = "#CC33CC"
    else
        m.accessBadge.text = ""
    end if
end sub

sub onFocusChanged()
    content = m.top.itemContent
    if content = invalid then return

    isOnline = content.getField("online")
    isAccessible = content.getField("accessible")
    if isOnline = invalid then isOnline = true
    if isAccessible = invalid then isAccessible = true

    focused = (m.top.focusPercent > 0.5)

    if focused
        if not isOnline
            m.nameLabel.color = "#666666"
        else if not isAccessible
            m.nameLabel.color = "#999999"
        else
            m.nameLabel.color = "#FFFFFF"
        end if
    else
        if not isOnline
            m.nameLabel.color = "#444444"
        else if not isAccessible
            m.nameLabel.color = "#666666"
        else
            m.nameLabel.color = "#AAAAAA"
        end if
    end if
end sub
