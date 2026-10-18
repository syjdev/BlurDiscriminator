plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
    id("com.vanniktech.maven.publish")
}

group = "io.github.syjdev"
version = providers.gradleProperty("VERSION_NAME").get()

android {
    namespace = "dev.syjdev.pixelblurdetector"
    compileSdk = 35

    defaultConfig {
        minSdk = 26
        consumerProguardFiles("consumer-rules.pro")
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
    testOptions {
        unitTests.all { it.useJUnitPlatform() }
    }
}

mavenPublishing {
    coordinates(group.toString(), "pixel-blur-detector", version.toString())

    // Uploads to the Central Portal; the deployment is released by hand there.
    publishToMavenCentral()
    // Maven Central requires signed artifacts. Signing only runs when a key is configured, so
    // publishToMavenLocal works without one; an unsigned upload is rejected by the Central Portal.
    if (providers.gradleProperty("signingInMemoryKey").isPresent) {
        signAllPublications()
    }

    pom {
        name = "PixelBlurDetector"
        description = "Find the blurry regions of a photo, pixel by pixel, on Android."
        inceptionYear = "2021"
        url = "https://github.com/syjdev/PixelBlurDetector"
        licenses {
            license {
                name = "The Apache License, Version 2.0 (source code)"
                url = "https://www.apache.org/licenses/LICENSE-2.0.txt"
                distribution = "repo"
            }
            license {
                name = "Bundled model: research / non-commercial use only"
                url = "https://github.com/syjdev/PixelBlurDetector/blob/master/MODEL_LICENSE.md"
                distribution = "repo"
            }
        }
        developers {
            developer {
                id = "syjdev"
                name = "syjdev"
                url = "https://github.com/syjdev"
            }
        }
        scm {
            url = "https://github.com/syjdev/PixelBlurDetector"
            connection = "scm:git:git://github.com/syjdev/PixelBlurDetector.git"
            developerConnection = "scm:git:ssh://git@github.com/syjdev/PixelBlurDetector.git"
        }
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
    implementation("org.tensorflow:tensorflow-lite:2.16.1")

    testImplementation("org.junit.jupiter:junit-jupiter:5.11.4")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher:1.11.4")
}
