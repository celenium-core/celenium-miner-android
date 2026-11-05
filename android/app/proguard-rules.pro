# WorkManager (pulled in by google_mobile_ads) uses Room 2.2.5, whose consumer
# rules keep RoomDatabase subclasses by name only. R8 full mode then strips
# WorkDatabase_Impl's no-arg constructor and its abstract-method overrides —
# both reachable only through reflection — so the app dies in
# androidx.startup.InitializationProvider before the first frame is drawn.
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keepclassmembers class * extends androidx.room.RoomDatabase { <init>(); }
