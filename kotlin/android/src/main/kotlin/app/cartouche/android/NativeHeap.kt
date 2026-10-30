// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.android

/**
 * The C allocator Godot and the graphics driver share (`src/main/cpp/native_heap.c`). It keeps the memory a program
 * frees for reuse, so the app would hold a hundred MB it no longer uses: what the start and each screen built.
 */
internal object NativeHeap {
    init {
        System.loadLibrary("cartouche")
    }

    /** Every free page goes back to the system. */
    @JvmStatic external fun release()
}
