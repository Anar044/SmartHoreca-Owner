#!/usr/bin/env ruby
# Configure the generated Flutter iOS Runner for manual App Store distribution.
# The private signing identity and provisioning profile are imported on the
# ephemeral macOS runner; no key material belongs in this repository.
require 'xcodeproj'
require 'fileutils'

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

# On TestFlight, Apple Push notifications use the production APNs environment.
# This entitlement requires Push Notifications enabled for the App ID and
# a matching App Store provisioning profile. Firebase configuration and APNs
# delivery must still be tested separately on an actual iPhone.
entitlements_path = 'ios/Runner/Runner.entitlements'
File.write(entitlements_path, <<~XML)
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0">
    <dict>
      <key>aps-environment</key>
      <string>production</string>
    </dict>
  </plist>
XML

runner.build_configurations.each do |config|
  settings = config.build_settings
  settings['PRODUCT_BUNDLE_IDENTIFIER'] = bundle
  settings['DEVELOPMENT_TEAM'] = team
  settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
  next unless %w[Release Profile].include?(config.name)

  settings['CODE_SIGN_STYLE'] = 'Manual'
  settings['CODE_SIGN_IDENTITY'] = 'Apple Distribution'
  settings['PROVISIONING_PROFILE_SPECIFIER'] = profile_name
  settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end

# Test targets are not exported to TestFlight and must have unique IDs.
project.targets.select { |t| t.name != 'Runner' }.each do |target|
  target.build_configurations.each do |config|
    config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = "#{bundle}.#{target.name}"
  end
end
project.save

# Generate the Xcode export plist without a nonstandard Ruby 'plist' gem.
# These values contain only validated public identifiers.
export_xml = <<~XML
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0">
    <dict>
      <key>method</key><string>app-store-connect</string>
      <key>teamID</key><string>#{team}</string>
      <key>signingStyle</key><string>manual</string>
      <key>signingCertificate</key><string>Apple Distribution</string>
      <key>manageAppVersionAndBuildNumber</key><false/>
      <key>provisioningProfiles</key>
      <dict><key>#{bundle}</key><string>#{profile_name}</string></dict>
    </dict>
  </plist>
XML
File.write('/tmp/sh_owner_export_options.plist', export_xml)
puts "iOS release identity set: #{bundle} (team #{team})."
puts "Required provisioning profile: #{profile_name}"
