Pod::Spec.new do |spec|
  spec.name = 'jolibox_ads_flutter'
  spec.version = '0.1.0'
  spec.summary = 'Flutter bridge for the Jolibox Host Ads SDK.'
  spec.description = <<-DESC
Flutter MethodChannel and PlatformView bridge for a native Jolibox Host Ads SDK.
The native host owns SDK initialization; Flutter only loads and shows scene-based ads.
DESC
  spec.homepage = 'https://github.com/Jolibox-Developer/jolibox-ads-flutter'
  spec.license = { :type => 'Proprietary', :file => '../LICENSE' }
  spec.author = { 'Jolibox Pte. Ltd.' => 'contact@jolibox.com' }
  spec.source = { :path => '.' }
  spec.source_files = 'Classes/**/*.{swift,h,m}'
  spec.ios.deployment_target = '15.0'
  spec.dependency 'Flutter'
  spec.dependency 'JoliboxSDKAll', '1.10.3'
  spec.swift_version = '5.0'
end
