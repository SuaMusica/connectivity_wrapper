Pod::Spec.new do |s|
  s.name             = 'connectivity_wrapper'
  s.version          = '1.1.0'
  s.summary          = 'Network-aware widgets with validated connectivity on iOS and Android.'
  s.description      = <<-DESC
Flutter package which exposes native validated network status (online, limited, offline).
                       DESC
  s.homepage         = 'https://github.com/suamusica/connectivity_wrapper'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'suamusica' => 'contato@suamusica.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'connectivity_wrapper/Sources/connectivity_wrapper/**/*.swift'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'
  s.swift_version    = '5.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end
