Pod::Spec.new do |s|
  s.name             = 'media_kit_libs_macos_video'
  s.version          = '1.1.4'
  s.summary          = 'Observideo controlled media runtime.'
  s.homepage         = 'https://github.com/mping/observideo'
  s.license          = { :type => 'GPL-3.0' }
  s.author           = { 'Observideo' => 'maintainers@observideo.org' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.platform         = :osx, '10.15'
  s.swift_version    = '5.0'
  s.dependency 'FlutterMacOS'
  s.vendored_frameworks = 'Frameworks/Mpv.framework'
  s.vendored_libraries = 'Libraries/*.dylib'
  s.preserve_paths = 'Frameworks/Mpv.framework/Headers/**/*'
  s.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => '$(inherited) "${PODS_TARGET_SRCROOT}/Frameworks/Mpv.framework/Headers"'
  }
end
