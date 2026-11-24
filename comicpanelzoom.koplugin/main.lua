local Device = require("device")
local Dispatcher = require("dispatcher")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InfoMessage = require("ui/widget/infomessage")
local Screen = require("device").screen
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local PanelViewer = require("cpz_panel_viewer")
local Blitbuffer = require("ffi/blitbuffer")
local gettext = require("gettext")

-- Deutsche Menuetexte (Comic Panel Zoom). Andere Sprachen: KOReaders Uebersetzung bzw. Englisch.
-- Text fuer "Wie funktioniert das?" (englische Fassung; die deutsche steht in DE)
local HELP_TEXT = "Turn on panel zoom (below: Allow panel zoom) and hold on a panel: the panel view opens.\n\nIn the panel view:\n• Tap the right or left edge: next or previous panel, at the end of the page on to the next page.\n• Tap the middle: back to the page.\n• Hold: free zoom.\n• Swipe up: whole page, swipe down: back to the panel.\n• Swipe left or right: mask on/off.\n• Tap top middle / bottom middle: KOReader's menus.\n\nReading direction (comic or manga) and everything else is set here in the panel zoom menu.\n\nThe automatic options (background, refresh on panel change) are experimental: they guess from brightness and colour. If they guess wrong, choose a fixed setting."
-- Texte fuer den Refresh beim Panelwechsel (Aufbau wie bei Comic Display)
local REFRESH_CLEAN_HELP = "After the panel change a second, full refresh follows. Cleanest, but flashes twice."
local REFRESH_FAST_HELP = "No second refresh. Instead, Panel Zoom switches on the screen's colour mode on panel change (like the \"Dithering\" switch), following the automatic settings below: only colourful panels, optionally also dark black-and-white panels. Fastest, very slight ghosting may remain."
local REFRESH_AUTO_HELP = "On colour e-ink, mainly colourful panels leave visible ghosting. With this on, only colourful panels get the extra refresh or the dithering, black-and-white panels do not (no needless flashing). Experimental: it guesses from colour and is not always right."
local REFRESH_DARK_HELP = "For gloomy black-and-white comics: very dark panels get the extra refresh or the dithering as well, light black-and-white panels still do not. Experimental: the automatic mode guesses from brightness and colour and is not always right."
local REFRESH_HELP = "Panel Zoom always changes panels the way KOReader turns a normal page. If KOReader's \"Dithering\" switch is on, it applies in the panel view too.\n\nAgainst ghosting you can add:\n• Clean: after the panel change a second, full refresh clears what is left of the previous panel. Cleanest, flashes twice.\n• Fast: no second refresh. Instead, Panel Zoom switches on dithering on panel change (the screen's colour mode). Fastest, very slight ghosting may remain.\n\nAutomatic (both modes): only colourful panels get the second refresh or the dithering, optionally also dark black-and-white panels. The automatic mode is experimental and guesses from colour and brightness.\n\n\"How often\" belongs to the second refresh and only applies in \"Clean\" mode."

local DE = {
    ["0% (None)"] = "0 % (keiner)",
    ["10% (Wide)"] = "10 % (weit)",
    ["2% (Tight)"] = "2 % (eng)",
    ["20% (Context)"] = "20 % (mit Umfeld)",
    ["5% (Normal)"] = "5 % (normal)",
    ["Are you sure you want to reset all Panel Zoom settings to their default values?"] = "Alle Einstellungen von Comic Panel Zoom auf Standard zurücksetzen?",
    ["Auto (based on reading direction)"] = "Automatisch (nach Leserichtung)",
    ["Experimental Panel Sorting (Z-pattern)"] = "Experimentelle Panel-Sortierung (Z-Muster)",
    ["Experimental features"] = "Experimentelle Funktionen",
    ["Fit to screen (1.0x)"] = "Bildschirmfüllend (1,0x)",
    ["Strong (2.0x)"] = "Stark (2,0x)",
    ["Padding when zooming"] = "Rand beim Zoom",
    ["Free zoom (hold in a panel)"] = "Freier Zoom (lang drücken im Panel)",
    ["Initial zoom level"] = "Anfangs-Zoom",
    ["Left side"] = "Linke Seite",
    ["Left-to-Right (LTR)"] = "Links nach rechts (Comics)",
    ["Medium (1.5x)"] = "Mittel (1,5x)",
    ["Next panel by tapping on"] = "Nächstes Panel durch Tippen auf",
    ["No panels on this page"] = "Keine Panels auf dieser Seite",
    ["Padding around panel"] = "Rand um das Panel",
    ["Reading direction"] = "Leserichtung",
    ["Reset settings"] = "Einstellungen zurücksetzen",
    ["Restored default settings successfully!"] = "Standardeinstellungen wiederhergestellt.",
    ["Right side"] = "Rechte Seite",
    ["Right-to-Left (RTL)"] = "Rechts nach links (Manga)",
    ["Show panel surroundings (off = background colour)"] = "Umgebung des Panels zeigen (aus = Hintergrundfarbe)",
    ["Slight (1.2x)"] = "Leicht (1,2x)",
    ["Panel view"] = "Panel-Ansicht",
    -- Neue Funktionen
    ["Gestures"] = "Gesten",
    ["Page overview by swiping up"] = "Seitenübersicht per Wischen nach oben",
    ["Swipe up to see the whole page, swipe down to go back to the panel."] = "Nach oben wischen zeigt die ganze Seite, nach unten wischen geht zurück zum Panel.",
    ["Frame current panel in page overview"] = "Aktuelles Panel in der Seitenübersicht umrahmen",
    ["Toggle mask: swipe left or right"] = "Maske umschalten: nach links oder rechts wischen",
    ["Off"] = "Aus",
    ["Refresh on panel change: %1"] = "Refresh beim Panelwechsel: %1",
    ["off"] = "aus",
    ["clean"] = "sauber",
    ["fast"] = "schnell",
    ["Enabled"] = "Aktiv",
    ["Clean: two refreshes"] = "Sauber: zwei Refreshes",
    ["Fast: automatic dithering"] = "Schnell: Dithering automatisch",
    [REFRESH_CLEAN_HELP] = "Nach dem Panelwechsel folgt ein zweiter, voller Refresh. Am saubersten, blitzt aber zweimal.",
    [REFRESH_FAST_HELP] = "Kein zweiter Refresh. Stattdessen schaltet Panel Zoom beim Panelwechsel den Farbmodus des Bildschirms ein (wie der Schalter „Dithering“), passend zu den Automatik-Einstellungen darunter: nur farbige Panels, auf Wunsch auch dunkle Schwarzweiß-Panels. Am schnellsten, ganz leichtes Ghosting kann bleiben.",
    ["Also dark black-and-white panels (experimental)"] = "Auch dunkle Schwarzweiß-Panels (experimentell)",
    [REFRESH_DARK_HELP] = "Für düstere Schwarzweiß-Comics: Sehr dunkle Panels bekommen dann ebenfalls den Extra-Refresh bzw. das Dithering, helle Schwarzweiß-Panels weiterhin nicht. Experimentell: Die Automatik schätzt nach Helligkeit und Farbe und liegt nicht immer richtig.",
    [REFRESH_HELP] = "Panel Zoom wechselt die Panels immer so wie KOReader beim normalen Umblättern. Ist KOReaders Schalter „Dithering“ an, gilt er auch in der Panel-Ansicht.\n\nGegen Ghosting lässt sich dazuschalten:\n• Sauber: Nach dem Panelwechsel folgt ein zweiter, voller Refresh, der Reste des vorherigen Panels entfernt. Am saubersten, blitzt zweimal.\n• Schnell: kein zweiter Refresh. Stattdessen schaltet Panel Zoom beim Panelwechsel Dithering ein (den Farbmodus des Bildschirms). Am schnellsten, ganz leichtes Ghosting kann bleiben.\n\nAutomatik (beide Modi): Den zweiten Refresh bzw. das Dithering bekommen nur farbige Panels, auf Wunsch auch dunkle Schwarzweiß-Panels. Die Automatik ist experimentell und schätzt nach Farbe und Helligkeit.\n\n„Wie oft“ gehört zum zweiten Refresh und gilt nur bei „Sauber“.",
    ["Every panel"] = "Bei jedem Panel",
    ["First panel of each page"] = "Nur beim ersten Panel einer Seite",
    ["This comic"] = "Dieser Comic",
    ["Default for new comics"] = "Standard für neue Comics",
    ["Mask on"] = "Maske an",
    ["Mask off"] = "Maske aus",
    ["Black background instead of white"] = "Hintergrund schwarz statt weiß",
    ["Background"] = "Hintergrund",
    ["white"] = "weiß",
    ["black"] = "schwarz",
    ["automatic"] = "automatisch",
    ["White"] = "Weiß",
    ["Black"] = "Schwarz",
    ["Automatic"] = "Automatisch",
    ["Automatic (experimental)"] = "Automatisch (experimentell)",
    ["Black when the panel has a dark edge or is very dark, otherwise white (same rule as Comic Display). Experimental: if it guesses wrong, choose white or black."] = "Schwarz, wenn das Panel einen dunklen Rand hat oder sehr dunkel ist, sonst weiß (gleiche Regel wie bei Comic Display). Experimentell: Liegt sie daneben, wähle fest weiß oder schwarz.",
    ["Detect small panels"] = "Kleine Panels erkennen",
    ["Normal (from 1/8 of the page)"] = "Normal (ab 1/8 der Seite)",
    ["Slightly smaller (from 1/10)"] = "Etwas kleinere (ab 1/10)",
    ["Smaller (from 1/12)"] = "Kleinere (ab 1/12)",
    ["Very small (from 1/16)"] = "Sehr kleine (ab 1/16)",
    ["Automatic: only colourful panels (experimental)"] = "Automatisch: nur farbige Panels (experimentell)",
    [REFRESH_AUTO_HELP] = "Auf Farb-E-Ink hinterlassen vor allem farbige Panels sichtbares Ghosting. Ist das an, bekommen nur farbige Panels den Extra-Refresh bzw. das Dithering, Schwarzweiß-Panels nicht (kein unnötiges Blitzen). Experimentell: Die Automatik schätzt nach der Farbe und liegt nicht immer richtig.",
    ["Every 2nd panel"] = "Jedes 2. Panel",
    ["Every 3rd panel"] = "Jedes 3. Panel",
    ["Every 5th panel"] = "Jedes 5. Panel",
    ["Full page"] = "Ganze Seite",
    ["never"] = "nie",
    ["before"] = "vorher",
    ["after"] = "nachher",
    ["before & after"] = "vorher & nachher",
    ["Never"] = "Nie",
    ["Before the first panel"] = "Vor dem ersten Panel",
    ["After the last panel"] = "Nach dem letzten Panel",
    ["Before and after"] = "Vorher und nachher",
    ["How does it work?"] = "Wie funktioniert das?",
    [HELP_TEXT] = "Panel-Zoom einschalten (unten: Panel-Zoom zulassen) und lange auf ein Panel drücken: Die Panel-Ansicht öffnet sich.\n\nIn der Panel-Ansicht:\n• Rand rechts oder links antippen: nächstes oder vorheriges Panel, am Seitenende weiter zur nächsten Seite.\n• Mitte antippen: zurück zur Seite.\n• Lange drücken: freier Zoom.\n• Nach oben wischen: ganze Seite, nach unten: zurück zum Panel.\n• Nach links oder rechts wischen: Maske an/aus.\n• Oben Mitte / unten Mitte antippen: KOReaders Menüs.\n\nLeserichtung (Comic oder Manga) und alles andere stellst du hier im Panel-Zoom-Menü ein.\n\nDie automatischen Einstellungen (Hintergrund, Refresh beim Panelwechsel) sind experimentell: Sie schätzen nach Helligkeit und Farbe. Liegen sie daneben, wähle eine feste Einstellung.",
}

local function use_german()
    local ok, lang = pcall(function() return G_reader_settings:readSetting("language") end)
    if not ok or type(lang) ~= "string" then
        ok, lang = pcall(function() return gettext.current_lang end)
    end
    return ok and type(lang) == "string" and lang:sub(1, 2):lower() == "de"
end

local function _(s)
    if DE[s] and use_german() then return DE[s] end
    return gettext(s)
end
local logger = require("logger")
local util = require("util")
local json = require("json")
local DataStorage = require("datastorage")
local ConfirmBox = require("ui/widget/confirmbox")

local USER_SETTINGS = {
    reading_direction_override = "ltr", -- User override for reading direction (rtl/ltr)
    zoom_margin_percent = 0.05, -- Default 5% extra margin for the free zoom mode
    standard_margin_percent = 0.0, -- Default 0% extra margin for standard panel-by-panel navigation
    show_adjacent_panels = true, -- Show adjacent content (Smart Fill)
    zoom_initial_scale = 1.2, -- Default 1.2x initial software scale for the free zoom mode
    panelzoom_tap_forward_zone = "auto", -- auto, left, or right
    experimental_panel_sorting_enabled = false,
    overview_gesture = true, -- Wischen hoch = ganze Seite, Wischen runter = zurueck zum Panel
    mask_swipe = true, -- Wischen links/rechts in der Panel-Ansicht = Maske an/aus
    panel_refresh_on = true, -- Refresh beim Panelwechsel gegen Ghosting: aktiv
    panel_refresh_mode = false, -- "clean" (zweiter Refresh) oder "fast" (Dithering); false = noch nicht gesetzt
    panel_refresh_auto = true, -- Automatik: nur farbige Panels
    panel_refresh_dark = false, -- Automatik: auch dunkle Schwarzweiss-Panels
    panel_refresh = "panel", -- Wie oft im Modus Sauber: panel, nth oder page (bis 24.10. auch off/auto)
    mask_black = false, -- alt (bis 1.11): Hintergrund schwarz statt weiss; wird in mask_bg uebernommen
    mask_bg = false, -- Hintergrund um das Panel: "white", "black" oder "auto" (false = noch nicht gesetzt)
    overview_frame = true, -- Rahmen um das aktuelle Panel in der Seitenuebersicht per Wischen
    page_overview = "off", -- ganze Seite automatisch zeigen: off, before (vor 1. Panel), after (nach letztem), both
    panel_refresh_every = 2, -- bei panel_refresh = "nth": jedes wievielte Panel
    panel_min_size = "normal", -- Mindestgroesse erkannter Panels: normal (1/8 der Seite), small (1/12), tiny (1/16)
}

local PanelZoomIntegration = WidgetContainer:extend{
    name = "comicpanelzoom",
    integration_mode = false,
    current_panels = {},
    current_panel_index = 1,
    last_page_seen = -1,
    tap_navigation_enabled = true,
    tap_zones = { left = 0.3, right = 0.7 },
    _panel_cache = {}, -- Cache JSON per document
    _preloaded_image = nil, -- Pre-rendered next panel
    _preloaded_panel_index = nil, -- Index of preloaded panel
    _is_switching = false, -- Debounce guard to prevent fast tap issues
    _is_changing_page = false, -- True while a page change is in progress
    _page_change_diff = nil, -- Direction of current page change (+1 or -1)
    _original_panel_zoom_handler = nil, -- Store original panel zoom handler
    _original_ocr_handler = nil, -- Store original OCR handler
    _original_ocr_menu_enabled = nil, -- Store original OCR menu state
    _original_genPanelZoomMenu = nil, -- Store original panel zoom menu function
    _json_available = false, -- Track if JSON is available for current document
}

-- Einstellungen liegen in KOReaders Einstellungsordner, nicht im Plugin-Ordner.
-- So gehen sie nicht verloren, wenn der Plugin-Ordner bei einem Update ersetzt wird.
function PanelZoomIntegration:settingsFile()
    return DataStorage:getSettingsDir() .. "/comicpanelzoom.json"
end

function PanelZoomIntegration:savePluginSettings()
    local filepath = self:settingsFile()
    local file = io.open(filepath, "w")
    if file then
        local settings_to_save = {}
        
        for key, _ in pairs(USER_SETTINGS) do
            settings_to_save[key] = self[key]
        end
        
        file:write(json.encode(settings_to_save))
        file:close()
        
        logger.info("PanelZoom: Settings successfully saved to " .. filepath)
    else
        logger.warn("PanelZoom: Failed to open settings file for writing")
    end
end

local function read_json(filepath)
    local file = io.open(filepath, "r")
    if not file then return nil end
    local content = file:read("*all")
    file:close()
    local ok, data = pcall(json.decode, content)
    if ok and type(data) == "table" then return data end
    return nil
end

function PanelZoomIntegration:loadSavedSettings()
    local saved_settings = read_json(self:settingsFile())
    local migrated = false
    if not saved_settings then
        -- Erster Start mit neuem Speicherort: alte settings.json aus dem Plugin-Ordner uebernehmen
        saved_settings = read_json(self.path .. "/settings.json")
        migrated = saved_settings ~= nil
    end
    saved_settings = saved_settings or {}

    for key, default_value in pairs(USER_SETTINGS) do
        if saved_settings[key] ~= nil then
            self[key] = saved_settings[key]
        else
            self[key] = default_value
        end
    end

    -- Hintergrund: alten Schalter (schwarz an/aus) in die neue Auswahl uebernehmen
    if self.mask_bg ~= "white" and self.mask_bg ~= "black" and self.mask_bg ~= "auto" then
        self.mask_bg = self.mask_black and "black" or "white"
    end

    -- Refresh: alte Auswahl (bis 24.10.: off, auto, panel, nth, page) in Modus und Automatik uebernehmen
    if self.panel_refresh_mode ~= "clean" and self.panel_refresh_mode ~= "fast" then
        local old = saved_settings.panel_refresh
        if old == nil then
            self.panel_refresh_mode = "fast"
        elseif old == "off" then
            -- bisher kein zweiter Refresh, aber Dithering bei jedem Panel: so bleibt es
            self.panel_refresh_mode, self.panel_refresh_auto = "fast", false
        else
            self.panel_refresh_mode = "clean"
            self.panel_refresh_auto = old == "auto"
        end
        if old ~= nil then migrated = true end
    end
    if self.panel_refresh ~= "panel" and self.panel_refresh ~= "nth" and self.panel_refresh ~= "page" then
        self.panel_refresh = "panel"
    end

    if migrated then
        logger.info("PanelZoom: Migrated settings from plugin folder to " .. self:settingsFile())
        self:savePluginSettings()
    end
end

function PanelZoomIntegration:resetSettingsToDefault()
    local reset_dialog
    reset_dialog = ConfirmBox:new{
        text = _("Are you sure you want to reset all Panel Zoom settings to their default values?"),
        type = "yes_no",
        ok_callback = function()
            for key, default_value in pairs(USER_SETTINGS) do
                self[key] = default_value
            end

            self:savePluginSettings()
            self:invalidatePanelCache()

            UIManager:close(reset_dialog)
            
            local InfoMessage = require("ui/widget/infomessage")
            UIManager:show(InfoMessage:new{
                text = _("Restored default settings successfully!"),
                timeout = 2,
            })
        end,
        cancel_callback = function()
            UIManager:close(reset_dialog)
        end,
    }
    UIManager:show(reset_dialog)
end

function PanelZoomIntegration:invalidatePanelCache()
    -- Clear all caches globally so next panel invocation re-sorts
    self._panel_cache = {}
    self.current_panels = {}
    self:refreshCurrentPanelIfActive()
end

function PanelZoomIntegration:init()
    self:loadSavedSettings()

    -- Auto-detect JSON and integrate with Panel Zoom when document is opened
    self.onDocumentLoaded = function()
        self:checkAndIntegratePanelZoom()
    end
    
    -- Page change handler: event-driven panel transitions
    -- KOReader dispatches PageUpdate as: handler(self, new_page_no, orig_mode)
    -- When _is_changing_page is true, the event was triggered by our changePage()
    -- call to onGotoViewRel(), so we handle the panel transition.
    -- Otherwise it's a normal page change (user swipe, menu, etc.)
    self.onPageUpdate = function(_, new_page_no)
        if self._is_changing_page then
            self:_onPageChangeComplete(new_page_no)
        else
            self:checkAndIntegratePanelZoom()
        end
    end
    
    -- Optional: Re-render current panel if document settings change
    self.onSettingsUpdate = function()
        if self._current_imgviewer and self.integration_mode then
            logger.info("PanelZoom: Settings changed, refreshing current panel")
            self:displayCurrentPanel()
        end
    end
    
    -- Integrate with existing panel zoom menu
    self:setupPanelZoomMenuIntegration()
end

-- Leserichtung pro Comic aus den Buch-Einstellungen holen
function PanelZoomIntegration:onReaderReady()
    self:wrapHinting()
    self._book_direction = self.ui.doc_settings and self.ui.doc_settings:readSetting("comicpanelzoom_direction") or nil
end


-- Helligkeit/Waerme am Rand auch in der Panel-Ansicht: Der Viewer liegt ueber der Lese-Ansicht und
-- bekommt alle Gesten. Hier werden sie gezielt an die Rand-Zonen der Lese-Ansicht weitergereicht:
-- LiveLight (livelight_*) und KOReaders eigene Rand-Wischgesten (*_left_edge_* / *_right_edge_*).
-- Andere Zonen (z. B. Umblaettern) bekommen nichts, damit sich unter dem Viewer nichts bewegt.
local function is_edge_zone(id)
    return id:find("livelight", 1, true) or id:find("left_edge", 1, true) or id:find("right_edge", 1, true)
end

function PanelZoomIntegration:forwardEdgeGesture(ges)
    local zones = self.ui and self.ui._ordered_touch_zones
    if not zones or not ges then return false end
    for _, tz in ipairs(zones) do
        local id = tz.def and tz.def.id
        if id and is_edge_zone(id) and tz.gs_range:match(ges) and tz.handler(ges) then
            return true
        end
    end
    return false
end

-- KOReader-Menues aus der Panel-Ansicht heraus oeffnen (der Viewer faengt sonst alle Tipps ab)
function PanelZoomIntegration:showReaderMenu()
    if self.ui.menu and self.ui.menu.onShowMenu then
        self.ui.menu:onShowMenu()
        return true
    end
    return false
end

function PanelZoomIntegration:showConfigMenu()
    if self.ui.config and self.ui.config.onShowConfigMenu then
        self.ui.config:onShowConfigMenu()
        return true
    end
    return false
end

-- Get effective reading direction (override takes precedence over JSON)
function PanelZoomIntegration:getEffectiveReadingDirection()
    -- Pro Comic gespeicherte Leserichtung hat Vorrang vor dem Standard fuer neue Comics
    if self._book_direction then
        return self._book_direction
    end
    if self.reading_direction_override then
        return self.reading_direction_override
    end
    return "ltr"
end

-- Check if document is compatible and integrate with Panel Zoom automatically
function PanelZoomIntegration:checkAndIntegratePanelZoom()
    if not self.ui.document then return end
    
    local doc_path = self.ui.document.file
    if not doc_path then return end
    
    -- Dynamic Panel Zoom is always available, we just integrate it
    self._json_available = true -- we fake it to keep the integration flag happy
    self:integrateWithPanelZoom()
    logger.info("DynamicPanelZoom: Auto-integration enabled")
end

-- Integrate with built-in Panel Zoom
function PanelZoomIntegration:integrateWithPanelZoom()
    if not self.ui.highlight then return end
    
    -- Store the original handler if not already stored
    if not self._original_panel_zoom_handler then
        self._original_panel_zoom_handler = self.ui.highlight.onPanelZoom
    end
    
    -- Store the original panel zoom enabled state
    if self._original_panel_zoom_enabled == nil then
        self._original_panel_zoom_enabled = self.ui.highlight.panel_zoom_enabled
    end
    
    -- Override Panel Zoom to use our JSON when available
    self.ui.highlight.onPanelZoom = function(inst, arg, ges)
        return self:onIntegratedPanelZoom(arg, ges)
    end
    
    self.integration_mode = true
    if self.ui.highlight then self.ui.highlight.panel_zoom_enabled = true end
    
    -- Block OCR when Panel Zoom integration is active
    self:blockOCR()
end

-- Restore original Panel Zoom behavior
function PanelZoomIntegration:restoreOriginalPanelZoom()
    if not self.ui.highlight then return end
    
    -- Restore the original handler
    if self._original_panel_zoom_handler then
        self.ui.highlight.onPanelZoom = self._original_panel_zoom_handler
    else
        self.ui.highlight.onPanelZoom = nil
    end
    
    -- Restore the original panel zoom enabled state
    if self._original_panel_zoom_enabled ~= nil then
        self.ui.highlight.panel_zoom_enabled = self._original_panel_zoom_enabled
    end
    
    self.integration_mode = false
    
    -- Restore OCR when Panel Zoom integration is disabled
    self:restoreOCR()
    
    -- Restore original panel zoom menu
    self:restorePanelZoomMenu()
end

-- Block OCR functionality when Panel Zoom is active
function PanelZoomIntegration:blockOCR()
    -- Store original OCR handler if not already stored
    if not self._original_ocr_handler and self.ui.ocr then
        self._original_ocr_handler = self.ui.ocr.onOCRText
    end
    
    -- Disable OCR by replacing the handler with a no-op function
    if self.ui.ocr then
        self.ui.ocr.onOCRText = function()
            logger.info("DynamicPanelZoom: OCR blocked - Panel Zoom integration is active")
            return false
        end
        logger.info("DynamicPanelZoom: OCR functionality blocked")
    end
    
    -- Also disable OCR menu items if available
    if self.ui.menu and self.ui.menu.ocr_menu then
        self._original_ocr_menu_enabled = self.ui.menu.ocr_menu.enabled
        self.ui.menu.ocr_menu.enabled = false
        logger.info("DynamicPanelZoom: OCR menu items disabled")
    end
end

-- Restore OCR functionality when Panel Zoom is disabled
function PanelZoomIntegration:restoreOCR()
    -- Guard against multiple restoration calls
    if not self._original_ocr_handler and (self._original_ocr_menu_enabled == nil) then
        return -- Already restored or never stored
    end
    
    -- Restore original OCR handler
    if self.ui.ocr and self._original_ocr_handler then
        self.ui.ocr.onOCRText = self._original_ocr_handler
        self._original_ocr_handler = nil
        logger.info("DynamicPanelZoom: OCR functionality restored")
    end
    
    -- Restore OCR menu items
    if self.ui.menu and self.ui.menu.ocr_menu and self._original_ocr_menu_enabled ~= nil then
        self.ui.menu.ocr_menu.enabled = self._original_ocr_menu_enabled
        self._original_ocr_menu_enabled = nil
        logger.info("DynamicPanelZoom: OCR menu items restored")
    end
end

-- Mindestgroesse fuer erkannte Panels. Kleinere Kaesten gelten als Stoerung und werden verworfen.
-- Standard wie im Original: mindestens 1/8 der Seitenbreite und -hoehe.
local MIN_PANEL = {
    normal = { frac = 1 / 8, area = 0.02, side = 0.05 },
    mid = { frac = 1 / 10, area = 0.015, side = 0.045 },
    small = { frac = 1 / 12, area = 0.01, side = 0.04 },
    tiny = { frac = 1 / 16, area = 0.005, side = 0.03 },
}

function PanelZoomIntegration:minPanelFraction()
    return (MIN_PANEL[self.panel_min_size or "normal"] or MIN_PANEL.normal).frac
end

function PanelZoomIntegration:minPanelArea()
    local m = MIN_PANEL[self.panel_min_size or "normal"] or MIN_PANEL.normal
    return m.area, m.side
end

-- Ganze Seite vor dem ersten bzw. nach dem letzten Panel (Einstellung page_overview: off, before, after, both)
function PanelZoomIntegration:wantsOverview(kind)
    local o = self.page_overview or "off"
    if not (o == "both" or o == kind) then return false end
    -- Seite besteht nur aus einem Panel, das fast die ganze Seite fuellt (Doppelseite, Splash-Panel):
    -- Die Uebersicht saehe genauso aus wie das Panel, also weglassen, sonst kommt dieselbe Seite dreimal.
    if #self.current_panels == 1 then
        local p = self.current_panels[1]
        if p.w * p.h >= 0.7 then return false end -- 70 % der Seitenflaeche, Raender eingerechnet
    end
    return true
end

-- Ein Panel weiter in Lesereihenfolge (beruecksichtigt die automatische Seitenuebersicht)
function PanelZoomIntegration:goForward()
    local kind = self._overview_active and self._overview_kind or nil
    if kind == "before" then
        -- Uebersicht vor dem ersten Panel: jetzt das erste Panel zeigen
        return self:displayCurrentPanel(false)
    elseif kind == "after" then
        logger.info("PanelZoom: Overview after last panel done, jumping to next page")
        return self:changePage(1)
    end

    -- Check preload first for Next
    if self._preloaded_image and self._preloaded_panel_index == self.current_panel_index + 1 then
        logger.info("PanelZoom: Using preloaded panel for instant switch (Forward)")
        self.current_panel_index = self.current_panel_index + 1
        if not self:displayPreloadedPanel() then self:displayCurrentPanel() end
        return
    end

    if self.current_panel_index < #self.current_panels then
        self.current_panel_index = self.current_panel_index + 1
        self:displayCurrentPanel()
    elseif self:wantsOverview("after") and not self._overview_active then
        self:showOverview(true, "after")
    else
        -- End of page, go to next page
        logger.info("PanelZoom: End of page reached, jumping to next page")
        self:changePage(1)
    end
end

-- Ein Panel zurueck in Lesereihenfolge
function PanelZoomIntegration:goBackward()
    local kind = self._overview_active and self._overview_kind or nil
    if kind == "after" then
        -- Uebersicht nach dem letzten Panel: zurueck zum letzten Panel
        return self:displayCurrentPanel(false)
    elseif kind == "before" then
        logger.info("PanelZoom: Overview before first panel, jumping to previous page")
        return self:changePage(-1)
    end

    if self.current_panel_index > 1 then
        self.current_panel_index = self.current_panel_index - 1
        self:displayCurrentPanel()
    elseif self:wantsOverview("before") and not self._overview_active then
        self:showOverview(true, "before")
    else
        -- Top of page reached, go to previous page
        logger.info("PanelZoom: Top of page reached, jumping to previous page")
        self:changePage(-1)
    end
end

-- Callback methods for PanelViewer
-- Spatial navigation methods for PanelViewer
-- Blaettertasten: "weiter" ist immer das naechste Panel in Lesereihenfolge. Nicht ueber die
-- Tipp-Seiten gehen, sonst blaettert die Weiter-Taste rueckwaerts, wenn die eingestellte
-- Tipp-Seite nicht zur Leserichtung passt (z. B. Manga mit "rechts = weiter").
function PanelZoomIntegration:handleKey(forward)
    if self._is_switching or self._is_changing_page then return end
    self._is_switching = true
    UIManager:scheduleIn(0.3, function() self._is_switching = false end)
    if forward then self:goForward() else self:goBackward() end
end

function PanelZoomIntegration:handleTapRight()
    if self._is_switching or self._is_changing_page then return end
    self._is_switching = true
    UIManager:scheduleIn(0.3, function() self._is_switching = false end)
    
    local tap_forward_zone = self.panelzoom_tap_forward_zone or "auto"
    local reading_dir = self:getEffectiveReadingDirection()
    local is_rtl = reading_dir == "rtl"
    
    logger.info(string.format("DynamicPanelZoom: handleTapRight index=%d, is_rtl=%s, reading_dir=%s", 
        self.current_panel_index, tostring(is_rtl), reading_dir))
    
    local intent_forward = false
    if tap_forward_zone == "right" then
        intent_forward = true
    elseif tap_forward_zone == "left" then
        intent_forward = false
    else
        intent_forward = not is_rtl
    end
    
    if intent_forward then
        self:goForward()
    else
        self:goBackward()
    end
end

function PanelZoomIntegration:handleTapLeft()
    if self._is_switching or self._is_changing_page then return end
    self._is_switching = true
    UIManager:scheduleIn(0.3, function() self._is_switching = false end)
    
    local tap_forward_zone = self.panelzoom_tap_forward_zone or "auto"
    local reading_dir = self:getEffectiveReadingDirection()
    local is_rtl = reading_dir == "rtl"
    
    logger.info(string.format("DynamicPanelZoom: handleTapLeft index=%d, is_rtl=%s, reading_dir=%s", 
        self.current_panel_index, tostring(is_rtl), reading_dir))
    
    local intent_forward = false
    if tap_forward_zone == "left" then
        intent_forward = true
    elseif tap_forward_zone == "right" then
        intent_forward = false
    else
        intent_forward = is_rtl
    end
    
    if intent_forward then
        self:goForward()
    else
        self:goBackward()
    end
end

function PanelZoomIntegration:closeViewer()
    if self._current_imgviewer then
        -- Ensure E-Ink refresh suppression is restored if we were mid-page-change
        if UIManager.currently_scrolling then
            UIManager.currently_scrolling = false
        end
        UIManager:close(self._current_imgviewer)
        self._current_imgviewer = nil
        self:cleanupPreloadedImage()
        -- Restore OCR when panel viewer is closed
        self:restoreOCR()
    end
    -- Always clear in-flight page-change state on exit so re-entering panel
    -- view on a new page can't inherit a stuck _is_changing_page from a
    -- prior session where onPageUpdate didn't fire.
    self._is_changing_page = false
    self._page_change_diff = nil
end

-- Preload the next panel in background
function PanelZoomIntegration:preloadNextPanel()
    -- Clean up any existing preloaded image
    self:cleanupPreloadedImage()
    
    local reading_dir = self:getEffectiveReadingDirection()
    local is_rtl = reading_dir == "rtl"
    
    -- In absolute terms, "next" means index+1 (if LTR) or index-1 (if RTL)
    -- Actually, wait: the index IS correctly sorted in importToggleZoomPanels based on reading direction!
    -- Yes, the array is ALWAYS sorted so that index 1 is the START and index N is the END of the page.
    -- So "next panel in logical reading order" is always index + 1!
    local next_panel_index = self.current_panel_index + 1
    
    -- Check if there's a next panel to preload
    if next_panel_index <= #self.current_panels then
        local next_panel = self.current_panels[next_panel_index]
        
        if next_panel then
            logger.info(string.format("DynamicPanelZoom: Preloading panel %d in background", next_panel_index))
            
            local page = self:getSafePageNumber()
            local dim = self.ui.document:getNativePageDimensions(page)
            
            if dim then
                -- Calculate and log panel center coordinates for preloaded panel
                local center = self:calculatePanelCenter(next_panel, dim)
                
                -- Use helper function for center-preserving quantization
                local margin = self.standard_margin_percent or 0.0
                local rect = self:panelToRect(next_panel, dim, margin)
                
                -- Render the next panel with document settings (standard margins for preloading)
                local image, rotate, custom_position = self:drawPagePartWithSettings(page, rect, center, next_panel, dim)
                -- Store preloaded image with panel data for proper centering
                if image then
                    self._preloaded_image = image
                    self._preloaded_panel_index = next_panel_index
                    self._preloaded_panel = next_panel  -- Store panel data
                    self._preloaded_dim = dim          -- Store dimensions
                    self._preloaded_custom_position = custom_position  -- Store calculated position
                    logger.info("DynamicPanelZoom: Successfully preloaded next panel with document settings")
                else
                    logger.warn("DynamicPanelZoom: Failed to preload next panel")
                end
            end
        end
    end
end

-- Display preloaded panel instantly
function PanelZoomIntegration:displayPreloadedPanel()
    if self._current_imgviewer and not UIManager:isWidgetShown(self._current_imgviewer) then
        self._current_imgviewer = nil
    end
    if not self._preloaded_image or not self._current_imgviewer then
        logger.warn("DynamicPanelZoom: No preloaded image or viewer available")
        return false
    end
    
    logger.info("DynamicPanelZoom: Displaying preloaded panel instantly")
    
    -- Update existing viewer with preloaded image using PanelViewer's method
    self._current_imgviewer:updateImage(self._preloaded_image)
    
    -- Get screen and image dimensions
    local Screen = require("device").screen
    local screen_w = Screen:getWidth()
    local screen_h = Screen:getHeight()
    local image_w = self._preloaded_image:getWidth()
    local image_h = self._preloaded_image:getHeight()
    
    -- Use the pre-calculated center-locked position instead of simple centering
    local custom_position = self._preloaded_custom_position or {
        x = math.floor(((screen_w - image_w) / 2) + 0.5),
        y = math.floor(((screen_h - image_h) / 2) + 0.5),
    }
    
    logger.info(string.format("PanelZoom: Using preloaded center-locked position - x:%d, y:%d (image:%dx%d, screen:%dx%d)", 
        custom_position.x, custom_position.y, image_w, image_h, screen_w, screen_h))
    
    self._current_imgviewer:updateCustomPosition(custom_position)
    logger.info(string.format("PanelZoom: Updated custom position for preloaded panel - x:%d, y:%d (image:%dx%d, screen:%dx%d)", 
        custom_position.x, custom_position.y, image_w, image_h, screen_w, screen_h))
    
    self._current_imgviewer.plain = false
    self._current_imgviewer.bg_black = self:bgBlackFor(self._preloaded_image)
    self._current_imgviewer.dither = self:panelDither(self._preloaded_image)
    self._current_imgviewer:update()
    self._overview_active = false
    self:panelRefresh(false, self._preloaded_image)

    -- Clear preloaded data after use
    self._preloaded_image = nil
    self._preloaded_panel_index = nil
    self._preloaded_panel = nil
    self._preloaded_dim = nil
    self._preloaded_custom_position = nil
    
    -- Start preloading the next panel
    UIManager:scheduleIn(0.1, function()
        self:preloadNextPanel()
    end)
    
    return true
end

-- Custom drawPagePart that applies document settings
function PanelZoomIntegration:drawPagePartWithSettings(pageno, rect, panel_center, panel, dim, scale_override)
    -- 1. Document & Screen Settings
    local doc_cfg = self.ui.document.info.config or {}
    local gamma = self.ui.view.state.gamma or doc_cfg.gamma or 1.0
    local contrast = doc_cfg.contrast or 1.0
    
    local Screen = require("device").screen
    local screen_w = Screen:getWidth()
    local screen_h = Screen:getHeight()

    -- 2. DEFINE ABSOLUTE LIMIT SAFE ZONE
    local padding = 5
    local safe_w = screen_w - (padding * 2)
    local safe_h = screen_h - (padding * 2)

    -- 3. CALCULATE SCALE (Must fit inside Safe Zone)
    local final_scale = 1.0
    if scale_override then
        final_scale = scale_override
        logger.info(string.format("DynamicPanelZoom: Using override scale %.4f", final_scale))
    else
        local scale_w = safe_w / rect.w
        local scale_h = safe_h / rect.h
        final_scale = math.min(scale_w, scale_h)
    end

    -- Calculate final display dimensions
    local display_w = math.floor(rect.w * final_scale + 0.5)
    local display_h = math.floor(rect.h * final_scale + 0.5)

    -- 4. ORIGINAL CENTERING LOGIC
    -- We calculate the top-left to perfectly center the box on screen
    local pos_x = (screen_w - display_w) / 2
    local pos_y = (screen_h - display_h) / 2

    -- 5. CLAMPING TO ABSOLUTE LIMITS
    -- Forces the panel to stay at least 5px from any edge
    local custom_position = {
        x = math.floor(math.max(padding, math.min(pos_x, screen_w - display_w - padding)) + 0.5),
        y = math.floor(math.max(padding, math.min(pos_y, screen_h - display_h - padding)) + 0.5)
    }

    -- 6. ASPECT RATIO NUDGES (Original offsets)
    if panel and dim then
        local panel_aspect_ratio = (panel.w * dim.w) / (panel.h * dim.h)
        if panel_aspect_ratio >= 0.67 then
            custom_position.x = custom_position.x - 1
        else
            custom_position.y = custom_position.y - 0
        end
    end

    -- 7. RENDER
    -- Create the geometry for MuPDF
    local geom_rect = Geom:new(rect)
    local scaled_rect = geom_rect:copy()
    scaled_rect:transformByScale(final_scale, final_scale)
    rect.scaled_rect = scaled_rect

    local tile
    local renderPage = self.ui.document.renderPage
    local info = debug.getinfo(renderPage, "u")
    if info and info.nparams and info.nparams >= 8 then
        -- New signature: pageno, rect, zoom, rotation, gamma, saturation, hinting.
        -- KOReaders Farbsaettigung uebernehmen (Farb-E-Ink, z. B. Libra Colour; gemeldet bei PanelsPlus #8)
        local view_state = self.ui.view and self.ui.view.state
        local saturation = view_state and view_state.saturation or 1.0
        tile = self.ui.document:renderPage(pageno, rect, final_scale, 0, gamma, saturation, true)
    else
        -- Old signature: pageno, rect, zoom, rotation, gamma, hinting
        tile = self.ui.document:renderPage(pageno, rect, final_scale, 0, gamma, true)
    end
    local image = tile and tile.bb

    -- 8. POST-PROCESSING
    if image then
        if contrast ~= 1.0 and image.contrast then
            image:contrast(contrast)
        end
        if doc_cfg.invert and image.invert then
            image:invert()
        end
        
        logger.info(string.format("DynamicPanelZoom: [Safe Zone %dpx] Rendered %dx%d at (%d,%d)", 
            padding, display_w, display_h, custom_position.x, custom_position.y))
    end

    return image, false, custom_position
end

-- Apply KOReader's contrast and gamma settings to image buffer
-- This can be used for preloaded images or manual refreshes
function PanelZoomIntegration:applyDocumentSettings(image)
    if not image then return false end
    
    local doc_cfg = self.ui.document.info.config or {}
    local contrast = doc_cfg.contrast or 1.0
    local gamma = self.ui.view.state.gamma or doc_cfg.gamma or 1.0
    
    -- Contrast
    if image.contrast and contrast ~= 1.0 then
        image:contrast(contrast)
        logger.info(string.format("DynamicPanelZoom: Applied contrast %.2f", contrast))
    end
    
    -- Gamma (if not handled during renderPage)
    if image.gamma and gamma ~= 1.0 then
        image:gamma(gamma)
        logger.info(string.format("DynamicPanelZoom: Applied gamma %.2f", gamma))
    end
    
    -- Invert
    if image.invert and doc_cfg.invert then
        image:invert()
        logger.info("DynamicPanelZoom: Applied image inversion")
    end
    
    return true
end

-- Clean up preloaded image to prevent memory leaks
function PanelZoomIntegration:cleanupPreloadedImage()
    if self._preloaded_image then
        logger.info("DynamicPanelZoom: Cleaning up preloaded image")
        self._preloaded_image = nil
        self._preloaded_panel_index = nil
        self._preloaded_custom_position = nil
    end
end

function PanelZoomIntegration:changePage(diff)
    -- DO NOT close the current panel viewer immediately. 
    -- Leaving it open keeps the screen covered with the last panel 
    -- while KOReader renders the new full page in the background, 
    -- preventing the "flash of full page" spoiler.

    -- Clear preloaded cache immediately to prevent ghost images
    self:cleanupPreloadedImage()

    -- Eine offene Seitenuebersicht gehoert zur alten Seite. Ohne Zuruecksetzen wuerde die Uebersicht
    -- der neuen Seite ("vorher") denken, sie sei schon offen, und die alte Seite stehen lassen.
    self._overview_active = false
    self._overview_kind = nil

    -- Save current state for the event-driven flow
    self._is_changing_page = true
    self._page_change_diff = diff

    -- FLASH PREVENTION: Suppress E-Ink screen refreshes while KOReader
    -- renders the new page underneath our PanelViewer.
    -- `currently_scrolling = true` forces all refresh modes to "fast" (no flash).
    UIManager.currently_scrolling = true

    -- Safety net: if onPageUpdate never fires (legacy Kindle builds, missed
    -- events, etc.), _is_changing_page would stay true forever and silently
    -- drop every subsequent handleTapRight/Left/Key navigation, making the
    -- viewer look softlocked. Force-reset both the E-Ink refresh suppression
    -- and the page-change flag after 1s so the worst case is a 1s delay, not
    -- a permanent dead viewer.
    UIManager:scheduleIn(1.0, function()
        if UIManager.currently_scrolling then
            logger.warn("DynamicPanelZoom: Safety net restored currently_scrolling to false")
            UIManager.currently_scrolling = false
        end
        if self._is_changing_page then
            logger.warn("DynamicPanelZoom: Safety net forced _is_changing_page to false (onPageUpdate likely never fired)")
            self._is_changing_page = false
            self._page_change_diff = nil
        end
    end)

    -- Trigger page navigation.
    -- onGotoViewRel is SYNCHRONOUS: it calls _gotoPage() which emits PageUpdate
    -- before returning. Our onPageUpdate handler will detect _is_changing_page
    -- and call _onPageChangeComplete() via nextTick.
    if self.ui.paging and self.ui.paging.onGotoViewRel then
        self.ui.paging:onGotoViewRel(diff)
        logger.info(string.format("DynamicPanelZoom: Used ui.paging.onGotoViewRel(%d)", diff))
    else
        -- Fallback to key event — this path does NOT guarantee a PageUpdate event,
        -- so we handle it directly with nextTick as a safety measure.
        local key = diff > 0 and "Right" or "Left"
        UIManager:sendEvent({ key = key, modifiers = {} })
        logger.info(string.format("DynamicPanelZoom: Used %s key event as fallback", key))
        -- Since key events may not trigger onPageUpdate synchronously,
        -- schedule the completion handler ourselves.
        self:_onPageChangeComplete(nil)
    end
end

-- Handle page change completion. Called by onPageUpdate (event-driven) or
-- directly from changePage() fallback path. Uses nextTick to ensure all
-- other PageUpdate handlers (ReaderView, ReaderZooming, etc.) have finished
-- processing before we load our panel.
function PanelZoomIntegration:_onPageChangeComplete(new_page_no)
    UIManager:nextTick(function()
        -- Restore normal refresh behavior now that we're ready to show our panel
        UIManager.currently_scrolling = false
        -- Prevent the partial->full flash promotion counter from triggering
        UIManager:avoidFlashOnNextRepaint()

        local new_page = new_page_no or self:getSafePageNumber()
        local diff = self._page_change_diff or 1
        logger.info(string.format("DynamicPanelZoom: Page change complete - page %d (diff: %d)", new_page, diff))
        self.last_page_seen = new_page

        self:importToggleZoomPanels()

        if #self.current_panels > 0 then
            -- Moving Forward (diff > 0): Start at first panel of new page.
            -- Moving Backward (diff < 0): Start at last panel of previous page.
            self.current_panel_index = (diff > 0) and 1 or #self.current_panels
            -- Neue Seite: auf Wunsch erst die ganze Seite zeigen (vorwaerts: vor dem ersten Panel,
            -- rueckwaerts: die Uebersicht "nach dem letzten Panel" dieser Seite)
            local kind = (diff > 0) and "before" or "after"
            if not (self:wantsOverview(kind) and self._current_imgviewer and self:showOverview(true, kind)) then
                self:displayCurrentPanel(true)
            end
        else
            UIManager:show(InfoMessage:new{ text = _("No panels on this page"), timeout = 1 })
            self:closeViewer()
        end

        self._is_changing_page = false
        self._page_change_diff = nil
    end)
end

function PanelZoomIntegration:getSafePageNumber()
    -- Try multiple methods to get the current page number
    local page = nil
    
    -- Method 1: Try ui.paging.getPage()
    if self.ui.paging and self.ui.paging.getPage then 
        page = self.ui.paging:getPage()
        logger.info(string.format("PanelZoom: Method 1 - ui.paging.getPage() -> %d", page))
    end
    
    -- Method 2: Try ui.paging.cur_page
    if not page and self.ui.paging and self.ui.paging.cur_page then 
        page = self.ui.paging.cur_page
        logger.info(string.format("PanelZoom: Method 2 - ui.paging.cur_page -> %d", page))
    end
    
    -- Method 3: Try ui.document.current_page
    if not page and self.ui.document and self.ui.document.current_page then 
        page = self.ui.document.current_page
        logger.info(string.format("PanelZoom: Method 3 - ui.document.current_page -> %d", page))
    end
    
    -- Method 4: Try ui.view.state.page
    if not page and self.ui.view and self.ui.view.state and self.ui.view.state.page then 
        page = self.ui.view.state.page
        logger.info(string.format("PanelZoom: Method 4 - ui.view.state.page -> %d", page))
    end
    
    -- Method 5: Try getting from the highlighting system
    if not page and self.ui.highlight and self.ui.highlight.page then 
        page = self.ui.highlight.page
        logger.info(string.format("PanelZoom: Method 5 - ui.highlight.page -> %d", page))
    end
    
    -- Fallback
    if not page then 
        page = 1
        logger.info("PanelZoom: Using fallback page number 1")
    end
    
    return page
end

function PanelZoomIntegration:onIntegratedPanelZoom(arg, ges)
    -- Ensure we have the gesture object
    local actual_ges = (type(arg) == "table" and arg.pos) and arg or ges
    
    -- If JSON is not available, fall back to built-in Panel Zoom
    if not self._json_available then
        logger.info("DynamicPanelZoom: JSON not available, using built-in Panel Zoom")
        if self._original_panel_zoom_handler then
            return self._original_panel_zoom_handler(self.ui.highlight, arg, ges)
        end
        return false
    end
    
    local current_page = self:getSafePageNumber()
    logger.info(string.format("DynamicPanelZoom: onIntegratedPanelZoom called - current_page: %d, last_page_seen: %d, panels_count: %d", 
        current_page, self.last_page_seen or -1, #self.current_panels))
    
    -- Force import if page changed or panels empty
    if current_page ~= self.last_page_seen or #self.current_panels == 0 then
        logger.info(string.format("DynamicPanelZoom: Page changed or no panels - importing for page %d", current_page))
        self.last_page_seen = current_page
        self:importToggleZoomPanels()
    else
        logger.info(string.format("DynamicPanelZoom: Using cached panels for page %d", current_page))
    end

    if #self.current_panels > 0 then
        -- Mit dem Panel unter dem Finger starten (wie KOReaders eigener Panel-Zoom), sonst mit dem ersten
        self.current_panel_index = self:findPanelAt(actual_ges) or 1
        return self:displayCurrentPanel(true)
    end

    logger.warn("DynamicPanelZoom: No panels found for this page in JSON.")
    return false
end

-- Index des Panels unter der Fingerposition (nil, wenn keins getroffen)
function PanelZoomIntegration:findPanelAt(ges)
    if not ges or not ges.pos or not self.ui.view or not self.ui.view.screenToPageTransform then return nil end
    local ok, pos = pcall(self.ui.view.screenToPageTransform, self.ui.view, ges.pos)
    if not ok or not pos or not pos.x then return nil end
    local dim = self.ui.document:getNativePageDimensions(self:getSafePageNumber())
    if not dim or dim.w <= 0 or dim.h <= 0 then return nil end
    local fx, fy = pos.x / dim.w, pos.y / dim.h
    local best, best_area
    for i, p in ipairs(self.current_panels) do
        if fx >= p.x and fx <= p.x + p.w and fy >= p.y and fy <= p.y + p.h then
            -- Bei verschachtelten Treffern das kleinste Panel nehmen
            local area = p.w * p.h
            if not best_area or area < best_area then best, best_area = i, area end
        end
    end
    return best
end

function PanelZoomIntegration:importToggleZoomPanels()
    local doc_path = self.ui.document.file
    if not doc_path then return end
    
    local page_idx = self:getSafePageNumber()
    local reading_dir = self:getEffectiveReadingDirection()
    
    -- The cache key must now include reading_dir, otherwise flipping direction
    -- uses the old cached layout where panel 1 meant LTR/top-left instead of RTL/top-right.
    if not self._panel_cache[doc_path] then self._panel_cache[doc_path] = {} end
    if not self._panel_cache[doc_path][reading_dir] then self._panel_cache[doc_path][reading_dir] = {} end
    
    -- Check if we already have panels for this page cached in memory FOR THIS READING DIR
    if self._panel_cache[doc_path][reading_dir][page_idx] then
        logger.info(string.format("DynamicPanelZoom: Using cached %s panels for page %d", reading_dir, page_idx))
        self.current_panels = self._panel_cache[doc_path][reading_dir][page_idx]
        return
    end
    
    logger.info(string.format("DynamicPanelZoom: Analyzing page %d for %s panels dynamically", page_idx, reading_dir))
    if self.experimental_panel_sorting_enabled then
        self.current_panels = self:analyzePageForPanelsExperimental(page_idx)
    else
        self.current_panels = self:analyzePageForPanels(page_idx)
    end
    
    -- Cache it for this document and page and direction
    self._panel_cache[doc_path][reading_dir][page_idx] = self.current_panels
    
    if #self.current_panels > 0 then
        logger.info(string.format("DynamicPanelZoom: SUCCESS! Detected %d panels for page %d (%s)", #self.current_panels, page_idx, reading_dir))
    else
        logger.warn(string.format("DynamicPanelZoom: No panels detected on page %d", page_idx))
    end
end

function PanelZoomIntegration:analyzePageForPanels(pageno)
    local ffi = require("ffi")
    local leptonica = ffi.loadlib("leptonica", "6")
    
    if not self.ui.document or not self.ui.document._document then return {} end
    
    -- Re-use or instantiate KOPTContext
    local KOPTContext = require("ffi/koptcontext")
    local page_size = self.ui.document:getNativePageDimensions(pageno)
    
    if not page_size then return {} end
    
    -- Limit the dimensions to avoid OOM or slow processing
    local target_w = page_size.w
    local target_h = page_size.h
    
    local bbox = {
        x0 = 0, y0 = 0,
        x1 = target_w,
        y1 = target_h,
    }
    
    -- We can get the koptinterface from pdfdocument/cbzdocument if needed,
    -- or manually via KoptInterface:createContext
    local Document = require("document/document")
    local koptinterface
    if self.ui.document.koptinterface then
        koptinterface = self.ui.document.koptinterface
    end
    
    local kc
    if koptinterface and koptinterface.createContext then
        kc = koptinterface:createContext(self.ui.document, pageno, bbox)
    else
        -- Fallback: manual creation
        kc = KOPTContext.new()
        kc:setZoom(1.0)
        kc:setBBox(bbox.x0, bbox.y0, bbox.x1, bbox.y1)
    end
    
    local page = self.ui.document._document:openPage(pageno)
    if not page then 
        if kc.free then kc:free() end
        return {} 
    end
    
    page:getPagePix(kc, self.ui.document.render_mode)
    
    local panels = {}
    
    if kc.src.data then
        local KOPTContextClass = require("ffi/koptcontext")
        local k2pdfopt = KOPTContextClass.k2pdfopt
        
        -- Helper destructors for FFI to avoid memory leaks
        local function _gc_ptr(p, destructor)
            return p and ffi.gc(p, destructor)
        end
        local function pixDestroy(pix)
            leptonica.pixDestroy(ffi.new('PIX *[1]', pix))
            ffi.gc(pix, nil)
        end
        local function boxDestroy(box)
            leptonica.boxDestroy(ffi.new('BOX *[1]', box))
            ffi.gc(box, nil)
        end
        local function boxaDestroy(boxa)
            leptonica.boxaDestroy(ffi.new('BOXA *[1]', boxa))
            ffi.gc(boxa, nil)
        end

        local pixs = _gc_ptr(k2pdfopt.bitmap2pix(kc.src, 0, 0, kc.src.width, kc.src.height), pixDestroy)
        
        local pixg
        if leptonica.pixGetDepth(pixs) == 32 then
            pixg = leptonica.pixConvertRGBToGrayFast(pixs)
        else
            pixg = leptonica.pixClone(pixs)
        end
        pixg = _gc_ptr(pixg, pixDestroy)
        
        local pix_inverted = _gc_ptr(leptonica.pixInvert(nil, pixg), pixDestroy)
        local pix_thresholded = _gc_ptr(leptonica.pixThresholdToBinary(pix_inverted, 50), pixDestroy)
        leptonica.pixInvert(pix_thresholded, pix_thresholded)
        
        local bb = _gc_ptr(leptonica.pixConnCompBB(pix_thresholded, 8), boxaDestroy)
        
        local img_w = leptonica.pixGetWidth(pixs)
        local img_h = leptonica.pixGetHeight(pixs)
        
        local function boxGetGeometry(box)
            local geo = ffi.new('l_int32[4]')
            leptonica.boxGetGeometry(box, geo, geo + 1, geo + 2, geo + 3)
            return tonumber(geo[0]), tonumber(geo[1]), tonumber(geo[2]), tonumber(geo[3])
        end

        local count = leptonica.boxaGetCount(bb)
        for index = 0, count - 1 do
            local box = _gc_ptr(leptonica.boxaGetBox(bb, index, leptonica.L_CLONE), boxDestroy)
            
            local pix_tmp = _gc_ptr(leptonica.pixClipRectangle(pixs, box, nil), pixDestroy)
            local w = leptonica.pixGetWidth(pix_tmp)
            local h = leptonica.pixGetHeight(pix_tmp)
            
            local min_frac = self:minPanelFraction()
            if w >= img_w * min_frac and h >= img_h * min_frac then
                local box_x, box_y, box_w, box_h = boxGetGeometry(box)
                
                table.insert(panels, {
                    x = box_x / target_w,
                    y = box_y / target_h,
                    w = box_w / target_w,
                    h = box_h / target_h,
                })
            end
            -- Note: Memory is handled automatically by _gc_ptr!
        end
    end
    
    page:close()
    if kc.free then kc:free() end
    
    -- Sort panels based on reading direction (Manga TR->BL)
    local effective_dir = self:getEffectiveReadingDirection()
    table.sort(panels, function(a, b)
        -- We want to sort primarily top-to-bottom, and secondarily according to direction
        -- If their y ranges overlap significantly, they are on the same "row"
        local a_center_y = a.y + (a.h / 2)
        local b_center_y = b.y + (b.h / 2)
        
        -- Rough same-row threshold ~10% of page height
        if math.abs(a_center_y - b_center_y) < 0.1 then
            if effective_dir == "rtl" then
                return a.x > b.x -- Right to Left
            else
                return a.x < b.x -- Left to Right
            end
        end
        
        return a_center_y < b_center_y -- Top to bottom
    end)
    
    return panels
end

function PanelZoomIntegration:analyzePageForPanelsExperimental(pageno)
    local ffi = require("ffi")
    local leptonica = ffi.loadlib("leptonica", "6")
    
    if not self.ui.document or not self.ui.document._document then return {} end
    
    local KOPTContext = require("ffi/koptcontext")
    local page_size = self.ui.document:getNativePageDimensions(pageno)
    
    if not page_size then return {} end
    
    local target_w = page_size.w
    local target_h = page_size.h
    
    local bbox = {
        x0 = 0, y0 = 0,
        x1 = target_w,
        y1 = target_h,
    }
    
    local Document = require("document/document")
    local koptinterface
    if self.ui.document.koptinterface then
        koptinterface = self.ui.document.koptinterface
    end
    
    local kc
    if koptinterface and koptinterface.createContext then
        kc = koptinterface:createContext(self.ui.document, pageno, bbox)
    else
        kc = KOPTContext.new()
        kc:setZoom(1.0)
        kc:setBBox(bbox.x0, bbox.y0, bbox.x1, bbox.y1)
    end
    
    local page = self.ui.document._document:openPage(pageno)
    if not page then 
        if kc.free then kc:free() end
        return {} 
    end
    
    page:getPagePix(kc, self.ui.document.render_mode)
    
    local initial_boxes = {}
    
    if kc.src.data then
        local KOPTContextClass = require("ffi/koptcontext")
        local k2pdfopt = KOPTContextClass.k2pdfopt
        
        local function _gc_ptr(p, destructor)
            return p and ffi.gc(p, destructor)
        end
        local function pixDestroy(pix)
            leptonica.pixDestroy(ffi.new('PIX *[1]', pix))
            ffi.gc(pix, nil)
        end
        local function boxDestroy(box)
            leptonica.boxDestroy(ffi.new('BOX *[1]', box))
            ffi.gc(box, nil)
        end
        local function boxaDestroy(boxa)
            leptonica.boxaDestroy(ffi.new('BOXA *[1]', boxa))
            ffi.gc(boxa, nil)
        end

        local pixs = _gc_ptr(k2pdfopt.bitmap2pix(kc.src, 0, 0, kc.src.width, kc.src.height), pixDestroy)
        
        local pixg
        if leptonica.pixGetDepth(pixs) == 32 then
            pixg = leptonica.pixConvertRGBToGrayFast(pixs)
        else
            pixg = leptonica.pixClone(pixs)
        end
        pixg = _gc_ptr(pixg, pixDestroy)
        
        local pix_inverted = _gc_ptr(leptonica.pixInvert(nil, pixg), pixDestroy)
        local pix_thresholded = _gc_ptr(leptonica.pixThresholdToBinary(pix_inverted, 50), pixDestroy)
        leptonica.pixInvert(pix_thresholded, pix_thresholded)
        
        local bb = _gc_ptr(leptonica.pixConnCompBB(pix_thresholded, 8), boxaDestroy)
        
        local img_w = leptonica.pixGetWidth(pixs)
        local img_h = leptonica.pixGetHeight(pixs)
        
        local function boxGetGeometry(box)
            local geo = ffi.new('l_int32[4]')
            leptonica.boxGetGeometry(box, geo, geo + 1, geo + 2, geo + 3)
            return tonumber(geo[0]), tonumber(geo[1]), tonumber(geo[2]), tonumber(geo[3])
        end

        local count = leptonica.boxaGetCount(bb)
        for index = 0, count - 1 do
            local box = _gc_ptr(leptonica.boxaGetBox(bb, index, leptonica.L_CLONE), boxDestroy)
            
            -- We don't filter during extraction, we just get all boxes
            local box_x, box_y, box_w, box_h = boxGetGeometry(box)
            table.insert(initial_boxes, {
                x = box_x / target_w,
                y = box_y / target_h,
                w = box_w / target_w,
                h = box_h / target_h,
            })
        end
    end
    
    page:close()
    if kc.free then kc:free() end

    logger.info(string.format("DynamicPanelZoom (Experimental): Extracted %d raw components from Leptonica", #initial_boxes))

    -- 3.1 Minimum area filter
    local filtered_boxes = {}
    local min_area_threshold, min_side = self:minPanelArea() -- Standard: 2% der Seitenflaeche, Seiten > 5%
    for _, box in ipairs(initial_boxes) do
        local area = box.w * box.h
        -- Also check minimum w/h proportions to avoid extremely thin lines being accepted
        if area >= min_area_threshold and box.w > min_side and box.h > min_side then
            table.insert(filtered_boxes, box)
        end
    end

    -- 3.2 Nesting check (discard boxes completely contained in others)
    local final_boxes = {}
    for i, box1 in ipairs(filtered_boxes) do
        local is_nested = false
        for j, box2 in ipairs(filtered_boxes) do
            if i ~= j then
                -- Add a small margin of error (0.01) for the nesting check
                if box1.x >= box2.x - 0.01 and box1.y >= box2.y - 0.01 and 
                   (box1.x + box1.w) <= (box2.x + box2.w) + 0.01 and 
                   (box1.y + box1.h) <= (box2.y + box2.h) + 0.01 then
                    is_nested = true
                    break
                end
            end
        end
        if not is_nested then
            table.insert(final_boxes, box1)
        end
    end

    logger.info(string.format("DynamicPanelZoom (Experimental): %d components remaining after filtering", #final_boxes))

    -- 4.1 Sort vertically by top `y` coordinate
    table.sort(final_boxes, function(a, b)
        return a.y < b.y
    end)

    -- 4.2 Group into rows by intersection
    local rows = {}
    local current_row = {}
    local current_row_min_y = nil
    local current_row_max_y = nil

    for _, box in ipairs(final_boxes) do
        if #current_row == 0 then
            table.insert(current_row, box)
            current_row_min_y = box.y
            current_row_max_y = box.y + box.h
        else
            -- Check intersection with current row bounds
            local box_max_y = box.y + box.h
            -- A box intersects the row if its top is before row's bottom, and its bottom is after row's top
            -- Adding a small margin
            local margin = 0.05
            if box.y < current_row_max_y - margin and box_max_y > current_row_min_y + margin then
                -- Belongs to current row
                table.insert(current_row, box)
                -- Update row bounds
                current_row_min_y = math.min(current_row_min_y, box.y)
                current_row_max_y = math.max(current_row_max_y, box_max_y)
            else
                -- Start a new row
                table.insert(rows, current_row)
                current_row = {box}
                current_row_min_y = box.y
                current_row_max_y = box.y + box.h
            end
        end
    end
    if #current_row > 0 then
        table.insert(rows, current_row)
    end

    -- 4.3 Sort each row horizontally and 4.4 Concatenate
    local effective_dir = self:getEffectiveReadingDirection()
    local final_panels = {}
    
    for row_idx, row in ipairs(rows) do
        table.sort(row, function(a, b)
            if effective_dir == "rtl" then
                return a.x > b.x
            else
                return a.x < b.x
            end
        end)
        
        for _, box in ipairs(row) do
            table.insert(final_panels, box)
        end
    end

    -- 5.1 Debug log the final ordered panel sequence
    logger.info(string.format("DynamicPanelZoom (Experimental): Final sequence (%d panels, %d rows) for %s reading direction:", #final_panels, #rows, effective_dir))
    for i, p in ipairs(final_panels) do
        logger.info(string.format("  Panel %d: x=%.3f, y=%.3f, w=%.3f, h=%.3f", i, p.x, p.y, p.w, p.h))
    end

    return final_panels
end

function PanelZoomIntegration:calculatePanelCenter(panel, dim)
    -- Calculate absolute center coordinates from panel JSON data
    -- Center_x = x + w/2, Center_y = y + h/2
    local center_x = panel.x + (panel.w / 2)
    local center_y = panel.y + (panel.h / 2)
    
    -- Convert to absolute pixel coordinates
    local abs_center_x = math.floor(center_x * dim.w + 0.5)
    local abs_center_y = math.floor(center_y * dim.h + 0.5)
    
    logger.info(string.format("PanelZoom: Panel center - normalized:(%.3f, %.3f), absolute:(%d, %d)", 
        center_x, center_y, abs_center_x, abs_center_y))
    
    return {
        x = center_x,
        y = center_y,
        abs_x = abs_center_x,
        abs_y = abs_center_y
    }
end

function PanelZoomIntegration:panelToRect(panel, dim, apply_margin_percent)
    -- Step 1: Compute panel center (NO padding involved) - semantic center only
    local panel_cx = (panel.x + panel.w / 2) * dim.w
    local panel_cy = (panel.y + panel.h / 2) * dim.h
    
    -- Step 2: Build a padded render rect (crop source)
    -- panel rect in page pixels
    local px = panel.x * dim.w
    local py = panel.y * dim.h
    local pw = panel.w * dim.w
    local ph = panel.h * dim.h
    
    local left_extension = 0
    local right_extension = 0
    local top_extension = 0
    local bottom_extension = 0

    if apply_margin_percent and apply_margin_percent > 0 then
        -- Zoom mode (or standard mode with custom margins): Apply constant absolute margin based on page size
        local base_dimension = math.max(dim.w, dim.h)
        local constant_margin = math.floor(base_dimension * apply_margin_percent + 0.5)
        
        left_extension = constant_margin
        right_extension = constant_margin
        top_extension = constant_margin
        bottom_extension = constant_margin
        logger.info(string.format("PanelZoom: Applying constant %.0fpx expanded margins", constant_margin))
    else
        -- Standard Panel Mode: Use default tight constraints
        local panel_aspect_ratio = pw / ph
        
        left_extension = 2   -- Less extension on left side
        right_extension = 2 -- 4px + 5px more extension on right
        top_extension = 0.5
        bottom_extension = 2.5
    end
    
    local render_rect = {
        x = px - left_extension,
        y = py - top_extension,
        w = pw + left_extension + right_extension,
        h = ph + top_extension + bottom_extension,
    }
    
    -- Clamp to page bounds
    render_rect.w = math.min(render_rect.w, dim.w)
    render_rect.h = math.min(render_rect.h, dim.h)
    render_rect.x = math.max(0, math.min(render_rect.x, dim.w - render_rect.w))
    render_rect.y = math.max(0, math.min(render_rect.y, dim.h - render_rect.h))

    -- Step 3: Smart Fill (Aspect Ratio Expansion)
    if self.show_adjacent_panels then
        local screen_width = Screen:getWidth()
        local screen_height = Screen:getHeight()
        -- Handle landscape mode if orientation changed
        if self.view and self.view.mode == "landscape" then
            screen_width, screen_height = screen_height, screen_width
        end

        local screen_ratio = screen_width / screen_height
        local rect_ratio = render_rect.w / render_rect.h

        if rect_ratio > screen_ratio then
            -- Panel is wider than screen: Need to expand vertically (height)
            local target_new_h = render_rect.w / screen_ratio
            local total_expansion_needed = target_new_h - render_rect.h
            local expansion_per_side = total_expansion_needed / 2
            
            -- V4: Apply expansion symmetrically WITHOUT clamping to document bounds
            -- This allows render_rect.y to be negative and render_rect.h to exceed dim.h
            render_rect.y = render_rect.y - expansion_per_side
            render_rect.h = render_rect.h + (expansion_per_side * 2)
            
        elseif rect_ratio < screen_ratio then
            -- Panel is taller than screen: Need to expand horizontally (width)
            local target_new_w = render_rect.h * screen_ratio
            local total_expansion_needed = target_new_w - render_rect.w
            local expansion_per_side = total_expansion_needed / 2
            
            -- V4: Apply expansion symmetrically WITHOUT clamping to document bounds
            -- This allows render_rect.x to be negative and render_rect.w to exceed dim.w
            render_rect.x = render_rect.x - expansion_per_side
            render_rect.w = render_rect.w + (expansion_per_side * 2)
        end
    end
    
    logger.info(string.format("PanelZoom: Panel center:(%.1f,%.1f) render_rect:(%d,%d,%dx%d)", 
        panel_cx, panel_cy, render_rect.x, render_rect.y, render_rect.w, render_rect.h))
    
    -- Return render rect and panel center for later calculations
    return {
        x = render_rect.x,
        y = render_rect.y,
        w = render_rect.w,
        h = render_rect.h,
        panel_cx = panel_cx,  -- Semantic center (no padding)
        panel_cy = panel_cy   -- Semantic center (no padding)
    }
end


-- Seitenuebersicht: ganze Seite zeigen (on = true, Wischen hoch), aktuelles Panel umrahmt.
-- on = false (Wischen runter) fuehrt zurueck zum Panel.
-- kind: "manual" (Wischen), "before" (vor dem ersten Panel) oder "after" (nach dem letzten Panel)
function PanelZoomIntegration:showOverview(on, kind)
    kind = kind or "manual"
    if not self._current_imgviewer then return false end
    if kind == "manual" and not self.overview_gesture then return false end
    if not on then
        if not self._overview_active then return false end
        self._overview_active = false
        self:displayCurrentPanel(false)
        return true
    end
    if self._overview_active then
        self._overview_kind = kind
        return true
    end

    local page = self:getSafePageNumber()
    local dim = self.ui.document:getNativePageDimensions(page) or self.ui.document:getPageSize(page)
    if not dim then return false end
    local rect = { x = 0, y = 0, w = dim.w, h = dim.h }
    local image, _, custom_position = self:drawPagePartWithSettings(page, rect, nil, nil, dim)
    if not image then return false end
    -- Kopie, denn das gerenderte Bild liegt im Seiten-Cache von KOReader und darf nicht bemalt werden
    image = image:copy()

    -- Rahmen um das aktuelle Panel, damit man sieht, wo man gerade ist.
    -- Nur bei der Uebersicht per Wischen (abschaltbar), nicht bei der automatischen vorher/nachher.
    local panel = self.current_panels[self.current_panel_index]
    if panel and kind == "manual" and self.overview_frame then
        local iw, ih = image:getWidth(), image:getHeight()
        local x, y = math.floor(panel.x * iw), math.floor(panel.y * ih)
        local w, h = math.floor(panel.w * iw), math.floor(panel.h * ih)
        local t = math.max(3, math.floor(math.min(iw, ih) / 200))
        local black = Blitbuffer.COLOR_BLACK
        image:paintRect(x, y, w, t, black)
        image:paintRect(x, y + h - t, w, t, black)
        image:paintRect(x, y, t, h, black)
        image:paintRect(x + w - t, y, t, h, black)
    end

    local viewer = self._current_imgviewer
    viewer.plain = true
    viewer.bg_black = self:bgBlackFor(image)
    viewer:updateCustomPosition(custom_position)
    viewer:updatePanelAspectRatio(nil)
    viewer:updateImage(image)
    viewer.dither = self:panelDither(image)
    viewer:update()
    self._overview_active = true
    self._overview_kind = kind
    self:panelRefresh(true, image)
    return true
end

-- Weisse Maske um das Panel an/aus (gleiche Einstellung wie im Menue)
function PanelZoomIntegration:toggleMask()
    if not self.mask_swipe or not self._current_imgviewer or self._overview_active then return false end
    self.show_adjacent_panels = not self.show_adjacent_panels
    self:savePluginSettings()
    self:refreshCurrentPanelIfActive()
    pcall(function()
        local Notification = require("ui/widget/notification")
        Notification:notify(self.show_adjacent_panels and _("Mask off") or _("Mask on"))
    end)
    return true
end

function PanelZoomIntegration:switchToZoomMode()
    logger.info("DynamicPanelZoom: Switching to Free Zoom Mode")
    
    local panel = self.current_panels[self.current_panel_index]
    if not panel then return false end

    local page = self:getSafePageNumber()
    local dim = self.ui.document:getNativePageDimensions(page) or self.ui.document:getPageSize(page)
    if not dim then return false end

    -- 1. Get expanded rect (margin for reading text that spills out)
    local margin = self.zoom_margin_percent or 0.05
    local expanded_rect = self:panelToRect(panel, dim, margin)
    local center = self:calculatePanelCenter(panel, dim)
    
    -- 2. DYNAMIC SCALING (To prevent Segmentation Fault)
    -- We cannot render arbitrary large images on E-Ink memory limits.
    -- We calculate the scale so the image buffer NEVER exceeds screen size + a small buffer
    local screen_w = Screen:getWidth()
    local screen_h = Screen:getHeight()
    
    -- Safe memory rendering constraints
    -- E-ink displays can usually handle a buffer 2.5x to 3x their resolution
    -- before hitting SegFaults, but 1.5x is too blurry for comics text.
    -- We raise this to 2.5x to get crisp text while staying safely below the crash threshold.
    local max_buffer_w = screen_w * 2.5
    local max_buffer_h = screen_h * 2.5
    
    -- Find a safe base scale for the MuPDF render phase
    local scale_w = max_buffer_w / expanded_rect.w
    local scale_h = max_buffer_h / expanded_rect.h
    local safe_scale = math.min(scale_w, scale_h, 3.5) -- Raised the hard render scale cap to 3.5x
    
    logger.info(string.format("DynamicPanelZoom: Using safe memory render scale %.4f", safe_scale))

    -- 3. Generate safe expanded image
    local expanded_image, _, _ = self:drawPagePartWithSettings(page, expanded_rect, center, panel, dim, safe_scale)
    if not expanded_image then return false end

    -- Create native ImageViewer using safe dynamic loading
    local ok, ImageViewer = pcall(require, "ui/widget/imageviewer")
    if not ok or type(ImageViewer) ~= "table" then
        logger.warn("DynamicPanelZoom: Failed to load imageviewer widget")
        return false
    end
    
    -- 4. APPLY SOFTWARE ZOOM OVER THE SAFE RENDER
    -- To prevent any visual "jump" when switching to 1.0x, we need to match the exact visual scale 
    -- the user was just looking at in the PanelViewer.
    -- First, calculate what the scale was in the normal PanelViewer:
    local standard_margin = self.standard_margin_percent or 0.0
    local normal_rect = self:panelToRect(panel, dim, standard_margin) -- Rect with standard panel margins
    local padding = 5
    local safe_w = screen_w - (padding * 2)
    local safe_h = screen_h - (padding * 2)
    local normal_scale = math.min(safe_w / normal_rect.w, safe_h / normal_rect.h)
    
    -- The absolute scale we want to achieve on the physical screen (1 pixel image = 1 pixel screen at 1.0x)
    local target_absolute_scale = normal_scale / safe_scale
    
    -- IMPORTANT: ImageViewer doesn't treat scale_factor 1.0 as 1:1 pixels.
    -- It treats 1.0 as "Fit to screen" for the given image within its UI context.
    -- When buttons_visible = true, ImageViewer reserves space at the bottom (usually ~10-12% of screen height).
    local image_w = expanded_image:getWidth()
    local image_h = expanded_image:getHeight()
    
    -- Estimate ImageViewer's actual usable viewport (it reserves bottom space for buttons)
    local Size = require("ui/size")
    local button_bar_height = Size.bottom_menu_height or math.floor(screen_h * 0.1)
    local usable_h = screen_h - button_bar_height
    
    local fit_to_screen_scale = math.min(screen_w / image_w, usable_h / image_h)
    
    -- The software scale factor to pass to ImageViewer to achieve our target absolute scale
    -- Fix: ImageViewer uses explicit scale_factor as absolute scale on the image's native resolution, 
    -- not as a multiplier over fit_to_screen. Therefore, we pass target_absolute_scale directly.
    local base_visual_scale = target_absolute_scale
    
    -- Apply the user's zoom preference on top of that base scale
    local bump_factor = self.zoom_initial_scale or 1.2
    local initial_scale_factor = base_visual_scale * bump_factor
    
    logger.info(string.format("DynamicPanelZoom: ImageViewer usable height approx %d (screen %d)", usable_h, screen_h))
    logger.info(string.format("DynamicPanelZoom: ImageViewer Fit-to-screen scale is %.4f", fit_to_screen_scale))
    logger.info(string.format("DynamicPanelZoom: Required Absolute scale is %.4f", target_absolute_scale))
    logger.info(string.format("DynamicPanelZoom: Setting ImageViewer software scale factor to %.4f (bump: %.1fx)", initial_scale_factor, bump_factor))

    local image_viewer = ImageViewer:new{
        image = expanded_image,
        image_disposable = false, -- Disabled forced deletion to prevent garbage collection races/color noise
        fullscreen = true,
        with_title_bar = false,
        buttons_visible = true, -- Restored native UI buttons and minimap
        scale_factor = initial_scale_factor,
        
        -- Calculate the exact semantic center ratio of the panel inside our cropped expanded image
        -- This ensures the ImageViewer starts positioned right over the panel, compensating for asymmetrical margins near page edges.
        _center_x_ratio = (center.abs_x - expanded_rect.x) / expanded_rect.w,
        _center_y_ratio = (center.abs_y - expanded_rect.y) / expanded_rect.h,
    }

    -- We just push the image_viewer on top of the UI stack. 
    -- The PanelViewer stays underneath. When image_viewer is closed, PanelViewer is instantly revealed without flashing the background page.
    UIManager:show(image_viewer)
    return true
end

-- Voll-Refresh nach einem Panelwechsel gegen Ghosting (Einstellung panel_refresh).
-- tickAfterNext: laeuft direkt nachdem das neue Panel gezeichnet wurde.
-- Bewertung eines Panel-Bildes: Stichprobe 24 x 32 Bildpunkte, mittlere Helligkeit und Farbigkeit.
-- Dunkle oder farbige Panels brauchen den Refresh gegen Ghosting, helle Schwarzweiss-Panels nicht.
local AUTO_COLOUR_ABOVE = 30

-- Mittlere Helligkeit, Farbigkeit und Randhelligkeit eines Panels (nil, wenn nicht messbar)
local function panel_metrics(bb)
    if not bb then return nil end
    local ok, l, c, e = pcall(function()
        local w, h = bb:getWidth(), bb:getHeight()
        if w < 8 or h < 8 then return nil end
        local sum_l, sum_c, n = 0, 0, 0
        for j = 0, 31 do
            local y = math.floor((j + 0.5) * h / 32)
            for i = 0, 23 do
                local px = bb:getPixel(math.floor((i + 0.5) * w / 24), y)
                if px then
                    local col = px:getColorRGB32()
                    sum_l = sum_l + 0.299 * col.r + 0.587 * col.g + 0.114 * col.b
                    sum_c = sum_c + math.max(col.r, col.g, col.b) - math.min(col.r, col.g, col.b)
                    n = n + 1
                end
            end
        end
        if n == 0 then return nil end
        -- Rand des Panels (2 % nach innen), wie bei Comic Display der Seitenrand
        local bx, by = math.max(1, math.floor(w * 0.02)), math.max(1, math.floor(h * 0.02))
        local sum_e, n_e = 0, 0
        for k = 0, 39 do
            local x, y = math.floor((k + 0.5) * w / 40), math.floor((k + 0.5) * h / 40)
            for _, p in ipairs({ { x, by }, { x, h - 1 - by }, { bx, y }, { w - 1 - bx, y } }) do
                local px = bb:getPixel(p[1], p[2])
                if px then
                    local col = px:getColorRGB32()
                    sum_e = sum_e + 0.299 * col.r + 0.587 * col.g + 0.114 * col.b
                    n_e = n_e + 1
                end
            end
        end
        return sum_l / n, sum_c / n, n_e > 0 and sum_e / n_e or nil
    end)
    if not ok or not l then return nil end
    return l, c, e
end

-- Automatik gegen Ghosting (wie Comic Display): auf Farb-E-Ink stoert vor allem Farbe,
-- auf Wunsch bekommen auch sehr dunkle Schwarzweiss-Panels den Extra-Schritt
local DARK_BW_BELOW = 100
local function panel_wants_extra(bb, dark)
    local l, c = panel_metrics(bb)
    if not l then return true end
    if c > AUTO_COLOUR_ABOVE then return true end
    return dark and l < DARK_BW_BELOW or false
end

-- Hintergrund automatisch, gleiche Regel wie die dunklen Raender von Comic Display:
-- schwarz, wenn das Panel einen dunklen Rand hat (Bild bis an den Rand) oder ganz sehr dunkel ist.
-- Farbe allein zaehlt nicht. Pufferzone: die Grenze haengt von der vorigen Entscheidung ab,
-- damit aehnliche Panels hintereinander nicht zwischen hell und dunkel springen.
local BG_EDGE_DARK_BELOW, BG_DARK_ENTER, BG_DARK_LEAVE = 110, 100, 125
local function panel_wants_black(bb, previous)
    local l, _c, e = panel_metrics(bb)
    if not l then return previous or false end
    if e and e < BG_EDGE_DARK_BELOW then return true end
    if previous then return l < BG_DARK_LEAVE end
    return l < BG_DARK_ENTER
end

-- Hintergrundfarbe fuer ein Panel: fest weiss/schwarz oder automatisch nach dem Panel-Inhalt
function PanelZoomIntegration:bgBlackFor(image)
    if self.mask_bg == "black" then return true end
    if self.mask_bg == "auto" then
        self._auto_bg_black = panel_wants_black(image, self._auto_bg_black)
        return self._auto_bg_black
    end
    return false
end

-- Refresh beim Panelwechsel: off, clean (zweiter Refresh) oder fast (Dithering)
function PanelZoomIntegration:refreshMode()
    if self.panel_refresh_on == false then return "off" end
    return self.panel_refresh_mode == "clean" and "clean" or "fast"
end

-- Dithering fuer das neue Panel (schaltet auf Kaleido den Farbmodus ein): immer, wenn KOReaders
-- Dithering-Schalter fuer das Buch an ist, sonst im Modus Schnell nach der Automatik
function PanelZoomIntegration:panelDither(image)
    if self.ui.document and self.ui.document.hw_dithering then return true end
    if self:refreshMode() ~= "fast" then return false end
    if not self.panel_refresh_auto then return true end
    local want = panel_wants_extra(image, self.panel_refresh_dark)
    logger.info("DynamicPanelZoom: auto dither", want and "on" or "off")
    return want
end

function PanelZoomIntegration:panelRefresh(new_page, image)
    local due = false
    if self:refreshMode() == "clean" then
        local freq = self.panel_refresh
        if freq == "nth" then
            -- Nur jedes n-te Panel (Zaehler laeuft ueber Seitengrenzen weiter)
            self._panel_counter = (self._panel_counter or 0) + 1
            due = self._panel_counter % math.max(1, self.panel_refresh_every or 2) == 0
        elseif freq == "page" then
            due = new_page and true or false
        else
            due = true
        end
        if due and self.panel_refresh_auto then
            due = panel_wants_extra(image, self.panel_refresh_dark)
            logger.info("DynamicPanelZoom: auto refresh", due and "refresh" or "skip")
        end
    end
    if not due and self._refresh_pending then
        -- Kein Refresh mehr faellig (z. B. schnell weitergeblaettert): Vorausladen nicht liegen lassen
        if self._refresh_wrapper then UIManager:unschedule(self._refresh_wrapper) end
        self._refresh_seq = (self._refresh_seq or 0) + 1
        self._refresh_pending = false
        local hint = self._deferred_hint
        self._deferred_hint = nil
        if hint then hint() end
    end
    if due then
        if self._refresh_wrapper then UIManager:unschedule(self._refresh_wrapper) end
        -- Waehrend der Refresh aussteht, wartet KOReaders Vorausladen der naechsten Seite (siehe wrapHinting)
        self._refresh_pending = true
        self._refresh_seq = (self._refresh_seq or 0) + 1
        local seq = self._refresh_seq
        self._refresh_wrapper = UIManager:tickAfterNext(function()
            UIManager:setDirty(nil, "full", nil, true)
            -- erst freigeben, wenn der Refresh auf dem Bildschirm ist (Ende dieses Durchlaufs)
            UIManager:scheduleIn(0.05, function()
                if seq ~= self._refresh_seq then return end
                self._refresh_pending = false
                local hint = self._deferred_hint
                self._deferred_hint = nil
                if hint then hint() end
            end)
        end)
    end
end

-- Vorausladen erst nach dem Panel-Refresh: Springt die Panel-Ansicht auf eine neue Seite, rechnet
-- KOReader direkt danach die naechste Seite vor. Der Refresh muesste darauf warten. Deshalb wird
-- das Vorausladen zurueckgehalten, bis der Refresh auf dem Bildschirm ist (wie bei Comic Display).
function PanelZoomIntegration:wrapHinting()
    local hinting = self.ui.hinting
    if not hinting or hinting._comicpanelzoom_wrapped then return end
    hinting._comicpanelzoom_wrapped = true
    local original = hinting.onHintPage
    local plugin = self
    hinting.onHintPage = function(h, ...)
        if plugin._refresh_pending then
            local args = { ... }
            plugin._deferred_hint = function() original(h, unpack(args)) end
            return true
        end
        return original(h, ...)
    end
end

function PanelZoomIntegration:displayCurrentPanel(new_page)
    logger.info("DynamicPanelZoom: displayCurrentPanel called")
    self._overview_active = false
    local panel = self.current_panels[self.current_panel_index]
    if not panel then 
        logger.warn("DynamicPanelZoom: No panel data found for index " .. self.current_panel_index)
        return false 
    end

    local page = self:getSafePageNumber()
    
    -- Get dimensions from document for consistent coordinate space
    local dim = self.ui.document:getNativePageDimensions(page) or self.ui.document:getPageSize(page)
    if not dim then 
        logger.warn("DynamicPanelZoom: Could not get page dimensions")
        return false 
    end
    logger.info(string.format("DynamicPanelZoom: Using document dimensions - w:%d, h:%d", dim.w, dim.h))

    -- Use helper function for center-preserving quantization with dynamic frame
    local margin = self.standard_margin_percent or 0.0
    local rect = self:panelToRect(panel, dim, margin)
    
    -- Calculate and log panel center coordinates
    local center = self:calculatePanelCenter(panel, dim)
    
    logger.info(string.format("DynamicPanelZoom: Panel rect - x:%d, y:%d, w:%d, h:%d", rect.x, rect.y, rect.w, rect.h))
    
    -- Create new image for the panel with document settings
    local image, rotate, custom_position = self:drawPagePartWithSettings(page, rect, center, panel, dim)
    if not image then 
        logger.warn("DynamicPanelZoom: Could not draw page part")
        return false 
    end
    
    logger.info("DynamicPanelZoom: Successfully created panel image with document settings")

    -- Calculate panel aspect ratio for border logic
    local panel_aspect_ratio = nil
    if panel and dim then
        local panel_w = panel.w * dim.w
        local panel_h = panel.h * dim.h
        panel_aspect_ratio = panel_w / panel_h
        logger.info(string.format("DynamicPanelZoom: Panel aspect ratio: %.3f", panel_aspect_ratio))
    end

    -- Viewer wurde ausserhalb des Plugins geschlossen (Selbst-Schliessen im Viewer): Verweis verwerfen
    if self._current_imgviewer and not UIManager:isWidgetShown(self._current_imgviewer) then
        self._current_imgviewer = nil
    end

    -- Reuse existing viewer if available instead of closing to prevent flash of full page
    if self._current_imgviewer then
        logger.info("DynamicPanelZoom: Updating existing PanelViewer")
        self._current_imgviewer:updateReadingDirection(self:getEffectiveReadingDirection())
        self._current_imgviewer.plain = false
        self._current_imgviewer.bg_black = self:bgBlackFor(image)
        self._current_imgviewer:updateCustomPosition(custom_position)
        self._current_imgviewer:updatePanelAspectRatio(panel_aspect_ratio)
        self._current_imgviewer:updateImage(image)
        self._current_imgviewer.dither = self:panelDither(image)
        self._current_imgviewer:update()
        self:panelRefresh(new_page, image)

        -- Start preloading the next panel after a short delay
        UIManager:scheduleIn(0.2, function()
            self:preloadNextPanel()
        end)
        return true
    end
    
    -- Create new PanelViewer instance with our custom implementation
    logger.info("DynamicPanelZoom: Creating new PanelViewer instance")
    local panel_viewer = PanelViewer:new{
        image = image,
        dither = self:panelDither(image), -- Dithering (Farbmodus) beim Panelwechsel
        fullscreen = true,
        buttons_visible = false,
        reading_direction = self:getEffectiveReadingDirection(),
        custom_position = custom_position,  -- Pass custom position for center matching
        panel_aspect_ratio = panel_aspect_ratio,  -- Pass panel aspect ratio for border logic
        onTapRight = function() self:handleTapRight() end,
        onTapLeft = function() self:handleTapLeft() end,
        onKeyForward = function() self:handleKey(true) end,
        onKeyBackward = function() self:handleKey(false) end,
        onClose = function() 
            self:closeViewer()
            -- Restore OCR when panel viewer is closed
            self:restoreOCR()
        end,
        onHold = function()
            self:switchToZoomMode()
        end,
        onSwipeUp = function() return self:showOverview(true) end,
        onSwipeDown = function() return self:showOverview(false) end,
        onSwipeHorizontal = function() return self:toggleMask() end,
        onEdgeGesture = function(ges) return self:forwardEdgeGesture(ges) end,
        onTopTap = function() return self:showReaderMenu() end,
        onBottomTap = function() return self:showConfigMenu() end,
        bg_black = self:bgBlackFor(image),
    }
    
    self._current_imgviewer = panel_viewer
    logger.info("DynamicPanelZoom: Showing new PanelViewer")
    UIManager:show(panel_viewer)
    
    -- Use "ui" refresh for initial panel display to avoid E-Ink flash.
    -- "flashui" would cause a visible full-screen flash on E-Ink devices.
    -- Dithering is still enabled for image quality on grayscale E-Ink displays.
    -- "partial" wie beim normalen Umblaettern (weniger Ghosting als "ui" auf Farb-E-Ink),
    -- Dithering (Farbmodus auf Kaleido) nach den Refresh-Einstellungen
    local dither = panel_viewer.dither and true or false
    panel_viewer.dithered = dither or nil
    UIManager:setDirty(panel_viewer, function()
        return "partial", panel_viewer.dimen, dither
    end)
    
    logger.info("DynamicPanelZoom: New PanelViewer shown with flash-free refresh")
    self:panelRefresh(new_page, image)

    -- Start preloading the next panel after a short delay
    UIManager:scheduleIn(0.2, function()
        self:preloadNextPanel()
    end)
    
    return true -- Success, new viewer created
end

function PanelZoomIntegration:setStandardMarginPercent(percent)
    self.standard_margin_percent = percent
    self:savePluginSettings()
end

function PanelZoomIntegration:setZoomMarginPercent(percent)
    self.zoom_margin_percent = percent
    self:savePluginSettings()
end

function PanelZoomIntegration:setZoomInitialScale(scale)
    self.zoom_initial_scale = scale
    self:savePluginSettings()
end

-- Integrate reading direction options into existing panel zoom menu
function PanelZoomIntegration:setupPanelZoomMenuIntegration()
    -- Store original genPanelZoomMenu function
    if not self._original_genPanelZoomMenu and self.ui.highlight and self.ui.highlight.genPanelZoomMenu then
        self._original_genPanelZoomMenu = self.ui.highlight.genPanelZoomMenu
        
        -- Override genPanelZoomMenu to include our reading direction options
        self.ui.highlight.genPanelZoomMenu = function()
            local menu_items = self._original_genPanelZoomMenu(self.ui.highlight)
            
            -- Add reading direction submenu at the beginning
            -- Leserichtung: oben fuer diesen Comic (wird im Buch gespeichert), darunter der Standard fuer neue Comics
            local function set_book_direction(dir)
                self._book_direction = dir
                if self.ui.doc_settings then self.ui.doc_settings:saveSetting("comicpanelzoom_direction", dir) end
                logger.info("DynamicPanelZoom: Reading direction for this book set to " .. dir)
                self:invalidatePanelCache()
            end
            local function set_default_direction(dir)
                self.reading_direction_override = dir
                logger.info("DynamicPanelZoom: Default reading direction set to " .. dir)
                self:invalidatePanelCache()
                self:savePluginSettings()
            end
            table.insert(menu_items, 1, {
                text = _("Reading direction"),
                sub_item_table = {
                    {
                        text = _("This comic") .. ": " .. _("Left-to-Right (LTR)"),
                        radio = true,
                        checked_func = function() return self:getEffectiveReadingDirection() == "ltr" end,
                        callback = function() set_book_direction("ltr") end,
                    },
                    {
                        text = _("This comic") .. ": " .. _("Right-to-Left (RTL)"),
                        radio = true,
                        checked_func = function() return self:getEffectiveReadingDirection() == "rtl" end,
                        callback = function() set_book_direction("rtl") end,
                        separator = true,
                    },
                    {
                        text = _("Default for new comics"),
                        sub_item_table = {
                            {
                                text = _("Left-to-Right (LTR)"),
                                radio = true,
                                checked_func = function()
                                    return self.reading_direction_override == "ltr" or self.reading_direction_override == nil
                                end,
                                callback = function() set_default_direction("ltr") end,
                            },
                            {
                                text = _("Right-to-Left (RTL)"),
                                radio = true,
                                checked_func = function() return self.reading_direction_override == "rtl" end,
                                callback = function() set_default_direction("rtl") end,
                            },
                        },
                    },
                },
                separator = true,
            })

            -- Gesten
            table.insert(menu_items, 2, {
                text = _("Gestures"),
                sub_item_table = {
                    {
                        text = _("Page overview by swiping up"),
                        help_text = _("Swipe up to see the whole page, swipe down to go back to the panel."),
                        checked_func = function() return self.overview_gesture end,
                        callback = function()
                            self.overview_gesture = not self.overview_gesture
                            self:savePluginSettings()
                        end,
                    },
                    {
                        text = _("Frame current panel in page overview"),
                        checked_func = function() return self.overview_frame end,
                        callback = function()
                            self.overview_frame = not self.overview_frame
                            self:savePluginSettings()
                        end,
                    },
                    {
                        text = _("Toggle mask: swipe left or right"),
                        checked_func = function() return self.mask_swipe end,
                        callback = function()
                            self.mask_swipe = not self.mask_swipe
                            self:savePluginSettings()
                        end,
                    },
                },
                separator = true,
            })

            -- Refresh beim Panelwechsel
            table.insert(menu_items, 3, {
                -- Aufbau wie bei Comic Display: Aktiv, Sauber/Schnell, Automatik, Wie oft, Hilfe
                text_func = function()
                    local m = self:refreshMode()
                    local state = m == "clean" and _("clean") or m == "fast" and _("fast") or _("off")
                    return (_("Refresh on panel change: %1"):gsub("%%1", state))
                end,
                sub_item_table = {
                    {
                        text = _("Enabled"),
                        checked_func = function() return self.panel_refresh_on ~= false end,
                        callback = function()
                            self.panel_refresh_on = self.panel_refresh_on == false
                            self:savePluginSettings()
                        end,
                    },
                    {
                        text = _("Clean: two refreshes"),
                        radio = true,
                        enabled_func = function() return self.panel_refresh_on ~= false end,
                        checked_func = function() return self.panel_refresh_mode == "clean" end,
                        callback = function() self.panel_refresh_mode = "clean"; self:savePluginSettings() end,
                        help_text = _(REFRESH_CLEAN_HELP),
                    },
                    {
                        text = _("Fast: automatic dithering"),
                        radio = true,
                        enabled_func = function() return self.panel_refresh_on ~= false end,
                        checked_func = function() return self.panel_refresh_mode ~= "clean" end,
                        callback = function() self.panel_refresh_mode = "fast"; self:savePluginSettings() end,
                        help_text = _(REFRESH_FAST_HELP),
                        separator = true,
                    },
                    {
                        text = _("Automatic: only colourful panels (experimental)"),
                        enabled_func = function() return self.panel_refresh_on ~= false end,
                        checked_func = function() return self.panel_refresh_auto ~= false end,
                        callback = function()
                            self.panel_refresh_auto = self.panel_refresh_auto == false
                            self:savePluginSettings()
                        end,
                        help_text = _(REFRESH_AUTO_HELP),
                    },
                    {
                        text = _("Also dark black-and-white panels (experimental)"),
                        enabled_func = function() return self.panel_refresh_on ~= false and self.panel_refresh_auto ~= false end,
                        checked_func = function() return self.panel_refresh_dark == true end,
                        callback = function()
                            self.panel_refresh_dark = not self.panel_refresh_dark
                            self:savePluginSettings()
                        end,
                        help_text = _(REFRESH_DARK_HELP),
                    },
                    {
                        -- Wie oft der zweite Refresh kommt (nur Modus Sauber), zeigt die aktuelle Wahl
                        text_func = function()
                            if self.panel_refresh == "page" then return _("First panel of each page") end
                            if self.panel_refresh == "nth" then
                                local n = self.panel_refresh_every
                                return n == 3 and _("Every 3rd panel") or n == 5 and _("Every 5th panel") or _("Every 2nd panel")
                            end
                            return _("Every panel")
                        end,
                        enabled_func = function() return self:refreshMode() == "clean" end,
                        sub_item_table = {
                            {
                                text = _("Every panel"),
                                radio = true,
                                checked_func = function() return self.panel_refresh == "panel" end,
                                callback = function() self.panel_refresh = "panel"; self:savePluginSettings() end,
                            },
                            {
                                text = _("Every 2nd panel"),
                                radio = true,
                                checked_func = function() return self.panel_refresh == "nth" and self.panel_refresh_every == 2 end,
                                callback = function() self.panel_refresh = "nth"; self.panel_refresh_every = 2; self:savePluginSettings() end,
                            },
                            {
                                text = _("Every 3rd panel"),
                                radio = true,
                                checked_func = function() return self.panel_refresh == "nth" and self.panel_refresh_every == 3 end,
                                callback = function() self.panel_refresh = "nth"; self.panel_refresh_every = 3; self:savePluginSettings() end,
                            },
                            {
                                text = _("Every 5th panel"),
                                radio = true,
                                checked_func = function() return self.panel_refresh == "nth" and self.panel_refresh_every == 5 end,
                                callback = function() self.panel_refresh = "nth"; self.panel_refresh_every = 5; self:savePluginSettings() end,
                            },
                            {
                                text = _("First panel of each page"),
                                radio = true,
                                checked_func = function() return self.panel_refresh == "page" end,
                                callback = function() self.panel_refresh = "page"; self:savePluginSettings() end,
                            },
                        },
                        separator = true,
                    },
                    {
                        text = _("How does it work?"),
                        keep_menu_open = true,
                        callback = function() UIManager:show(InfoMessage:new{ text = _(REFRESH_HELP) }) end,
                    },
                },
                separator = true,
            })

            -- Add Tap Zone settings
            table.insert(menu_items, 4, {
                text = _("Next panel by tapping on"),
                sub_item_table = {
                    {
                        text = _("Auto (based on reading direction)"),
                        radio = true,
                        checked_func = function() return self.panelzoom_tap_forward_zone == "auto" end,
                        callback = function()
                            self.panelzoom_tap_forward_zone = "auto"
                            logger.info("DynamicPanelZoom: Tap forward zone set to auto")
                            self:savePluginSettings()
                        end,
                    },
                    {
                        text = _("Left side"),
                        radio = true,
                        checked_func = function() return self.panelzoom_tap_forward_zone == "left" end,
                        callback = function()
                            self.panelzoom_tap_forward_zone = "left"
                            logger.info("DynamicPanelZoom: Tap forward zone set to left")
                            self:savePluginSettings()
                        end,
                    },
                    {
                        text = _("Right side"),
                        radio = true,
                        checked_func = function() return self.panelzoom_tap_forward_zone == "right" end,
                        callback = function()
                            self.panelzoom_tap_forward_zone = "right"
                            logger.info("DynamicPanelZoom: Tap forward zone set to right")
                            self:savePluginSettings()
                        end,
                    },
                },
                separator = true,
            })

            -- Add Standard Panel options
            table.insert(menu_items, 5, {
                text = _("Panel view"),
                sub_item_table = {
                    {
                        text = _("Show panel surroundings (off = background colour)"),
                        checked_func = function() return self.show_adjacent_panels end,
                        callback = function()
                            self.show_adjacent_panels = not self.show_adjacent_panels
                            self:refreshCurrentPanelIfActive()
                            self:savePluginSettings()
                        end,
                    },
                    {
                        text_func = function()
                            local names = { white = _("white"), black = _("black"), auto = _("automatic") }
                            return _("Background") .. ": " .. (names[self.mask_bg] or _("white"))
                        end,
                        sub_item_table = (function()
                            local items = {}
                            for _i, entry in ipairs({
                                { "white", _("White") },
                                { "black", _("Black") },
                                { "auto", _("Automatic (experimental)"), _("Black when the panel has a dark edge or is very dark, otherwise white (same rule as Comic Display). Experimental: if it guesses wrong, choose white or black.") },
                            }) do
                                items[#items + 1] = {
                                    text = entry[2],
                                    help_text = entry[3],
                                    radio = true,
                                    checked_func = function() return self.mask_bg == entry[1] end,
                                    callback = function()
                                        self.mask_bg = entry[1]
                                        self.mask_black = entry[1] == "black"
                                        self:refreshCurrentPanelIfActive()
                                        self:savePluginSettings()
                                    end,
                                }
                            end
                            return items
                        end)(),
                    },
                    {
                        text_func = function()
                            local names = { off = _("never"), before = _("before"), after = _("after"), both = _("before & after") }
                            return _("Full page") .. ": " .. (names[self.page_overview or "off"] or _("never"))
                        end,
                        sub_item_table = {
                            {
                                text = _("Never"),
                                radio = true,
                                checked_func = function() return (self.page_overview or "off") == "off" end,
                                callback = function() self.page_overview = "off"; self:savePluginSettings() end,
                            },
                            {
                                text = _("Before the first panel"),
                                radio = true,
                                checked_func = function() return self.page_overview == "before" end,
                                callback = function() self.page_overview = "before"; self:savePluginSettings() end,
                            },
                            {
                                text = _("After the last panel"),
                                radio = true,
                                checked_func = function() return self.page_overview == "after" end,
                                callback = function() self.page_overview = "after"; self:savePluginSettings() end,
                            },
                            {
                                text = _("Before and after"),
                                radio = true,
                                checked_func = function() return self.page_overview == "both" end,
                                callback = function() self.page_overview = "both"; self:savePluginSettings() end,
                            },
                        },
                    },
                    {
                        text = _("Detect small panels"),
                        sub_item_table = {
                            {
                                text = _("Normal (from 1/8 of the page)"),
                                radio = true,
                                checked_func = function() return (self.panel_min_size or "normal") == "normal" end,
                                callback = function() self.panel_min_size = "normal"; self:invalidatePanelCache(); self:savePluginSettings() end,
                            },
                            {
                                text = _("Slightly smaller (from 1/10)"),
                                radio = true,
                                checked_func = function() return self.panel_min_size == "mid" end,
                                callback = function() self.panel_min_size = "mid"; self:invalidatePanelCache(); self:savePluginSettings() end,
                            },
                            {
                                text = _("Smaller (from 1/12)"),
                                radio = true,
                                checked_func = function() return self.panel_min_size == "small" end,
                                callback = function() self.panel_min_size = "small"; self:invalidatePanelCache(); self:savePluginSettings() end,
                            },
                            {
                                text = _("Very small (from 1/16)"),
                                radio = true,
                                checked_func = function() return self.panel_min_size == "tiny" end,
                                callback = function() self.panel_min_size = "tiny"; self:invalidatePanelCache(); self:savePluginSettings() end,
                            },
                        },
                    },
                    {
                        text = _("Experimental Panel Sorting (Z-pattern)"),
                        checked_func = function() return self.experimental_panel_sorting_enabled end,
                        callback = function()
                            self.experimental_panel_sorting_enabled = not self.experimental_panel_sorting_enabled
                            logger.info("DynamicPanelZoom: Experimental Panel Sorting set to " .. tostring(self.experimental_panel_sorting_enabled))
                            self:invalidatePanelCache()
                            self:savePluginSettings()
                        end,
                    },
                    {
                        text = _("Padding around panel"),
                        sub_item_table = {
                            {
                                text = _("0% (None)"),
                                radio = true,
                                checked_func = function() return self.standard_margin_percent == 0.0 end,
                                callback = function() self:setStandardMarginPercent(0.0) end,
                            },
                            {
                                text = _("2% (Tight)"),
                                radio = true,
                                checked_func = function() return self.standard_margin_percent == 0.02 end,
                                callback = function() self:setStandardMarginPercent(0.02) end,
                            },
                            {
                                text = _("5% (Normal)"),
                                radio = true,
                                checked_func = function() return self.standard_margin_percent == 0.05 end,
                                callback = function() self:setStandardMarginPercent(0.05) end,
                            },
                            {
                                text = _("10% (Wide)"),
                                radio = true,
                                checked_func = function() return self.standard_margin_percent == 0.10 end,
                                callback = function() self:setStandardMarginPercent(0.10) end,
                            },
                        }
                    }
                },
                separator = true,
            })
            
            -- Add Free Zoom options
            table.insert(menu_items, 6, {
                text = _("Free zoom (hold in a panel)"),
                sub_item_table = {
                    {
                        text = _("Padding when zooming"),
                        sub_item_table = {
                            {
                                text = _("2% (Tight)"),
                                radio = true,
                                checked_func = function() return self.zoom_margin_percent == 0.02 end,
                                callback = function() self:setZoomMarginPercent(0.02) end,
                            },
                            {
                                text = _("5% (Normal)"),
                                radio = true,
                                checked_func = function() return self.zoom_margin_percent == 0.05 end,
                                callback = function() self:setZoomMarginPercent(0.05) end,
                            },
                            {
                                text = _("10% (Wide)"),
                                radio = true,
                                checked_func = function() return self.zoom_margin_percent == 0.10 end,
                                callback = function() self:setZoomMarginPercent(0.10) end,
                            },
                            {
                                text = _("20% (Context)"),
                                radio = true,
                                checked_func = function() return self.zoom_margin_percent == 0.20 end,
                                callback = function() self:setZoomMarginPercent(0.20) end,
                            },
                        }
                    },
                    {
                        text = _("Initial zoom level"),
                        sub_item_table = {
                            {
                                text = _("Fit to screen (1.0x)"),
                                radio = true,
                                checked_func = function() return self.zoom_initial_scale == 1.0 end,
                                callback = function() self:setZoomInitialScale(1.0) end,
                            },
                            {
                                text = _("Slight (1.2x)"),
                                radio = true,
                                checked_func = function() return self.zoom_initial_scale == 1.2 end,
                                callback = function() self:setZoomInitialScale(1.2) end,
                            },
                            {
                                text = _("Medium (1.5x)"),
                                radio = true,
                                checked_func = function() return self.zoom_initial_scale == 1.5 end,
                                callback = function() self:setZoomInitialScale(1.5) end,
                            },
                            {
                                text = _("Strong (2.0x)"),
                                radio = true,
                                checked_func = function() return self.zoom_initial_scale == 2.0 end,
                                callback = function() self:setZoomInitialScale(2.0) end,
                            },
                        }
                    },
                },
                separator = true,
            })
            
            -- Add Reset defaults option
            table.insert(menu_items, 7, {
                text = _("Reset settings"),
                callback = function()
                    self:resetSettingsToDefault()
                end,
            })

            -- Hilfe (in allen Plugins als letzter eigener Eintrag)
            table.insert(menu_items, 8, {
                text = _("How does it work?"),
                keep_menu_open = true,
                callback = function()
                    UIManager:show(InfoMessage:new{ text = _(HELP_TEXT) })
                end,
                separator = true,
            })
            
            return menu_items
        end
        
        logger.info("DynamicPanelZoom: Integrated reading direction options into panel zoom menu")
    end
end

-- Restore original panel zoom menu when plugin is disabled
function PanelZoomIntegration:restorePanelZoomMenu()
    -- Guard against multiple restoration calls
    if not self._original_genPanelZoomMenu then
        return -- Already restored or never stored
    end
    
    if self._original_genPanelZoomMenu and self.ui.highlight then
        self.ui.highlight.genPanelZoomMenu = self._original_genPanelZoomMenu
        self._original_genPanelZoomMenu = nil
        logger.info("DynamicPanelZoom: Restored original panel zoom menu")
    end
end

-- Refresh current panel if viewer is active (for reading direction changes)
function PanelZoomIntegration:refreshCurrentPanelIfActive()
    if self._current_imgviewer and self.integration_mode and #self.current_panels > 0 then
        logger.info("DynamicPanelZoom: Refreshing panel viewer with new reading direction")
        
        -- To ensure correct spatial flow, we must re-sort the panels
        -- by the new reading direction and map the current panel to its new index
        local old_panel = self.current_panels[self.current_panel_index]
        
        -- Import will automatically use the NEW reading direction and 
        -- either generate a new layout or pull it from the direction-specific cache.
        self:importToggleZoomPanels()
        
        -- Find the old panel in the newly sorted array so we stay on the same physical panel
        if old_panel and #self.current_panels > 0 then
            for i, p in ipairs(self.current_panels) do
                -- Compare coordinates (allowing tiny float variations)
                if math.abs(p.x - old_panel.x) < 0.001 and math.abs(p.y - old_panel.y) < 0.001 then
                    self.current_panel_index = i
                    break
                end
            end
        end
        
        -- Propagate reading direction immediately
        if self._current_imgviewer.updateReadingDirection then
            self._current_imgviewer:updateReadingDirection(self:getEffectiveReadingDirection())
        end
        self:displayCurrentPanel()
    end
end

-- Helper function: Calculate position to move panel center exactly to screen center
function PanelZoomIntegration:panelCenterToScreenPosition(panel, rect, dim, zoom)
    if not panel or not rect or not dim or not zoom then
        logger.warn("DynamicPanelZoom: Invalid parameters in panelCenterToScreenPosition")
        -- Fallback to screen center
        local screen_w = Screen:getWidth()
        local screen_h = Screen:getHeight()
        return {
            x = math.floor(screen_w / 2),
            y = math.floor(screen_h / 2),
        }
    end
    
    local screen_w = Screen:getWidth()
    local screen_h = Screen:getHeight()

    -- Absolute panel center (page space) from normalized JSON coordinates
    local panel_cx = (panel.x + panel.w / 2) * dim.w
    local panel_cy = (panel.y + panel.h / 2) * dim.h

    -- Center inside rect (page space)
    local cx_in_rect = panel_cx - rect.x
    local cy_in_rect = panel_cy - rect.y

    -- Scaled center (screen space)
    local cx_screen = cx_in_rect * zoom
    local cy_screen = cy_in_rect * zoom

    -- Translation to move center to screen center
    return {
        x = math.floor(screen_w / 2 - cx_screen + 0.5),
        y = math.floor(screen_h / 2 - cy_screen + 0.5),
    }
end

return PanelZoomIntegration
