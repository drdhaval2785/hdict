allprojects {
    repositories {
        google()
        mavenCentral()
    }
    // Only exclude non-free libraries when building the fdroid flavor.
    // This allows local development builds to compile normally while ensuring
    // the F-Droid build remains clean.
    if (gradle.startParameter.taskNames.any { it.contains("fdroid", ignoreCase = true) }) {
        configurations.all {
            exclude(group = "com.google.android.play")
            exclude(group = "com.google.android.gms")
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
