-- AOC 27" 1440p primary.
hl.monitor({
    output = "desc:AOC Q27G2SG4 XFXQ5HA008268",
    mode = "2560x1440@155",
    position = "0x0",
    scale = "1",
})

-- Samsung 1080p to the left; description survives HDMI connector renumbering.
hl.monitor({
    output = "desc:Samsung Electric Company SyncMaster",
    mode = "1920x1080@60",
    position = "-1920x370",
    scale = "1",
})

-- Safe fallback for an unknown or temporarily attached display.
hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = "auto",
})
