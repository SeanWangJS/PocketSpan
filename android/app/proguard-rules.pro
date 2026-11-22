# Keep flutter_local_notifications scheduled alarm receivers & models intact under R8
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
