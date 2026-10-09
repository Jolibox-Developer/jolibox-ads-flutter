Pod::Spec.new do |s|
  s.name = 'JoliboxFlutterAdsBridgeAdMob'
  s.version = '0.8.0'
  s.summary = 'Native iOS bridge for the Jolibox Flutter ads channels.'
  s.description = 'An explicitly registered iOS adapter for a host-owned FlutterEngine.'
  s.homepage = 'https://github.com/Jolibox-Developer/jolibox-ads-flutter'
  s.license = { :type => 'Proprietary', :file => 'LICENSE' }
  s.author = 'Jolibox'
  # This local source spec is consumed by :path; publication awaits an authorized Git ref.
  s.source = { :path => '.' }
  s.source_files = 'Classes/**/*.swift'
  s.vendored_frameworks = 'Frameworks/JoliboxAdMediation.xcframework'
  s.static_framework = true
  s.platform = :ios, '13.0'
  s.swift_version = '5.0'
  s.dependency 'Flutter'
  s.dependency 'Google-Mobile-Ads-SDK', '12.1.0'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
  }
end
