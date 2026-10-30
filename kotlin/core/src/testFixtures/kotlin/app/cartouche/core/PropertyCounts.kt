// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core

import io.kotest.property.PropertyTesting
import org.junit.platform.engine.TestDescriptor
import org.junit.platform.launcher.TestExecutionListener
import org.junit.platform.launcher.TestIdentifier

private const val INVARIANT_CASES = 1000
private const val CASES = 100

/**
 * An invariant's property draws 1000 cases, any other 100: the suites stay fast, the guarantees keep their strength.
 * Robolectric's sandbox loads its own Kotest, out of this listener's reach, so its properties keep Kotest's 1000.
 */
public class PropertyCounts : TestExecutionListener {
    override fun executionStarted(testIdentifier: TestIdentifier) {
        if (testIdentifier.type == TestDescriptor.Type.TEST) {
            PropertyTesting.defaultIterationCount = if (testIdentifier.displayName.startsWith("INV-")) INVARIANT_CASES else CASES
        }
    }
}
