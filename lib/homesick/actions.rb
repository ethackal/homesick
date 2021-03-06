class Homesick
  module Actions
    # TODO move this to be more like thor's template, empty_directory, etc
    def git_clone(repo, config = {})
      config ||= {}
      destination = config[:destination] || begin
        repo =~ /([^\/]+)\.git$/
       $1
      end

      destination = Pathname.new(destination) unless destination.kind_of?(Pathname)
      FileUtils.mkdir_p destination.dirname

      if ! destination.directory?
        say_status 'git clone', "#{repo} to #{destination.expand_path}", :green unless options[:quiet]
        system "git clone -q #{repo} #{destination}" unless options[:pretend]
      else
        say_status :exist, destination.expand_path, :blue unless options[:quiet]
      end
    end

    def git_init(path = ".")
      path = Pathname.new(path)

      inside path do
        unless path.join('.git').exist?
          say_status 'git init', '' unless options[:quiet]
          system "git init >/dev/null" unless options[:pretend]
        else
          say_status 'git init', 'already initialized', :blue unless options[:quiet]
        end
      end
    end

    def git_remote_add(name, url)
      existing_remote = `git config remote.#{name}.url`.chomp
      existing_remote = nil if existing_remote == ''

      unless existing_remote
        say_status 'git remote', "add #{name} #{url}" unless options[:quiet]
        system "git remote add #{name} #{url}" unless options[:pretend]
      else
        say_status 'git remote', "#{name} already exists", :blue unless options[:quiet]
      end
    end

    def git_submodule_init(config = {})
      say_status 'git submodule', 'init', :green unless options[:quiet]
      system "git submodule --quiet init" unless options[:pretend]
    end

    def git_submodule_update(config = {})
      say_status 'git submodule', 'update', :green unless options[:quiet]
      system "git submodule --quiet update >/dev/null 2>&1" unless options[:pretend]
    end

    def git_pull(config = {})
      say_status 'git pull', '', :green unless options[:quiet]
      system "git pull --quiet" unless options[:pretend]
    end

    def mv(source, destination, config = {})
      source = Pathname.new(source)
      destination = Pathname.new(destination + source.basename)

      if destination.exist?
        say_status :conflict, "#{destination} exists", :red unless options[:quiet]

        if options[:force] || shell.file_collision(destination) { source }
          system "mv #{source} #{destination}" unless options[:pretend]
        end
      else
        # this needs some sort of message here.
        system "mv #{source} #{destination}" unless options[:pretend]
      end
    end

    def ln_s(source, destination, config = {})
      source = Pathname.new(source)
      destination = Pathname.new(destination)
      recurse = false
      
      if destination.symlink?
        if destination.readlink == source
          say_status :identical, destination.expand_path, :blue unless options[:quiet]
        else
          say_status :conflict, "#{destination} exists and points to #{destination.readlink}", :red unless options[:quiet]

          if options[:force] || shell.file_collision(destination) { source }
            system "ln -sf #{source} #{destination}" unless options[:pretend]
          end
        end
      elsif destination.exist?
        if destination.directory? && source.directory? && options[:overlay]
          say_status :overlaying, "#{destination} exists, overlaying directory contents", :blue unless options[:quiet]
          recurse = true
        else
          say_status :conflict, "#{destination} exists", :red unless options[:quiet]
          if options[:force] || shell.file_collision(destination) { source }
            if source.directory? && options[:overlay]
              system "rm -rf #{destination}" unless options[:pretend]
              system "mkdir #{destination}" unless options[:pretend]
              recurse = true
            else
              system "ln -sf #{source} #{destination}" unless options[:pretend]
            end
          end
        end
      else
        if source.directory?
          system "mkdir #{destination}" unless options[:pretend]
          recurse = true
        else
          system "ln -s #{source} #{destination}" unless options[:pretend]
        end
      end

      if recurse && options[:overlay]
        files = Pathname.glob([source+"*", source+".*"]).reject{|a| [".",".."].include?(a.split.last.to_s)}
        files.each do |path|
          self.ln_s path.expand_path, destination.expand_path + path.split.last
        end  
      end
    end
  end
end
