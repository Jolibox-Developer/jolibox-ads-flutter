#!/usr/bin/env ruby

require 'open3'

repo = File.expand_path('..', __dir__)
module_dir = File.join(repo, 'examples/native_channels/flutter_module')
Dir.chdir(module_dir) do
  abort('flutter pub get failed') unless system('flutter', 'pub', 'get')
end

flutter_bin, flutter_status = Open3.capture2('which', 'flutter')
abort('Flutter SDK not found') unless flutter_status.success?
flutter_root = File.dirname(File.dirname(File.realpath(flutter_bin.strip)))
jdk_home, jdk_status = Open3.capture2('/usr/libexec/java_home', '-v', '17')
abort('Java 17 is required') unless jdk_status.success?
jdk_home = jdk_home.strip

generated = File.join(module_dir, '.android')

def replace_generated(path, before, after)
  content = File.read(path)
  return if content.include?(after)
  abort("Unexpected generated Flutter template: #{path}") unless content.include?(before)
  File.write(path, content.sub(before, after))
end

root_gradle = File.join(generated, 'build.gradle')
replace_generated(root_gradle, 'ext.kotlin_version = "1.7.10"', 'ext.kotlin_version = "2.0.21"')
replace_generated(root_gradle, 'com.android.tools.build:gradle:7.3.0', 'com.android.tools.build:gradle:8.6.1')
replace_generated(root_gradle, 'compileSdk = 34', 'compileSdk = 35')
replace_generated(
  root_gradle,
  "allprojects {\n    repositories {\n        google()\n        mavenCentral()\n    }\n}",
  <<~GRADLE.chomp
    allprojects {
        repositories {
            google()
            mavenCentral()
        }
        configurations.configureEach {
            resolutionStrategy.eachDependency { details ->
                if (details.requested.group == "org.jetbrains.kotlin" &&
                    details.requested.name in ["kotlin-stdlib-jdk7", "kotlin-stdlib-jdk8"]) {
                    details.useTarget("org.jetbrains.kotlin:kotlin-stdlib:$kotlin_version")
                }
            }
        }
    }
  GRADLE
)

flutter_gradle = File.join(generated, 'Flutter/build.gradle')
replace_generated(
  flutter_gradle,
  "android {\n",
  "android {\n    publishing {\n        singleVariant(\"debug\")\n        singleVariant(\"release\")\n    }\n",
)
wrapper = File.join(generated, 'gradle/wrapper/gradle-wrapper.properties')
replace_generated(wrapper, 'gradle-7.5-all.zip', 'gradle-8.7-bin.zip')

properties = File.join(generated, 'gradle.properties')
content = File.read(properties)
content += "\norg.gradle.java.home=#{jdk_home}\n" unless content.include?('org.gradle.java.home=')
File.write(properties, content)

output_dir = File.join(module_dir, 'build/host')
gradle_args = [
  File.join(generated, 'gradlew'),
  "-I=#{File.join(flutter_root, 'packages/flutter_tools/gradle/aar_init_script.gradle')}",
  "-Pflutter-root=#{flutter_root}",
  "-Poutput-dir=#{output_dir}",
  '-Pis-plugin=false',
  '-PbuildNumber=1.0',
  '-Ptarget=lib/main.dart',
  '-Ptarget-platform=android-arm,android-arm64,android-x64',
  'assembleAarDebug',
  'assembleAarRelease',
]
gradle_args.insert(1, '--offline') unless ENV['GRADLE_OFFLINE'] == '0'
Dir.chdir(generated) do
  abort('Shared Flutter AAR build failed') unless system(*gradle_args)
end

puts "Shared AAR repository: #{File.join(output_dir, 'outputs/repo')}"
