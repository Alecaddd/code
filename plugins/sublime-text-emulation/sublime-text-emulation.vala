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
            start_indent (false);
            return true;
        }

        if (ctrl && event.keyval == 93) {
            start_indent (true);
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

    // determine how many characters precede a given iterator position
    private int measure_indent_at_iter(Scratch.Widgets.SourceView view, Gtk.TextIter iter) {
        Gtk.TextIter line_begin, pos;

        view.buffer.get_iter_at_line(out line_begin, iter.get_line());

        pos = line_begin;
        int indent = 0;
        int tabwidth = Scratch.settings.indent_width;

        unichar ch = pos.get_char();
        while (pos.get_offset() < iter.get_offset() && ch != '\n') {
            if (ch == '\t')
                indent += tabwidth;
            else
                ++indent;

            pos.forward_char ();
            ch = pos.get_char ();
        }
        return indent;
    }

    private void start_indent(bool type) {
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

            if (type)
                this.increase_indent_in_region (doc.source_view, start, end);
            else
                this.decrease_indent_in_region (doc.source_view, start, end);
        }
    }

    private void increase_indent_in_region (Scratch.Widgets.SourceView view,
                                            Gtk.TextIter region_begin,
                                            Gtk.TextIter region_end)
    {
        int first_line = region_begin.get_line();
        int last_line = region_end.get_line();
        int nchars = 4;

        int nlines = (first_line - last_line).abs() + 1;
        if ( nlines < 1 || nchars < 1 || last_line < first_line || !view.editable)
            return;

        // add a string of whitespace to each line after the first pasted line
        string indent_str;

        if (view.insert_spaces_instead_of_tabs)
            indent_str = string.nfill(nchars, ' ');

        else {
            int tabwidth = Scratch.settings.indent_width;
            int tabs = nchars / tabwidth;
            int spaces = nchars % tabwidth;

            indent_str = string.nfill(tabs, '\t');
            if (spaces > 0)
                indent_str += string.nfill(spaces, ' ');
        }

        Gtk.TextIter itr;
        for (var i=first_line; i<=last_line; ++i) {
            view.buffer.get_iter_at_line(out itr, i);
            view.buffer.insert(ref itr, indent_str, indent_str.length);
        }
    }

    private void decrease_indent_in_region (Scratch.Widgets.SourceView view,
                                            Gtk.TextIter region_begin,
                                            Gtk.TextIter region_end)
    {
        int first_line = region_begin.get_line();
        int last_line = region_end.get_line();
        int nchars = 4;

        int nlines = (first_line - last_line).abs() + 1;
        if ( nlines < 1 || nchars < 1 || last_line < first_line || !view.editable)
            return;

        Gtk.TextBuffer buffer = view.buffer;
        int tabwidth = Scratch.settings.indent_width;
        Gtk.TextIter del_begin, del_end, itr;

        for (var line = first_line; line <= last_line; ++line) {
            buffer.get_iter_at_line(out itr, line);
            // crawl along the line and tally indentation as we go,
            // when requested number of chars is hit, or if we run out of whitespace (eg. find glyphs or newline),
            // delete the segment from line start to where we are now
            int chars_to_delete = 0;
            int indent_chars_found = 0;
            unichar ch = itr.get_char();
            while(ch != '\n' && !ch.isgraph() && indent_chars_found < nchars) {
                if(ch == ' ') {
                    ++chars_to_delete;
                    ++indent_chars_found;
                }
                else if (ch == '\t') {
                    ++chars_to_delete;
                    indent_chars_found += tabwidth;
                }
                itr.forward_char();
                ch = itr.get_char();
            }

            if( ch == '\n' || chars_to_delete < 1)
                continue;

            buffer.get_iter_at_line(out del_begin, line);
            buffer.get_iter_at_line_offset(out del_end, line, chars_to_delete);
            buffer.delete(ref del_begin, ref del_end);
        }

    }
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Peas.Activatable),
                                     typeof (Scratch.Plugins.SublimeTextEmulation));
}
