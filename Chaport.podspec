Pod::Spec.new do |s|
  s.name             = 'Chaport'
  s.version          = '1.0.22'
  s.summary          = 'Chaport live chat for your iOS app.'
  s.homepage         = 'https://github.com/chaport-com/ios-sdk'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Chaport Inc.' => 'info@chaport.com' }
  s.source           = { :git => 'https://github.com/chaport-com/ios-sdk.git', :tag => s.version.to_s }
  s.source_files     = 'Sources/**/*.swift'

  s.ios.deployment_target = '15.0'
  s.frameworks = 'UIKit', 'WebKit'
  s.swift_version = '5.0'
  s.module_name = 'Chaport'
end
