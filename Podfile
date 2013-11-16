workspace 'Typhoon'
inhibit_all_warnings!

def import_test_pods
  pod 'OCHamcrest', '~> 1.9'
  pod 'OCMockito', '~> 0.2'
end

def import_typhoon_pod
  pod 'Typhoon', :path => '.'
end

target 'Typhoon-OSX' do
  xcodeproj 'Typhoon'
  platform :osx, '10.7'
  podspec
  link_with 'Typhoon-OSX'
end

target 'Typhoon-iOS' do
  xcodeproj 'Typhoon'
  platform :ios, '5.0'
  podspec
  link_with 'Typhoon-iOS'
end

target :ios do
  xcodeproj 'Tests/Tests'
  platform :ios, '5.0'
  import_test_pods
  link_with 'iOS Tests (Static Library)'
end

target 'iOS Tests (Cocoapods)' do
  xcodeproj 'Tests/Tests'
  platform :ios, '5.0'
  import_test_pods
  import_typhoon_pod
  link_with 'iOS Tests (Cocoapods)'
end

target :osx do
  xcodeproj 'Tests/Tests'
  platform :osx, '10.7'
  import_test_pods

  # until such time as we start generating os x coverage. then, use the commented out lines below.
  link_with 'OS X Tests (Cocoapods)'
  import_typhoon_pod


  # link_with 'OS X Tests (Static Library)'

  # target 'OS X Tests (Cocoapods)' do
  #   import_typhoon_pod
  # end
end

post_install do |installer_representation|
  # libffi or Cocoapods overwrite several of the libffi headers, so the iOS
  # headers are lost. Fortunately those overwritten headers can be easily
  # merged, since they have guards again being included in the wrong arch.
  require 'fileutils'

  read_io, write_io = IO.pipe
  pid = spawn('patch -r tmp.libffi.rej -N -p1', :in => read_io)
  write_io.write <<EOP
diff --git i/Pods/libffi/osx/include/ffi.h w/Pods/libffi/osx/include/ffi.h
index 9915fd3..d48a992 100644
--- i/Pods/libffi/osx/include/ffi.h
+++ w/Pods/libffi/osx/include/ffi.h
@@ -1,2 +1,3 @@
 #include <ffi_x86_64.h>
 #include <ffi_i386.h>
+#include <ffi_arm.h>

diff --git i/Pods/libffi/osx/include/fficonfig.h w/Pods/libffi/osx/include/fficonfig.h
index 9bf37bb..59a1365 100644
--- i/Pods/libffi/osx/include/fficonfig.h
+++ w/Pods/libffi/osx/include/fficonfig.h
@@ -1,2 +1,3 @@
 #include <fficonfig_x86_64.h>
 #include <fficonfig_i386.h>
+#include <fficonfig_arm.h>

diff --git i/Pods/libffi/osx/include/ffitarget.h w/Pods/libffi/osx/include/ffitarget.h
index 61a8ffd..18b5d72 100644
--- i/Pods/libffi/osx/include/ffitarget.h
+++ w/Pods/libffi/osx/include/ffitarget.h
@@ -1,2 +1,3 @@
 #include <ffitarget_x86_64.h>
 #include <ffitarget_i386.h>
+#include <ffitarget_arm.h>

EOP
  write_io.close
  Process.wait pid

  FileUtils.rm_f 'tmp.libffi.rej'
end
