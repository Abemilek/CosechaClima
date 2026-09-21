# Reglas ProGuard/R8 para el build de release.
#
# Se activo isMinifyEnabled/isShrinkResources en build.gradle.kts para
# reducir el tamaño del APK. R8 puede eliminar por error clases que solo
# se referencian por reflexion desde el motor de Flutter o desde los
# plugins, asi que hay que preservarlas explicitamente.

# ── Motor de Flutter ─────────────────────────────────────────────────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ── flutter_secure_storage ───────────────────────────────────────────
# Usa androidx.security.crypto, que resuelve proveedores por reflexion.
-keep class androidx.security.crypto.** { *; }
-keep class com.google.crypto.tink.** { *; }

# ── geolocator ───────────────────────────────────────────────────────
-keep class com.baseflow.geolocator.** { *; }

# ── Anotaciones y firmas genericas ───────────────────────────────────
# Necesarias para que la serializacion y la reflexion sigan funcionando.
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# No advertir por clases opcionales que no estan en el classpath.
-dontwarn io.flutter.embedding.**
-dontwarn javax.annotation.**
