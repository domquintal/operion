import PySimpleGUI as sg
import datetime, os, sys, platform

def info():
    return f"""Operion Python App
Python: {sys.version.split()[0]}
Platform: {platform.platform()}
CWD: {os.getcwd()}
Time: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
"""

layout = [
    [sg.Text("Operion — Python GUI", font=("Segoe UI", 14, "bold"))],
    [sg.Multiline(info(), size=(70,8), key="-LOG-", autoscroll=True, disabled=True)],
    [sg.Button("Do Work"), sg.Button("Exit")]
]

window = sg.Window("Operion", layout, finalize=True)

while True:
    event, values = window.read()
    if event in (sg.WINDOW_CLOSED, "Exit"):
        break
    if event == "Do Work":
        window["-LOG-"].update(values["-LOG-"] + "Working step 1...\n")
        window["-LOG-"].update(values["-LOG-"] + "Working step 2...\n")
        window["-LOG-"].update(values["-LOG-"] + "Done! ✅\n")

window.close()
