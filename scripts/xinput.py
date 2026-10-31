#!/usr/bin/env python3
"""Synthetic mouse/keyboard input over XTEST, so the running app can be
navigated and screenshotted without a real display or xdotool.

Usage:
  xinput.py click X Y          # move the pointer and press+release button 1
  xinput.py move  X Y
  xinput.py key   <keysym>...  # e.g. xinput.py key Tab Return
"""
import ctypes
import ctypes.util
import sys
import time

x11 = ctypes.cdll.LoadLibrary("libX11.so.6")
xtst = ctypes.cdll.LoadLibrary("libXtst.so.6")

x11.XOpenDisplay.restype = ctypes.c_void_p
x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
x11.XSync.argtypes = [ctypes.c_void_p, ctypes.c_bool]
x11.XStringToKeysym.restype = ctypes.c_ulong
x11.XStringToKeysym.argtypes = [ctypes.c_char_p]

xtst.XTestFakeMotionEvent.argtypes = [
    ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_ulong
]
xtst.XTestFakeButtonEvent.argtypes = [
    ctypes.c_void_p, ctypes.c_uint, ctypes.c_bool, ctypes.c_ulong
]
xtst.XTestFakeKeyEvent.argtypes = [
    ctypes.c_void_p, ctypes.c_uint, ctypes.c_bool, ctypes.c_ulong
]

BUTTON1, BUTTON3 = 1, 3


def open_display():
    import os
    name = os.environ.get("DISPLAY", ":99").encode()
    d = x11.XOpenDisplay(name)
    if not d:
        sys.exit("cannot open display %r" % name)
    return d


def click(display, x, y):
    xtst.XTestFakeMotionEvent(display, -1, int(x), int(y), 0)
    x11.XSync(display, False)
    time.sleep(0.08)
    xtst.XTestFakeButtonEvent(display, BUTTON1, True, 0)
    x11.XSync(display, False)
    time.sleep(0.06)
    xtst.XTestFakeButtonEvent(display, BUTTON1, False, 0)
    x11.XSync(display, False)


def key(display, names):
    for name in names:
        sym = x11.XStringToKeysym(name.encode())
        if not sym:
            sys.exit("unknown keysym %r" % name)
        xtst.XTestFakeKeyEvent(display, sym, True, 0)
        x11.XSync(display, False)
        time.sleep(0.03)
        xtst.XTestFakeKeyEvent(display, sym, False, 0)
        x11.XSync(display, False)
        time.sleep(0.05)


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    d = open_display()
    try:
        cmd = sys.argv[1]
        if cmd == "click" and len(sys.argv) == 4:
            click(d, sys.argv[2], sys.argv[3])
        elif cmd == "move" and len(sys.argv) == 4:
            xtst.XTestFakeMotionEvent(d, -1, int(sys.argv[2]), int(sys.argv[3]), 0)
            x11.XSync(d, False)
        elif cmd == "key" and len(sys.argv) > 2:
            key(d, sys.argv[2:])
        else:
            sys.exit(__doc__)
    finally:
        x11.XCloseDisplay(d)


if __name__ == "__main__":
    main()
