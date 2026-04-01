import org.jetbrains.kotlin.gradle.tasks.KotlinCompile
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.gradle.api.tasks.compile.JavaCompile

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    project.layout.buildDirectory.value(newBuildDir.dir(project.name))
}

// Fix JVM target mismatch in third-party plugins (e.g. disk_space_2):
// Match Kotlin jvmTarget to whatever Java sourceCompatibility the plugin sets,
// rather than forcing everything to 17 (which breaks plugins written for Java 8).
gradle.projectsEvaluated {
    subprojects {
        // Skip the app module — it manages its own config correctly
        if (project.name == "app") return@subprojects

        tasks.withType<KotlinCompile>().configureEach {
            // Read the Java compile target for this project and match it
            val javaTarget = tasks.withType<JavaCompile>()
                .firstOrNull()
                ?.targetCompatibility
                ?: "17"

            compilerOptions {
                jvmTarget.set(
                    when (javaTarget) {
                        "1.8", "8" -> JvmTarget.JVM_1_8
                        "11"       -> JvmTarget.JVM_11
                        "17"       -> JvmTarget.JVM_17
                        else       -> JvmTarget.JVM_1_8
                    }
                )
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
