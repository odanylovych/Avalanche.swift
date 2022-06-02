Pod::Spec.new do |s|
  s.name             = 'Avalanche'
  s.version          = '0.0.1'
  s.summary          = 'Avalanche.swift - The Avalanche Platform Swift Library'

  s.description      = <<-DESC
Avalanche.swift is a Swift Library for interfacing with the Avalanche Platform.
The library allows one to issue commands to the Avalanche node APIs.
                       DESC

  s.homepage         = 'https://github.com/tesseract-one/Avalanche.swift'

  s.license          = { :type => 'Apache 2.0', :file => 'LICENSE' }
  s.author           = { 'Tesseract Systems, Inc.' => 'info@tesseract.one' }
  s.source           = { :git => 'https://github.com/tesseract-one/Avalanche.swift.git', :tag => s.version.to_s }

  s.ios.deployment_target = '10.0'
  s.osx.deployment_target = '10.12'
  s.tvos.deployment_target = '10.0'
  s.watchos.deployment_target = '6.0'
  
  s.swift_version = '5.4'

  s.module_name = 'Avalanche'
  
  s.subspec 'Avalanche' do |ss|
    ss.source_files = 'Sources/Avalanche/**/*.swift'

    ss.dependency 'JsonRPC.swift', '~> 0.0.1'
    ss.dependency 'UncommonCrypto' '~> 0.1.0'
    ss.dependency 'Bech32.swift', '~> 1.1.0'
    ss.dependency 'Serializable.swift', '~> 0.2'
    ss.dependency 'BigInt', '~> 5.3'
    ss.dependency 'web3swift', '~> 2.6.3'
    
    ss.test_spec 'AvalancheTests' do |test_spec|
      test_spec.platforms = {:ios => '10.0', :osx => '10.12', :tvos => '10.0'}
      test_spec.source_files = 'Tests/AvalancheTests/**/*.swift'
    end
  end
  
  s.subspec 'Keychain' do |ss|
    ss.source_files = 'Sources/Keychain/**/*.swift'

    ss.dependency 'Avalanche/Avalanche'
    
    ss.test_spec 'KeychainTests' do |test_spec|
      test_spec.platforms = {:ios => '10.0', :osx => '10.12', :tvos => '10.0'}
      test_spec.source_files = 'Tests/KeychainTests/**/*.swift'
    end
  end
  
  s.default_subspecs = 'Avalanche'
end
