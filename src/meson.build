peek_sources = [
  'main.vala',
  'application.vala',
  'desktop-integration.vala',
  'defaults.vala',
  'errordomain.vala',
  'gtk-helper.vala',
  'utils.vala',
  'xdg-desktop-portal.vala',
  'dbus/freedesktop-dbus.vala',
  'dbus/freedesktop-filemanager.vala',
  'dbus/freedesktop-portal-request.vala',
  'dbus/freedesktop-portal-screen-cast.vala',
  'dbus/freedesktop-portal-session.vala',
  'dbus/gnome-shell-screencast.vala',
  'dbus/gnome-shell.vala',
  'post-processing/cli-post-processor.vala',
  'post-processing/extract-frames-post-processor.vala',
  'post-processing/ffmpeg-post-processor.vala',
  'post-processing/gifski-post-processor.vala',
  'post-processing/post-processing-pipeline.vala',
  'post-processing/post-processor.vala',
  'recording/base-screen-recorder.vala',
  'recording/cli-screen-recorder.vala',
  'recording/ffmpeg-screen-recorder.vala',
  'recording/ffmpeg.vala',
  'recording/gnome-shell-dbus-recorder.vala',
  'recording/pipewire-recorder.vala',
  'recording/recording-area.vala',
  'recording/recording-config.vala',
  'recording/screen-recorder-factory.vala',
  'recording/screen-recorder.vala',
  'ui/about-dialog.vala',
  'ui/application-window.vala',
  'ui/set-window-size-dialog.vala',
  'ui/error-dialog.vala',
  'ui/preferences-dialog.vala',
  'ui/shortcut-label.vala',
  'vapi/config.vapi',
]

vala_args = [
  '--vapidir', join_paths(meson.current_source_dir(), 'vapi'),
  '--pkg', 'posix',
  '--header', 'application.h',
  '--use-header',
  '--includedir', '../..',
  '--gresourcesdir', meson.current_build_dir(),
]

# Options
enable_file_chooser_native = get_option('enable-file-chooser-native')
enable_gnome_shell = get_option('enable-gnome-shell')
enable_xdg_desktop_portal = get_option('enable-xdg-desktop-portal')
enable_open_file_manager = get_option('enable-open-file-manager')

# Dependencies
gtk = dependency('gtk+-3.0', version: '>= 3.20')
keybinder = dependency('keybinder-3.0', required: get_option('enable-keybinder'))
gstreamer = dependency('gstreamer-1.0', required: enable_xdg_desktop_portal)

peek_deps = [
  dependency('cairo'),
  dependency('gio-2.0', version: '>= 2.42'),
  dependency('glib-2.0', version: '>= 2.38'),
  dependency('gmodule-2.0'),
  dependency('gdk-x11-3.0', version: '>= 3.20'),
  gtk,
  gstreamer,
]

if keybinder.found()
  peek_deps += keybinder
  vala_args += ['-D', 'HAS_KEYBINDER']
endif

# Feature configuration
if gtk.version().version_compare('>= 3.20')
  message('Compiling with features for GTK >= 3.20')
  if enable_file_chooser_native
    message('Compiling with Gtk.FileChooserNative')
    vala_args += ['-D', 'HAS_GTK_FILE_CHOOSER_NATIVE']
  endif
endif

if gtk.version().version_compare('>= 3.22')
  message('Compiling with features for GTK >= 3.22')
  vala_args += ['-D', 'HAS_GTK_SHORTCUT_LABEL']
  vala_args += ['-D', 'HAS_GTK_SHOW_URI_ON_WINDOW']
endif

if not enable_gnome_shell
  message('GNOME Shell recorder disabled by configuration')
  vala_args += ['-D', 'DISABLE_GNOME_SHELL']
endif

if not enable_xdg_desktop_portal
  message('XDG desktop portal and pipe wire recorder disabled by configuration')
  vala_args += ['-D', 'DISABLE_XDG_DESKTOP_PORTAL']
endif

if not enable_open_file_manager
  message('File manager integration disabled by configuration')
  vala_args += ['-D', 'DISABLE_OPEN_FILE_MANAGER']
endif

# Resource files
configuration_data = configuration_data()
configuration_data.set('PEEK_VERSION_FULL', meson.project_version())
about_ui_file = configure_file(
  input: '../ui/about.ui.in',
  output: 'about.ui',
  configuration: configuration_data
)

gnome = import('gnome')

peek_sources += gnome.compile_resources('peek-resources',
  '../ui/peek.gresource.xml',
  source_dir: '../ui/',
  c_name: 'peek',
  dependencies: [about_ui_file]
)

executable('peek', peek_sources,
  vala_args: vala_args,
  dependencies: peek_deps,
  install: true,
)
