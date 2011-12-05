module Motion; module Project
  class Config
    VARS = []

    def self.variable(*syms)
      syms.each do |sym|
        attr_accessor sym
        VARS << sym.to_s
      end
    end

    class Deps < Hash
      def []=(key, val)
        key = relpath(key)
        val = [val] unless val.is_a?(Array)
        val = val.map { |x| relpath(x) }
        super
      end

      def relpath(path)
        /^\./.match(path) ? path : File.join('.', path)
      end
    end

    variable :files, :platforms_dir, :sdk_version, :frameworks,
      :delegate_class, :name, :build_dir, :resources_dir,
      :codesign_certificate, :provisioning_profile, :device_family,
      :interface_orientations, :version, :icons

    def initialize(project_dir)
      @project_dir = project_dir
      @files = Dir.glob(File.join(project_dir, 'app/**/*.rb'))
      @dependencies = {}
      @platforms_dir = '/Developer/Platforms'
      @frameworks = ['UIKit', 'Foundation', 'CoreGraphics']
      @delegate_class = 'AppDelegate'
      @name = 'My App'
      @build_dir = File.join(project_dir, 'build')
      @resources_dir = File.join(project_dir, 'resources')
      @device_family = :iphone
      @bundle_signature = '????'
      @interface_orientations = [:portrait, :landscape_left, :landscape_right]
      @version = '1.0'
      @icons = []
    end

    def variables
      map = {}
      VARS.each do |sym|
        val = send(sym) rescue "ERROR"
        map[sym] = val
      end
      map
    end

    def validate
      # sdk_version
      ['iPhoneSimulator', 'iPhoneOS'].each do |platform|
        sdk_path = File.join(platforms_dir, platform + '.platform',
            "Developer/SDKs/#{platform}#{sdk_version}.sdk")
        unless File.exist?(sdk_path)
          $stderr.puts "Can't locate #{platform} SDK #{sdk_version} at `#{sdk_path}'" 
          exit 1
        end
      end
      unless File.exist?(datadir)
        $stderr.puts "iOS SDK #{sdk_version} is not supported by this version of RubyMotion"
        exit 1
      end
    end

    attr_reader :project_dir

    def project_file
      File.join(@project_dir, 'Rakefile')
    end

    def files_dependencies(deps_hash)
      p = lambda { |x| /^\./.match(x) ? x : File.join('.', x) }
      deps_hash.each do |path, deps|
        deps = [deps] unless deps.is_a?(Array)
        @dependencies[p.call(path)] = deps.map(&p)
      end
    end

    attr_reader :vendor_projects

    def vendor_project(path, type, opts={})
      @vendor_projects ||= []
      @vendor_projects << Motion::Project::Vendor.new(path, type, self, opts)
    end

    def ordered_build_files
      ary = []
      @files.each do |file|
        deps = @dependencies[file]
        if deps
          deps.each do |dep|
            ary << dep unless ary.index(dep)
          end
        end
        ary << file unless ary.index(file)
      end
      ary
    end

    def motiondir
      File.expand_path(File.join(File.dirname(__FILE__), '../../..'))
    end

    def bindir
      File.join(motiondir, 'bin')
    end

    def datadir
      File.join(motiondir, 'data', sdk_version)
    end

    def platform_dir(platform)
      File.join(@platforms_dir, platform + '.platform')
    end

    def sdk_version
      @sdk_version ||= begin
        versions = Dir.glob(File.join(platforms_dir, 'iPhoneOS.platform/Developer/SDKs/iPhoneOS*.sdk')).map do |path|
          File.basename(path).scan(/iPhoneOS(.*)\.sdk/)[0][0]
        end
        if versions.size == 0
          $stderr.puts "Can't find an iOS SDK in `#{platforms_dir}'"
          exit 1
        #elsif versions.size > 1
        #  $stderr.puts "found #{versions.size} SDKs, will use the latest one"
        end
        versions.max
      end
    end

    def sdk(platform)
      File.join(platform_dir(platform), 'Developer/SDKs',
        platform + sdk_version + '.sdk')
    end

    def app_bundle(platform)
      File.join(@build_dir, platform, @name + '.app')
    end

    def archive
      File.join(@build_dir, @name + '.ipa')
    end

    def device_family_ints
      ary = @device_family.is_a?(Array) ? @device_family : [@device_family]
      ary.map do |family|
        case family
          when :iphone then 1
          when :ipad then 2
          else
            $stderr.puts "Unknown device_family value: `#{family}'"
            exit 1
        end
      end
    end

    def interface_orientations_consts
      @interface_orientations.map do |ori|
        case ori
          when :portrait then 'UIInterfaceOrientationPortrait'
          when :landscape_left then 'UIInterfaceOrientationLandscapeLeft'
          when :landscape_right then 'UIInterfaceOrientationLandscapeRight'
          when :portrait_upside_down then 'UIInterfaceOrientationPortraitUpsideDown'
          else
            $stderr.puts "Unknown interface_orientation value: `#{ori}'"
            exit 1
        end
      end
    end

    def plist_data
<<DATA
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>BuildMachineOSBuild</key>
	<string>#{`sw_vers -buildVersion`.strip}</string>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleDisplayName</key>
	<string>#{@name}</string>
	<key>CFBundleExecutable</key>
	<string>#{@name}</string>
	<key>CFBundleIdentifier</key>
	<string>com.omgwtf.#{@name}</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>#{@name}</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleResourceSpecification</key>
	<string>ResourceRules.plist</string>
	<key>CFBundleShortVersionString</key>
	<string>#{@version}</string>
	<key>CFBundleSignature</key>
	<string>#{@bundle_signature}</string>
	<key>CFBundleSupportedPlatforms</key>
	<array>
		<string>iPhoneOS</string>
	</array>
	<key>CFBundleVersion</key>
	<string>#{@version}</string>
	<key>DTCompiler</key>
	<string>com.apple.compilers.llvmgcc42</string>
	<key>DTPlatformBuild</key>
	<string>8H7</string>
	<key>DTPlatformName</key>
	<string>iphoneos</string>
	<key>DTPlatformVersion</key>
	<string>#{sdk_version}</string>
	<key>DTSDKBuild</key>
	<string>8H7</string>
	<key>DTSDKName</key>
	<string>iphoneos#{sdk_version}</string>
	<key>DTXcode</key>
	<string>0402</string>
	<key>DTXcodeBuild</key>
	<string>4A2002a</string>
	<key>LSRequiresIPhoneOS</key>
	<true/>
	<key>MinimumOSVersion</key>
	<string>#{sdk_version}</string>
        <key>CFBundleIconFiles</key>
        <array>
                #{icons.map { |icon| '<string>' + icon + '</string>' }.join('')}
        </array>
	<key>UIDeviceFamily</key>
	<array>
		#{device_family_ints.map { |family| '<integer>' + family.to_s + '</integer>' }.join('')}
	</array>
	<key>UISupportedInterfaceOrientations</key>
	<array>
		#{interface_orientations_consts.map { |ori| '<string>' + ori + '</string>' }.join('')}
	</array>
</dict>
</plist>
DATA
    end

    def pkginfo_data
      "AAPL#{@bundle_signature}"
    end

    def codesign_certificate
      @codesign_certificate ||= begin
        certs = `/usr/bin/security -q find-certificate -a`.scan(/"iPhone Developer: [^"]+"/).uniq
        if certs.size == 0
          $stderr.puts "Can't find an iPhone Developer certificate in the keychain"
          exit 1
        elsif certs.size > 1
          $stderr.puts "Found #{certs.size} iPhone Developer certificates, will use the first one: `#{certs[0]}'"
        end
        certs[0][1..-2] # trim trailing `"` characters
      end 
    end

    def provisioning_profile
      @provisioning_profile ||= begin
        paths = Dir.glob(File.expand_path("~/Library/MobileDevice/Provisioning\ Profiles/*.mobileprovision"))
        if paths.size == 0
          $stderr.puts "Can't find a provisioning profile"
          exit 1
        elsif paths.size > 1
          $stderr.puts "Found #{paths.size} provisioning profiles, will use the first one: `#{paths[0]}'"
        end
        paths[0]
      end
    end
  end
end; end
