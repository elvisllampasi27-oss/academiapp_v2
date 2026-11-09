# Pasar a Blaze (producción)

Hoy todo lo que necesita servidor o archivos se prueba con emuladores. Esta es
la lista para el día que se active Blaze, en orden. Cada paso dice cómo
comprobar que salió bien. **Nunca pegues claves en el chat ni en git.**

## Ya se puede hacer (plan gratis)

- Reglas e índices de Firestore: `firebase deploy --only firestore`
  (sube `firestore.rules` y `firestore.indexes.json`; el índice de
  `en_vivos` tarda unos minutos en quedar listo). Si la consola pregunta si
  borra índices que no están en el archivo, responde **No**.

## El día de Blaze

1. **Activar Blaze y poner un presupuesto con alertas.**
   Consola de Firebase → Uso y facturación → Detalles y configuración →
   Modificar plan. Luego Google Cloud → Facturación → Presupuestos y alertas:
   un presupuesto de US$ 10 al mes con avisos al 50 %, 90 % y 100 %.
   *Comprueba:* la consola muestra "Blaze".

2. **Guardar la clave de Gemini como secreto** (la que hoy está en
   `functions/.secret.local`):

   ```powershell
   firebase functions:secrets:set GEMINI_API_KEY
   ```

   Pega la clave cuando la pida (no se ve en pantalla).
   *Comprueba:* `firebase functions:secrets:access GEMINI_API_KEY` no da error.

3. **Actualizar y probar las funciones:**

   ```powershell
   cd functions
   npm install firebase-functions@latest firebase-admin@latest
   npm test
   cd ..
   ```

   *Comprueba:* "pass" en todas las pruebas.

4. **Desplegar funciones, Firestore y Storage:**

   ```powershell
   firebase deploy --only functions
   firebase deploy --only firestore
   firebase deploy --only storage
   ```

   *Comprueba:* "Deploy complete!" en los tres.

5. **Permitir que la web lea imágenes y audios de Storage (CORS).** En la
   versión web, las figuras de los exámenes y las narraciones se descargan
   desde otro dominio. Con el SDK de Google Cloud (`gcloud`) instalado, o en
   Cloud Shell:

   ```powershell
   gcloud storage buckets update gs://academiapp-v2-7b9ce.firebasestorage.app --cors-file=storage.cors.json
   ```

   *Comprueba:* en la app web se ve una figura subida desde el panel.

6. **Compilar sin emuladores.** Los `--dart-define=EMULADOR_...` solo se usan
   en modo debug; las versiones `--release` ya van directo a Firebase.
   Compila y publica la app y el panel como siempre.

7. **Activar lo que esperaba a Blaze, desde el panel:**
   - Configuración → "Foto del comprobante" (los pagos suben su captura).
   - Cursos y temas → Narraciones: subir los audios reales (los enlaces de
     prueba se pueden eliminar).

8. **Revisar todo de una vez:** Panel → Estado del sistema. Firestore,
   Functions y Storage deben salir en verde. Luego, en la app: una duda al
   tutor, un quiz corregido y una narración que suene.

## Después (no bloquean la salida)

- Activar App Check en la app y en el panel.
- Crear un proyecto aparte para pruebas (dev) y dejar este solo para
  producción.
- Cambiar la contraseña de la cuenta de prueba del estudiante.

## Si algo falla

- **Functions no responde:** `firebase functions:log` muestra el error.
  Si dice que falta el secreto, repite el paso 2 y vuelve a desplegar.
- **Storage dice "permission denied":** revisa que el paso 4 desplegó
  `storage.rules` y que el usuario del panel tiene el permiso admin
  (`tool/hacer_admin.js`).
- **Las figuras no se ven solo en la web:** falta el paso 5 (CORS).
