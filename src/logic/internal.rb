require_relative '../bot'
require_relative '../constants'

module InteralCalc

  def ready_to_start channel, afk_timeout, start_timeout, players, captains, idle_time
    data = $con.query("SELECT
       current_players.captain 
       FROM `current_players` 
       WHERE current_players.channel = '#{channel}'
       ")

    if data.num_rows > 0 # Subtract from our standard list
      while row = data.fetch_row do
        if row[0].to_i == 1
          captains -= 1
        end
        players -= 1
      end
      players = 0 if players < 0 # Don't give then a negative value
      captains = 0 if captains < 0
    end

    if players == 0 && captains == 0
      afk_check channel, afk_timeout, start_timeout, idle_time
    end
  end

  def afk_check channel, afk_timeout, start_timeout, idle_time
    channel = $con.escape_string(channel.to_s)
    init = $con.query("SELECT `timeout_start_at`,`afk_check` FROM `pug_status` WHERE `channel` = '#{channel}'")
    timeout = nil
    afk = nil
    cont = 0
    # Let's see if we already have a status
    # in progress.
    if init.num_rows > 0
      while row = init.fetch_row do
        timeout = row[0].to_i
        afk = row[1].to_i
      end
    else
      cont = 1
      $con.query("INSERT INTO `pug_status` (`channel`,`afk_check`,`timeout_start_at`,`locked_out`,`completed`) VALUES ('#{channel}', '#{Time.new.to_i}', '0', '0', '0')")
    end

    if cont == 1
      afk_users = []

      data = $con.query("SELECT
         irc_players.nick, current_players.idle_time, current_players.captain, irc_players.player_id  
         FROM `current_players` 
         INNER JOIN `irc_players` ON current_players.player_id = irc_players.player_id 
         WHERE current_players.channel = '#{channel}'
         ")

      if data.num_rows > 0 # Subtract from our standard list
        while row = data.fetch_row do
          if Time.new.to_i - row[1].to_i >= idle_time
            afk_users.push(row[0])
          else
            $con.query("UPDATE `current_players` SET `idle_time` = '#{Time.new.to_i}' WHERE `player_id` = '#{row[3]}'") # We do this so we don't have any spam issues with re-checks
          end
        end
      end

      if data.num_rows > 0 # If this is false, then something went horribly wrong...
        if afk_users.empty?
          begin_countdown channel, start_timeout
        else
          warn_players channel, afk_users, afk_timeout, start_timeout, idle_time
        end
      end

    elsif Time.new.to_i - afk >= afk_timeout && timeout == 0
      a = Time.new.to_i - idle_time + afk_timeout
      $con.query("DELETE FROM `current_players` WHERE `idle_time` <= '#{a}'")
      if confirm_start(channel) == 1
        begin_countdown channel, start_timeout
      else
        $con.query("DELETE FROM `pug_status` WHERE `channel` = '#{channel}'")
        pm(channel, "0,1Not enough players after AFK check.", 1, nil)
      end
    elsif timeout > 0
      try_captains channel, start_timeout
    end
  end

  def confirm_start channel
    players = Constants.const['pug']['players_required'].to_i
    captains = Constants.const['pug']['captains_required'].to_i
    data = $con.query("SELECT `captain`,`player_id` 
       FROM `current_players` 
       WHERE `channel` = '#{channel}'
       ")

    if data.num_rows > 0 # Subtract from our standard list
      while row = data.fetch_row do
        if row[0].to_i == 1
          captains -= 1
        end
        players -= 1
      end
      players = 0 if players < 0 # Don't give then a negative value
      captains = 0 if captains < 0
    end

    if players == 0 && captains == 0
      return 1
    else
      return 0
    end
  end

  def warn_players channel, afk_users, afk_timeout, start_timeout, idle_time
    $con.query("UPDATE `pug_status` SET `afk_check` = '#{Time.new.to_i}' WHERE `channel` = '#{channel}'")
    string = afk_users.join(", ")
    if afk_users.count > 1
      pm(channel, "8,1[!WARNING!]0,1 #{string} are considered AFK by the bot. If they do not show activity within the next #{afk_timeout} seconds, then they will be removed.", 1, nil)
    else
      pm(channel, "8,1[!WARNING!]0,1 #{string} is considered AFK by the bot. If they do not show activity within the next #{afk_timeout} seconds, then they will be removed.", 1, nil)
    end
    afk_users.each { |u| pm(u, "4,1[!WARNING!] You are considered AFK by the bot. Please type something in #{channel} so you are not removed.", nil, nil) }
    sleep afk_timeout + 3
    afk_check channel, afk_timeout, start_timeout, idle_time
  end

  def begin_countdown channel, start_timeout
    $con.query("UPDATE `pug_status` SET `timeout_start_at` = '#{Time.new.to_i}', `afk_check` = '0', `locked_out` = '0', `completed` = '0' WHERE `channel` = '#{channel}'")
    pm(channel, "0,1Teams are being drafted. Captains will be selected in #{start_timeout} seconds.", 1, nil)
    sleep start_timeout + 3
    try_captains channel, start_timeout
  end

  def try_captains channel, start_timeout
    time = 0
    locked = 0
    value = $con.query("SELECT `timeout_start_at`,`locked_out` FROM `pug_status` WHERE `channel` = '#{channel}'")
    while row = value.fetch_row do
      time = row[0].to_i
      locked = row[1].to_i
    end
    if Time.new.to_i - time >= start_timeout && locked == 0
      if confirm_start(channel) == 1
        $con.query("UPDATE `pug_status` SET `locked_out` = '1' WHERE `channel` = '#{channel}'")
        captains = $con.query("SELECT current_players.player_id, irc_players.nick 
          FROM `current_players` 
          INNER JOIN `irc_players` ON current_players.player_id = irc_players.player_id 
          WHERE current_players.captain = '1' AND current_players.channel = '#{channel}' ORDER BY RAND() LIMIT 2;")
        intteam = 1
        captains_array = []
        while row = captains.fetch_row do
          captains_array.push(row[1])
          $con.query("INSERT INTO `teams` (`player_id`,`team_id`,`captain`,`channel`,`picked_when`) VALUES ('#{row[0]}', '#{intteam}', '1', '#{channel}', '#{Time.new.to_i}')")
          $con.query("DELETE FROM `current_players` WHERE `player_id` = '#{row[0]}'")
          intteam += 1
        end
        pm(channel, "0,1Captains have been selected: 4,1#{captains_array[0]}0,1 and 11,1#{captains_array[1]}0,1. 4,1#{captains_array[0]}0,1 will go first.", 1, nil)
        pm(captains_array[0], "Added players to choose from: #{fetch_players channel}", nil, nil)
      else
        pm(channel, "0,1Failed to start. Not enough players.", 1, nil)
      end
    end
  end

  def fetch_players channel
    data = $con.query("SELECT irc_players.nick 
      FROM irc_players 
      INNER JOIN current_players 
      ON irc_players.player_id = current_players.playerid 
      WHERE current_players = '#{channel}'")
    string = ""
    while row = data.fetch_row do
      if string.empty?
        string = row[0] + ", "
      else
        string = string + ", "
      end
    end
    string = string[0...-2] + "."
    return string
  end

  def pm target, message, chan, notice
    if chan
      if notice
        BotManager.cnot(target, message)
      else
        BotManager.cmsg(target, message)
      end
    else
      if notice
        BotManager.unot(target, message)
      else
        BotManager.umsg(target, message)
      end
    end
  end

  def add_server channel, authname
  end

  def remove_server channel, authname
  end

  def lock_out_adds channel
  end

  def find_servers channel
  end

end