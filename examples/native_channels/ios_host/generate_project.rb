#!/usr/bin/env ruby
# Reproducibly generate the two native app targets. CocoaPods then creates the workspace.
require 'xcodeproj'

root = File.expand_path(__dir__)
project_path = File.join(root, 'NativeChannelsHost.xcodeproj')
project = Xcodeproj::Project.new(project_path)
project.root_object.attributes['LastUpgradeCheck'] = '1640'

apps = {}
%w[HostBase HostAds].each do |name|
  group = project.main_group.new_group(name, name)
  source = group.new_file('AppDelegate.swift')
  group.new_file('Info.plist')
  target = project.new_target(:application, name, :ios, '13.0')
  apps[name] = target
  target.source_build_phase.add_file_reference(source)
  target.build_configurations.each do |configuration|
    settings = configuration.build_settings
    settings['PRODUCT_BUNDLE_IDENTIFIER'] = "com.jolibox.examples.nativechannels.#{name.downcase}"
    settings['INFOPLIST_FILE'] = "#{name}/Info.plist"
    settings['SWIFT_VERSION'] = '5.0'
    settings['CLANG_ENABLE_MODULES'] = 'YES'
    settings['TARGETED_DEVICE_FAMILY'] = '1,2'
    settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
    settings['CODE_SIGNING_ALLOWED'] = 'NO'
    settings['LD_RUNPATH_SEARCH_PATHS'] = '$(inherited) @executable_path/Frameworks'
  end
  scheme = Xcodeproj::XCScheme.new
  scheme.configure_with_targets(target, nil)
  scheme.save_as(project_path, name, true)
end

tests_group = project.main_group.new_group('HostAdsTests', 'HostAdsTests')
test_source = tests_group.new_file('BridgeLifecycleTests.swift')
test_target = project.new_target(:unit_test_bundle, 'HostAdsTests', :ios, '13.0')
test_target.source_build_phase.add_file_reference(test_source)
test_target.add_dependency(apps.fetch('HostAds'))
test_target.build_configurations.each do |configuration|
  settings = configuration.build_settings
  settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.jolibox.examples.nativechannels.hostadstests'
  settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  settings['SWIFT_VERSION'] = '5.0'
  settings['CLANG_ENABLE_MODULES'] = 'YES'
  settings['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/HostAds.app/HostAds'
  settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
  settings['CODE_SIGNING_ALLOWED'] = 'NO'
end
scheme = Xcodeproj::XCScheme.new
scheme.configure_with_targets(apps.fetch('HostAds'), test_target)
# CLI lifecycle tests do not need a debugger connection. Keep LaunchAction debug-enabled.
scheme.test_action.xml_element.attributes['selectedDebuggerIdentifier'] = ''
scheme.test_action.xml_element.attributes['selectedLauncherIdentifier'] = 'Xcode.IDEFoundation.Launcher.PosixSpawn'
scheme.save_as(project_path, 'HostAds', true)

project.build_configurations.each do |configuration|
  configuration.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
end
project.save
