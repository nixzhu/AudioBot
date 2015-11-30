Pod::Spec.new do |s|

  s.name        = "AudioBot"
  s.version     = "0.1"
  s.summary     = "AudioBot helps your do audio record & playback."

  s.description = <<-DESC
                   AudioBot helps your do audio record & playback.
                   DESC

  s.homepage    = "https://github.com/nixzhu/AudioBot"

  s.license     = { :type => "MIT", :file => "LICENSE" }

  s.authors           = { "nixzhu" => "zhuhongxu@gmail.com" }
  s.social_media_url  = "https://twitter.com/nixzhu"

  s.ios.deployment_target   = "8.0"
  # s.osx.deployment_target = "10.7"

  s.source          = { :git => "https://github.com/nixzhu/AudioBot.git", :tag => s.version }
  s.source_files    = "AudioBot/*.swift"
  s.requires_arc    = true

end
