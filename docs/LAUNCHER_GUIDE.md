# Convert APK to Android Launcher

## 1. Install apktool
```powershell
New-Item -ItemType Directory -Path "D:\apktool" -Force
Invoke-WebRequest -Uri "https://github.com/iBotPeaches/Apktool/releases/download/v2.9.3/apktool_2.9.3.jar" -OutFile "D:\apktool\apktool.jar"
```

## 2. Decompile APK
```powershell
cd D:\apktool
java -jar apktool.jar d "YOUR_APK_PATH.apk" -o catui_unpacked
```

## 3. Edit AndroidManifest.xml
Open `D:\apktool\catui_unpacked\AndroidManifest.xml` and add these lines inside `<intent-filter>`:
```xml
<category android:name="android.intent.category.HOME"/>
<category android:name="android.intent.category.DEFAULT"/>
```

## 4. Fix resource errors (if any)
```powershell
Remove-Item -Recurse -Force "D:\apktool\catui_unpacked\res\values-anydpi-v26"
(Get-Content "D:\apktool\catui_unpacked\res\values\public.xml") | Where-Object { $_ -notmatch "themed_icon" } | Set-Content "D:\apktool\catui_unpacked\res\values\public.xml"
```

## 5. Recompile APK
```powershell
java -jar apktool.jar b catui_unpacked -o catui_launcher.apk
```

## 6. Create signing key (only once)
```powershell
& "C:\Program Files (x86)\Java\jre1.8.0_471\bin\keytool.exe" -genkey -v -keystore release.keystore -alias catui -keyalg RSA -keysize 2048 -validity 10000 -storepass android -keypass android -dname "CN=CatUI, OU=Dev, O=Dev, L=City, ST=State, C=BR"
```

## 7. Sign APK
```powershell
& "$env:LOCALAPPDATA\Android\Sdk\build-tools\35.0.0\apksigner.bat" sign --ks release.keystore --ks-pass pass:android catui_launcher.apk
```

## 8. Install
```powershell
adb install catui_launcher.apk
```

Done! Press HOME button and select your app as launcher.
