plugins {
    // [核心修正] 移除了错误的 "version '8.5.1'"，让系统自动选择版本
    id("com.android.application") apply false
    id("org.jetbrains.kotlin.android") version "2.0.0" apply false
}

allprojects {
    repositories {
        maven { setUrl("https://maven.aliyun.com/repository/central") }
        maven { setUrl("https://maven.aliyun.com/repository/jcenter") }
        maven { setUrl("https://maven.aliyun.com/repository/google") }
        maven { setUrl("https://maven.aliyun.com/repository/gradle-plugin") }
        maven { setUrl("https://maven.aliyun.com/repository/public") }
        maven { setUrl("https://jitpack.io") }
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}