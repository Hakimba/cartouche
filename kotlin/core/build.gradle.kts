// SPDX-License-Identifier: GPL-3.0-or-later
plugins {
    alias(libs.plugins.kotlin.jvm)
    alias(libs.plugins.ktlint)
}

kotlin {
    jvmToolchain(17)
    explicitApi()
    compilerOptions { allWarningsAsErrors = true }
}

dependencies {
    api(libs.arrow.core)
    implementation(libs.serialization.json)
    testImplementation(libs.bundles.test)
}

// The tests check the definition files shipped with the app, not copies.
tasks.test { systemProperty("cartouche.platformData", rootProject.file("../app/data/platforms/daijishou").path) }
