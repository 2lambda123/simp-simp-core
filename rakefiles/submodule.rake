#!/usr/bin/rake -T
namespace :submodule do

  include Simp::Rake
  include FileUtils

  desc "Run bundle in every submodule (in gitmodules)"
  task :bundle, :verbose do |t, args|
    verbose = args[:verbose] || false
    # http://stackoverflow.com/questions/13262608/bundle-package-fails-when-run-inside-rake-task
    system %q(/usr/bin/env RUBYOPT= bundle package)

    # Grab all currently tracked submodules.
    $modules = (Simp::Git.submodules_in_gitmodules.keys).sort.uniq.unshift('.')

    basedir = pwd()
    failed_mods = Parallel.map(
      $modules,
      :in_processes => 1,
      :progress => t.name
    ) do |mod|

      success = true
      moddir = basedir +  "/#{mod}"
      next if not File.exists? "#{moddir}/Gemfile"
      puts "\n#{mod}\n" if verbose
      FileUtils.cd(moddir)

      # Any ruby code that opens a subshell will automatically use the current Bundler environment.
      # Clean env will give bundler the environment present before Bundler is activated.
      Bundler.with_clean_env do
        out = %x(bundle)
        success = $?.success?
        puts out if verbose
      end
      mod if not success
    end

    failed_mods.compact!
    warn "The following modules failed bundle: #{failed_mods}"
  end
end
