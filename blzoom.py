import os
import sys
import time
import json
import ctypes
import logging
import threading
import subprocess
from pathlib import Path

# Konsolsuz başlatma
if (
    os.name == "nt"
    and Path(sys.executable).name.lower() == "python.exe"
    and os.environ.get("BLZOOM_NO_CONSOLE") != "1"
):
    pythonw = Path(sys.executable).with_name("pythonw.exe")

    if pythonw.exists():
        env = os.environ.copy()
        env["BLZOOM_NO_CONSOLE"] = "1"

        subprocess.Popen(
            [str(pythonw), str(Path(__file__).resolve())],
            cwd=str(Path(__file__).resolve().parent),
            env=env,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        sys.exit(0)

import cv2
import dxcam
import numpy as np
import psutil

from pynput import keyboard, mouse

from PySide6.QtCore import (
    Qt, QTimer, QObject, Signal, QPropertyAnimation,
    QEasingCurve, QParallelAnimationGroup, QRect,
    QPoint, QByteArray, QEvent
)

from PySide6.QtGui import (
    QImage, QPixmap, QPainter, QColor, QPen,
    QBrush, QIcon, QAction
)

from PySide6.QtSvg import QSvgRenderer

from PySide6.QtWidgets import (
    QApplication, QWidget, QFrame, QLabel, QPushButton,
    QVBoxLayout, QHBoxLayout, QSlider, QLineEdit,
    QListWidget, QListWidgetItem, QScrollArea,
    QSystemTrayIcon, QMenu, QGraphicsOpacityEffect,
    QSizePolicy
)


# ============================================================
# BLZOOM SETTINGS
# ============================================================

APP_NAME = "BLZOOM"
APP_VERSION = "1.0.0"
CREATOR = "@blazystick"

APP_DIR = Path(__file__).resolve().parent
CONFIG_FILE = APP_DIR / "config.json"
LOG_FILE = APP_DIR / "app.log"

DEFAULT_ZOOM = 2.0
MIN_ZOOM = 1.25
MAX_ZOOM = 5.0
ZOOM_STEP = 0.25

DOUBLE_SHIFT_DELAY = 0.45

# Capture processing target. The monitor still limits unique desktop frames.
CAPTURE_TARGET_FPS = 200

SPI_GETMOUSESPEED = 0x0070
SPI_SETMOUSESPEED = 0x0071

GWL_EXSTYLE = -20
WS_EX_TRANSPARENT = 0x20
WS_EX_LAYERED = 0x80000
WS_EX_NOACTIVATE = 0x08000000
WS_EX_TOOLWINDOW = 0x80

WDA_EXCLUDEFROMCAPTURE = 0x11

user32 = ctypes.windll.user32

user32.SystemParametersInfoW.argtypes = [
    ctypes.c_uint,
    ctypes.c_uint,
    ctypes.c_void_p,
    ctypes.c_uint
]
user32.SystemParametersInfoW.restype = ctypes.c_bool


# ============================================================
# LOGGING
# ============================================================

logging.basicConfig(
    filename=str(LOG_FILE),
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s",
    encoding="utf-8"
)

logger = logging.getLogger("BLZOOM")


# ============================================================
# THEMES
# ============================================================

THEMES = {
    "VIOLET": {
        "accent": "#d06bff",
        "accent2": "#9948d6",
        "glow": "#edb1ff",
        "soft": "#2b1938",
        "border": "#54356b",
        "background": "#0b0911",
        "panel": "#14111b",
        "card": "#191522",
    },

    "EMERALD": {
        "accent": "#00e6a0",
        "accent2": "#00a982",
        "glow": "#75ffd0",
        "soft": "#0d3028",
        "border": "#235a49",
        "background": "#09120f",
        "panel": "#111d18",
        "card": "#16251e",
    },

    "CRIMSON": {
        "accent": "#ff527a",
        "accent2": "#ca315b",
        "glow": "#ff96b0",
        "soft": "#381522",
        "border": "#713047",
        "background": "#140a10",
        "panel": "#21111a",
        "card": "#2a1520",
    },

    "AMBER": {
        "accent": "#ffb84d",
        "accent2": "#dc8128",
        "glow": "#ffda91",
        "soft": "#382716",
        "border": "#71502c",
        "background": "#130f09",
        "panel": "#211a10",
        "card": "#2a2115",
    },
}


# ============================================================
# LANGUAGES
# ============================================================

LANG = {
    "TR": {
        "dashboard": "DASHBOARD",
        "zoom": "YAKINLAŞTIRMA",
        "zoom_desc": "Ekran merkezini yakınlaştır",
        "start": "YAKINLAŞTIRMAYI AÇ",
        "stop": "YAKINLAŞTIRMAYI KAPAT",
        "zoom_level": "YAKINLAŞTIRMA SEVİYESİ",
        "mouse": "FARE HASSASİYETİ",
        "mouse_desc": "Yakınlaştırma açıkken Windows imlecini yavaşlat",
        "mouse_factor": "YAVAŞLATMA ÇARPANI",
        "display": "EKRAN BİLGİLERİ",
        "resolution": "ÇÖZÜNÜRLÜK",
        "refresh": "YENİLEME HIZI",
        "capture": "İŞLENEN FPS",
        "target": "YAKALAMA SINIRI",
        "double_shift": "Çift Shift: Yakınlaştırmayı aç / kapat",
        "settings": "AYARLAR",
        "appearance": "GÖRÜNÜM",
        "theme": "Tema",
        "language": "Dil",
        "controls": "KONTROLLER",
        "hotkey": "Panel açma / kapama tuşu",
        "press_key": "F1 - F12 TUŞUNA BAS",
        "config": "YAPILANDIRMALAR",
        "preset_name": "Yapılandırma adı",
        "save": "KAYDET",
        "load": "YÜKLE",
        "delete": "SİL",
        "about": "HAKKINDA",
        "logs": "Log dosyasını aç",
        "creator": "Geliştirici",
        "live": "LIVE",
        "not_live": "NOT LIVE",
        "ready": "HAZIR",
        "active": "YAKINLAŞTIRMA AÇIK",
        "tray_open": "BLZOOM'u aç",
        "tray_exit": "Çıkış",
        "saved": "Yapılandırma kaydedildi",
        "loaded": "Yapılandırma yüklendi",
        "deleted": "Yapılandırma silindi",
        "no_presets": "Kayıtlı yapılandırma yok",
        "select_preset": "Önce bir yapılandırma seç",
        "preset_empty": "Yapılandırma adı gir",
        "version": "Sürüm",
    },

    "EN": {
        "dashboard": "DASHBOARD",
        "zoom": "ZOOM CONTROL",
        "zoom_desc": "Magnify the center of your screen",
        "start": "START ZOOM",
        "stop": "STOP ZOOM",
        "zoom_level": "ZOOM LEVEL",
        "mouse": "MOUSE SENSITIVITY",
        "mouse_desc": "Slow down Windows pointer while zooming",
        "mouse_factor": "SLOWDOWN FACTOR",
        "display": "DISPLAY INFORMATION",
        "resolution": "RESOLUTION",
        "refresh": "REFRESH RATE",
        "capture": "PROCESSED FPS",
        "target": "CAPTURE LIMIT",
        "double_shift": "Double Shift: Toggle zoom",
        "settings": "SETTINGS",
        "appearance": "APPEARANCE",
        "theme": "Theme",
        "language": "Language",
        "controls": "CONTROLS",
        "hotkey": "Panel toggle key",
        "press_key": "PRESS F1 - F12",
        "config": "CONFIGURATIONS",
        "preset_name": "Configuration name",
        "save": "SAVE",
        "load": "LOAD",
        "delete": "DELETE",
        "about": "ABOUT",
        "logs": "Open log file",
        "creator": "Developer",
        "live": "LIVE",
        "not_live": "NOT LIVE",
        "ready": "READY",
        "active": "ZOOM ACTIVE",
        "tray_open": "Open BLZOOM",
        "tray_exit": "Exit",
        "saved": "Configuration saved",
        "loaded": "Configuration loaded",
        "deleted": "Configuration deleted",
        "no_presets": "No saved configurations",
        "select_preset": "Select a configuration first",
        "preset_empty": "Enter a configuration name",
        "version": "Version",
    }
}


# ============================================================
# GLOBAL STATE
# ============================================================

state_lock = threading.RLock()
stop_event = threading.Event()

zoom = DEFAULT_ZOOM
zoom_active = False

toggle_hotkey = "F2"
language = "TR"
current_theme = "VIOLET"

mouse_speed_factor = 0.60
original_mouse_speed = None

shift_keys = set()
ctrl_keys = set()
function_keys_down = set()

shift_is_down = False
last_shift_press = 0.0
capturing_hotkey = False

latest_image = None
latest_image_buffer = None
image_version = 0
displayed_version = -1

screen_width = 1280
screen_height = 1024
screen_refresh = 75
screen_revision = 0

processed_fps = 0

signals = None
keyboard_listener = None
mouse_listener = None
capture_thread = None
game_thread = None

zoom_overlay = None
main_window = None

saved_data = {
    "zoom": DEFAULT_ZOOM,
    "toggle_hotkey": "F2",
    "language": "TR",
    "theme": "VIOLET",
    "mouse_speed_factor": 0.60,
    "presets": [],
}


# ============================================================
# CONFIGURATION
# ============================================================

def load_config():
    global zoom, toggle_hotkey, language
    global current_theme, mouse_speed_factor

    if CONFIG_FILE.exists():
        try:
            data = json.loads(
                CONFIG_FILE.read_text(encoding="utf-8")
            )

            if isinstance(data, dict):
                saved_data.update(data)

        except Exception:
            logger.exception("Config load failed")

    try:
        zoom = max(
            MIN_ZOOM,
            min(MAX_ZOOM, float(saved_data.get("zoom", DEFAULT_ZOOM)))
        )
    except Exception:
        zoom = DEFAULT_ZOOM

    key = str(
        saved_data.get("toggle_hotkey", "F2")
    ).upper()

    toggle_hotkey = (
        key if key in [f"F{i}" for i in range(1, 13)] else "F2"
    )

    lang = str(
        saved_data.get("language", "TR")
    ).upper()

    language = lang if lang in LANG else "TR"

    theme = str(
        saved_data.get("theme", "VIOLET")
    ).upper()

    current_theme = theme if theme in THEMES else "VIOLET"

    try:
        mouse_speed_factor = max(
            0.20,
            min(1.0, float(saved_data.get("mouse_speed_factor", 0.60)))
        )
    except Exception:
        mouse_speed_factor = 0.60


def save_config():
    saved_data["zoom"] = zoom
    saved_data["toggle_hotkey"] = toggle_hotkey
    saved_data["language"] = language
    saved_data["theme"] = current_theme
    saved_data["mouse_speed_factor"] = mouse_speed_factor

    try:
        CONFIG_FILE.write_text(
            json.dumps(saved_data, ensure_ascii=False, indent=2),
            encoding="utf-8"
        )
    except Exception:
        logger.exception("Config save failed")


# ============================================================
# MOUSE SPEED
# ============================================================

def get_mouse_speed():
    value = ctypes.c_int()

    pointer = ctypes.cast(
        ctypes.byref(value),
        ctypes.c_void_p
    )

    success = user32.SystemParametersInfoW(
        SPI_GETMOUSESPEED,
        0,
        pointer,
        0
    )

    if not success:
        raise ctypes.WinError()

    return value.value


def set_mouse_speed(speed):
    speed = max(1, min(20, int(speed)))

    success = user32.SystemParametersInfoW(
        SPI_SETMOUSESPEED,
        0,
        ctypes.c_void_p(speed),
        0x0002
    )

    if not success:
        raise ctypes.WinError()


def update_mouse_speed(enabled):
    if original_mouse_speed is None:
        return

    try:
        if enabled:
            reduced = round(
                original_mouse_speed * mouse_speed_factor
            )

            if mouse_speed_factor < 1.0:
                reduced = min(
                    reduced,
                    original_mouse_speed - 1
                )

            set_mouse_speed(max(1, reduced))

            logger.info(
                "Mouse speed reduced: %s -> %s",
                original_mouse_speed,
                get_mouse_speed()
            )

        else:
            set_mouse_speed(original_mouse_speed)

            logger.info("Original mouse speed restored")

    except Exception:
        logger.exception("Mouse speed update failed")


def restore_mouse_speed():
    if original_mouse_speed is not None:
        try:
            set_mouse_speed(original_mouse_speed)
        except Exception:
            logger.exception("Mouse restore failed")


# ============================================================
# DISPLAY
# ============================================================

def get_display_metrics():
    screen = QApplication.primaryScreen()

    if screen is None:
        return 1280, 1024, 60

    geometry = screen.geometry()

    width = geometry.width()
    height = geometry.height()
    refresh = round(screen.refreshRate())

    if refresh < 1 or refresh > 1000:
        refresh = 60

    return width, height, refresh


def update_display_metrics(width, height, refresh):
    global screen_width, screen_height
    global screen_refresh, screen_revision

    with state_lock:
        if (
            width != screen_width
            or height != screen_height
            or refresh != screen_refresh
        ):
            screen_width = width
            screen_height = height
            screen_refresh = refresh
            screen_revision += 1

            logger.info(
                "Display changed: %sx%s @ %s Hz",
                width, height, refresh
            )


# ============================================================
# SIGNALS
# ============================================================

class AppSignals(QObject):
    zoom_changed = Signal(bool)
    zoom_level_changed = Signal(float)

    window_toggle = Signal()
    hotkey_captured = Signal(str)

    capture_fps = Signal(int)
    game_status = Signal(bool)
    exit_requested = Signal()


# ============================================================
# ICONS
# ============================================================

ICONS = {
    "settings": """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
      <g fill="none" stroke="currentColor" stroke-width="1.7"
      stroke-linecap="round" stroke-linejoin="round">
        <circle cx="12" cy="12" r="3"/>
        <path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1
        -1.5 2.5-.2-.1a1.7 1.7 0 0 0-1.8 0l-.2.1h-3
        l-.1-.2a1.7 1.7 0 0 0-1.5-1l-.2-.1-1.5 2.5
        -.2-.1a1.7 1.7 0 0 0-1.8-.3l-.2.1-2.5-1.5
        .1-.2a1.7 1.7 0 0 0 0-1.8l-.1-.2v-3
        l.2-.1a1.7 1.7 0 0 0 1-1.5l.1-.2-2.5-1.5
        .1-.2a1.7 1.7 0 0 0 .3-1.8l-.1-.2 1.5-2.5
        .2.1a1.7 1.7 0 0 0 1.8 0l.2-.1h3l.1.2
        a1.7 1.7 0 0 0 1.5 1l.2.1 1.5-2.5.2.1
        a1.7 1.7 0 0 0 1.8.3l.2-.1 2.5 1.5-.1.2
        a1.7 1.7 0 0 0 0 1.8l.1.2v3l-.2.1a1.7 1.7
        0 0 0-1 1.5l-.1.2 2.5 1.5z"/>
      </g>
    </svg>
    """,

    "restart": """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
      <g fill="none" stroke="currentColor" stroke-width="1.8"
      stroke-linecap="round" stroke-linejoin="round">
        <path d="M20 7v5h-5"/>
        <path d="M19 12a7.5 7.5 0 1 1-2.2-5.3L20 9"/>
      </g>
    </svg>
    """,

    "tray": """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
      <g fill="none" stroke="currentColor" stroke-width="1.8"
      stroke-linecap="round" stroke-linejoin="round">
        <path d="M4 13h4l2 3h4l2-3h4"/>
        <path d="M5 13V5h14v8"/>
        <path d="M12 2v7"/>
        <path d="m9 6 3 3 3-3"/>
      </g>
    </svg>
    """,

    "close": """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
      <g fill="none" stroke="currentColor" stroke-width="1.8"
      stroke-linecap="round">
        <path d="m6 6 12 12"/>
        <path d="M18 6 6 18"/>
      </g>
    </svg>
    """,

    "play": """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
      <path d="M8 5.5v13l11-6.5z"
      fill="none" stroke="currentColor" stroke-width="1.8"
      stroke-linejoin="round"/>
    </svg>
    """,

    "pause": """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
      <g fill="none" stroke="currentColor" stroke-width="2"
      stroke-linecap="round">
        <path d="M8 5v14"/>
        <path d="M16 5v14"/>
      </g>
    </svg>
    """,

    "file": """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
      <g fill="none" stroke="currentColor" stroke-width="1.7"
      stroke-linecap="round" stroke-linejoin="round">
        <path d="M6 3h8l4 4v14H6z"/>
        <path d="M14 3v5h5"/>
        <path d="M9 13h6M9 17h6"/>
      </g>
    </svg>
    """
}


def make_icon(name, color="#e4d4ef", size=20):
    svg = ICONS.get(name)

    if not svg:
        return QIcon()

    svg = svg.replace("currentColor", color)

    renderer = QSvgRenderer(
        QByteArray(svg.encode("utf-8"))
    )

    pixmap = QPixmap(size, size)
    pixmap.fill(Qt.GlobalColor.transparent)

    painter = QPainter(pixmap)
    painter.setRenderHint(QPainter.RenderHint.Antialiasing)
    renderer.render(painter)
    painter.end()

    return QIcon(pixmap)


# ============================================================
# SMOOTH SETTINGS SCROLL
# ============================================================

class SmoothScrollArea(QScrollArea):

    def __init__(self, parent=None):
        super().__init__(parent)

        self.setWidgetResizable(True)
        self.setFrameShape(QFrame.Shape.NoFrame)

        self.setHorizontalScrollBarPolicy(
            Qt.ScrollBarPolicy.ScrollBarAlwaysOff
        )

        self.setVerticalScrollBarPolicy(
            Qt.ScrollBarPolicy.ScrollBarAsNeeded
        )

        self.setFocusPolicy(Qt.FocusPolicy.StrongFocus)

        self._target_value = 0

        self._scroll_animation = QPropertyAnimation(
            self.verticalScrollBar(),
            b"value",
            self
        )

        self._scroll_animation.setDuration(190)
        self._scroll_animation.setEasingCurve(
            QEasingCurve.Type.OutCubic
        )

        self.verticalScrollBar().valueChanged.connect(
            self._sync_scroll_target
        )

    def set_smooth_widget(self, widget):
        self.setWidget(widget)

        widget.installEventFilter(self)

        # Wheel events from the cards and controls are also captured.
        for child in widget.findChildren(QWidget):
            child.installEventFilter(self)

    def _sync_scroll_target(self, value):
        if self._scroll_animation.state() != (
            QPropertyAnimation.State.Running
        ):
            self._target_value = value

    def animate_to(self, value):
        bar = self.verticalScrollBar()

        maximum = bar.maximum()
        target = max(0, min(maximum, int(value)))

        if not self._scroll_animation.state() == (
            QPropertyAnimation.State.Running
        ):
            self._target_value = bar.value()

        self._target_value = target

        self._scroll_animation.stop()

        self._scroll_animation.setStartValue(
            bar.value()
        )

        self._scroll_animation.setEndValue(
            self._target_value
        )

        self._scroll_animation.start()

    def handle_wheel(self, event):
        bar = self.verticalScrollBar()

        pixel = event.pixelDelta().y()
        angle = event.angleDelta().y()

        if pixel:
            delta = pixel
        else:
            delta = (angle / 120.0) * 105

        if not delta:
            return False

        if self._scroll_animation.state() == (
            QPropertyAnimation.State.Running
        ):
            base = self._target_value
        else:
            base = bar.value()

        target = base - delta

        self.animate_to(target)

        event.accept()
        return True

    def wheelEvent(self, event):
        if self.handle_wheel(event):
            return

        super().wheelEvent(event)

    def eventFilter(self, watched, event):
        if event.type() == QEvent.Type.Wheel:
            return self.handle_wheel(event)

        return super().eventFilter(watched, event)

    def keyPressEvent(self, event):
        bar = self.verticalScrollBar()

        if event.key() == Qt.Key.Key_PageDown:
            self.animate_to(
                bar.value() + self.viewport().height() * 0.8
            )
            event.accept()
            return

        if event.key() == Qt.Key.Key_PageUp:
            self.animate_to(
                bar.value() - self.viewport().height() * 0.8
            )
            event.accept()
            return

        if event.key() == Qt.Key.Key_Home:
            self.animate_to(0)
            event.accept()
            return

        if event.key() == Qt.Key.Key_End:
            self.animate_to(bar.maximum())
            event.accept()
            return

        super().keyPressEvent(event)


# ============================================================
# INPUT LISTENERS
# ============================================================

def function_key_name(key):
    for number in range(1, 13):
        if key == getattr(keyboard.Key, f"f{number}", None):
            return f"F{number}"

    return None


def keyboard_on_press(key):
    global shift_is_down
    global last_shift_press
    global zoom_active
    global capturing_hotkey

    if capturing_hotkey:
        name = function_key_name(key)

        if name:
            capturing_hotkey = False
            signals.hotkey_captured.emit(name)

        elif key == keyboard.Key.esc:
            capturing_hotkey = False
            signals.hotkey_captured.emit(toggle_hotkey)

        return

    if key in (
        keyboard.Key.ctrl,
        keyboard.Key.ctrl_l,
        keyboard.Key.ctrl_r
    ):
        ctrl_keys.add(key)
        return

    if key in (
        keyboard.Key.shift,
        keyboard.Key.shift_l,
        keyboard.Key.shift_r
    ):
        with state_lock:
            if key in shift_keys:
                return

            shift_keys.add(key)

            if not shift_is_down:
                shift_is_down = True
                now = time.monotonic()

                if now - last_shift_press <= DOUBLE_SHIFT_DELAY:
                    last_shift_press = 0
                    zoom_active = not zoom_active

                    update_mouse_speed(zoom_active)
                    signals.zoom_changed.emit(zoom_active)

                    logger.info(
                        "Zoom toggled: %s",
                        zoom_active
                    )
                else:
                    last_shift_press = now

        return

    name = function_key_name(key)

    if name:
        if name not in function_keys_down:
            function_keys_down.add(name)

            if name == toggle_hotkey:
                signals.window_toggle.emit()

    if (
        key == keyboard.KeyCode.from_char("c")
        and ctrl_keys
    ):
        signals.exit_requested.emit()


def keyboard_on_release(key):
    global shift_is_down

    if key in (
        keyboard.Key.ctrl,
        keyboard.Key.ctrl_l,
        keyboard.Key.ctrl_r
    ):
        ctrl_keys.discard(key)
        return

    if key in (
        keyboard.Key.shift,
        keyboard.Key.shift_l,
        keyboard.Key.shift_r
    ):
        with state_lock:
            shift_keys.discard(key)
            shift_is_down = bool(shift_keys)

    name = function_key_name(key)

    if name:
        function_keys_down.discard(name)


def mouse_on_scroll(x, y, dx, dy):
    global zoom

    with state_lock:
        if not shift_is_down or dy == 0:
            return

        zoom += ZOOM_STEP if dy > 0 else -ZOOM_STEP
        zoom = max(MIN_ZOOM, min(MAX_ZOOM, zoom))

        current_zoom = zoom

    signals.zoom_level_changed.emit(current_zoom)
    logger.info("Zoom level: %.2fx", current_zoom)


# ============================================================
# IMAGE PROCESSING
# ============================================================

def process_image(frame, width, height):
    return cv2.resize(
        frame,
        (width, height),
        interpolation=cv2.INTER_CUBIC
    )


# ============================================================
# CAPTURE THREAD
# ============================================================

def capture_worker():
    global latest_image
    global latest_image_buffer
    global image_version
    global processed_fps

    camera = None
    capturing = False

    previous_region = None
    previous_revision = -1

    fps_count = 0
    fps_start = time.perf_counter()

    try:
        camera = dxcam.create(
            output_idx=0,
            output_color="BGR",
            max_buffer_len=1
        )

        logger.info("DXGI camera initialized")

        while not stop_event.is_set():
            with state_lock:
                active = zoom_active
                current_zoom = zoom

                width = screen_width
                height = screen_height
                revision = screen_revision

            if not active:
                if capturing:
                    camera.stop()
                    capturing = False
                    previous_region = None

                time.sleep(0.01)
                continue

            crop_width = max(
                2,
                int(width / current_zoom)
            )

            crop_height = max(
                2,
                int(height / current_zoom)
            )

            left = (width - crop_width) // 2
            top = (height - crop_height) // 2

            region = (
                left,
                top,
                left + crop_width,                top + crop_height
            )

            if (
                not capturing
                or region != previous_region
                or revision != previous_revision
            ):
                if capturing:
                    camera.stop()

                camera.start(
                    region=region,
                    target_fps=CAPTURE_TARGET_FPS,
                    video_mode=False
                )

                capturing = True
                previous_region = region
                previous_revision = revision

                fps_count = 0
                fps_start = time.perf_counter()

                logger.info(
                    "Capture started (target %s FPS): %s x %s",
                    CAPTURE_TARGET_FPS,
                    crop_width,
                    crop_height
                )

            frame = camera.get_latest_frame()

            if frame is None:
                time.sleep(0.002)
                continue

            enlarged = process_image(
                frame,
                width,
                height
            )

            # Keep the NumPy buffer alive while QImage reads its memory.
            # This avoids copying the full frame on every capture.
            image = QImage(
                enlarged.data,
                width,
                height,
                enlarged.strides[0],
                QImage.Format.Format_BGR888
            )

            with state_lock:
                latest_image_buffer = enlarged
                latest_image = image
                image_version += 1

            fps_count += 1

            now = time.perf_counter()

            if now - fps_start >= 1.0:
                processed_fps = fps_count

                signals.capture_fps.emit(
                    processed_fps
                )

                fps_count = 0
                fps_start = now

    except Exception:
        logger.exception("Capture worker failed")

    finally:
        if camera is not None:
            try:
                if capturing:
                    camera.stop()

                camera.release()

            except Exception:
                logger.exception("Camera cleanup failed")

        logger.info("Capture worker stopped")


# ============================================================
# GAME DETECTION
# ============================================================

def game_detection_worker():
    previous_status = None

    while not stop_event.is_set():
        live = False

        try:
            for process in psutil.process_iter(["name"]):
                name = (
                    process.info.get("name") or ""
                ).casefold()

                if name == "valorant-win64-shipping.exe":
                    live = True
                    break

        except Exception:
            logger.exception("Game process detection failed")

        if live != previous_status:
            previous_status = live
            signals.game_status.emit(live)

        stop_event.wait(1.5)


# ============================================================
# FULLSCREEN ZOOM OVERLAY
# ============================================================

class ZoomOverlay(QWidget):

    def __init__(self, width, height, main):
        super().__init__(None)

        self.main = main
        self.last_raise = 0.0

        self.setWindowFlags(
            Qt.WindowType.FramelessWindowHint
            | Qt.WindowType.WindowStaysOnTopHint
            | Qt.WindowType.Tool
            | Qt.WindowType.WindowDoesNotAcceptFocus
            | Qt.WindowType.WindowTransparentForInput
        )

        self.setAttribute(
            Qt.WidgetAttribute.WA_ShowWithoutActivating
        )

        self.setAttribute(
            Qt.WidgetAttribute.WA_TransparentForMouseEvents
        )

        self.setGeometry(0, 0, width, height)

        self.label = QLabel(self)
        self.label.setGeometry(0, 0, width, height)

        self.label.setAttribute(
            Qt.WidgetAttribute.WA_TransparentForMouseEvents
        )

        self.label.setStyleSheet("background: black;")

        self.hwnd = int(self.winId())

        style = user32.GetWindowLongW(
            self.hwnd,
            GWL_EXSTYLE
        )

        style |= (
            WS_EX_TRANSPARENT
            | WS_EX_LAYERED
            | WS_EX_NOACTIVATE
            | WS_EX_TOOLWINDOW
        )

        user32.SetWindowLongW(
            self.hwnd,
            GWL_EXSTYLE,
            style
        )

        try:
            user32.SetWindowDisplayAffinity(
                self.hwnd,
                WDA_EXCLUDEFROMCAPTURE
            )
        except Exception:
            logger.warning("Overlay capture exclusion unavailable")

        self.hide()

        self.timer = QTimer(self)
        self.timer.timeout.connect(self.update_frame)
        # 8 ms polling is enough for a 75 Hz display and avoids
        # waking the GUI thread 250 times per second.
        self.timer.start(8)

    def change_display(self, width, height):
        self.setGeometry(0, 0, width, height)
        self.label.setGeometry(0, 0, width, height)

    def update_frame(self):
        global displayed_version

        with state_lock:
            active = zoom_active
            image = latest_image
            version = image_version

        if not active:
            if self.isVisible():
                self.hide()

            return

        if not self.isVisible():
            self.showFullScreen()

        if image is not None and version != displayed_version:
            self.label.setPixmap(
                QPixmap.fromImage(image)
            )

            displayed_version = version

        now = time.monotonic()

        if (
            self.main.isVisible()
            and now - self.last_raise > 0.5
        ):
            self.main.raise_()
            self.last_raise = now


# ============================================================
# MAIN WINDOW
# ============================================================

class MainWindow(QWidget):

    def __init__(self):
        super().__init__()

        self.lang = language
        self.theme_name = current_theme

        self.presets = list(
            saved_data.get("presets", [])
        )

        self.translatable = []

        self.compact = False
        self.settings_open = False
        self.closing = False
        self.hidden_animation = False

        self.window_animation = None
        self.compact_animation = None
        self.settings_animation = None
        self.fade_animation = None

        self.setWindowTitle(APP_NAME)

        self.setWindowFlags(
            Qt.WindowType.FramelessWindowHint
            | Qt.WindowType.WindowStaysOnTopHint
            | Qt.WindowType.Tool
            | Qt.WindowType.WindowDoesNotAcceptFocus
        )

        self.setAttribute(
            Qt.WidgetAttribute.WA_TranslucentBackground
        )

        self.setMinimumSize(490, 128)
        self.setMaximumSize(778, 690)
        self.resize(490, 690)

        self.build_interface()
        self.apply_theme()
        self.position_window()
        self.create_tray()

        self.display_timer = QTimer(self)
        self.display_timer.timeout.connect(self.check_display)
        self.display_timer.start(1200)

        self.update_zoom_ui(zoom_active)

    # --------------------------------------------------------
    # TRANSLATION
    # --------------------------------------------------------

    def t(self, key):
        return LANG[self.lang].get(key, key)

    def label(self, key, name="bodyText"):
        widget = QLabel(self.t(key))
        widget.setObjectName(name)
        widget.setWordWrap(True)

        self.translatable.append((widget, key))
        return widget

    def button(self, key, name="secondaryButton"):
        widget = QPushButton(self.t(key))
        widget.setObjectName(name)

        widget.setCursor(
            Qt.CursorShape.PointingHandCursor
        )

        self.translatable.append((widget, key))
        return widget

    def retranslate(self):
        for widget, key in self.translatable:
            widget.setText(self.t(key))

        self.hotkey_button.setText(toggle_hotkey)
        self.update_zoom_ui(zoom_active)
        self.update_theme_buttons()
        self.populate_presets()
        self.update_tray_menu()

    def change_language(self, code):
        global language

        if code not in LANG:
            return

        self.lang = code
        language = code

        self.retranslate()
        save_config()

        logger.info("Language changed: %s", code)

    # --------------------------------------------------------
    # COMPONENT HELPERS
    # --------------------------------------------------------

    def card(self):
        frame = QFrame()
        frame.setObjectName("card")
        return frame

    def icon_button(self, name, tooltip):
        button = QPushButton()

        button.setObjectName("iconButton")
        button.setIcon(make_icon(name))
        button.setIconSize(QPixmap(20, 20).size())
        button.setFixedSize(35, 35)
        button.setToolTip(tooltip)

        button.setCursor(
            Qt.CursorShape.PointingHandCursor
        )

        return button

    def value_label(self, value):
        label = QLabel(value)
        label.setObjectName("valueText")
        return label

    def info_row(self, key, value_widget):
        row = QHBoxLayout()

        row.addWidget(
            self.label(key, "smallTitle")
        )

        row.addStretch(1)
        row.addWidget(value_widget)

        return row

    # --------------------------------------------------------
    # INTERFACE
    # --------------------------------------------------------

    def build_interface(self):
        outer = QHBoxLayout(self)
        outer.setContentsMargins(8, 8, 8, 8)
        outer.setSpacing(8)

        # Main panel
        self.main_panel = QFrame()
        self.main_panel.setObjectName("mainPanel")
        self.main_panel.setFixedWidth(474)

        main_layout = QVBoxLayout(self.main_panel)
        main_layout.setContentsMargins(14, 13, 14, 12)
        main_layout.setSpacing(10)

        header = QFrame()
        header.setObjectName("header")

        header_layout = QHBoxLayout(header)
        header_layout.setContentsMargins(10, 8, 8, 8)
        header_layout.setSpacing(7)

        brand_column = QVBoxLayout()
        brand_column.setSpacing(2)

        brand_row = QHBoxLayout()
        brand_row.setSpacing(8)

        self.brand = QLabel("BLZOOM")
        self.brand.setObjectName("brand")

        self.live_dot = QLabel("●")
        self.live_dot.setObjectName("liveDot")

        self.live_status = QLabel("NOT LIVE")
        self.live_status.setObjectName("liveStatus")

        brand_row.addWidget(self.brand)
        brand_row.addWidget(self.live_dot)
        brand_row.addWidget(self.live_status)
        brand_row.addStretch(1)

        self.brand_sub = QLabel("PRECISION DISPLAY ENGINE")
        self.brand_sub.setObjectName("brandSub")

        brand_column.addLayout(brand_row)
        brand_column.addWidget(self.brand_sub)

        header_layout.addLayout(brand_column, 1)

        self.settings_button = self.icon_button(
            "settings", "Settings"
        )

        self.restart_button = self.icon_button(
            "restart", "Restart"
        )

        self.tray_button = self.icon_button(
            "tray", "Minimize to tray"
        )

        self.exit_button = self.icon_button(
            "close", "Exit"
        )

        self.settings_button.clicked.connect(self.open_settings)
        self.restart_button.clicked.connect(self.restart_app)
        self.tray_button.clicked.connect(self.minimize_to_tray)
        self.exit_button.clicked.connect(self.exit_app)

        header_layout.addWidget(self.settings_button)
        header_layout.addWidget(self.restart_button)
        header_layout.addWidget(self.tray_button)
        header_layout.addWidget(self.exit_button)

        main_layout.addWidget(header)

        self.hotkey_caption = QLabel(
            f"{toggle_hotkey} / PANEL CONTROL"
        )

        self.hotkey_caption.setObjectName("hotkeyCaption")
        main_layout.addWidget(self.hotkey_caption)

        # Dashboard
        self.body = QWidget()

        body_layout = QVBoxLayout(self.body)
        body_layout.setContentsMargins(0, 0, 0, 0)
        body_layout.setSpacing(10)

        body_layout.addWidget(
            self.label("dashboard", "sectionTitle")
        )

        # Game card
        status_card = self.card()

        status_layout = QVBoxLayout(status_card)
        status_layout.setContentsMargins(13, 11, 13, 11)
        status_layout.setSpacing(6)

        status_row = QHBoxLayout()

        status_row.addWidget(
            QLabel("GAME PROCESS")
        )

        status_row.addStretch(1)

        self.game_value = QLabel("NOT LIVE")
        self.game_value.setObjectName("gameValue")

        status_row.addWidget(self.game_value)
        status_layout.addLayout(status_row)

        self.engine_status = self.label(
            "ready",
            "engineStatus"
        )

        status_layout.addWidget(self.engine_status)
        body_layout.addWidget(status_card)

        # Zoom card
        zoom_card = self.card()

        zoom_layout = QVBoxLayout(zoom_card)
        zoom_layout.setContentsMargins(13, 12, 13, 12)
        zoom_layout.setSpacing(8)

        zoom_layout.addWidget(
            self.label("zoom", "sectionTitle")
        )

        zoom_layout.addWidget(
            self.label("zoom_desc", "mutedText")
        )

        self.zoom_button = QPushButton()
        self.zoom_button.setObjectName("primaryButton")
        self.zoom_button.setFixedHeight(42)

        self.zoom_button.setCursor(
            Qt.CursorShape.PointingHandCursor
        )

        self.zoom_button.clicked.connect(self.toggle_zoom)
        zoom_layout.addWidget(self.zoom_button)

        zoom_row = QHBoxLayout()

        zoom_row.addWidget(
            self.label("zoom_level", "smallTitle")
        )

        zoom_row.addStretch(1)

        self.zoom_value = self.value_label(f"{zoom:.2f}x")
        zoom_row.addWidget(self.zoom_value)

        zoom_layout.addLayout(zoom_row)

        self.zoom_slider = QSlider(Qt.Orientation.Horizontal)
        self.zoom_slider.setRange(
            int(MIN_ZOOM * 100),
            int(MAX_ZOOM * 100)
        )

        self.zoom_slider.setValue(int(zoom * 100))
        self.zoom_slider.setSingleStep(25)

        self.zoom_slider.valueChanged.connect(self.change_zoom)
        self.zoom_slider.sliderReleased.connect(save_config)

        zoom_layout.addWidget(self.zoom_slider)

        self.shift_hint = self.label(
            "double_shift",
            "hintText"
        )

        zoom_layout.addWidget(self.shift_hint)
        body_layout.addWidget(zoom_card)

        # Mouse card
        mouse_card = self.card()

        mouse_layout = QVBoxLayout(mouse_card)
        mouse_layout.setContentsMargins(13, 11, 13, 11)
        mouse_layout.setSpacing(7)

        mouse_layout.addWidget(
            self.label("mouse", "sectionTitle")
        )

        mouse_layout.addWidget(
            self.label("mouse_desc", "mutedText")
        )

        mouse_row = QHBoxLayout()

        mouse_row.addWidget(
            self.label("mouse_factor", "smallTitle")
        )

        mouse_row.addStretch(1)

        self.mouse_value = self.value_label(
            f"{mouse_speed_factor:.2f}x"
        )

        mouse_row.addWidget(self.mouse_value)
        mouse_layout.addLayout(mouse_row)

        self.mouse_slider = QSlider(Qt.Orientation.Horizontal)
        self.mouse_slider.setRange(20, 100)
        self.mouse_slider.setValue(
            int(mouse_speed_factor * 100)
        )

        self.mouse_slider.setSingleStep(5)
        self.mouse_slider.valueChanged.connect(
            self.change_mouse_factor
        )

        self.mouse_slider.sliderReleased.connect(save_config)
        mouse_layout.addWidget(self.mouse_slider)

        body_layout.addWidget(mouse_card)

        # Display card
        display_card = self.card()

        display_layout = QVBoxLayout(display_card)
        display_layout.setContentsMargins(13, 11, 13, 11)
        display_layout.setSpacing(7)

        display_layout.addWidget(
            self.label("display", "sectionTitle")
        )

        self.resolution_value = self.value_label("--")
        self.refresh_value = self.value_label("--")
        self.fps_value = self.value_label("0 FPS")
        self.target_value = self.value_label("AUTO")

        display_layout.addLayout(
            self.info_row("resolution", self.resolution_value)
        )

        display_layout.addLayout(
            self.info_row("refresh", self.refresh_value)
        )

        display_layout.addLayout(
            self.info_row("capture", self.fps_value)
        )

        display_layout.addLayout(
            self.info_row("target", self.target_value)
        )

        body_layout.addWidget(display_card)

        # Body opacity animation
        self.body_opacity = QGraphicsOpacityEffect(self.body)
        self.body_opacity.setOpacity(1.0)
        self.body.setGraphicsEffect(self.body_opacity)

        main_layout.addWidget(self.body, 1)

        # Footer
        self.footer_left = QLabel("BLZOOM / DISPLAY SYSTEM")
        self.footer_left.setObjectName("footerText")

        self.footer_right = QLabel(APP_VERSION)
        self.footer_right.setObjectName("footerText")

        footer = QHBoxLayout()
        footer.addWidget(self.footer_left)
        footer.addStretch(1)
        footer.addWidget(self.footer_right)

        main_layout.addLayout(footer)

        outer.addWidget(self.main_panel)

        # Settings panel
        self.settings_panel = self.build_settings_panel()
        self.settings_panel.setMinimumWidth(0)
        self.settings_panel.setMaximumWidth(0)
        self.settings_panel.setSizePolicy(
            QSizePolicy.Policy.Fixed,
            QSizePolicy.Policy.Expanding
        )

        self.settings_panel.hide()
        outer.addWidget(self.settings_panel)

    # --------------------------------------------------------
    # SETTINGS PANEL
    # --------------------------------------------------------

    def build_settings_panel(self):
        panel = QFrame()
        panel.setObjectName("settingsPanel")

        layout = QVBoxLayout(panel)
        layout.setContentsMargins(13, 12, 13, 12)
        layout.setSpacing(10)

        header = QHBoxLayout()

        header.addWidget(
            self.label("settings", "settingsTitle")
        )

        header.addStretch(1)

        close_button = self.icon_button(
            "close",
            "Close settings"
        )

        close_button.clicked.connect(self.close_settings)
        header.addWidget(close_button)

        layout.addLayout(header)

        scroll = SmoothScrollArea()
        self.settings_scroll = scroll

        content = QWidget()
        content_layout = QVBoxLayout(content)

        content_layout.setContentsMargins(0, 0, 0, 0)
        content_layout.setSpacing(9)

        # Appearance
        content_layout.addWidget(
            self.label("appearance", "sectionTitle")
        )

        theme_card = self.card()

        theme_layout = QVBoxLayout(theme_card)
        theme_layout.setContentsMargins(10, 9, 10, 9)
        theme_layout.setSpacing(6)

        theme_layout.addWidget(
            self.label("theme", "rowTitle")
        )

        self.theme_buttons = {}

        for theme_name in THEMES:
            button = QPushButton(theme_name.title())
            button.setObjectName("themeButton")
            button.setFixedHeight(31)

            button.clicked.connect(
                lambda checked=False, name=theme_name:
                self.change_theme(name)
            )

            self.theme_buttons[theme_name] = button
            theme_layout.addWidget(button)

        content_layout.addWidget(theme_card)

        # Language
        language_card = self.card()

        language_layout = QHBoxLayout(language_card)
        language_layout.setContentsMargins(10, 8, 10, 8)

        language_layout.addWidget(
            self.label("language", "rowTitle")
        )

        language_layout.addStretch(1)

        self.tr_button = QPushButton("TR")
        self.en_button = QPushButton("EN")

        for button in (self.tr_button, self.en_button):
            button.setObjectName("languageButton")
            button.setFixedSize(42, 29)

        self.tr_button.clicked.connect(
            lambda: self.change_language("TR")
        )

        self.en_button.clicked.connect(
            lambda: self.change_language("EN")
        )

        language_layout.addWidget(self.tr_button)
        language_layout.addWidget(self.en_button)

        content_layout.addWidget(language_card)

        # Keybind
        content_layout.addWidget(
            self.label("controls", "sectionTitle")
        )

        key_card = self.card()

        key_layout = QVBoxLayout(key_card)
        key_layout.setContentsMargins(10, 9, 10, 9)
        key_layout.setSpacing(6)

        key_layout.addWidget(
            self.label("hotkey", "rowTitle")
        )

        self.hotkey_button = QPushButton(toggle_hotkey)
        self.hotkey_button.setObjectName("keyButton")
        self.hotkey_button.setFixedHeight(36)

        self.hotkey_button.clicked.connect(self.capture_hotkey)
        key_layout.addWidget(self.hotkey_button)

        content_layout.addWidget(key_card)

        # Presets
        content_layout.addWidget(
            self.label("config", "sectionTitle")
        )

        config_card = self.card()

        config_layout = QVBoxLayout(config_card)
        config_layout.setContentsMargins(10, 9, 10, 9)
        config_layout.setSpacing(6)

        self.preset_input = QLineEdit()
        self.preset_input.setObjectName("textInput")
        self.preset_input.setPlaceholderText(
            self.t("preset_name")
        )

        config_layout.addWidget(self.preset_input)

        self.save_preset_button = self.button(
            "save",
            "actionButton"
        )

        self.save_preset_button.clicked.connect(self.save_preset)
        config_layout.addWidget(self.save_preset_button)

        self.preset_list = QListWidget()
        self.preset_list.setObjectName("presetList")
        self.preset_list.setMaximumHeight(120)

        config_layout.addWidget(self.preset_list)

        actions = QHBoxLayout()

        self.load_preset_button = self.button(
            "load",
            "actionButton"
        )

        self.delete_preset_button = self.button(
            "delete",
            "dangerButton"
        )

        self.load_preset_button.clicked.connect(self.load_preset)
        self.delete_preset_button.clicked.connect(self.delete_preset)

        actions.addWidget(self.load_preset_button)
        actions.addWidget(self.delete_preset_button)

        config_layout.addLayout(actions)

        self.preset_message = QLabel("")
        self.preset_message.setObjectName("hintText")

        config_layout.addWidget(self.preset_message)
        content_layout.addWidget(config_card)

        # About
        content_layout.addWidget(
            self.label("about", "sectionTitle")
        )

        about_card = self.card()

        about_layout = QVBoxLayout(about_card)
        about_layout.setContentsMargins(10, 9, 10, 9)
        about_layout.setSpacing(7)

        self.logs_button = QPushButton()
        self.logs_button.setObjectName("logButton")
        self.logs_button.setIcon(make_icon("file"))
        self.logs_button.clicked.connect(self.open_logs)

        self.translatable.append(
            (self.logs_button, "logs")
        )

        about_layout.addWidget(self.logs_button)

        creator_row = QHBoxLayout()

        creator_row.addWidget(
            self.label("creator", "smallTitle")
        )

        creator_row.addStretch(1)

        creator_value = QLabel(CREATOR)
        creator_value.setObjectName("accentText")

        creator_row.addWidget(creator_value)
        about_layout.addLayout(creator_row)

        version_row = QHBoxLayout()

        version_row.addWidget(
            self.label("version", "smallTitle")
        )

        version_row.addStretch(1)

        version_value = QLabel(APP_VERSION)
        version_value.setObjectName("valueText")

        version_row.addWidget(version_value)
        about_layout.addLayout(version_row)

        content_layout.addWidget(about_card)
        content_layout.addStretch(1)

        scroll.set_smooth_widget(content)
        layout.addWidget(scroll, 1)

        self.populate_presets()

        return panel

    # --------------------------------------------------------
    # STYLE
    # --------------------------------------------------------

    def apply_theme(self):
        colors = THEMES[self.theme_name]

        accent = colors["accent"]
        soft = colors["soft"]
        border = colors["border"]

        self.setStyleSheet(f"""
            QWidget {{
                color: #eeeaf4;
                font-family: "Segoe UI";
                font-size: 9pt;
                background: transparent;
            }}

            #mainPanel, #settingsPanel {{
                background: {colors["background"]};
                border: 1px solid {border};
                border-radius: 16px;
            }}

            #header {{
                background: {colors["panel"]};
                border: 1px solid {border};
                border-radius: 11px;
            }}

            #brand {{
                color: #ffffff;
                font-size: 19px;
                font-weight: 900;
                letter-spacing: 3px;
            }}

            #brandSub {{
                color: #81778e;
                font-size: 8px;
                letter-spacing: 1.8px;
            }}

            #liveDot {{
                color: #ff587d;
                font-size: 11px;
            }}

            #liveStatus {{
                color: #ff829a;
                background: #29151f;
                border: 1px solid #643044;
                border-radius: 6px;
                padding: 3px 6px;
                font-size: 8px;
                font-weight: 900;
            }}

            #hotkeyCaption {{
                color: #796e88;
                font-size: 8px;
                letter-spacing: 1.5px;
            }}

            #iconButton {{
                background: {colors["panel"]};
                border: 1px solid {border};
                border-radius: 9px;
            }}

            #iconButton:hover {{
                background: {soft};
                border: 1px solid {accent};
            }}

            #card {{
                background: {colors["card"]};                border: 1px solid {border};
                border-radius: 11px;
            }}

            #sectionTitle {{
                color: {accent};
                font-size: 9px;
                font-weight: 900;
                letter-spacing: 1.4px;
            }}

            #settingsTitle {{
                color: #ffffff;
                font-size: 14px;
                font-weight: 900;
                letter-spacing: 1px;
            }}

            #rowTitle {{
                color: #eeeaf4;
                font-size: 9px;
                font-weight: 700;
            }}

            #mutedText {{
                color: #817b8d;
                font-size: 8px;
            }}

            #smallTitle {{
                color: #a69bad;
                font-size: 8px;
                font-weight: 800;
                letter-spacing: 0.6px;
            }}

            #valueText {{
                color: #f3eaff;
                font-size: 10px;
                font-weight: 900;
            }}

            #engineStatus, #accentText {{
                color: {accent};
                font-size: 10px;
                font-weight: 900;
            }}

            #gameValue {{
                color: #ff829a;
                font-size: 9px;
                font-weight: 900;
            }}

            #footerText {{
                color: #655d70;
                font-size: 7px;
                letter-spacing: 1px;
            }}

            #hintText {{
                color: #81778d;
                font-size: 8px;
            }}

            #primaryButton {{
                background: {accent};
                color: #160d1d;
                border: 1px solid {colors["glow"]};
                border-radius: 9px;
                font-size: 9px;
                font-weight: 900;
                letter-spacing: 1px;
            }}

            #primaryButton:hover {{
                background: {colors["glow"]};
            }}

            #themeButton, #languageButton, #keyButton {{
                color: #e9e1f2;
                background: {colors["panel"]};
                border: 1px solid {border};
                border-radius: 8px;
                font-size: 9px;
                font-weight: 800;
            }}

            #themeButton:hover, #languageButton:hover,
            #keyButton:hover {{
                border: 1px solid {accent};
                background: {soft};
            }}

            #actionButton {{
                color: {accent};
                background: {soft};
                border: 1px solid {border};
                border-radius: 7px;
                padding: 7px;
                font-size: 8px;
                font-weight: 800;
            }}

            #dangerButton {{
                color: #ff819a;
                background: #30151f;
                border: 1px solid #673044;
                border-radius: 7px;
                padding: 7px;
                font-size: 8px;
                font-weight: 800;
            }}

            #logButton {{
                color: #d9d0e4;
                background: {colors["panel"]};
                border: 1px solid {border};
                border-radius: 7px;
                padding: 7px;
                text-align: left;
            }}

            #textInput {{
                color: #ffffff;
                background: {colors["background"]};
                border: 1px solid {border};
                border-radius: 7px;
                padding: 8px;
            }}

            #textInput:focus {{
                border: 1px solid {accent};
            }}

            #presetList {{
                color: #e9e1f2;
                background: {colors["background"]};
                border: 1px solid {border};
                border-radius: 7px;
                outline: none;
            }}

            #presetList::item {{
                padding: 7px;
                border-radius: 5px;
            }}

            #presetList::item:selected {{
                background: {soft};
                border: 1px solid {accent};
            }}

            QSlider::groove:horizontal {{
                height: 4px;
                background: #393242;
                border-radius: 2px;
            }}

            QSlider::sub-page:horizontal {{
                background: {accent};
                border-radius: 2px;
            }}

            QSlider::handle:horizontal {{
                background: #ffffff;
                border: 2px solid {accent};
                width: 12px;
                height: 12px;
                margin: -5px 0;
                border-radius: 7px;
            }}

            QScrollArea {{
                background: transparent;
                border: none;
            }}

            QScrollBar:vertical {{
                background: transparent;
                width: 5px;
                margin: 2px 0;
            }}

            QScrollBar::handle:vertical {{
                background: {accent};
                min-height: 25px;
                border-radius: 2px;
            }}

            QScrollBar::handle:vertical:hover {{
                background: {colors["glow"]};
            }}

            QScrollBar::add-line:vertical,
            QScrollBar::sub-line:vertical {{
                height: 0;
            }}

            QScrollBar::add-page:vertical,
            QScrollBar::sub-page:vertical {{
                background: transparent;
            }}
        """)

        self.update_theme_buttons()

    def update_theme_buttons(self):
        if not hasattr(self, "theme_buttons"):
            return

        for name, button in self.theme_buttons.items():
            colors = THEMES[name]

            if name == self.theme_name:
                button.setStyleSheet(
                    f"background:{colors['soft']};"
                    f"border:1px solid {colors['accent']};"
                    f"color:{colors['accent']};"
                    "font-weight:900;border-radius:8px;"
                )
            else:
                button.setStyleSheet("")

        if hasattr(self, "tr_button"):
            self.tr_button.setStyleSheet(
                f"border:1px solid {THEMES[self.theme_name]['accent']};"
                if self.lang == "TR" else ""
            )

            self.en_button.setStyleSheet(
                f"border:1px solid {THEMES[self.theme_name]['accent']};"
                if self.lang == "EN" else ""
            )

    # --------------------------------------------------------
    # WINDOW ANIMATIONS
    # --------------------------------------------------------

    def position_window(self):
        screen = QApplication.primaryScreen()

        if screen is None:
            self.move(26, 100)
            return

        area = screen.availableGeometry()

        x = area.x() + 26
        y = area.y() + (area.height() - self.height()) // 2

        self.move(x, y)

    def fade_show(self):
        if self.fade_animation:
            self.fade_animation.stop()

        self.setWindowOpacity(0.0)
        self.show()
        self.raise_()

        self.fade_animation = QPropertyAnimation(
            self,
            b"windowOpacity",
            self
        )

        self.fade_animation.setDuration(190)
        self.fade_animation.setStartValue(0.0)
        self.fade_animation.setEndValue(1.0)

        self.fade_animation.setEasingCurve(
            QEasingCurve.Type.OutCubic
        )

        self.fade_animation.start()

    def fade_hide(self):
        if not self.isVisible():
            return

        if self.fade_animation:
            self.fade_animation.stop()

        self.fade_animation = QPropertyAnimation(
            self,
            b"windowOpacity",
            self
        )

        self.fade_animation.setDuration(150)
        self.fade_animation.setStartValue(1.0)
        self.fade_animation.setEndValue(0.0)

        self.fade_animation.setEasingCurve(
            QEasingCurve.Type.InCubic
        )

        self.fade_animation.finished.connect(
            self.finish_fade_hide
        )

        self.fade_animation.start()

    def finish_fade_hide(self):
        self.hide()
        self.setWindowOpacity(1.0)

    def toggle_visibility(self):
        if self.isVisible():
            self.fade_hide()
        else:
            self.fade_show()

    # --------------------------------------------------------
    # SMOOTH COMPACT / EXPAND
    # --------------------------------------------------------

    def set_compact(self, enabled):
        if self.compact == enabled:
            return

        self.compact = enabled

        # Close the settings drawer before collapsing.
        if enabled and self.settings_open:
            self.close_settings(immediate=True)

        if self.compact_animation:
            self.compact_animation.stop()

        self.compact_animation = QParallelAnimationGroup(self)

        current_geometry = self.geometry()

        screen = QApplication.primaryScreen()

        area = (
            screen.availableGeometry()
            if screen is not None
            else QRect(0, 0, 1280, 1024)
        )

        if enabled:
            self.settings_button.hide()
            self.hotkey_caption.hide()
            self.footer_left.hide()
            self.footer_right.hide()

            self.body.show()

            content_height = max(
                self.body.height(),
                self.body.sizeHint().height(),
                100
            )

            self.body.setMaximumHeight(content_height)
            self.body_opacity.setOpacity(1.0)

            target_height = 128

            target_y = (
                area.y()
                + (area.height() - target_height) // 2
            )

            target_geometry = QRect(
                area.x() + 26,
                target_y,
                490,
                target_height
            )

            body_target = 0
            opacity_target = 0.0

        else:
            self.settings_button.show()
            self.hotkey_caption.show()
            self.footer_left.show()
            self.footer_right.show()

            self.body.show()
            self.body.setMaximumHeight(0)
            self.body_opacity.setOpacity(0.0)

            content_height = max(
                self.body.sizeHint().height(),
                100
            )

            target_height = 690

            target_y = (
                area.y()
                + (area.height() - target_height) // 2
            )

            target_geometry = QRect(
                area.x() + 26,
                target_y,
                490,
                target_height
            )

            body_target = content_height
            opacity_target = 1.0

        window_animation = QPropertyAnimation(
            self,
            b"geometry",
            self
        )

        window_animation.setDuration(270)
        window_animation.setStartValue(current_geometry)
        window_animation.setEndValue(target_geometry)

        window_animation.setEasingCurve(
            QEasingCurve.Type.InOutCubic
        )

        body_animation = QPropertyAnimation(
            self.body,
            b"maximumHeight",
            self
        )

        body_animation.setDuration(240)

        if enabled:
            body_animation.setStartValue(
                self.body.maximumHeight()
            )
        else:
            body_animation.setStartValue(0)

        body_animation.setEndValue(body_target)

        body_animation.setEasingCurve(
            QEasingCurve.Type.InOutCubic
        )

        opacity_animation = QPropertyAnimation(
            self.body_opacity,
            b"opacity",
            self
        )

        opacity_animation.setDuration(210)
        opacity_animation.setStartValue(
            1.0 if enabled else 0.0
        )
        opacity_animation.setEndValue(opacity_target)

        opacity_animation.setEasingCurve(
            QEasingCurve.Type.InOutCubic
        )

        self.compact_animation.addAnimation(window_animation)
        self.compact_animation.addAnimation(body_animation)
        self.compact_animation.addAnimation(opacity_animation)

        if enabled:
            self.compact_animation.finished.connect(
                self.finish_compact
            )
        else:
            self.compact_animation.finished.connect(
                self.finish_expand
            )

        self.compact_animation.start()

    def finish_compact(self):
        self.body.hide()
        self.body.setMaximumHeight(16777215)
        self.body_opacity.setOpacity(1.0)

    def finish_expand(self):
        self.body.setMaximumHeight(16777215)
        self.body_opacity.setOpacity(1.0)

    # --------------------------------------------------------
    # SETTINGS DRAWER ANIMATION
    # --------------------------------------------------------

    def open_settings(self):
        if self.compact or self.settings_open:
            return

        self.settings_open = True

        if self.settings_animation:
            self.settings_animation.stop()

        self.settings_panel.show()
        self.settings_panel.setMaximumWidth(0)

        self.setMaximumWidth(778)

        self.settings_animation = QParallelAnimationGroup(self)

        window_animation = QPropertyAnimation(
            self,
            b"geometry",
            self
        )

        window_animation.setDuration(250)
        window_animation.setStartValue(self.geometry())

        window_animation.setEndValue(
            QRect(
                self.x(),
                self.y(),
                778,
                self.height()
            )
        )

        window_animation.setEasingCurve(
            QEasingCurve.Type.OutCubic
        )

        drawer_animation = QPropertyAnimation(
            self.settings_panel,
            b"maximumWidth",
            self
        )

        drawer_animation.setDuration(250)
        drawer_animation.setStartValue(0)
        drawer_animation.setEndValue(280)

        drawer_animation.setEasingCurve(
            QEasingCurve.Type.OutCubic
        )

        self.settings_animation.addAnimation(window_animation)
        self.settings_animation.addAnimation(drawer_animation)

        self.settings_animation.start()

    def close_settings(self, immediate=False):
        if not self.settings_open:
            return

        self.settings_open = False

        if self.settings_animation:
            self.settings_animation.stop()

        if immediate:
            self.settings_panel.hide()
            self.settings_panel.setMaximumWidth(0)

            self.setMaximumWidth(490)
            self.resize(490, self.height())
            return

        self.settings_animation = QParallelAnimationGroup(self)

        window_animation = QPropertyAnimation(
            self,
            b"geometry",
            self
        )

        window_animation.setDuration(210)
        window_animation.setStartValue(self.geometry())

        window_animation.setEndValue(
            QRect(
                self.x(),
                self.y(),
                490,
                self.height()
            )
        )

        drawer_animation = QPropertyAnimation(
            self.settings_panel,
            b"maximumWidth",
            self
        )

        drawer_animation.setDuration(200)
        drawer_animation.setStartValue(
            self.settings_panel.maximumWidth()
        )
        drawer_animation.setEndValue(0)

        window_animation.setEasingCurve(
            QEasingCurve.Type.InCubic
        )

        drawer_animation.setEasingCurve(
            QEasingCurve.Type.InCubic
        )

        self.settings_animation.addAnimation(window_animation)
        self.settings_animation.addAnimation(drawer_animation)

        self.settings_animation.finished.connect(
            self.finish_close_settings
        )

        self.settings_animation.start()

    def finish_close_settings(self):
        self.settings_panel.hide()
        self.settings_panel.setMaximumWidth(0)
        self.setMaximumWidth(490)

    # --------------------------------------------------------
    # ZOOM
    # --------------------------------------------------------

    def toggle_zoom(self):
        global zoom_active

        with state_lock:
            zoom_active = not zoom_active
            active = zoom_active

        update_mouse_speed(active)
        self.update_zoom_ui(active)
        signals.zoom_changed.emit(active)

    def update_zoom_ui(self, active):
        self.zoom_button.setText(
            self.t("stop") if active else self.t("start")
        )

        self.zoom_button.setIcon(
            make_icon(
                "pause" if active else "play",
                "#160d1d",
                20
            )
        )

        self.engine_status.setText(
            self.t("active") if active else self.t("ready")
        )

        self.zoom_value.setText(f"{zoom:.2f}x")

        if self.zoom_slider.value() != int(zoom * 100):
            self.zoom_slider.blockSignals(True)
            self.zoom_slider.setValue(int(zoom * 100))
            self.zoom_slider.blockSignals(False)

        self.set_compact(active)

    def change_zoom(self, value):
        global zoom

        zoom = max(
            MIN_ZOOM,
            min(MAX_ZOOM, value / 100.0)
        )

        self.zoom_value.setText(f"{zoom:.2f}x")

    # --------------------------------------------------------
    # MOUSE FACTOR
    # --------------------------------------------------------

    def change_mouse_factor(self, value):
        global mouse_speed_factor

        mouse_speed_factor = value / 100.0

        self.mouse_value.setText(
            f"{mouse_speed_factor:.2f}x"
        )

        if zoom_active:
            update_mouse_speed(True)

    # --------------------------------------------------------
    # HOTKEY
    # --------------------------------------------------------

    def capture_hotkey(self):
        global capturing_hotkey

        capturing_hotkey = True

        self.hotkey_button.setText(
            self.t("press_key")
        )

    def set_hotkey(self, name):
        global toggle_hotkey
        global capturing_hotkey

        capturing_hotkey = False
        toggle_hotkey = name

        self.hotkey_button.setText(name)

        self.hotkey_caption.setText(
            f"{toggle_hotkey} / PANEL CONTROL"
        )

        save_config()

        logger.info("Hotkey changed: %s", name)

    # --------------------------------------------------------
    # DISPLAY
    # --------------------------------------------------------

    def check_display(self):
        width, height, refresh = get_display_metrics()

        old = (
            screen_width,
            screen_height,
            screen_refresh
        )

        if (width, height, refresh) == old:
            if self.resolution_value.text() == "--":
                self.update_display_labels(
                    width, height, refresh
                )
            return

        update_display_metrics(width, height, refresh)

        self.update_display_labels(
            width, height, refresh
        )

        if zoom_overlay is not None:
            zoom_overlay.change_display(width, height)

        self.position_window()

    def update_display_labels(self, width, height, refresh):
        self.resolution_value.setText(
            f"{width} × {height}"
        )

        self.refresh_value.setText(
            f"{refresh} Hz"
        )

        self.target_value.setText(f"{CAPTURE_TARGET_FPS} FPS")

    # --------------------------------------------------------
    # GAME STATUS
    # --------------------------------------------------------

    def update_game_status(self, live):
        if live:
            self.live_status.setText(self.t("live"))
            self.game_value.setText(self.t("live"))

            self.live_dot.setStyleSheet(
                "color:#00f0a0;font-size:11px;"
            )

            self.live_status.setStyleSheet(
                "color:#00f0a0;background:#102b24;"
                "border:1px solid #24634e;border-radius:6px;"
                "padding:3px 6px;font-size:8px;font-weight:900;"
            )

            self.game_value.setStyleSheet(
                "color:#00f0a0;font-weight:900;"
            )

        else:
            self.live_status.setText(self.t("not_live"))
            self.game_value.setText(self.t("not_live"))

            self.live_dot.setStyleSheet(
                "color:#ff587d;font-size:11px;"
            )

            self.live_status.setStyleSheet(
                "color:#ff829a;background:#29151f;"
                "border:1px solid #643044;border-radius:6px;"
                "padding:3px 6px;font-size:8px;font-weight:900;"
            )

            self.game_value.setStyleSheet(
                "color:#ff829a;font-weight:900;"
            )

    # --------------------------------------------------------
    # THEME / LANGUAGE
    # --------------------------------------------------------

    def change_theme(self, name):
        global current_theme

        if name not in THEMES:
            return

        self.theme_name = name
        current_theme = name

        self.apply_theme()
        save_config()

        logger.info("Theme changed: %s", name)

    # --------------------------------------------------------
    # PRESETS
    # --------------------------------------------------------

    def populate_presets(self):
        self.preset_list.clear()

        for preset in self.presets:
            if isinstance(preset, dict) and preset.get("name"):
                self.preset_list.addItem(str(preset["name"]))

        if not self.presets:
            item = QListWidgetItem(self.t("no_presets"))
            item.setFlags(Qt.ItemFlag.NoItemFlags)
            self.preset_list.addItem(item)

    def save_preset(self):
        name = self.preset_input.text().strip()

        if not name:
            self.preset_message.setText(self.t("preset_empty"))
            return

        preset = {
            "name": name,
            "zoom": zoom,
            "mouse_speed_factor": mouse_speed_factor,
            "toggle_hotkey": toggle_hotkey,
            "language": language,
            "theme": current_theme,
        }

        self.presets = [
            item for item in self.presets
            if not (
                isinstance(item, dict)
                and item.get("name") == name
            )
        ]

        self.presets.append(preset)
        saved_data["presets"] = self.presets

        save_config()

        self.preset_input.clear()
        self.preset_message.setText(self.t("saved"))

        self.populate_presets()

        logger.info("Preset saved: %s", name)

    def selected_preset(self):
        item = self.preset_list.currentItem()

        if item is None:
            return None

        name = item.text()

        for preset in self.presets:
            if (
                isinstance(preset, dict)
                and preset.get("name") == name
            ):
                return preset

        return None

    def load_preset(self):
        global zoom, mouse_speed_factor
        global toggle_hotkey, language, current_theme

        preset = self.selected_preset()

        if preset is None:
            self.preset_message.setText(self.t("select_preset"))
            return

        try:
            zoom = max(
                MIN_ZOOM,
                min(MAX_ZOOM, float(preset.get("zoom", DEFAULT_ZOOM)))
            )

            mouse_speed_factor = max(
                0.20,
                min(1.0, float(preset.get("mouse_speed_factor", 0.60)))
            )

            toggle_hotkey = str(
                preset.get("toggle_hotkey", "F2")
            ).upper()

            if toggle_hotkey not in [
                f"F{i}" for i in range(1, 13)
            ]:
                toggle_hotkey = "F2"

            language = str(
                preset.get("language", "TR")
            ).upper()

            if language not in LANG:
                language = "TR"

            current_theme = str(
                preset.get("theme", "VIOLET")
            ).upper()

            if current_theme not in THEMES:
                current_theme = "VIOLET"

            self.lang = language
            self.theme_name = current_theme

            self.zoom_slider.setValue(int(zoom * 100))
            self.mouse_slider.setValue(
                int(mouse_speed_factor * 100)
            )

            self.hotkey_button.setText(toggle_hotkey)
            self.hotkey_caption.setText(
                f"{toggle_hotkey} / PANEL CONTROL"
            )

            self.apply_theme()
            self.retranslate()

            if zoom_active:
                update_mouse_speed(True)

            save_config()

            self.preset_message.setText(self.t("loaded"))

            logger.info(
                "Preset loaded: %s",
                preset.get("name")
            )

        except Exception:
            logger.exception("Preset load failed")

    def delete_preset(self):
        preset = self.selected_preset()

        if preset is None:
            self.preset_message.setText(self.t("select_preset"))
            return

        name = preset.get("name")

        self.presets = [
            item for item in self.presets
            if not (
                isinstance(item, dict)
                and item.get("name") == name
            )
        ]

        saved_data["presets"] = self.presets

        save_config()
        self.populate_presets()

        self.preset_message.setText(self.t("deleted"))

        logger.info("Preset deleted: %s", name)

    # --------------------------------------------------------
    # TRAY
    # --------------------------------------------------------

    def create_tray(self):
        if not QSystemTrayIcon.isSystemTrayAvailable():
            self.tray = None
            logger.warning("System tray unavailable")
            return

        self.tray = QSystemTrayIcon(
            make_icon(
                "settings",
                THEMES[self.theme_name]["accent"],
                32
            ),            self
        )

        self.create_tray_menu()

        self.tray.activated.connect(self.tray_activated)
        self.tray.show()

    def create_tray_menu(self):
        if self.tray is None:
            return

        menu = QMenu()

        open_action = QAction(self.t("tray_open"), self)
        exit_action = QAction(self.t("tray_exit"), self)

        open_action.triggered.connect(self.show_from_tray)
        exit_action.triggered.connect(self.exit_app)

        menu.addAction(open_action)
        menu.addSeparator()
        menu.addAction(exit_action)

        self.tray.setContextMenu(menu)

    def update_tray_menu(self):
        self.create_tray_menu()

    def tray_activated(self, reason):
        if reason in (
            QSystemTrayIcon.ActivationReason.Trigger,
            QSystemTrayIcon.ActivationReason.DoubleClick
        ):
            self.show_from_tray()

    def show_from_tray(self):
        if zoom_active:
            self.set_compact(True)
        else:
            self.set_compact(False)

        self.fade_show()

    def minimize_to_tray(self):
        self.fade_hide()

    # --------------------------------------------------------
    # LOGS
    # --------------------------------------------------------

    def open_logs(self):
        try:
            LOG_FILE.touch(exist_ok=True)
            os.startfile(str(LOG_FILE))
        except Exception:
            logger.exception("Could not open app.log")

    # --------------------------------------------------------
    # RESTART / EXIT
    # --------------------------------------------------------

    def restart_app(self):
        logger.info("Restart requested")
        self.shutdown(restart=True)

    def exit_app(self):
        logger.info("Exit requested")
        self.shutdown(restart=False)

    def shutdown(self, restart=False):
        global zoom_active

        if self.closing:
            return

        self.closing = True
        stop_event.set()

        with state_lock:
            zoom_active = False

        restore_mouse_speed()

        try:
            if keyboard_listener is not None:
                keyboard_listener.stop()

            if mouse_listener is not None:
                mouse_listener.stop()

        except Exception:
            logger.exception("Listener cleanup failed")

        try:
            if capture_thread is not None and capture_thread.is_alive():
                capture_thread.join(timeout=3)

            if game_thread is not None and game_thread.is_alive():
                game_thread.join(timeout=2)

        except Exception:
            logger.exception("Worker cleanup failed")

        if self.tray is not None:
            self.tray.hide()

        save_config()

        if restart:
            try:
                if getattr(sys, "frozen", False):
                    command = [sys.executable, *sys.argv[1:]]
                else:
                    pythonw = Path(sys.executable).with_name("pythonw.exe")
                    executable = (
                        pythonw if pythonw.exists()
                        else Path(sys.executable)
                    )

                    command = [
                        str(executable),
                        str(Path(__file__).resolve())
                    ]

                subprocess.Popen(
                    command,
                    cwd=str(APP_DIR),
                    stdin=subprocess.DEVNULL,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    creationflags=0x08000000
                )

            except Exception:
                logger.exception("Restart failed")

        logger.info("Application shutdown complete")
        QApplication.quit()


# ============================================================
# MAIN
# ============================================================

def main():
    global signals
    global keyboard_listener
    global mouse_listener
    global capture_thread
    global game_thread
    global original_mouse_speed
    global zoom_overlay
    global main_window

    load_config()

    app = QApplication(sys.argv)

    app.setApplicationName(APP_NAME)
    app.setQuitOnLastWindowClosed(False)

    signals = AppSignals()

    width, height, refresh = get_display_metrics()

    update_display_metrics(
        width,
        height,
        refresh
    )

    try:
        original_mouse_speed = get_mouse_speed()

        logger.info(
            "Original mouse speed: %s",
            original_mouse_speed
        )

    except Exception:
        logger.exception("Could not read original mouse speed")

    main_window = MainWindow()

    zoom_overlay = ZoomOverlay(
        width,
        height,
        main_window
    )

    signals.zoom_changed.connect(
        main_window.update_zoom_ui
    )

    def update_zoom_level(value):
        main_window.zoom_value.setText(f"{value:.2f}x")

        main_window.zoom_slider.blockSignals(True)
        main_window.zoom_slider.setValue(int(value * 100))
        main_window.zoom_slider.blockSignals(False)

    signals.zoom_level_changed.connect(update_zoom_level)

    signals.window_toggle.connect(
        main_window.toggle_visibility
    )

    signals.hotkey_captured.connect(
        main_window.set_hotkey
    )

    signals.capture_fps.connect(
        lambda value: main_window.fps_value.setText(
            f"{value} FPS"
        )
    )

    signals.game_status.connect(
        main_window.update_game_status
    )

    signals.exit_requested.connect(
        main_window.exit_app
    )

    keyboard_listener = keyboard.Listener(
        on_press=keyboard_on_press,
        on_release=keyboard_on_release
    )

    mouse_listener = mouse.Listener(
        on_scroll=mouse_on_scroll
    )

    capture_thread = threading.Thread(
        target=capture_worker,
        name="BLZOOM-Capture",
        daemon=True
    )

    game_thread = threading.Thread(
        target=game_detection_worker,
        name="BLZOOM-GameDetection",
        daemon=True
    )

    keyboard_listener.start()
    mouse_listener.start()

    capture_thread.start()
    game_thread.start()

    main_window.show()
    main_window.raise_()

    logger.info(
        "BLZOOM started | version=%s | display=%sx%s@%sHz | hotkey=%s",
        APP_VERSION,
        width,
        height,
        refresh,
        toggle_hotkey
    )

    try:
        return app.exec()

    finally:
        stop_event.set()
        restore_mouse_speed()

        try:
            if keyboard_listener is not None:
                keyboard_listener.stop()

            if mouse_listener is not None:
                mouse_listener.stop()

            if capture_thread is not None and capture_thread.is_alive():
                capture_thread.join(timeout=3)

            if game_thread is not None and game_thread.is_alive():
                game_thread.join(timeout=2)

        except Exception:
            logger.exception("Final cleanup failed")

        logger.info("BLZOOM process ended")


if __name__ == "__main__":
    try:
        sys.exit(main())

    except Exception:
        logger.exception("Fatal application error")