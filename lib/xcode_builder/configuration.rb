require 'pathname'
require File.dirname(__FILE__) + '/deployment_strategies'
require File.dirname(__FILE__) + '/release_strategies'

module XcodeBuilder
  class Configuration < OpenStruct
    def release_notes_text
      return release_notes.call if release_notes.is_a? Proc
      release_notes
    end

    def build_arguments
      args = []
      if workspace_file_path
        raise "A scheme is required if building from a workspace" unless scheme
        args << "-workspace '#{workspace_file_path}'"
        args << "-scheme '#{scheme}'"
      else
        args << "-target '#{target}'"
        args << "-project '#{project_file_path}'" if project_file_path
      end

      args << "-sdk #{sdk}"
      
      args << "-configuration '#{configuration}'"
      
      if xcodebuild_extra_args
          args.concat xcodebuild_extra_args if xcodebuild_extra_args.is_a? Array
          args << "#{xcodebuild_extra_args}" if xcodears.is_a? String
      end
      
      args
    end
    
    def app_file_name
      raise ArgumentError, "app_name or target must be set in the BetaBuilder configuration block" if app_name.nil?
      "#{app_name}.#{app_extension}"
    end
    
    def info_plist_path
      if info_plist != nil then 
        File.expand_path info_plist
      else 
        nil
      end
    end

    def build_number
      # no plist is found, return a nil version
      if (info_plist_path == nil)  || (!File.exists? info_plist_path) then
        return nil
      end

      # read the plist and extract data
      plist = CFPropertyList::List.new(:file => info_plist_path)
      data = CFPropertyList.native_types(plist.value)
      data["CFBundleVersion"]
    end

    def next_build_number
      # if we don't have a current version, we don't have a next version :)
      if build_number == nil then
        return nil
      end

      # get a hold on the build number and increment it
      version_components = build_number.split(".")
      new_build_number = version_components.pop.to_i + 1
      version_components.push new_build_number.to_s
      version_components.join "."
    end

    def built_app_long_version_suffix
      if build_number == nil then
        ""
      else 
        "-#{build_number}"
      end
    end

    def ipa_name
      prefix = app_name == nil ? target : app_name
      "#{prefix}#{built_app_long_version_suffix}.ipa"
    end      
    
    def built_app_path
      sdk_extension = if sdk.eql? "macosx" then "" else "-#{sdk}" end
      if build_dir == :derived
        File.join("#{derived_build_dir}", "#{configuration}#{sdk_extension}", "#{app_file_name}")
      else
        File.join("#{build_dir}", "#{configuration}#{sdk_extension}", "#{app_file_name}")
      end
    end
    
    def built_dsym_path
      "#{built_app_path}.dSYM"
    end
    
    def derived_build_dir 
      workspace_name = Pathname.new(workspace_file_path).basename.to_s.split(".")[0]
      for dir in Dir[File.join(File.expand_path("~/Library/Developer/Xcode/DerivedData"), "#{workspace_name}-*")]
        return "#{dir}/Build/Products" if File.read( File.join(dir, "info.plist") ).match workspace_file_path
      end
    end
    
    
    def derived_build_dir_from_build_output
      output = BuildOutputParser.new(File.read("build.output"))
      output.build_output_dir  
    end

    def zipped_package_name
      "#{app_name}#{built_app_long_version_suffix}.zip"
    end

    def ipa_path
      File.join(File.expand_path(package_destination_path), ipa_name)
    end

    def dsym_name
      "#{app_name}#{built_app_long_version_suffix}.dSYM.zip"
    end

    def dsym_path
      File.join(File.expand_path(package_destination_path), dsym_name)
    end

    def app_bundle_path
      "#{package_destination_path}/#{app_name}.#{app_extension}"
    end
    
    def deploy_using(strategy_name, &block)
      if DeploymentStrategies.valid_strategy?(strategy_name.to_sym)
        self.deployment_strategy = DeploymentStrategies.build(strategy_name, self)
        self.deployment_strategy.configure(&block)
      else
        raise "Unknown deployment strategy '#{strategy_name}'."
      end
    end

    def release_using(strategy_name, &block)
      if ReleaseStrategies.valid_strategy?(strategy_name.to_sym)
        self.release_strategy = ReleaseStrategies.build(strategy_name, self)
        self.release_strategy.configure(&block)
        self.release_strategy.prepare
      else
        raise "Unknown release strategy '#{strategy_name}'."
      end
    end
  end
end