require 'jekyll/minibundle/asset_bundle'
require 'jekyll/minibundle/asset_file_operations'
require 'jekyll/minibundle/asset_stamp'
require 'jekyll/minibundle/asset_tag_markup'

module Jekyll::Minibundle
  class BundleFile
    include AssetFileOperations

    def self.clear_cache
      @@mtimes = {}
      @@writes_after_rebundling = Hash.new false
      @@asset_bundles = {}
    end

    clear_cache

    def initialize(config)
      @type = config['type']
      @site_source_dir = config['site_dir']
      asset_source_dir = File.join @site_source_dir, config['source_dir']
      @assets = config['assets'].map { |asset_path| File.join asset_source_dir, "#{asset_path}.#{@type}" }
      @destination_path = config['destination_path']
      @attributes = config['attributes']
    end

    def markup
      # we must rebundle here, if at all, in order to make sure the
      # markup and generated file have the same fingerprint
      rebundle_assets if modified?
      AssetTagMarkup.make_markup @type, asset_destination_path, @attributes
    end

    def path
      asset_bundle.path
    end

    def check_no_existing_static_file(static_files)
      existing = @assets & static_files.map(&:path)
      raise "Minibundle cannot handle static file already handled by Jekyll: #{existing.first}" unless existing.empty?
    end

    def asset_destination_path
      "#{@destination_path}-#{asset_stamp}.#{@type}"
    end

    def destination(site_destination_dir)
      File.join site_destination_dir, asset_destination_path
    end

    def mtime
      @assets.map { |f| File.stat(f).mtime.to_i }.max
    end

    def modified?
      @@mtimes[asset_destination_canonical_path] != mtime
    end

    def write(site_destination_dir)
      if File.exists?(destination(site_destination_dir)) && destination_written_after_rebundling?
        false
      else
        write_destination site_destination_dir
        @@writes_after_rebundling[asset_destination_canonical_path] = true
        true
      end
    end

    private

    def asset_destination_canonical_path
      "#{@destination_path}.#{@type}"
    end

    def asset_stamp
      @asset_stamp ||= AssetStamp.from_file path
    end

    def asset_bundle
      @@asset_bundles[asset_destination_canonical_path] ||= AssetBundle.new(@type, @assets, @site_source_dir)
    end

    def rebundle_assets
      p = asset_destination_canonical_path
      @@writes_after_rebundling[p] = false
      @@mtimes[p] = mtime
      @asset_stamp = nil
      asset_bundle.make_bundle
    end

    def destination_written_after_rebundling?
      @@writes_after_rebundling[asset_destination_canonical_path]
    end
  end
end
