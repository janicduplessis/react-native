/*
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

pluginManagement {
    repositories {
        gradlePluginPortal()
        mavenLocal()
        google()
    }
}

include(
    ":ReactAndroid",
    ":packages:rn-tester:android:app"
)

// Include this to enable codegen Gradle plugin.
includeBuild("packages/react-native-codegen/android")

include(":react-native-annotations")
project(":react-native-annotations").projectDir = File(rootProject.projectDir, "android/annotations")

include(":react-native-annotations-compiler")
project(":react-native-annotations-compiler").projectDir = File(rootProject.projectDir, "android/annotations-compiler")
