/***
  BEGIN LICENSE

  Copyright (C) 2018 Alessandro Castellani <castellani.ale@gmail.com>
  This program is free software: you can redistribute it and/or modify it
  under the terms of the GNU Lesser General Public License version 3, as published
  by the Free Software Foundation.

  This program is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranties of
  MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
  PURPOSE.  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License along
  with this program.  If not, see <http://www.gnu.org/licenses/>

  END LICENSE
***/

public class Scratch.Plugins.SublimeTextEmulation : Peas.ExtensionBase,  Peas.Activatable {

    Gee.TreeSet<Scratch.Widgets.SourceView> views;

    Scratch.MainWindow? window = null;
    Scratch.Widgets.SourceView? view = null;
    Scratch.Widgets.SplitView? split_view = null;

    Scratch.Services.Interface plugins;
    public Object object { owned get; construct; }

    construct {
        views = new Gee.TreeSet<Scratch.Widgets.SourceView> ();
    }

    public void update_state () {}

    public void activate () {
        plugins = (Scratch.Services.Interface) object;

        plugins.hook_window.connect ((win) => {
            this.window = win;
            var action_l = win.actions.lookup_action ("action_to_lower_case") as SimpleAction;
            action_l.set_enabled (false);
            action_l.activate.connect (select_line);
        });

        plugins.hook_document.connect ((doc) => {
            this.view = doc.source_view;
            this.view.key_press_event.disconnect (handle_key_press);
            this.view.key_press_event.connect (handle_key_press);
            this.views.add (view);
        });

        plugins.hook_split_view.connect ((view) => {
            this.split_view = view;
        });
    }

    public void deactivate () {
        var action_l = this.window.actions.lookup_action ("action_to_lower_case") as SimpleAction;
        action_l.set_enabled (true);
        action_l.activate.disconnect (select_line);

        foreach (var v in views) {
            v.key_press_event.disconnect (handle_key_press);
        }
    }

    private bool handle_key_press (Gdk.EventKey event) {
        // debug (event.keyval.to_string ());
        //some extensions to the default navigating
        bool ctrl = (event.state & Gdk.ModifierType.CONTROL_MASK) != 0;
        bool shift = (event.state & Gdk.ModifierType.SHIFT_MASK) != 0;

        if (ctrl && shift && event.keyval == Gdk.Key.Up) {
            move_line_selection (true, shift);
            return true;
        }

        if (ctrl && shift && event.keyval == Gdk.Key.Down) {
            move_line_selection (false, shift);
            return true;
        }

        if (ctrl && event.keyval == Gdk.Key.l) {
            select_line ();
            return true;
        }

        // select multiple identical word
        if (ctrl && event.keyval == Gdk.Key.d) {

            return true;
        }

        if (ctrl && shift && event.keyval == Gdk.Key.d) {
            view.duplicate_selection ();
            return true;
        }

        if (ctrl && event.keyval == 47) {
            toggle_comment ();
            return true;
        }

        if (ctrl && event.keyval == 91) {
            // Indent selection/line
            return true;
        }

        if (ctrl && event.keyval == 93) {
            // Remove Indent selection/line
            return true;
        }

        return false;
    }

    private void move_line_selection (bool up, bool select) {
        int move = up ? -1 : 1;
        view.move_lines (false, move);
    }

    private void select_line () {
        var current_view = this.split_view.get_focus_child () as Scratch.Widgets.DocumentView;
        var doc = current_view.current_document;
        if (doc == null) {
             return;
        }

        var buffer = doc.source_view.buffer;
        if (buffer is Gtk.SourceBuffer) {
            Gtk.TextIter start, end;
            var sel = buffer.get_selection_bounds (out start, out end);
            start.set_line_offset (0);
            if (end.starts_line ()) {
                end.backward_char ();
            } else if (!end.ends_line ()) {
                end.forward_to_line_end ();
            }
            buffer.select_range (start, end);
        }
    }

    private void toggle_comment () {
        var current_view = this.split_view.get_focus_child () as Scratch.Widgets.DocumentView;
        var doc = current_view.current_document;
        if (doc == null) {
             return;
        }

        var buffer = doc.source_view.buffer;
        if (buffer is Gtk.SourceBuffer) {
            CommentToggler.toggle_comment (buffer as Gtk.SourceBuffer);
        }
    }
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Peas.Activatable),
                                     typeof (Scratch.Plugins.SublimeTextEmulation));
}
