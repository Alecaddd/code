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
    Scratch.Widgets.SourceView? view = null;

    Scratch.Services.Interface plugins;
    public Object object { owned get; construct; }

    construct {
        views = new Gee.TreeSet<Scratch.Widgets.SourceView> ();
    }

    public void update_state () {}

    public void activate () {
        plugins = (Scratch.Services.Interface) object;
        plugins.hook_document.connect ((doc) => {
            this.view = doc.source_view;
            this.view.key_press_event.disconnect (handle_key_press);
            this.view.key_press_event.connect (handle_key_press);
            this.views.add (view);
        });
    }

    public void deactivate () {
        foreach (var v in views) {
            v.key_press_event.disconnect (handle_key_press);
        }
    }

    private bool handle_key_press (Gdk.EventKey event) {
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

        if (ctrl && event.keyval == Gdk.Key.z) {
            debug ("undo");
        }

        // Parse commands
        // switch (event.keyval) {
            //navigation
            // case Gdk.Key.Left:
            // case Gdk.Key.h:
            //     view.move_cursor (Gtk.MovementStep.VISUAL_POSITIONS, -1, false);
            //     break;
            // case Gdk.Key.Down:
            // case Gdk.Key.j:
            // case Gdk.Key.plus:
            //     view.move_cursor (Gtk.MovementStep.DISPLAY_LINES, 1, false);
            //     break;
            // case Gdk.Key.Up:
            // case Gdk.Key.k:
            // case Gdk.Key.minus:
            //     view.move_cursor (Gtk.MovementStep.DISPLAY_LINES, -1, false);
            //     break;
            // case Gdk.Key.Right:
            // case Gdk.Key.l:
            //     view.move_cursor (Gtk.MovementStep.VISUAL_POSITIONS, 1, false);
            //     break;
            // case Gdk.Key.End:
            // case Gdk.Key.dollar:
            //     view.move_cursor (Gtk.MovementStep.DISPLAY_LINE_ENDS, 1, false);
            //     break;
            // case Gdk.Key.u:
            //     view.undo ();
            //     break;
            // case Gdk.Key.H:
            //     view.move_cursor (Gtk.MovementStep.BUFFER_ENDS, -1, false);
            //     break;
            // case Gdk.Key.L:
            //     view.move_cursor (Gtk.MovementStep.BUFFER_ENDS, 1, false);
            //     break;
            // case Gdk.Key.w:
            //     view.move_cursor (Gtk.MovementStep.WORDS, 1, false);
            //     break;
            // case Gdk.Key.b:
            //     view.move_cursor (Gtk.MovementStep.WORDS, -1, false);
            //     break;
            // case Gdk.Key.I:
            //     if (mode == Mode.INSERT) {
            //         return false;
            //     }

            //     mode = Mode.INSERT;
            //     var buffer = view.buffer;
            //     Gtk.TextIter start, end;
            //     buffer.get_selection_bounds (out start, out end);
            //     buffer.get_iter_at_mark (out start, buffer.get_insert ());
            //     start.backward_sentence_start ();
            //     buffer.place_cursor (start);
            //     debug ("Vim Emulation: INSERT Mode!");
            //     break;
            // case Gdk.Key.A:
            //     if (mode == Mode.INSERT) {
            //         return false;
            //     }

            //     mode = Mode.INSERT;
            //     view.move_cursor (Gtk.MovementStep.DISPLAY_LINE_ENDS, 1, false);
            //     debug ("Vim Emulation: INSERT Mode!");
            //     break;
            // case 46: // Dot "."
            //     debug (action);
            //     view.insert_at_cursor (action);
            //     break;
            // case Gdk.Key.Home:
            // case Gdk.Key.@0:
            //     if (number == "") {
            //         view.move_cursor (Gtk.MovementStep.DISPLAY_LINES, 1, false);
            //     } else {
            //         number += "0";
            //     }

            //     break;
            // case Gdk.Key.e:
            //     view.move_cursor (Gtk.MovementStep.WORDS, number == "" ? 1 : int.parse (number), false);
            //     break;
            // case Gdk.Key.g:
            //     g = true;
            //     view.go_to_line (int.parse (number));
            //     break;
        // }

        return false;
    }

    private void move_line_selection (bool up, bool select) {
        int move = up ? -1 : 1;
        view.move_lines (false, move);
    }
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Peas.Activatable),
                                     typeof (Scratch.Plugins.SublimeTextEmulation));
}
