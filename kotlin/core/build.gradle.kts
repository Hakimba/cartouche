// SPDX-License-Identifier: GPL-3.0-or-later
plugins {
    `java-test-fixtures`
    alias(libs.plugins.kotlin.jvm)
    alias(libs.plugins.kotlin.serialization)
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
    implementation(libs.arrow.serialization)
    implementation(libs.xz)
    testImplementation(libs.bundles.test)
    // Generators, fixtures and fakes shared by the tests of both modules.
    testFixturesImplementation(libs.kotest.property)
    testFixturesImplementation(libs.junit.launcher)
    testRuntimeOnly(libs.junit.vintage)
}

// The tests check the definition files shipped with the app, not copies.
tasks.test { systemProperty("cartouche.data", rootProject.file("../app/data").path) }
