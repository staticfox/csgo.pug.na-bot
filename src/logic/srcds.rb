require 'steam-condenser'

require_relative '../bot'
require_relative '../constants'

module SRCDS

  def get_map channel
    if @map.nil?
      determine_map
    end
    pm(channel, "0,1The current map is #{@map['name'].capitalize}", 1, nil)
  end

  def determine_map
    if @last_maps.nil? # Bot must have restarted, let's introduce new stuff
      @last_maps = []
      @pool = Constants.const['maps']['active_duty']
      @map = @pool.shuffle.first
      @last_maps << @map
      return @map
    else
      @pool = @pool - @last_maps # Time for a new map
      if @pool.empty? # Wow, they went through all those maps. reload!
        @pool = Constants.const['maps']['active_duty']
        @map = @pool.shuffle.first
        @last_maps << @map
        return @map['name']
      else # Pick a map we haven't played yet
        @pool = @pool - @last_maps
        @map = @pool.shuffle.first
        @last_maps << @map
        return @map
      end
    end
  end

    def gen_new_map
    if @last_maps.nil? # Bot must have restarted, let's introduce new stuff
      @last_maps = []
      @pool = Constants.const['maps']['active_duty']
      @map = @pool.shuffle.first
      @last_maps << @map
    else
      @pool = @pool - @last_maps # Time for a new map
      if @pool.empty? # Wow, they went through all those maps. reload!
        @pool = Constants.const['maps']['active_duty']
        @map = @pool.shuffle.first
        @last_maps << @map
      else # Pick a map we haven't played yet
        @pool = @pool - @last_maps
        @map = @pool.shuffle.first
        @last_maps << @map
      end
    end
  end

  def nextmap_logic channel
    gen_new_map
    return pm(channel, "0,1The map is now #{@map['name'].capitalize}", 1, nil)
  end

  # This seems sorta awkward
  def get_map_list channel
    maps = Constants.const['maps']['active_duty']
    t_array = []
    maps.each { |x|
      t_array.push(x['name'].capitalize)
    }
    maps_names = t_array.join(", ")
    pm(channel, "0,1The maps in my config file are #{maps_names}", 1, nil)
  end

  def get_server channel, tried, deadservers
    if @servers.nil?
      @servers = []
      srvrs = Constants.const['servers']
      srvrs.each { |x|
        @servers.push(x)
      }
    end
    if @current_server.nil?
      try_this = @servers.shuffle.first
      server_ip = IPAddr.new(try_this['ip'])
      server = SourceServer.new(server_ip, try_this['port'].to_i)
      begin
        server.rcon_auth(try_this['rcon'])
        cur_stat = server.rcon_exec('status')
        cur_array = []
        cur_stat.each_line do |line|
          case line.split(" ")[0]
          when "hostname:"
            cur_array.push(line.split(" ")[1])
          when "map"
            cur_array.push(line.split(" ")[2])
          when "players"
            s2a = line.split(" ")
            i = 2
            string = ""
            while i < s2a.length.to_i
              if string.empty?
                string = s2a[i]
              else
                string = string + " " + s2a[i]
              end
              i += 1
            end
            cur_array.push(string)
          end
        end
        pm(channel, "0,1Server 7,1#{try_this['name']} (#{cur_array[0]})0,1 is on map 9,1#{cur_array[1]}0,1. Status:8,1 #{cur_array[2]}", 1, nil)
        @current_server = try_this
      rescue => e
        if tried == 1
          pm(channel, "4,1#{try_this['name']} appears to be unreachable. Please contact a channel operator. Trying another server...", 1, nil)
          @dead_servers = []
          @dead_servers << try_this
          @current_server = try_this
          get_server channel, 0, @dead_servers
        else
          pm(channel, "4,1An error has occured connecting to #{try_this['name']} -> #{e}, retrying in 5 seconds...", 1, nil)
          tried = 1
          sleep 5
          get_server channel, tried, @dead_servers
        end
      end
    elsif deadservers
      if deadservers.include? @current_server
        have_any_left = @servers - @dead_servers
        if have_any_left.length.to_i == 0
          pm(channel, "0,1All available servers appear to be broken. Please contact a channel operator. In the mean time, I will assign a random server after drafts then you can figure it out from there", 1, nil)
          @current_server = @servers.shuffle.first
        else
          @servers = @servers - @dead_servers
          @current_server = nil
          get_server channel, 0, @dead_servers
        end
      end
    else
      server_ip = IPAddr.new(@current_server['ip'])
      server = SourceServer.new(server_ip, @current_server['port'].to_i)
      begin
        server.rcon_auth(@current_server['rcon'])
        cur_stat = server.rcon_exec('status')
        cur_array = []
        cur_stat.each_line do |line|
          case line.split(" ")[0]
          when "hostname:"
            cur_array.push(line.split(" ")[1])
          when "map"
            cur_array.push(line.split(" ")[2])
          when "players"
            s2a = line.split(" ")
            i = 2
            string = ""
            while i < s2a.length.to_i
              if string.empty?
                string = s2a[i]
              else
                string = string + " " + s2a[i]
              end
              i += 1
            end
            cur_array.push(string)
          end
        end
        pm(channel, "0,1Server 7,1#{@current_server['name']} (#{cur_array[0]})0,1 is on map9,1 #{cur_array[1]}0,1. Status:8,1 #{cur_array[2]}", 1, nil)
      rescue => e
        if tried == 1
          pm(channel, "4,1#{@current_server['name']} appears to be unreachable. Please contact a channel operator. Trying another server...", 1, nil)
          @dead_servers = []
          @dead_servers << @current_server
          get_server channel, 0, @dead_servers
        else
          pm(channel, "4,1An error has occured connecting to #{@current_server['name']} -> #{e}, retrying in 5 seconds...", 1, nil)
          tried = 1
          sleep 5
          get_server channel, tried, nil
        end
      end
    end
  end

  # If you've ever wondered what a jenga tower in Ruby would look like,
  # here it is.
  def find_not_full_server channel, broke, full, tried
    if @full_servers.nil?
      @full_servers = []
    end
    if @dead_servers.nil?
      @dead_servers = []
    end
    if @servers.nil?
      @servers = []
      srvrs = Constants.const['servers']
      srvrs.each { |x| @servers.push(x) }
    end
    if @current_server.nil? && !@servers.empty?
      try_this = @servers.shuffle.first
      server_ip = IPAddr.new(try_this['ip'])
      server = SourceServer.new(server_ip, try_this['port'].to_i)
      begin
        server.rcon_auth(try_this['rcon'])
        cur_stat = server.rcon_exec('status')
        cur_array = []
        usable = 0
        cur_stat.each_line do |line|
          case line.split(" ")[0]
          when "players"
            s2a = line.split(" ")
            if s2a[0].to_i < 7
              usable = 1
            end
          end
        end
        if usable == 1
          @current_server = try_this
          return @current_server
        else
          @current_server = try_this
          @full_servers << @current_server
          find_not_full_server channel, nil, @full_servers, nil
          end
      rescue => e
        if tried == 1
          pm(channel, "4,1#{try_this['name']} appears to be unreachable. Please contact a channel operator. Trying another server...", 1, nil)
          @dead_servers = []
          @dead_servers << try_this
          @current_server = try_this
          find_not_full_server channel, @dead_servers, nil, nil
        else
          pm(channel, "4,1An error has occured connecting to #{try_this['name']} -> #{e}, retrying in 5 seconds...", 1, nil)
          tried = 1
          sleep 5
          find_not_full_server channel, @dead_servers, nil, 1
        end
      end
    elsif @dead_servers.include? @current_server
      @servers = @servers - @dead_servers
      @current_server = nil
      have_any_left = @servers - @dead_servers
      if have_any_left.length.to_i == 0
        pm(channel, "0,1All available servers appear to be broken. Please contact a channel operator. In the mean time, I will assign a random server after drafts then you can figure it out from there", 1, nil)
        @current_server = @servers.shuffle.first
      else
        @servers = @servers - @dead_servers
        @current_server = nil
        find_not_full_server channel, @dead_servers, nil, nil
      end
    elsif @full_servers.include? @current_server
      @servers = @servers - @full_servers
      @current_server = nil
      find_not_full_server channel, nil, nil, nil
    elsif @servers.empty?
      pm(channel, "0,1All servers appear to be down or in use. Please contact a channel operator. In the mean time, I will assign a random server after drafts then you can figure it out from there", 1, nil)
      return
    else
      server_ip = IPAddr.new(@current_server['ip'])
      server = SourceServer.new(server_ip, @current_server['port'].to_i)
      begin
        server.rcon_auth(@current_server['rcon'])
        cur_stat = server.rcon_exec('status')
        cur_array = []
        usable = 0
        cur_stat.each_line do |line|
          case line.split(" ")[0]
          when "players"
            s2a = line.split(" ")
            if s2a[0].to_i < 7
              usable = 1
            end
          end
        end
        if usable == 1
          return @current_server
        else
          @full_servers << @current_server
          find_not_full_server channel, @full_servers, nil, nil
        end
      rescue => e
        if tried == 1
          pm(channel, "4,1#{@current_server['name']} appears to be unreachable. Please contact a channel operator. Trying another server...", 1, nil)
          @dead_servers = []
          @dead_servers << @current_server
          find_not_full_server channel, @dead_servers, nil, nil
        else
          pm(channel, "4,1An error has occured connecting to #{@current_server['name']} -> #{e}, retrying in 5 seconds...", 1, nil)
          tried = 1
          @dead_servers << @current_server
          sleep 5
          find_not_full_server channel, @dead_servers, nil, tried
        end
      end
    end
  end

  def configure_server channel, serversource
    @full_servers = []
    @dead_servers = []
    @servers = []
    srvrs = Constants.const['servers']
    if serversource.nil?
      srvrs.each { |x|
      if srvrs.length.to_i > 1
        @servers.push(x)
      end
      }
    else
      srvrs.each { |x|
        if srvrs.length.to_i > 1
          unless serversource = x
            @servers.push(x)
          end
        else
          @servers.push(x)
        end
      }
    end

    # Because we care about cycles (that's the excuse!)
    o = [('a'..'z'), ('A'..'Z')].map { |i| i.to_a }.flatten
    p = (0...8).map { o[rand(o.length)] }.join

    if @map.nil?
      gen_new_map
    end

    unless serversource.nil?
      begin
        server_ip = IPAddr.new(serversource['ip'])
        server = SourceServer.new(server_ip, serversource['port'].to_i)
        server.rcon_auth(serversource['rcon'])
        sleep(1)
        server.rcon_exec("sv_password #{p}")
        sleep(1)
        server.rcon_auth(serversource['rcon'])
        sleep(1)
        server.rcon_exec("changelevel #{@map['file']}")
      rescue => e
        puts "An error has occured: #{e} | #{e.backtrace}" # This should debug to IRC
      end
    end

    return p, @map['name']
  end

  def get_status channel
    if @servers.nil?
      @servers = []
      srvrs = Constants.const['servers']
      srvrs.each { |x|
        @servers.push(x)
      }
    end
    @servers.each { |s|
      server_ip = IPAddr.new(s['ip'])
      server = SourceServer.new(server_ip, s['port'].to_i)
      begin
        server.rcon_auth(s['rcon'])
        cur_stat = server.rcon_exec('status')
        cur_array = []
        cur_stat.each_line do |line|
          case line.split(" ")[0]
          when "hostname:"
            cur_array.push(line.split(" ")[1])
          when "map"
            cur_array.push(line.split(" ")[2])
          when "players"
            s2a = line.split(" ")
            i = 2
            string = ""
            while i < s2a.length.to_i
              if string.empty?
                string = s2a[i]
              else
                string = string + " " + s2a[i]
              end
              i += 1
            end
            cur_array.push(string)
          end
        end
        pm(channel, "0,1Server 7,1#{s['name']} (#{cur_array[0]})0,1 is on map 9,1#{cur_array[1]}0,1. Status:8,1  #{cur_array[2]}", 1, nil)
      rescue => e
        pm(channel, "4,1An error has occured connecting to #{s['name']} -> #{e}", 1, nil)
      end
    }
  end

  def pm target, message, chan, notice
    if chan
      if notice
        BotManager.cnot(target, message)
        sleep 0.5
      else
        BotManager.cmsg(target, message)
        sleep 0.5
      end
    else
      if notice
        BotManager.unot(target, message)
        sleep 0.5
      else
        BotManager.umsg(target, message)
        sleep 0.5
      end
    end
  end

end