/* Generated by vala-dbus-binding-tool 1.0-aa2fb. Do not modify! */
/* Generated with: vala-dbus-binding-tool --api-path=./org.freedesktop.portal.ScreenCast.xml --directory=./ --strip-namespace=org --rename-namespace=freedesktop:Freedesktop --rename-namespace=portal:Portal --no-synced */
using GLib;

namespace Freedesktop {

	namespace Portal {

		[DBus (name = "org.freedesktop.portal.ScreenCast", timeout = 120000)]
		public interface ScreenCast : GLib.Object {

			[DBus (name = "CreateSession")]
			public abstract GLib.ObjectPath create_session(GLib.HashTable<string, GLib.Variant> options) throws DBusError, IOError;

			[DBus (name = "SelectSources")]
			public abstract GLib.ObjectPath select_sources(GLib.ObjectPath session_handle, GLib.HashTable<string, GLib.Variant> options) throws DBusError, IOError;

			[DBus (name = "Start")]
			public abstract GLib.ObjectPath start(GLib.ObjectPath session_handle, string parent_window, GLib.HashTable<string, GLib.Variant> options) throws DBusError, IOError;

			[DBus (name = "OpenPipeWireRemote")]
			public abstract int open_pipe_wire_remote(GLib.ObjectPath session_handle, GLib.HashTable<string, GLib.Variant> options) throws DBusError, IOError;

			[DBus (name = "AvailableSourceTypes")]
			public abstract uint available_source_types {  get; }

			[DBus (name = "AvailableCursorModes")]
			public abstract uint available_cursor_modes {  get; }

			[DBus (name = "version")]
			public abstract uint version {  get; }
		}
	}
}
