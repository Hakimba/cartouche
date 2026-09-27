// SPDX-License-Identifier: GPL-3.0-or-later
plugins {
    alias(libs.plugins.kotlin.jvm) apply false
    alias(libs.plugins.android.library) apply false
    alias(libs.plugins.kotlin.android) apply false
    alias(libs.plugins.kotlin.serialization) apply false
    alias(libs.plugins.ktlint) apply false
}

// Property tests draw the same cases on every run, so that a failure always comes back.
subprojects {
    tasks.withType<Test>().configureEach { systemProperty("kotest.proptest.default.seed", "27092026") }
}
