Pod::Spec.new do |s|
  s.name         = "Clipper2-swift"
  s.version      = "1.0.0"
  s.summary      = "Polygon clipping and offsetting library for Swift"
  s.description  = <<-DESC
    Swift port of the Clipper2 polygon clipping and offsetting library.
    Supports boolean operations (intersection, union, difference, XOR),
    polygon offsetting, rectangular clipping, and Minkowski operations.
  DESC
  s.homepage     = "https://github.com/user/Clipper2-swift"
  s.license      = { :type => "BSL-1.0", :file => "LICENSE" }
  s.author       = "ninebot"
  s.source       = { :git => ".", :tag => s.version.to_s }

  s.ios.deployment_target = "13.0"
  s.macos.deployment_target = "10.15"
  s.swift_version = "5.9"

  s.source_files = "Sources/Clipper2/**/*.swift"

  s.test_spec 'Tests' do |test_spec|
    test_spec.source_files = "Tests/Clipper2Tests/**/*.swift"
    test_spec.resources = "Tests/Clipper2Tests/Resources/*"
  end
end
