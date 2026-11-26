# Publicar Sinchi en Android

El identificador de la app es **`pe.sinchi.academia`**. Una vez publicada en
Play Store ya no se puede cambiar. Cada paso dice cómo comprobar que salió
bien. **Nunca pegues contraseñas ni claves en el chat ni en git.**

## 1. Registrar el identificador en Firebase (una sola vez)

El archivo `android/app/google-services.json` está atado al identificador.
Hasta hacer este paso, la app de Android **no compila** (el error dice
*No matching client found for package name 'pe.sinchi.academia'*).

```powershell
dart pub global activate flutterfire_cli
flutterfire configure --project=academiapp-v2-7b9ce --platforms=android,web --android-package-name=pe.sinchi.academia --web-app-id=1:952131163064:web:81f9b5f79794bc04fff54d
```

- `--web-app-id` fija la app web que ya existe: no se crea otra.
- Registra una app Android nueva con `pe.sinchi.academia` y actualiza
  `android/app/google-services.json` y `lib/firebase_options.dart`.

*Comprueba:* `git diff lib/firebase_options.dart` cambia solo la parte de
Android; el `appId` de la web sigue siendo `1:952131163064:web:81f9b5f79794bc04fff54d`.

## 2. Huellas SHA (sin esto falla el ingreso con Google)

Firebase necesita las huellas de cada clave que firma la app. La de pruebas
(la que usa `flutter run`):

```powershell
keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

Copia **SHA1** y **SHA256** en la consola de Firebase → Configuración del
proyecto → Tus apps → la app Android `pe.sinchi.academia` → Agregar huella
digital.

> Si `keytool` no se encuentra: viene con Android Studio, en
> `C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe`
> (`flutter doctor -v` muestra la ruta de Java).

Después de agregar las huellas, vuelve a correr el `flutterfire configure`
del paso 1 para que `google-services.json` las incluya.

*Comprueba:* `flutter run` en el celular → ingresar con Google funciona.

## 3. Clave de firma para Play Store (una sola vez)

```powershell
keytool -genkey -v -keystore "$env:USERPROFILE\sinchi-upload.jks" -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Pide una contraseña y tus datos. **Guarda el archivo `.jks` y la contraseña
fuera de la PC** (USB o un gestor de contraseñas): sin ellos no puedes
publicar actualizaciones. El archivo queda fuera del proyecto a propósito.

Crea `android/key.properties` (ya está en `android/.gitignore`, no se sube):

```properties
storePassword=TU_CONTRASEÑA
keyPassword=TU_CONTRASEÑA
keyAlias=upload
storeFile=C:/Users/TU_USUARIO/sinchi-upload.jks
```

Usa `/` en la ruta, no `\`. Agrega también en Firebase las huellas SHA1 y
SHA256 de esta clave:

```powershell
keytool -list -v -keystore "$env:USERPROFILE\sinchi-upload.jks" -alias upload
```

*Comprueba:* `git status` no muestra `key.properties` ni el `.jks`.

## 4. Compilar para Play Store

```powershell
flutter build appbundle
```

El archivo queda en `build/app/outputs/bundle/release/app-release.aab`; ese
es el que se sube a Play Console.

**Importante:** Play Store vuelve a firmar la app con su propia clave ("Play
App Signing"). Después de la primera subida, en Play Console → Prueba y
lanzamiento → Configuración → Integridad de la app, copia el SHA1 y SHA256 de
la **clave de firma de apps** y agrégalos también en Firebase. Si no, el
ingreso con Google falla en las apps instaladas desde Play Store.

## 5. Limpieza

Cuando el ingreso con correo y con Google funcione con `pe.sinchi.academia`,
borra la app Android vieja (`pe.edu.unsch.academiapp_v2`) en Firebase →
Configuración del proyecto → Tus apps.
