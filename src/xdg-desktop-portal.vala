/*
Peek Copyright (c) 2015-2017 by Philipp Wolfer <ph.wolfer@gmail.com>

This file is part of Peek.

This software is licensed under the GNU General Public License
(version 3 or later). See the LICENSE file in this distribution.
*/

namespace Peek {

  public class XDGDesktopPortal {
    private const string BUS_NAME = "org.freedesktop.portal.Desktop";
    private const string OBJECT_PATH = "/org/freedesktop/portal/desktop";

    private enum AvailableSourceTypes {
      MONITOR = 1,
      WINDOW = 2,
      VIRTUAL = 4,
    }

    private enum AvailableCursorModes {
      Hidden = 1,
      Embedded = 2,
      Metadata = 4,
    }

    private enum PersistMode {
      None = 0,
      Transient = 1,
      Persistent = 2,
    }

    public class PipeWireStream {
      public uint node_id;
      public string? id;
      public int x = 0;
      public int y = 0;
      public int w = 0;
      public int h = 0;
      public uint? source_type;
      public string? mapping_id;
    }

    private static DBusConnection dbus_connection;
    private static Freedesktop.Portal.ScreenCast? _screen_cast_service = null;
    private static bool _screen_cast_dbus_initialized = false;
    private static Freedesktop.Portal.ScreenCast? screen_cast_service {
      get {
        if (!_screen_cast_dbus_initialized) {
          try {
            dbus_connection = Bus.get_sync (BusType.SESSION);
            _screen_cast_service = dbus_connection.get_proxy_sync (BUS_NAME, OBJECT_PATH);
          } catch (IOError e) {
            debug ("DBus service org.freedesktop.portal.Desktop not available: %s\n", e.message);
            _screen_cast_service = null;
          } finally {
            _screen_cast_dbus_initialized = true;
          }
        }

        return _screen_cast_service;
      }
    }

    public static string restore_token = "";
    private static uint source_types;
    private static uint cursor_modes;
    private static string? session_handle = null;
    private static Freedesktop.Portal.Session? session = null;

    private static uint last_handle_id = 0;
    private static string create_handle_token() {
      string token = "Peek" + last_handle_id.to_string ();
      last_handle_id++;
      return token;
    }

    public static async bool create_session () throws DBusError, IOError {
      if (screen_cast_service != null) {
        string token = create_handle_token ();
        string session_token = create_handle_token ();

        var options = new HashTable<string, Variant> (null, null);
        options.insert ("handle_token", new Variant.string(token));
        options.insert ("session_handle_token", new Variant.string(session_token));

        var r_handle = screen_cast_service.create_session (options);
        Freedesktop.Portal.Request request = dbus_connection.get_proxy_sync (BUS_NAME, r_handle);

        request.response.connect ((response, results) => {
          if (response == 0) {
            source_types = screen_cast_service.available_source_types;
            cursor_modes = screen_cast_service.available_cursor_modes;
            session_handle = results.get ("session_handle").get_string();
          }

          create_session.callback ();
        });

        yield;

        if (session_handle != null) {
          try {
            session = dbus_connection.get_proxy_sync (BUS_NAME, session_handle);
          } catch (IOError e) {
            session_handle = null;
            throw e;
          }
        }
      }

      return session != null;
    }

    public static async bool select_sources (bool capture_mouse) throws DBusError, IOError {
      bool ok = false;
 
      if (session_handle != null) {
        string token = create_handle_token ();

        var options = new HashTable<string, Variant> (null, null);
        options.insert ("handle_token", new Variant.string(token));
        options.insert ("types", new Variant.uint32(AvailableSourceTypes.MONITOR));
        options.insert ("multiple", new Variant.boolean (false));
        options.insert ("persist_mode", new Variant.uint32(PersistMode.Persistent));

        if (capture_mouse && (cursor_modes & AvailableCursorModes.Embedded) != 0) {
          options.insert ("cursor_mode", new Variant.uint32(AvailableCursorModes.Embedded));
        } else {
          options.insert ("cursor_mode", new Variant.uint32(AvailableCursorModes.Hidden));
        }

        if (restore_token != "") {
          options.insert ("restore_token", new Variant.string(restore_token));
        }

        var r_handle = screen_cast_service.select_sources (new ObjectPath (session_handle), options);
        Freedesktop.Portal.Request request = dbus_connection.get_proxy_sync (BUS_NAME, r_handle);

        request.response.connect ((response, results) => {
          if (response == 0) {
            ok = true;
          }
          select_sources.callback ();
        });

        yield;
      }

      return ok;
    }

    public static async PipeWireStream[] start (Gtk.Window window) throws DBusError, IOError {
      PipeWireStream[] streams = {};

      if (session_handle != null) {
        int xid = (int) ((Gdk.X11.Window) window.get_window ()).get_xid ();
        string parent_window = "x11:%x".printf (xid);
        string token = create_handle_token ();

        var options = new HashTable<string, Variant> (null, null);
        options.insert ("handle_token", new Variant.string(token));

        var r_handle = screen_cast_service.start (new ObjectPath (session_handle), parent_window, options);
        Freedesktop.Portal.Request request = dbus_connection.get_proxy_sync (BUS_NAME, r_handle);

        request.response.connect ((response, results) => {
          uint node_id;
          string property_name;
          Variant property_value;
          VariantIter properties;

          if (response == 0) {
            var v_streams = results.get ("streams");
            var iter = v_streams.iterator ();

            while (iter.next ("(ua{sv})", out node_id, out properties)) {
              PipeWireStream stream = new PipeWireStream() {
                node_id = node_id
              };

              while (properties.next ("{sv}", out property_name, out property_value)) {
                switch (property_name) {
                  case "id":
                    stream.id = property_value.get_string ();
                    break;
                  case "position":
                    property_value.get ("(ii)", out stream.x, out stream.y);
                    break;
                  case "size":
                    property_value.get ("(ii)", out stream.w, out stream.h);
                    break;
                  case "source_type":
                    stream.source_type = property_value.get_uint32 ();
                    break;
                  case "mapping_id":
                    stream.mapping_id = property_value.get_string ();
                    break;
                }
              }

              streams += stream;
            }

            if (results.contains ("restore_token")) {
              restore_token = results.get ("restore_token").get_string ();
            } else {
              restore_token = "";
            }
          }

          start.callback ();
        });

        yield;
      }

      return streams;
    }

    public static int open_pipewire_remote () throws Error {
      int fd = 0;

      if (session_handle != null) {
        var options = new VariantBuilder (VariantType.ARRAY);
        options.add ("{sv}", "", new Variant.string (""));

        // file handle type isn't handled properly by the binding tool, call this method manually 
        var result = dbus_connection.call_sync (
          BUS_NAME,
          OBJECT_PATH,
          "org.freedesktop.portal.ScreenCast",
          "OpenPipeWireRemote",
          new Variant("(oa{sv})", new ObjectPath (session_handle), options),
          new VariantType("(h)"),
          DBusCallFlags.NONE,
          120000);

        result.get ("(h)", out fd);
      }

      return fd;
    }

    public static void close_session () {
      try {
        if (session != null) {
          session.close ();
          session = null;
          session_handle = null;
        }
      } catch (Error e) {
        stderr.printf ("Unable to close screen cast session: %s\n", e.message);
      }
    }
  }
}
