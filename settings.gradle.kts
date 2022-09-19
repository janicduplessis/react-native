/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

pluginManagement {
  repositories {
    mavenCentral()
    google()
    gradlePluginPortal()
  }
}

include(":ReactAndroid", ":ReactAndroid:hermes-engine", ":packages:rn-tester:android:app")

// Include this to enable codegen Gradle plugin.
includeBuild("packages/react-native-gradle-plugin/")

rootProject.name = "react-native-github"

plugins { id("com.gradle.enterprise").version("3.7.1") }

// If you specify a file inside gradle/gradle-enterprise.gradle.kts
// you can configure your custom Gradle Enterprise instance
if (File("./gradle/gradle-enterprise.gradle.kts").exists()) {
  apply(from = "./gradle/gradle-enterprise.gradle.kts")
}

include(":react-native-annotations")
project(":react-native-annotations").projectDir = File(rootProject.projectDir, "packages/annotations-compiler/annotations")
include(":react-native-annotations-compiler")
project(":react-native-annotations-compiler").projectDir = File(rootProject.projectDir, "packages/annotations-compiler/compiler")
