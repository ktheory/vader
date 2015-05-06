class VaderSync
  require 'rb-fsevent'
  require 'shellwords'

  B2D_ROOT = ENV['VADER_B2D_ROOT'] || "/vader"
  CONFIG_DIR = File.expand_path(ENV['VADER_CONFIG_DIR'] || '~/.vader')
  SYNC_LATENCY = (ENV['VADER_SYNC_LATENCY'] || 0.1).to_f

  # Hash of local paths and boot2docker destination
  attr_reader :watch_paths
  # Array of local paths
  attr_reader :local_watch_paths

  def initialize
    glob = File.join(CONFIG_DIR, '*')

    # A hash of paths to watch and their boot2docker destinations
    # E.g.
    #  { '/Users/alice/Documents/my-project' => '/vader/my-project' }
    @watch_paths = Dir.glob(glob).inject({}) { |hash, config_path|
      b2d_path = File.join(B2D_ROOT, File.basename(config_path))

      begin
        watch_path = File.readlink(config_path)
        hash.merge(watch_path => b2d_path)
      rescue Errno::EINVAL
        hash
      end
    }

    @local_watch_paths = @watch_paths.keys

  end

  def run!
    # Make sure boot2docker is running
    waiting = false
    while `boot2docker status`.chomp != 'running'
      puts "Waiting until boot2docker is running" unless waiting
      waiting = true
      sleep 2
    end

    # Initialize boot2docker for vader
    cmds = [
      'tce-load -wi rsync', # Install rsync
      # Make vader destination and symlink to /vader
      'sudo mkdir -p /mnt/sda1/vader',
      'sudo ln -sf /mnt/sda1/vader /',
      'sudo chown docker:staff /vader'
    ]

    safe_paths = @watch_paths.values.map{|path| Shellwords.shellescape(path)}.join(' ')
    cmds << "mkdir #{safe_paths}" unless safe_paths.empty?
    cmds = cmds.join(' && ')

    puts "Running #{cmds}" if verbose?
    `boot2docker ssh "#{cmds}"`
    unless $?.success?
      puts "Error initalizing boot2docker for vader"
      exit 1
    end

    # Watch for fs changes
    puts "Watching #{local_watch_paths.inspect} + #{CONFIG_DIR}" if verbose?
    fsevent = FSEvent.new
    fsevent.watch local_watch_paths + [CONFIG_DIR], latency: SYNC_LATENCY do |path|
      handle_fs_event(paths)
    end
    fsevent.run
  end

  def handle_fs_event(full_paths)
    # full_paths is potentially large, so try to iterated efficiently
    matched_paths = []
    full_paths.each do |full_path|
      # Skip if we've already mathed this path
      next if matched_paths.any? {|p| full_path.start_with?(p) }

      matched_path = local_watch_paths.detect{|p| full_path.start_with?(p) }
      matched_paths << matched_path  if matched_path

      if full_path == CONFIG_DIR
        puts "Vader config change detected. Restarting"
        exit 0
      end
    end

    matched_paths.each {|path| sync(path) }
  end

  def sync(path)
    puts "Syncing #{path}"
    return 1
    pid = spawn(rsync_cmd)

    Process.wait(pid)
  end

  def verbose?
    ENV['VADER_VERBOSE']
  end
end

if $0 == __FILE__
  VaderSync.new.run!
end
