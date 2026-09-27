// SPDX-License-Identifier: GPL-3.0-or-later
import org.gradle.api.artifacts.component.ModuleComponentIdentifier
import org.gradle.api.artifacts.component.ProjectComponentIdentifier
import org.gradle.api.artifacts.result.ResolvedDependencyResult

plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.ktlint)
}

/** Name of the Godot singleton, used by the app's Android adapter. */
val godotPluginName = "CartoucheAndroid"

android {
    namespace = "app.cartouche.android"
    compileSdk = 36

    defaultConfig {
        // Android 11 is the first version with "All files access", which ROM scanning relies on;
        // every supported handheld runs 11 or newer.
        minSdk = 30
        manifestPlaceholders["godotPluginName"] = godotPluginName
        buildConfigField("String", "GODOT_PLUGIN_NAME", "\"$godotPluginName\"")
    }

    buildFeatures { buildConfig = true }

    // Robolectric runs the Android-bound code (intents, URI grants) in JVM tests.
    testOptions.unitTests.isIncludeAndroidResources = true
}

base { archivesName = "cartouche-android" }

kotlin {
    jvmToolchain(17)
    explicitApi()
    compilerOptions { allWarningsAsErrors = true }
}

dependencies {
    // Provided by the Godot app at runtime.
    compileOnly(libs.godot)
    testImplementation(libs.godot)
    implementation(project(":core"))
    implementation(libs.coroutines.android)
    implementation(libs.serialization.json)
    testImplementation(libs.bundles.test)
    testImplementation(testFixtures(project(":core")))
    testImplementation(libs.robolectric)
}

// The Godot export only bundles files it is told about: the plugin AARs, the core jar, and the
// Maven coordinates of their external dependencies, which export_plugin.gd reads from
// dependencies.txt so that versions are declared once, in the version catalog.
val writeGodotDependencies by tasks.registering {
    val output = layout.buildDirectory.file("godot/dependencies.txt")
    val coordinates =
        configurations.named("releaseRuntimeClasspath").map { classpath ->
            classpath.incoming.resolutionResult.root.dependencies
                .filterIsInstance<ResolvedDependencyResult>()
                .flatMap { dependency ->
                    val component = dependency.selected
                    if (component.id is ProjectComponentIdentifier) {
                        component.dependencies.filterIsInstance<ResolvedDependencyResult>().map { it.selected.id }
                    } else {
                        listOf(component.id)
                    }
                }.filterIsInstance<ModuleComponentIdentifier>()
                .map { "${it.group}:${it.module}:${it.version}" }
                .toSortedSet()
        }
    inputs.property("coordinates", coordinates)
    outputs.file(output)
    doLast { output.get().asFile.writeText(coordinates.get().joinToString("\n", postfix = "\n")) }
}

val syncToGodot by tasks.registering(Sync::class) {
    description = "Puts the plugin AARs, the core jar and dependencies.txt in the Godot addon's bin folder."
    from(tasks.named("bundleDebugAar"), tasks.named("bundleReleaseAar"), writeGodotDependencies)
    from(project(":core").tasks.named("jar")) { rename { "cartouche-core.jar" } }
    into(rootProject.file("../app/addons/cartouche_android/bin"))
}

tasks.named("assemble") { finalizedBy(syncToGodot) }
