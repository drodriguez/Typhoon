Pod::Spec.new do |spec|
    spec.name         = 'Typhoon'
    spec.version      = '1.5.3'
    spec.license      = 'Apache2.0'
    spec.summary      = 'A dependency injection container for Objective-C. Light-weight, yet flexible and full-featured.'
    spec.homepage     = 'http://www.typhoonframework.org'
    spec.author       = { 'Jasper Blues, Robert Gilliam & Contributors' => 'jasper@appsquick.ly' }
    spec.source       = { :git => 'https://github.com/jasperblues/Typhoon.git', :tag => spec.version.to_s, :submodules => true }
    spec.source_files = 'Source/**/*.{h,m}'
    spec.ios.exclude_files = "Source/osx"
    spec.osx.exclude_files = "Source/ios"
    spec.libraries    =  'z', 'xml2'
    spec.xcconfig     =  { 'HEADER_SEARCH_PATHS' => '$(SDKROOT)/usr/include/libxml2' }
    spec.requires_arc = true
    spec.dependency 'libffi', '~>3.0.13'
end 
