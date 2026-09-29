allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    val configureProject: Project.() -> Unit = {
        if (hasProperty("android")) {
            val androidExt = extensions.findByName("android")
            if (androidExt != null) {
                try {
                    val compileOptions = androidExt.javaClass.getMethod("getCompileOptions").invoke(androidExt)
                    compileOptions.javaClass.getMethod("setSourceCompatibility", JavaVersion::class.java).invoke(compileOptions, JavaVersion.VERSION_17)
                    compileOptions.javaClass.getMethod("setTargetCompatibility", JavaVersion::class.java).invoke(compileOptions, JavaVersion.VERSION_17)
                } catch (_: Throwable) {}
            }
        }
        tasks.withType<JavaCompile>().configureEach {
            sourceCompatibility = JavaVersion.VERSION_17.toString()
            targetCompatibility = JavaVersion.VERSION_17.toString()
        }
        tasks.matching { it.name.contains("Kotlin") }.configureEach {
            try {
                val kotlinOptions = this.javaClass.getMethod("getKotlinOptions").invoke(this)
                kotlinOptions.javaClass.getMethod("setJvmTarget", String::class.java).invoke(kotlinOptions, "17")
            } catch (_: Throwable) {}
            try {
                val compilerOptions = this.javaClass.getMethod("getCompilerOptions").invoke(this)
                val jvmTargetProp = compilerOptions.javaClass.getMethod("getJvmTarget").invoke(compilerOptions)
                val jvmTargetClass = Class.forName("org.jetbrains.kotlin.gradle.dsl.JvmTarget")
                val jvmTarget17 = jvmTargetClass.getField("JVM_17").get(null)
                jvmTargetProp.javaClass.getMethod("set", Object::class.java).invoke(jvmTargetProp, jvmTarget17)
            } catch (_: Throwable) {}
        }
    }

    if (state.executed) {
        configureProject()
    } else {
        afterEvaluate {
            configureProject()
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
