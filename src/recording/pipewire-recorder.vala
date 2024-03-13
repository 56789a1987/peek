/*
Peek Copyright (c) 2015-2017 by Philipp Wolfer <ph.wolfer@gmail.com>

This file is part of Peek.

This software is licensed under the GNU General Public License
(version 3 or later). See the LICENSE file in this distribution.
*/

using Gst;

namespace Peek.Recording {
  public class PipewireScreenRecorder : BaseScreenRecorder {
    private const string DBUS_NAME = "org.freedesktop.portal.ScreenCast";

    private uint wait_timeout = 0;
    private Element? pipeline = null;
    private XDGDesktopPortal.PipeWireStream[] streams;

    ~PipewireScreenRecorder () {
      cancel ();
      release_pipeline ();
      if (wait_timeout != 0) {
        Source.remove (wait_timeout);
      }
    }

    private void on_pipeline_message (Message message) {
      var type = message.type;
      if (type == MessageType.EOS || type == MessageType.ERROR) {
        release_pipeline ();
      }
    }

    private void release_pipeline () {
      if (pipeline != null) {
        pipeline.set_state (State.NULL);
        pipeline = null;
      }
      XDGDesktopPortal.close_session ();
    }

    protected override async bool prepare_recording(Gtk.Window window) throws RecordingError {
      try {
        bool ok = yield XDGDesktopPortal.create_session ();
        if (!ok) {
          return false;
        }

        ok = yield XDGDesktopPortal.select_sources (config.capture_mouse);
        if (!ok) {
          return false;
        }

        streams = yield XDGDesktopPortal.start (window);
        return streams.length > 0;
      } catch (DBusError e) {
        throw new RecordingError.INITIALIZING_RECORDING_FAILED (e.message);
      } catch (IOError e) {
        throw new RecordingError.INITIALIZING_RECORDING_FAILED (e.message);
      }
    }

    public override void cancel_prepare () {
      release_pipeline ();
    }

    protected override void start_recording (RecordingArea area) throws RecordingError {
      try {
        int fd = XDGDesktopPortal.open_pipewire_remote ();
        temp_file = Utils.create_temp_file (get_temp_file_extension ());

        string args = build_pipe_wire_args (area, fd);
        stdout.printf ("%s\n", args);

        pipeline = parse_launch (args);
        pipeline.set_state (State.PLAYING);
        pipeline.get_bus ().message.connect (on_pipeline_message);

        is_recording = true;
        recording_started ();
      } catch (FileError e) {
        throw new RecordingError.INITIALIZING_RECORDING_FAILED (e.message);
      } catch (Error e) {
        throw new RecordingError.INITIALIZING_RECORDING_FAILED (e.message);
      }
    }

    protected override void stop_recording () {
      if (pipeline != null) {
        pipeline.send_event (new Event.eos ());

        if (!is_cancelling) {
          // Add a small timeout after sending the EOS event.
          // The recorder will stop the GST pipeline and do some cleanup / finalization.
          wait_timeout = Timeout.add_full (GLib.Priority.LOW, 500, () => {
            Source.remove (wait_timeout);
            wait_timeout = 0;
            release_pipeline ();
            finalize_recording ();
            return true;
          });
        }
      }
    }

    public static bool is_available () throws PeekError {
      // Should only be used on Wayland, FFmpeg is stable enough on X11
      if (!DesktopIntegration.is_wayland ()) {
        return false;
      }

      try {
        Freedesktop.Portal.ScreenCast screen_cast = GLib.Bus.get_proxy_sync (
          BusType.SESSION,
          "org.freedesktop.portal.Desktop",
          "/org/freedesktop/portal/desktop");
        return screen_cast.version > 0;
      } catch (IOError e) {
        stderr.printf ("Error: %s\n", e.message);
        throw new PeekError.SCREEN_RECORDER_ERROR (e.message);
      }
    }

    private string build_pipe_wire_args(RecordingArea area, int fd) {
      XDGDesktopPortal.PipeWireStream stream = streams[0];
      uint node_id = stream.node_id;

      var args = new StringBuilder ("pipewiresrc ");
      if (fd != 0) {
        // Open remote may return fd 0, but the source still works without it
        args.append_printf ("fd=%d ", fd);
      }
      args.append_printf ("path=%u ! ", node_id);

      args.append ("videoconvert chroma-mode=GST_VIDEO_CHROMA_MODE_NONE dither=GST_VIDEO_DITHER_NONE matrix-mode=GST_VIDEO_MATRIX_MODE_OUTPUT_ONLY ! queue ! ");
      args.append_printf ("videorate ! video/x-raw,framerate=%i/1 ! ", config.framerate);
      // When user is propmpted to select sources, selecting the full screen is suggested.
      // The video is cropped using the position and size of the screen and Peek window.
      // For a rect area in the middle of the screen, the left and top of the area may not be returned. This breaks cropping.
      args.append_printf (
        "videocrop top=%i left=%i right=%i bottom=%i ! ",
        area.top - stream.y,
        area.left - stream.x,
        stream.x + stream.w - area.left - area.width,
        stream.y + stream.h - area.top - area.height);

      if (config.downsample > 1) {
        int width = area.width / config.downsample;
        int height = area.height / config.downsample;
        args.append_printf (
          "videoscale ! video/x-raw,width=%i,height=%i ! ", width, height);
      }

      if (config.output_format == OutputFormat.WEBM) {
        args.append ("vp9enc cpu-used=16 min_quantizer=10 max_quantizer=50 cq_level=13 deadline=1000000 ! ");
        if (config.capture_sound != "none") {
          args.append_printf ("mux. pulsesrc device=\"%s\" ! queue ! audioconvert ! vorbisenc ! ", config.capture_sound);
        }
        args.append ("queue ! mux. webmmux name=mux ! ");
      } else {
        // Use near lossless encoding for generating GIF, VP9 has the best quality by test
        args.append ("vp9enc cpu-used=16 min_quantizer=0 max_quantizer=0 cq_level=0 deadline=1000000 ! ");
        args.append ("queue ! webmmux ! ");
      }

      args.append_printf("filesink location=\"%s\"", temp_file);
      return args.str;
    }

    private string get_temp_file_extension () {
      if (config.output_format == OutputFormat.GIF
        || config.output_format == OutputFormat.APNG
        || config.output_format == OutputFormat.WEBP) {
        return "webm";
      } else {
        return Utils.get_file_extension_for_format (config.output_format);
      }
    }
  }
}
