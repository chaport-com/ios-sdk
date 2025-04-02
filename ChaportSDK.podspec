Pod::Spec.new do |s|
  s.name             = 'ChaportSDK'
  s.version          = '1.0.2'
  s.summary          = 'ChaportSDK chat window for your iOS app.'
  s.homepage         = 'https://github.com/chaport-com/ios-sdk'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'ChaportSDK Inc' => 'info@chaport.com' }
  s.source           = { :git => 'https://github.com/chaport-com/ios-sdk', :tag => s.version.to_s }

  s.ios.deployment_target = '12.0'
  s.vendored_frameworks = 'ChaportSDK.framework'
  s.frameworks = 'UIKit', 'WebKit', 'UserNotifications'
  s.swift_version = '6.1'
  s.module_name = 'ChaportSDK'

  s.pod_target_xcconfig = {
    'BUILD_LIBRARY_FOR_DISTRIBUTION' => 'YES',
    'DEFINES_MODULE' => 'YES'
  }
end
