#
# Be sure to run `pod lib lint MLeaksFinder.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "JCLeaksFinder"
  s.version          = "0.1.1"
  s.summary          = "Find memory leaks in your iOS app at develop time."
  s.description      = 'iOS 内存泄漏检测工具，支持检测内存泄漏并输出循环引用链/全局对象引用链。'
  s.author           = 'jerrychu'
  s.platform         = :ios
  s.homepage         = "https://github.com/JerryChu/JCLeaksFinder"
  s.license          = 'MIT'
  s.author           = { "" => "" }
  s.source           = { :git => "https://github.com/JerryChu/JCLeaksFinder", :branch => 'master' }
  s.ios.deployment_target   = '8.0'
  s.static_framework        = true
  
  s.subspec 'GlobalRetainDetector' do |ss|
    ss.requires_arc        = false
    ss.source_files        = 'GlobalRetainDetector/JCGlobalObjectsFinder.{h,m}'
    ss.public_header_files = 'GlobalRetainDetector/JCGlobalObjectsFinder.h'
  end

  s.subspec 'MLeaksFinder' do |ss|
    ss.source_files        = 'MLeaksFinder/**/*', 'JCLeaksConfig.{h,m}'
    ss.public_header_files = 'JCLeaksConfig.h', 'MLeaksFinder/NSObject+MemoryLeak.h'
    ss.dependency 'FBRetainCycleDetector'
    ss.dependency 'JCLeaksFinder/GlobalRetainDetector'
  end

end
