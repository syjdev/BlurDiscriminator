pluginManagement {
    repositories {
        google {
            content {
                includeGroupByRegex("com\\.android.*")
                includeGroupByRegex("com\\.google.*")
                includeGroupByRegex("androidx.*")
            }
        }
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "PixelBlurDetectorDemo"
include(":app")

// The demo uses the SDK published on Maven Central. To build it against a local checkout of
// PixelBlurDetector-Android instead, pass -PpixelBlurDetectorSdkPath=<path to the checkout>.
providers.gradleProperty("pixelBlurDetectorSdkPath").orNull?.let { includeBuild(it) }
