#!/usr/bin/env ruby
# Configure a generated Flutter iOS Runner for App Store distribution.
# Run ONLY on macOS with the xcodeproj gem available (CocoaPods installs it).
require 'xcodeproj'
require 'plist'

bundle = ENV.fetch('SH_OWNER_IOS_BUNDLE_ID', '')
team = ENV.fetch('APPSTORE_TEAM_ID', '')
unless bundle.match?(/\A[a-zA-Z][\w]*(?:\.[a-zA-Z][\w]*){2,}\z/) &&
       team.match?(/\A[A-Z0-9]{10}\z/)
  abort 'Final SH_OWNER_IOS_BUNDLE_ID and APPSTORE_TEAM_ID are required.'
end

project_path = 'ios/Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)
runner = project.targets.find { |t| t.name == 'Runner' }
abort 'Flutter Runner target not found' unless runner

profile_name = "AppStore #{bundle}"
runner.build_configurations.each do |config|
  settings = config.build_settings
  settings['PRODUCT_BUNDLE_IDENTIFIER'] = bundle
  settings['DEVELOPMENT_TEAM'] = team
  settings['CODE_SIGN_STYLE'] = 'Manual'
  settings['CODE_SIGN_IDENTITY'] = 'Apple Distribution'
  settings['PROVISIONING_PROFILE_SPECIFIER'] = profile_name
  settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
end

# Test targets are not exported to TestFlight, but their IDs must not
# collide with the signed Runner target.
project.targets.select { |t| t.name != 'Runner' }.each do |target|
  target.build_configurations.each do |config|
    settings = config.build_settings
    settings['PRODUCT_BUNDLE_IDENTIFIER'] = "#{bundle}.#{target.name}"
  end
end
project.save

# ExportOptions.plist is not a credential and can be generated on the runner.
require 'fileutils'
require 'rexml/document'
require 'plist'
options = {
  'method' => 'app-store-connect',
  'teamID' => team,
  'signingStyle' => 'manual',
  'uploadSymbols' => true,
  'manageAppVersionAndBuildNumber' => false,
  'provisioningProfiles' => { bundle => profile_name },
}
File.write('/tmp/sh_owner_export_options.plist', Plist::Emit.dump(options))
puts "iOS release identity set: #{bundle} (team #{team})."
puts 'App Store provisioning profile must be named: ' + profile_name
