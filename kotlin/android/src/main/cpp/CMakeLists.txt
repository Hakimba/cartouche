# SPDX-License-Identifier: GPL-3.0-or-later
cmake_minimum_required(VERSION 3.22.1)
project(cartouche C)
add_library(cartouche SHARED native_heap.c)
