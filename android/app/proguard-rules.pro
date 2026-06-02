# Keep ML Kit text recognition base classes
-keep class com.google.mlkit.vision.text.** { *; }

# Ignore missing optional recognizers
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-dontwarn com.google.mlkit.vision.text.devanagari.**

# Keep Firebase IID classes if referenced
-keep class com.google.firebase.iid.** { *; }
-dontwarn com.google.firebase.iid.**
