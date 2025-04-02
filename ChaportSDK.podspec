Pod::Spec.new do |s|
  s.name             = 'ChaportSDK'
  s.version          = '1.0.8'
  s.summary          = 'ChaportSDK chat window for your iOS app.'
  s.homepage         = 'https://github.com/chaport-com/ios-sdk'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'ChaportSDK Inc' => 'info@chaport.com' }
  s.source           = { :git => 'https://github.com/chaport-com/ios-sdk.git', :tag => s.version.to_s }

  s.ios.deployment_target = '12.0'
  s.frameworks = 'UIKit', 'WebKit', 'UserNotifications'
  s.swift_version = '6.1'
  s.module_name = 'ChaportSDK'
  s.vendored_frameworks = 'Frameworks/ChaportSDK.xcframework'
  s.preserve_paths = 'Frameworks/ChaportSDK.xcframework'
end
