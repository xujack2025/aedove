require 'xcodeproj'

project_path = 'Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.first

# Update build settings for all configurations
target.build_configurations.each do |config|
  config.build_settings['SWIFT_EMIT_MODULE_INTERFACE'] = 'NO'
  config.build_settings['DEFINES_MODULE'] = 'NO'
  config.build_settings['SWIFT_INSTALL_OBJC_HEADER'] = 'NO'
end

# Save the changes
project.save