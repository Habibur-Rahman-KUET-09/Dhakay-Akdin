// Google sign-in for the game (an Android library for Godot's v2 plugins).
// Built by CI: gradle -p android-plugin assembleRelease
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
    }
}
rootProject.name = "GoogleSignIn"
