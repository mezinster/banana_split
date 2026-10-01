#!/usr/bin/env ruby
# frozen_string_literal: true

# Configures banana_split_flutter/ios/Runner.xcodeproj beyond what
# `flutter create --platforms=ios` generates. Every project edit lives here,
# reviewable and re-runnable (idempotent) — don't hand-edit project.pbxproj.
# Needs the xcodeproj gem, which CocoaPods bundles; with a Homebrew CocoaPods:
#
#   GEM_HOME=$(brew --prefix cocoapods)/libexec \
#     ruby banana_split_flutter/ios/tool/configure_xcode_project.rb
#
# 1. Localized permission prompts: Runner/<lang>.lproj/InfoPlist.strings as a
#    variant group in Runner's resources, and the languages in knownRegions.
# 2. Bundle id through $(BSPL_BUNDLE_ID) (Flutter/*.xcconfig), and no
#    DEVELOPMENT_TEAM in the project: a team id belongs in the gitignored
#    Flutter/LocalOverrides.xcconfig.
# 3. Deployment target.
require 'xcodeproj'

IOS = File.expand_path('..', __dir__)
# The app's locales (lib/l10n/app_<lang>.arb); test/ios_project_test.dart
# fails if they drift apart.
LANGS = %w[en ru tr be ka uk pl es it].freeze
# Keep in step with `platform :ios` in the Podfile.
DEPLOYMENT = '13.0'

project = Xcodeproj::Project.open(File.join(IOS, 'Runner.xcodeproj'))
runner = project.targets.find { |t| t.name == 'Runner' } or abort('no Runner target')
tests = project.targets.find { |t| t.name == 'RunnerTests' }
runner_group = project.main_group['Runner'] or abort('no Runner group')

# --- 1. localized InfoPlist.strings -------------------------------------------
project.root_object.known_regions = (project.root_object.known_regions + LANGS).uniq
variant = runner_group.children.find { |c| c.isa == 'PBXVariantGroup' && c.name == 'InfoPlist.strings' }
unless variant
  variant = runner_group.new_variant_group('InfoPlist.strings')
  runner.resources_build_phase.add_file_reference(variant, true)
end
LANGS.each do |lang|
  next if variant.children.any? { |r| r.name == lang }

  variant.new_reference("#{lang}.lproj/InfoPlist.strings").name = lang
end

# --- 2. bundle id and signing -------------------------------------------------
runner.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = '$(BSPL_BUNDLE_ID)'
end
# RunnerTests' configurations don't inherit Flutter/*.xcconfig, so a literal.
tests&.build_configurations&.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.nfcarchiver.bananasplit.RunnerTests'
end
(project.build_configurations + project.targets.flat_map(&:build_configurations)).each do |config|
  config.build_settings.delete('DEVELOPMENT_TEAM')
end

# --- 3. deployment target -------------------------------------------------------
(project.build_configurations + project.targets.flat_map(&:build_configurations)).each do |config|
  s = config.build_settings
  next unless project.build_configurations.include?(config) || s.key?('IPHONEOS_DEPLOYMENT_TARGET')

  s['IPHONEOS_DEPLOYMENT_TARGET'] = DEPLOYMENT
end

project.save
puts "configured #{File.join(IOS, 'Runner.xcodeproj')}"
