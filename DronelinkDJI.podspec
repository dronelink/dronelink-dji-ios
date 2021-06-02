Pod::Spec.new do |s|
  s.name = "DronelinkDJI"
  s.version = "2.3.0"
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
  s.pod_target_xcconfig = { 'ONLY_ACTIVE_ARCH' => 'YES' }
  s.dependency "DronelinkCore", "~> 2.3.0"
  s.dependency "DJI-SDK-iOS", "~> 4.14"
end
