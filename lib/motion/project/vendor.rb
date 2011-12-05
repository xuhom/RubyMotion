module Motion; module Project;
  class Vendor
    include Rake::DSL if Rake.const_defined?(:DSL)

    def initialize(path, type, config, opts)
      @path = path
      @type = type
      @config = config
      @opts = opts
      @libs = []
      @bs_files = []
    end

    attr_reader :libs, :bs_files

    def build(platform, archs)
      send gen_method('build'), platform, archs, @opts
    end

    def clean
      send gen_method('clean')
    end

    def build_xcode(platform, archs, opts)
      Dir.chdir(@path) do
        build_dir = "build-#{platform}"
        if !File.exist?(build_dir)
          FileUtils.mkdir build_dir

          # Prepare Xcode project settings.
          xcodeproj = opts.delete(:xcodeproj) || begin
            projs = Dir.glob('*.xcodeproj')
            if projs.size != 1
              $stderr.puts "Can't locate Xcode project file for vendor project #{@path}"
              exit 1
            end
            projs[0]
          end
          target = opts.delete(:target) || File.basename(xcodeproj, '.xcodeproj')
          configuration = opts.delete(:configuration) || 'Release'
  
          # Build project into `build' directory. We delete the build directory each time because
          # Xcode is too stupid to be trusted to use the same build directory for different
          # platform builds.
          rm_rf 'build'
          sh "/usr/bin/xcodebuild -target #{target} -configuration #{configuration} -sdk #{platform.downcase}#{@config.sdk_version} #{archs.map { |x| '-arch ' + x }.join(' ')} CONFIGURATION_BUILD_DIR=build build"
  
          # Copy .a files into the platform build directory.
          Dir.glob('build/*.a').each do |lib|
            lib = File.readlink(lib)
            sh "/bin/cp \"#{lib}\" \"#{build_dir}\""      
          end
        end

        @bs_files.clear
        @bs_files.concat(Dir.glob('*.bridgesupport').map { |x| File.expand_path(x) })

        @libs.clear
        @libs.concat(Dir.glob("#{build_dir}/*.a").map { |x| File.expand_path(x) })
      end
    end

    def clean_xcode
      Dir.chdir(@path) do
        rm_rf 'build', 'build-iPhoneOS', 'build-iPhoneSimulator'
      end
    end

    private

    def gen_method(prefix)
      method = "#{prefix}_#{@type.to_s}".intern
      raise "Invalid vendor project type: #{@type}" unless respond_to?(method)
      method
    end
  end
end; end
