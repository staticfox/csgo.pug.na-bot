class HandleBotPug

# Return array method
# Element 1 determins what type of message this is.
# 1 = Channel
# 2 = User privnotice

  def self.ready_to_start(channel)
    channel = $con.escape_string(channel.to_s)
    players = 10
    captains = 2

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
      self.afk_check(channel)
    else
      return [nil, nil, nil, nil] # This is weird, but it's consistantly weird. And that's what counts. Sorta.
    end
  end

  def self.afk_check(channel)
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
         irc_players.nick, current_players.time_added, current_players.captain, irc_players.player_id  
         FROM `current_players` 
         INNER JOIN `irc_players` ON current_players.player_id = irc_players.player_id 
         WHERE current_players.channel = '#{channel}'
         ")

      if data.num_rows > 0 # Subtract from our standard list
        while row = data.fetch_row do
          if Time.new.to_i - row[1].to_i >= 600
            afk_users.push(row[0])
          else
            $con.query("UPDATE `current_players` SET `time_added` = '#{Time.new.to_i}' WHERE `player_id` = '#{row[3]}'") # We do this so we don't have any spam issues with re-checks
          end
        end
      end
      if data.num_rows > 0 # If this is false, then something went horribly wrong...
        if afk_users.empty?
          self.begin_countdown(channel)
        else
          self.warn_players(channel, afk_users)
        end
      end

    elsif Time.new.to_i - afk >= 45 && timeout == 0
      a = Time.new.to_i - 645
      $con.query("DELETE FROM `current_players` WHERE `time_added` <= '#{a}'")
      if self.confirm_start(channel) == 1
        self.begin_countdown(channel)
      else
        $con.query("DELETE FROM `pug_status` WHERE `channel` = '#{channel}'")
        return [channel, 1, "0,1Not enough players after AFK check.", nil]
      end
    elsif timeout > 0
      self.try_captains(channel)
    else
      return [nil, nil, nil, nil]
    end
  end

  def self.confirm_start(channel)
    players = 10
    captains = 2

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
      return 1
    else
      return 0
    end
  end

  def self.warn_players(channel, users)
    $con.query("UPDATE `pug_status` SET `afk_check` = '#{Time.new.to_i}' WHERE `channel` = '#{channel}'")
    return [users, 2, "4,1 [!WARNING!] You are consiered AFK by the bot. Please type something in #{channel} so you are not removed.", channel]
  end

  def self.begin_countdown(channel)
    $con.query("UPDATE `pug_status` SET `timeout_start_at` = '#{Time.new.to_i}', `afk_check` = '0', `locked_out` = '0', `completed` = '0' WHERE `channel` = '#{channel}'")
    return [channel, 1, "0,1Teams are being drafted. Captains will be selected in 45 seconds.", nil]
  end

  def self.try_captains(channel)
    time = 0
    locked = 0
    value = $con.query("SELECT `timeout_start_at`,`locked_out` FROM `pug_status` WHERE `channel` = '#{channel}'")
    while row = value.fetch_row do
      time = row[0].to_i
      locked = row[1].to_i
    end
    if Time.new.to_i - time >= 45 && locked == 0
      if self.confirm_start(channel) == 1
        $con.query("UPDATE `pug_status` SET `locked_out` = '1' WHERE `channel` = '#{channel}'")
        captains = $con.query("SELECT current_players.player_id, irc_players.nick 
          FROM `current_players` 
          INNER JOIN `irc_players` ON current_players.player_id = irc_players.player_id 
          WHERE current_players.captain = '1' AND current_players.channel = '#{channel}' ORDER BY RAND() LIMIT 2;")
        intteam = 1
        captains_array = []
        while row = captains.fetch_row do
          captains_array.push(row[1])
          $con.query("INSERT INTO `teams` (`player_id`,`team_id`,`captain`,`picked_when`) VALUES ('#{row[0]}', '#{intteam}', '1', '#{Time.new.to_i}')")
          intteam += 1
        end
        return [channel, 1, "0,1Captains have been selected: 4,1#{captains_array[0]}0,1 and 11,1#{captains_array[1]}0,1. 4,1#{captains_array[0]}0,1 will go first.", nil]
      else
        return [channel, 1, "0,1Failed to start. Not enough players.", nil]
      end
    else
      return [nil, nil, nil, nil]
    end
  end

  def self.add_server(channel, authname)
  end

  def self.remove_server(channel, authname)
  end

  def self.lock_out_adds(channel)
  end

  def self.find_servers(channel)
  end

end