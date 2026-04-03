"""
Applet: ARC Raid Events
Summary: ARC Raiders event timers
Description: Displays active and upcoming ARC Raiders map events with countdown timers. Data sourced from MetaForge.app.
Author: jeffver
"""

load("cache.star", "cache")
load("encoding/json.star", "json")
load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")
load("time.star", "time")

API_URL = "https://metaforge.app/api/arc-raiders/events-schedule"
CACHE_TTL = 300  # 5 minutes

# ARC Raiders brand colors (from logo stripes)
ARC_CYAN = "#00e5ff"  # Leftmost stripe
ARC_GREEN = "#00e050"  # Second stripe
ARC_YELLOW = "#ffd600"  # Third stripe
ARC_RED = "#ff3030"  # Rightmost stripe

# Dimmed variants for secondary text
ARC_CYAN_DIM = "#006670"
ARC_GREEN_DIM = "#005820"
ARC_YELLOW_DIM = "#665500"
ARC_RED_DIM = "#661414"

# Neutrals
WHITE = "#ffffff"
GRAY = "#9ca3af"
DARK_GRAY = "#374151"
BG_DARK = "#0a0a0f"

# Map short names to fit on 64px display
MAP_SHORT = {
    "Dam": "DAM",
    "Spaceport": "SPCE",
    "Buried City": "BCTY",
    "Blue Gate": "BGAT",
    "Stella Montis": "SMON",
}

# Event short names
EVENT_SHORT = {
    "Close Scrutiny": "CLOSE SCRUT",
    "Night Raid": "NIGHT RAID",
    "Electromagnetic Storm": "EM STORM",
    "Husk Graveyard": "HUSK GRAVE",
    "Bird City": "BIRD CITY",
    "Harvester": "HARVESTER",
    "Matriarch": "MATRIARCH",
    "Hurricane": "HURRICANE",
    "Hidden Bunker": "HID BUNKER",
    "Locked Gate": "LOCKED GATE",
    "Launch Tower Loot": "TOWER LOOT",
    "Prospecting Probes": "PROBES",
    "Uncovered Caches": "CACHES",
    "Lush Blooms": "LUSH BLOOM",
}

def get_short_map(map_name):
    return MAP_SHORT.get(map_name, map_name[:4].upper())

def get_short_event(event_name):
    return EVENT_SHORT.get(event_name, event_name[:12].upper())

def pad_zero(n):
    """Pad a number with a leading zero if less than 10."""
    if n < 10:
        return "0" + str(int(n))
    return str(int(n))

def format_countdown(ms_remaining):
    """Format milliseconds remaining into a readable countdown."""
    if ms_remaining <= 0:
        return "NOW"

    total_seconds = int(ms_remaining / 1000)
    hours = int(total_seconds / 3600)
    minutes = int((total_seconds % 3600) / 60)
    seconds = total_seconds % 60

    if hours > 0:
        return str(hours) + "h" + pad_zero(minutes) + "m"
    elif minutes > 0:
        return str(minutes) + "m" + pad_zero(seconds) + "s"
    else:
        return str(seconds) + "s"

def main(config):
    # Get current time in milliseconds
    now = time.now()
    now_ms = now.unix_nano // 1000000

    # Get optional map filter from config
    map_filter = config.get("map_filter", "All")

    # Try cache first
    cached = cache.get("arc_events")
    if cached != None:
        events = json.decode(cached)
    else:
        rep = http.get(API_URL)
        if rep.status_code != 200:
            return render.Root(
                child = render.Box(
                    render.Column(
                        cross_align = "center",
                        main_align = "center",
                        children = [
                            render.Text("ARC RAIDERS", color = ARC_RED, font = "tom-thumb"),
                            render.Box(width = 64, height = 1, color = DARK_GRAY),
                            render.Text("API ERROR", color = ARC_YELLOW, font = "tom-thumb"),
                        ],
                    ),
                ),
            )
        events = rep.json()
        if type(events) == "dict" and "data" in events:
            events = events["data"]

        # Cache the response
        cache.set("arc_events", json.encode(events), ttl_seconds = CACHE_TTL)

    # Filter by map if specified
    if map_filter != "All":
        events = [e for e in events if e["map"] == map_filter]

    # Separate into active and upcoming events
    active_events = []
    upcoming_events = []

    for event in events:
        start = int(event["startTime"])
        end = int(event["endTime"])

        if start <= now_ms and now_ms < end:
            active_events.append(event)
        elif start > now_ms and len(upcoming_events) < 6:
            upcoming_events.append(event)

    # Build animation frames
    frames = []

    # Show active events (green theme)
    for event in active_events[:4]:
        end_ms = int(event["endTime"])
        remaining = end_ms - now_ms
        countdown = format_countdown(remaining)
        event_name = get_short_event(event["name"])

        frame = render.Box(
            color = BG_DARK,
            child = render.Column(
                children = [
                    # Header row: cyan dot + "ACTIVE"
                    render.Row(
                        expanded = True,
                        main_align = "space_between",
                        cross_align = "center",
                        children = [
                            render.Row(
                                cross_align = "center",
                                children = [
                                    render.Box(width = 4, height = 4, color = ARC_CYAN),
                                    render.Box(width = 1, height = 1),
                                    render.Text("ACTIVE", color = ARC_CYAN, font = "tom-thumb"),
                                ],
                            ),
                            render.Text(countdown, color = ARC_GREEN, font = "tom-thumb"),
                        ],
                    ),
                    # Divider
                    render.Box(width = 64, height = 1, color = ARC_CYAN_DIM),
                    render.Box(width = 64, height = 1),
                    # Event name (scrolling if needed)
                    render.Marquee(
                        width = 64,
                        child = render.Text(event_name, color = WHITE, font = "tb-8"),
                    ),
                    render.Box(width = 64, height = 1),
                    # Map name
                    render.Row(
                        expanded = True,
                        main_align = "space_between",
                        children = [
                            render.Text(event["map"], color = GRAY, font = "tom-thumb"),
                            render.Text("ENDS " + countdown, color = ARC_CYAN_DIM, font = "tom-thumb"),
                        ],
                    ),
                ],
            ),
        )
        frames.append(frame)

    # Show upcoming events (cyan theme)
    for event in upcoming_events[:3]:
        start_ms = int(event["startTime"])
        remaining = start_ms - now_ms
        countdown = format_countdown(remaining)
        event_name = get_short_event(event["name"])

        frame = render.Box(
            color = BG_DARK,
            child = render.Column(
                children = [
                    # Header row: yellow dot + "NEXT"
                    render.Row(
                        expanded = True,
                        main_align = "space_between",
                        cross_align = "center",
                        children = [
                            render.Row(
                                cross_align = "center",
                                children = [
                                    render.Box(width = 4, height = 4, color = ARC_YELLOW),
                                    render.Box(width = 1, height = 1),
                                    render.Text("UPCOMING", color = ARC_YELLOW, font = "tom-thumb"),
                                ],
                            ),
                            render.Text(countdown, color = ARC_YELLOW, font = "tom-thumb"),
                        ],
                    ),
                    # Divider
                    render.Box(width = 64, height = 1, color = ARC_YELLOW_DIM),
                    render.Box(width = 64, height = 1),
                    # Event name (scrolling if needed)
                    render.Marquee(
                        width = 64,
                        child = render.Text(event_name, color = WHITE, font = "tb-8"),
                    ),
                    render.Box(width = 64, height = 1),
                    # Map name
                    render.Row(
                        expanded = True,
                        main_align = "space_between",
                        children = [
                            render.Text(event["map"], color = GRAY, font = "tom-thumb"),
                            render.Text("IN " + countdown, color = ARC_YELLOW_DIM, font = "tom-thumb"),
                        ],
                    ),
                ],
            ),
        )
        frames.append(frame)

    # Fallback if no events
    if len(frames) == 0:
        return render.Root(
            child = render.Box(
                color = BG_DARK,
                child = render.Column(
                    cross_align = "center",
                    main_align = "center",
                    expanded = True,
                    children = [
                        render.Text("ARC RAIDERS", color = ARC_CYAN, font = "tom-thumb"),
                        render.Box(width = 64, height = 2),
                        render.Text("NO EVENTS", color = GRAY, font = "tom-thumb"),
                        render.Text("SCHEDULED", color = GRAY, font = "tom-thumb"),
                    ],
                ),
            ),
        )

    # If only 1 frame, show it static
    if len(frames) == 1:
        return render.Root(
            child = frames[0],
        )

    # Animate through frames (each frame shown for ~4 seconds)
    animation_frames = []
    frames_per_event = 75  # ~5 seconds at 15fps

    for frame in frames:
        for _ in range(frames_per_event):
            animation_frames.append(frame)

    return render.Root(
        delay = 100,  # 100ms per frame = 10fps
        child = render.Animation(
            children = animation_frames,
        ),
    )

def get_schema():
    maps = [
        schema.Option(display = "All Maps", value = "All"),
        schema.Option(display = "Dam", value = "Dam"),
        schema.Option(display = "Spaceport", value = "Spaceport"),
        schema.Option(display = "Buried City", value = "Buried City"),
        schema.Option(display = "Blue Gate", value = "Blue Gate"),
        schema.Option(display = "Stella Montis", value = "Stella Montis"),
    ]

    return schema.Schema(
        version = "1",
        fields = [
            schema.Dropdown(
                id = "map_filter",
                name = "Map Filter",
                desc = "Filter events by map",
                icon = "map",
                default = "All",
                options = maps,
            ),
        ],
    )
