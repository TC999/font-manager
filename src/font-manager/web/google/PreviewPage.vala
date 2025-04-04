/* PreviewPage.vala
 *
 * Copyright (C) 2020-2025 Jerry Casiano
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.
 *
 * If not, see <http://www.gnu.org/licenses/gpl-3.0.txt>.
*/

#if HAVE_WEBKIT

internal const string HEADER = """
<html dir="%s">
  <head>
    <style>
      body, textarea {
        color: %s;
        background-color: %s;
      }
      textarea {
        width: 95%;
        height: 95%;
        resize: none;
        wrap: soft;
        -webkit-box-sizing: border-box;
      }
      .aligned {
        text-align: %s;
      }
      .padded {
        padding: 64px;
      }
      .bodyText {
        margin: 12px 8px 12px 8px;
        text-align: justify;
      }
      .previewText {
        font-size: %.0lfpx;
        font-family: %s, adobe-notdef;
        font-style: %s;
        font-weight: %i;
      }
      .noWrap {
        overflow: visible;
        white-space: nowrap;
        display:block;
        width:100%;
      }
      %s
      @font-face {
            font-family: 'adobe-notdef';
            src:
                url('https://github.com/adobe-fonts/adobe-notdef/blob/master/AND-Regular.ttf?raw=true')
                format('truetype');
      }
    </style>
  </head>
  <script>
    function onInput() {
      document.title = document.getElementById("textArea").value;
    }
  </script>
  <body oncontextmenu="return false;">
    <div>
""";

internal const string WATERFALL_ROW = """
      <p id="%.0lf" class="noWrap">
        <span style="font-family: monospace;font-size: 10px;">%s</span>
        <span class="previewText" style="font-size:%.0lfpx;">%s</span>
      </p>
""";

internal const string BODY_TEXT = """
      <p class="bodyText">
        <span class="previewText">%s</span>
      </p>
""";

internal const string ACTIVE_PREVIEW = """
      <div class="aligned">
        <div class="padded">
          <p class="previewText" style="white-space: pre-line;">%s</p>
        </div>
      </div>
""";

internal const string DEFAULT_ACTIVE_TEXT = """
The quick brown fox jumps over the lazy dog.
ABCDEFGHIJKLMNOPQRSTUVWXYZ
abcdefghijklmnopqrstuvwxyz
1234567890.:,;(*!?')
""";

internal const string FOOTER = """
    </div>
  </body>
</html>
""";

namespace FontManager.GoogleFonts {

    WebKit.WebView create_webview () {
        var webview = new WebKit.WebView();
        var settings = new WebKit.Settings () {
            allow_modal_dialogs = false,
            auto_load_images = false,
            enable_back_forward_navigation_gestures = false,
            enable_developer_extras = false,
            enable_fullscreen = false,
            enable_media = false,
            enable_media_stream = false,
            enable_site_specific_quirks = false,
            enable_smooth_scrolling = true,
            enable_webaudio = false,
        };
        settings.set_user_agent_with_application_details(Config.PACKAGE_NAME,
                                                         Config.PACKAGE_VERSION);
        webview.set_settings(settings);
        webview.web_context.set_cache_model(WebKit.CacheModel.DOCUMENT_BROWSER);
        webview.network_session.prefetch_dns("http://fonts.gstatic.com/");
        widget_set_expand(webview, true);
        return webview;
    }

    [GtkTemplate (ui = "/com/github/FontManager/FontManager/web/google/ui/google-fonts-preview-page.ui")]
    public class PreviewPage : Gtk.Box {

        public int predefined_size { get; set; }
        public bool show_line_size { get; set; default = true; }
        public double preview_size { get; set; default = 12.5; }
        public double min_waterfall_size { get; set; default = MIN_FONT_SIZE; }
        public double max_waterfall_size { get; set; default = MAX_FONT_SIZE * 2; }
        public double waterfall_size_ratio { get; set; default = 1.1; }
        public Object? selected_item { get; set; default = null; }
        public Gtk.Justification justification { get; set; default = Gtk.Justification.CENTER; }

        public PreviewPageMode preview_mode { get; set; default = PreviewPageMode.WATERFALL; }
        public WaterfallSettings waterfall_settings { get; set; }

        public string preview_text {
            get {
                return _preview_text != null ? _preview_text : default_pangram;
            }
            set {
                _preview_text = value;
                notify_property("preview-text");
            }
        }

        public string active_preview_text {
            get {
                return _active_preview_text != null ? _active_preview_text : DEFAULT_ACTIVE_TEXT;
            }
            set {
                _active_preview_text = value;
                notify_property("active-preview-text");
            }
        }

        string? _preview_text = null;
        string? waterfall_body = null;
        string? _active_preview_text = null;
        string default_pangram = "The quick brown fox jumps over the lazy dog.";

        [GtkChild] unowned Gtk.CenterBox controls;
        [GtkChild] unowned Gtk.MenuButton menu_button;
        [GtkChild] unowned Gtk.MenuButton sample_button;
        [GtkChild] unowned PreviewColors preview_colors;

        Font? font;
        FontScale fontscale;
        PreviewEntry entry;
        PreviewControls preview_controls;
        SampleList samples;
        Gdk.Rectangle clicked_area;
        WebKit.WebView? webview;
        Gtk.Revealer controls_revealer;
        Gtk.Revealer fontscale_revealer;
        Gtk.Stack preview_stack;
        Gtk.TextView textview;

        string [] requires_reload = { "preview-text",
                                      "preview-size",
                                      "preview-mode",
                                      "justification" };

        string [] affects_waterfall = { "min-waterfall-size",
                                        "max-waterfall-size",
                                        "waterfall-size-ratio",
                                        "preview-text", "show-line-size" };

        static construct {
            install_property_action("predefined-size", "predefined-size");
            install_property_action("show-line-size", "show-line-size");
        }

        public PreviewPage () {
            webview = create_webview();
            webview.add_css_class("FontManagerFontPreviewArea");
            webview.get_first_child().add_css_class("FontManagerFontPreviewArea");
            textview = new Gtk.TextView() { monospace = true };
            textview.add_css_class("FontManagerFontPreviewArea");
            widget_set_margin(textview, 64);
            preview_controls = new PreviewControls();
            controls_revealer = new Gtk.Revealer();
            controls_revealer.set_child(preview_controls);
            append(controls_revealer);
            preview_stack = new Gtk.Stack();
            preview_stack.add_css_class("FontManagerFontPreviewArea");
            preview_stack.add_named(webview, "WebView");
            preview_stack.add_named(textview, "TextView");
            append(preview_stack);
            entry = new PreviewEntry();
            controls.set_center_widget(entry);
            fontscale = new FontScale();
            fontscale_revealer = new Gtk.Revealer();
            fontscale_revealer.set_child(fontscale);
            append(fontscale_revealer);
            samples = new SampleList();
            sample_button.set_popover(samples);
            set_preview_page_mode_menu_and_actions(this, menu_button, (Callback) on_mode_action_activated);
            preview_colors.style_updated.connect(() => { reload_preview(); });
            BindingFlags flags = BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE;
            bind_property("preview-size", fontscale, "value", flags);
            bind_property("preview-text", entry, "placeholder-text", flags);
            bind_property("justification", preview_controls, "justification", flags);
            bind_property("justification", textview, "justification", flags);
            bind_property("active-preview-text", textview.buffer, "text", flags);
            notify["selected-item"].connect_after(on_item_selected);
            samples.row_selected.connect(on_sample_selected);
            preview_controls.undo_clicked.connect(on_undo_clicked);
            entry.changed.connect(on_entry_changed);
            foreach (var property in affects_waterfall)
                notify[property].connect_after(update_waterfall_body);
            foreach (var property in requires_reload)
                notify[property].connect_after(reload_preview);
            preview_controls.edit_toggled.connect(on_edit_toggled);
            update_waterfall_body();
            reload_preview();
            notify["waterfall-settings"].connect(() => {
                BindingFlags _flags = BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE;
                waterfall_settings.bind_property("predefined-size", this, "predefined-size", _flags);
                waterfall_settings.bind_property("show-line-size", this, "show-line-size", _flags);
            });
            notify["predefined-size"].connect_after(() => {
                Idle.add(() => {
                    // ???: Bind property seems to not trigger notify signal?
                    waterfall_settings.on_selection_changed();
                    min_waterfall_size = waterfall_settings.minimum;
                    max_waterfall_size = waterfall_settings.maximum;
                    waterfall_size_ratio = waterfall_settings.ratio;
                    update_waterfall_body();
                    reload_preview();
                    return GLib.Source.REMOVE;
                });
            });
            notify["show-line-size"].connect_after(() => {
                update_waterfall_body();
                reload_preview();
            });
            clicked_area = Gdk.Rectangle();
            Gtk.Gesture right_click = new Gtk.GestureClick() {
                button = Gdk.BUTTON_SECONDARY
            };
            ((Gtk.GestureClick) right_click).pressed.connect(on_show_context_menu);
            webview.add_controller(right_click);
            textview.map.connect_after(() => { textview.grab_focus(); });
        }

        // XXX : Shouldn't need this.
        void update_menu_button () {
            Variant args = preview_mode.to_string();
            activate_action_variant("preview.mode", args);
            return;
        }

        public void restore_state (GLib.Settings? settings) {
            if (settings == null)
                return;
            preview_colors.restore_state(settings);
            SettingsBindFlags flags = SettingsBindFlags.DEFAULT;
            settings.bind("preview-font-size", this, "preview-size", flags);
            settings.bind("preview-mode", this, "preview-mode", flags);
            update_menu_button();
            settings.changed.connect_after((key) => {
                if (key == "preview-mode")
                    update_menu_button();
            });
            settings.bind("google-fonts-preview-text", this, "preview-text", flags);
            return;
        }

        void on_sample_selected (string sample) {
            entry.set_text(sample);
            if (preview_mode == PreviewPageMode.PREVIEW) {
                preview_text = sample;
                reload_preview();
            }
            return;
        }

        void on_undo_clicked () {
            active_preview_text = null;
            reload_preview();
            return;
        }

        void on_edit_toggled (bool active) {
            preview_stack.set_visible_child_name(active ? "TextView" : "WebView");
            if (!active)
                reload_preview();
            return;
        }

        [CCode (instance_pos = -1)]
        void on_mode_action_activated (SimpleAction action, Variant parameter) {
            PreviewPageMode mode = PreviewPageMode.LOREM_IPSUM;
            string param = (string) parameter;
            if (param == "Waterfall")
                mode = PreviewPageMode.WATERFALL;
            if (param == "Preview")
                mode = PreviewPageMode.PREVIEW;
            preview_mode = mode;
            action.set_state(parameter);
            sample_button.set_visible(mode == PreviewPageMode.WATERFALL);
            return;
        }

        void on_entry_changed () {
            preview_text = (entry.text_length > 0) ? entry.text : null;
            return;
        }

        public void reload_preview () {
            string html = "<html><body><p> </p></body></html>";
            if (font != null) {
                switch (preview_mode) {
                    case PreviewPageMode.WATERFALL:
                        html = generate_waterfall();
                        break;
                    case PreviewPageMode.LOREM_IPSUM:
                        html = generate_lorem_ipsum();
                        break;
                    case PreviewPageMode.PREVIEW:
                        html = generate_active_preview();
                        break;
                    default:
                        assert_not_reached();
                }
                samples.items = font.subsets;
                string description = "%s %s".printf(font.family, font.to_display_name());
                preview_controls.description = description;
            }
            sample_button.sensitive = (preview_mode != PreviewPageMode.LOREM_IPSUM);
            controls_revealer.set_reveal_child(preview_mode == PreviewPageMode.PREVIEW);
            preview_controls.undo_available = active_preview_text != DEFAULT_ACTIVE_TEXT;
            fontscale_revealer.set_reveal_child(preview_mode != PreviewPageMode.WATERFALL);
            entry.visible = (preview_mode == PreviewPageMode.WATERFALL);
            webview.load_html(html, null);
            return;
        }

        void on_item_selected () {
            if (selected_item is Family)
                font = ((Family) selected_item).get_default_variant();
            else
                font = (Font) selected_item;
            reload_preview();
            uint langs = samples.model.get_n_items();
            sample_button.set_tooltip_text(
                ngettext("%i Language Sample Available ",
                         "%i Language Samples Available",
                         (ulong) langs).printf((int) langs)
            );
            return;
        }

        double get_next_line_size (double current) {
            if (waterfall_size_ratio <= 1.0)
                return current + 1.0;
            double next = current * waterfall_size_ratio;
            return waterfall_size_ratio > 1.1 ? Math.floor(next) : Math.ceil(next);
        }

        string get_current_header ()
        requires (font != null) {
            string justify = "justify";
            Pango.Direction dir = Pango.find_base_dir(entry.text, -1);
            if (preview_mode == PreviewPageMode.PREVIEW) {
                switch (justification) {
                    case Gtk.Justification.LEFT:
                        justify = "left";
                        break;
                    case Gtk.Justification.CENTER:
                        justify = "center";
                        break;
                    case Gtk.Justification.RIGHT:
                        justify = "right";
                        break;
                    default:
                        break;
                }
            }
            return HEADER.printf(dir == Pango.Direction.RTL ? "rtl" : "ltr",
                                 preview_colors.foreground_color.to_string(),
                                 preview_colors.background_color.to_string(),
                                 justify, preview_size,
                                 font.family, font.style, font.weight,
                                 font.to_font_face_rule());
        }



        void update_waterfall_body () {
            StringBuilder builder = new StringBuilder();
            for (double i = min_waterfall_size;
                        i <= max_waterfall_size;
                        i = get_next_line_size(i)) {
                string pixels = "&nbsp;";
                if (show_line_size)
                    pixels = i < 10 ?
                             "&nbsp;&nbsp;%.0lfpx&nbsp".printf(i) :
                             "&nbsp;%.0lfpx&nbsp;".printf(i);
                builder.append(WATERFALL_ROW.printf(i, pixels, i, preview_text));
            }
            waterfall_body = builder.str;
            return;
        }

        string generate_active_preview ()
        requires (font != null) {
            StringBuilder builder = new StringBuilder();
            builder.append(get_current_header());
            builder.append(ACTIVE_PREVIEW.printf(active_preview_text));
            builder.append(FOOTER);
            return builder.str;
        }

        string generate_waterfall ()
        requires (font != null) {
            StringBuilder builder = new StringBuilder();
            builder.append(get_current_header());
            builder.append(waterfall_body);
            builder.append(FOOTER);
            return builder.str;
        }

        string? generate_lorem_ipsum ()
        requires (font != null) {
            StringBuilder builder = new StringBuilder();
            builder.append(get_current_header());
            var pref_loc = Intl.setlocale(LocaleCategory.ALL, "");
            Intl.setlocale(LocaleCategory.ALL, "C");
            builder.append(BODY_TEXT.printf(LOREM_IPSUM));
            Intl.setlocale(LocaleCategory.ALL, pref_loc);
            builder.append(FOOTER);
            return builder.str;
        }

        void on_show_context_menu (int n_press, double x, double y) {
            if (waterfall_settings == null || preview_mode != PreviewPageMode.WATERFALL)
                return;
            clicked_area.x = (int) x;
            clicked_area.y = (int) y;
            clicked_area.width = 2;
            clicked_area.height = 2;
            if (waterfall_settings.context_menu.get_parent() != null)
                waterfall_settings.context_menu.unparent();
            waterfall_settings.context_menu.set_parent(webview);
            waterfall_settings.context_menu.set_pointing_to(clicked_area);
            waterfall_settings.context_menu.popup();
            return;
        }

    }

}

#endif /* HAVE_WEBKIT */

