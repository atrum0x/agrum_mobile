# Release builds are shrunk by R8, which renames and strips classes. ML Kit and TensorFlow Lite reach
# their classes from native code and by reflection, so R8 can't see those uses. Without these rules the
# face check failed only in release builds ("InputImageConverterError ... getClass() on a null object").
# The Flutter Gradle plugin picks this file up by name.

# ML Kit face detection and the Flutter plugin's image converter
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_face.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_face_bundled.** { *; }
-keep class com.google_mlkit_commons.** { *; }
-keep class com.google_mlkit_face_detection.** { *; }

# TensorFlow Lite (ArcFace); the GPU delegate is optional and not bundled
-keep class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.gpu.**
