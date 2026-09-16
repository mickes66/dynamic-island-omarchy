// Pure helpers for the Dynamic Island widget, kept Qt-free and stateless.
// Imported by BarWidget.qml and IslandMenu.qml alike.

// Stable identity for an MPRIS player across track changes.
function playerKey(p) {
  if (!p)
    return ""
  return String(p.dbusName || p.desktopEntry || p.identity || "")
}

// Human-readable name for the player picker menu.
function playerLabel(p) {
  if (!p)
    return ""
  return String(p.identity || p.desktopEntry || p.dbusName || "")
}

// Pill label for a label mode. Album modes fall back gracefully when the
// player reports no album.
function mediaTextFor(mode, title, artist, album) {
  var t = title || artist
  if (mode === "title")
    return t
  if (mode === "artistTitleAlbum") {
    var s = (artist && title) ? artist + " - " + title : t
    return album !== "" ? s + " · " + album : s
  }
  if (mode === "titleAlbum") {
    if (title !== "")
      return album !== "" ? title + " · " + album : title
    return artist
  }
  if (artist && title)
    return artist + " - " + title
  return t
}

// Strip notification HTML to plain text: <br> becomes a space, other tags
// are dropped, entities are decoded.
function decodeNotifBody(raw) {
  return String(raw || "")
    .replace(/<br\s*\/?>/gi, " ")
    .replace(/<[^>]*>/g, "")
    .replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
    .replace(/&quot;/g, "\"").replace(/&#39;/g, "'").replace(/&apos;/g, "'")
}
