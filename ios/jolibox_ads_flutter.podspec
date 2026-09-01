#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint jolibox_ads_flutter.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'jolibox_ads_flutter'
  s.version          = '0.6.7'
  s.summary          = 'Flutter bridge for Jolibox Ad Mediation.'
  s.description      = <<-DESC
Flutter bridge for the Jolibox native ad mediation SDK.
                       DESC
  s.homepage         = 'https://github.com/Jolibox-Developer/jolibox-ads-flutter'
  s.license          = { :type => 'Proprietary', :file => '../LICENSE' }
  s.author           = 'Jolibox'
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.vendored_frameworks = 'Frameworks/JoliboxAdMediation.xcframework'
  s.static_framework = true
  s.dependency 'Flutter'
  s.dependency 'Google-Mobile-Ads-SDK', '12.1.0'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'FRAMEWORK_SEARCH_PATHS[sdk=iphonesimulator*]' => '$(inherited) "$(PODS_TARGET_SRCROOT)/Frameworks/JoliboxAdMediation.xcframework/ios-arm64_x86_64-simulator"',
    'FRAMEWORK_SEARCH_PATHS[sdk=iphoneos*]' => '$(inherited) "$(PODS_TARGET_SRCROOT)/Frameworks/JoliboxAdMediation.xcframework/ios-arm64"'
  }
  s.swift_version = '5.0'
end
