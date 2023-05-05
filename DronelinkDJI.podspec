Pod::Spec.new do |s|
  s.name = "DronelinkDJI"
  s.version = "4.5.0"
  s.summary = "Dronelink vendor implementation for DJI"
  s.homepage = "https://dronelink.com/"
  s.license = { :type => "MIT", :file => "LICENSE" }
  s.author = { "Dronelink" => "dev@dronelink.com" }
  s.swift_version = "5.0"
  s.platform = :ios
  s.ios.deployment_target  = "12.0"
  s.source = { :git => "https://github.com/dronelink/dronelink-dji-ios.git", :tag => "#{s.version}" }
  s.source_files  = "DronelinkDJI/**/*.swift"
  s.resources = "DronelinkDJI/**/*.{strings}"
  s.pod_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64'}
  s.dependency "DronelinkCore", "~> 4.5.0"
  s.dependency "DJI-SDK-iOS", "~> 4.16.2"
  s.dependency "DJIWidget", "~> 1.6.8"
end
