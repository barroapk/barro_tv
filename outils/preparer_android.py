# Adapte le projet Android généré par "flutter create" pour BARRO TV.
import glob
import pathlib
import re

m = pathlib.Path("android/app/src/main/AndroidManifest.xml")
s = m.read_text()

if "android.permission.INTERNET" not in s:
    s = s.replace("<application", '<uses-permission android:name="android.permission.INTERNET"/>\n    <application', 1)

s = re.sub(r'android:label="[^"]*"', 'android:label="BARRO TV"', s, count=1)

if "supportsPictureInPicture" not in s:
    s = s.replace(
        'android:name=".MainActivity"',
        'android:name=".MainActivity"\n            android:supportsPictureInPicture="true"\n            android:resizeableActivity="true"',
        1,
    )

filtres = """
            <intent-filter android:label="Barro Play">
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <data android:scheme="content" android:mimeType="video/*"/>
            </intent-filter>
            <intent-filter android:label="Barro Play">
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <data android:scheme="file" android:mimeType="video/*"/>
            </intent-filter>
        </activity>"""
if "video/*" not in s:
    s = s.replace("</activity>", filtres, 1)

m.write_text(s)

# Écran de démarrage noir au lieu de blanc
for f in glob.glob("android/app/src/main/res/drawable*/launch_background.xml"):
    pathlib.Path(f).write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<layer-list xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <item android:drawable="@android:color/black" />\n'
        "</layer-list>\n"
    )
st = pathlib.Path("android/app/src/main/res/values/styles.xml")
if st.exists():
    st.write_text(st.read_text().replace("Theme.Light.NoTitleBar", "Theme.Black.NoTitleBar"))

print("Projet Android prêt pour BARRO TV")
