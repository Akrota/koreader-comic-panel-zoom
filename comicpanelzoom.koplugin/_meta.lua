-- Beschreibung auf Deutsch oder Englisch, je nach KOReader-Sprache
local ok, lang = pcall(function() return G_reader_settings:readSetting("language") end)
local de = ok and type(lang) == "string" and lang:sub(1, 2):lower() == "de"
return {
    fullname = "Comic Panel Zoom",
    description = de
        and "Panel-für-Panel-Ansicht für Comics und Manga mit automatischer Panel-Erkennung. Umbenannte, erweiterte Fassung von Dynamic Panel Zoom (JorgeTheFox, MIT), läuft mit KOReader ab 2026.07.1."
        or "Panel-by-panel view for comics and manga with automatic panel detection. Renamed, extended version of Dynamic Panel Zoom (JorgeTheFox, MIT), works with KOReader 2026.07.1 and later.",
    author = "JorgeTheFox & KOReader community (renamed fork)",
    version = "1.11.1-cpz",
}
