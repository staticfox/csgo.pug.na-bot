require 'date'

require_relative '../bot'
require_relative '../constants'
require_relative 'srcds'

module PugLogic

  include Const
  include SRCDS

  def quit_bot
    BotManager.quit
  end

  def get_list channel
    full_list = ""

    # Because relational tables are nice, we only need to
    # keep track of the player id from the main table. Other
    # then that, everything else is pretty much good to go.
    # Just a few joins, and we have our data with minimal
    # information required.
    data = $con.query("SELECT 
       irc_players.nick, current_players.idle_time, current_players.captain 
       FROM `current_players` 
       INNER JOIN `irc_players` ON current_players.player_id = irc_players.player_id 
       WHERE current_players.channel = '#{channel}'
       ")
    if data.num_rows > 0 # We have players! List them
      while row = data.fetch_row do
        is_captain = ""
        is_captain = "7,1[C]0,1" unless row[2].to_i == 0 # Give captains a fancy [C] to signify that they are a captain
        if full_list.empty?
          full_list = "0,1[Current Players]: " + row[0].to_s + is_captain + ", "
        else
          full_list = full_list + row[0].to_s + is_captain + ", "
        end
      end
      pm(channel, full_list[0...-2] + ".", 1, nil) # Trim it to make it look pretty
    else
      pm(channel, "0,1No players added, currently.", 1, nil) # No players :(
    end
  end

  def add_logic channel, playerid, nick, possible_capt, locked
    if locked == 0
      captain = 0
      if possible_capt
        posar = possible_capt.split(" ")
        if posar.include?("captain")
          captain = 1
        end
      end

      # Now let's see if we are already added
      addcheckq = $con.query("SELECT COUNT(`id`) FROM `current_players` WHERE `player_id` = '#{playerid}' AND `channel` = '#{channel}'")
      count = 0
      while row = addcheckq.fetch_row do
        count = row[0].to_i
      end

      if count == 0
        # We haven't added yet, so make a fresh entry
        $con.query("INSERT INTO `current_players` (`player_id`,`channel`,`captain`,`idle_time`) VALUES ('#{playerid}', '#{channel}', '#{captain}', '#{Time.new.to_i}')")
        get_list channel
      else
        # We are already listed, so go ahead and update our status.
        $con.query("UPDATE `current_players` SET `captain` = '#{captain}', `idle_time` = '#{Time.new.to_i}' WHERE `player_id` = '#{playerid}'")
        get_list channel
      end
    else
      pm(channel, "0,1Drafts are currently taking place.", 1, nil)
    end
  end

  def locked_logic channel
    locked = 0
    is_locked = $con.query("SELECT `locked_out` FROM `pug_status` WHERE `channel` = '#{channel}'")
    if is_locked.num_rows > 0
      while row = is_locked.fetch_row do
        locked = row[0].to_i
      end
    end
    return locked
  end

  def reward_logic playerid, channel, nick
    find_stats = $con.query("SELECT `times_played`,`times_captained` FROM `player_stats` WHERE `player_id` = '#{playerid}'")
    if find_stats.num_rows > 0
      total = percentage = captain = 0
      while row = find_stats.fetch_row do
        total = row[0].to_i
        captain = row[1].to_i
      end
      if total > Constants.const['bot']['games_for_reward'].to_i
        percentage = (((captain.to_f/total.to_f))*100)
        if percentage >= Constants.const['bot']['captain_percentage'].to_i
          BotManager.voiceuser channel, nick
        end
      end
    end
  end

  def get_stats ouruid, ournick, theirplayer, channel
    if theirplayer
      nick = $con.escape_string(theirplayer)
      pidq = $con.query("SELECT `player_id` FROM `irc_players` WHERE `nick` = '#{nick}' LIMIT 1")
      theirid = 0
      while row = pidq.fetch_row do
        theirid = row[0].to_i
      end
      if theirid != 0
        has_stats = $con.query("SELECT `times_played`,`times_captained` FROM `player_stats` WHERE `player_id` = '#{theirid}'")
        if has_stats.num_rows > 0
          total = captain = percentage = 0
          while row = has_stats.fetch_row do
            total = row[0].to_i
            captain = row[1].to_i
          end
          percentage = (((captain.to_f/total.to_f))*100)
          return pm(channel, "0,1 #{nick} has played #{total} game(s) and has captained #{captain} time(s). (#{percentage}% captain ratio)", 1, nil)
        else
          return pm(channel, "0,1 #{nick} has not played any games.", 1, nil)
        end
      else
        return pm(channel, "0,1 Could not find a player named #{nick}.", 1, nil)
      end
    else
      find_stats = $con.query("SELECT `times_played`,`times_captained` FROM `player_stats` WHERE `player_id` = '#{ouruid}'")
      if find_stats.num_rows > 0
        total = captain = percentage = 0
        while row = find_stats.fetch_row do
          total = row[0].to_i
          captain = row[1].to_i
        end
        percentage = (((captain.to_f/total.to_f))*100)
        return pm(channel, "0,1 #{ournick} has played #{total} game(s) and has captained #{captain} time(s). (#{percentage}% captain ratio)", 1, nil)
      else
        return pm(channel, "0,1 #{nournickick} has not played any games.", 1, nil)
      end
    end
  end

  def reward_manual playerid, channel, nick
    find_stats = $con.query("SELECT `times_played`,`times_captained` FROM `player_stats` WHERE `player_id` = '#{playerid}'")
    if find_stats.num_rows > 0
      total = percentage = captain = 0
      while row = find_stats.fetch_row do
        total = row[0].to_i
        captain = row[1].to_i
      end
      if total >= Constants.const['bot']['games_for_reward'].to_i
        percentage = (((captain.to_f/total.to_f))*100)
        if percentage >= Constants.const['bot']['captain_percentage'].to_i
          BotManager.voiceuser channel, nick
        else
          return pm(channel, "0,1You must have a #{Constants.const['bot']['captain_percentage']}% captain ratio to receive voice (You have a #{percentage}% ratio)", 1, nil)
        end
      else
        return pm(channel, "0,1You must have at least #{Constants.const['bot']['games_for_reward']} games to qualify for voice", 1, nil)
      end
    end
  end

  def remove_logic playerid, channel, locked
    # Now let's see if we are already added
    addcheckq = $con.query("SELECT COUNT(`id`) FROM `current_players` WHERE `player_id` = '#{playerid}' AND `channel` = '#{channel}'")
    count = 0
    while row = addcheckq.fetch_row do
      count = row[0].to_i
    end
    if locked == 0 && count > 0
      $con.query("DELETE FROM `current_players` WHERE `player_id` = '#{playerid}' AND `channel` = '#{channel}'")
      get_list channel
    end
  end

  def get_captain channel, playerid, nick
    is_captainq = $con.query("SELECT `team_id` FROM `teams` WHERE `player_id` = '#{playerid}' AND `captain` = '1' AND `channel` = '#{channel}'")
    is_capt = is_captainq.num_rows
    whos_picking = $con.query("SELECT `team_id` FROM `teams` WHERE `channel` = '#{channel}' ORDER BY `pick_id` DESC LIMIT 1;")
    team_to_pick = 0
    while row = whos_picking.fetch_row do
      team_to_pick = row[0].to_i
    end
    if team_to_pick == 2
      team_to_pick = 1
    elsif team_to_pick == 1
      team_to_pick = 2
    end
    get_name_query = $con.query("SELECT irc_players.nick, teams.team_id FROM irc_players INNER JOIN teams ON teams.player_id = irc_players.player_id WHERE teams.team_id = '#{team_to_pick}' AND teams.captain = '1' LIMIT 1")
    the_name = ""
    while row = get_name_query.fetch_row do
      the_name = row[0].to_s
      tid = row[1].to_i
    end
    if tid == 1
      color = "4,1"
    else
      color = "11,1"
    end
    pm(channel, "0,1It is #{color}#{the_name}'s0,1 turn to pick.", 1, nil)
    if is_capt == 1
      pm(nick, "Added players to choose from: #{fetch_players channel}", nil, nil)
    end
  end

  def pick_logic channel, playerid, pick, locked
    if locked == 0
      return pm(channel, "0,1There are no team drafts in process.", 1, nil)
    end
    is_captainq = $con.query("SELECT `team_id` FROM `teams` WHERE `player_id` = '#{playerid}' AND `captain` = '1' AND `channel` = '#{channel}'")
    is_capt = is_captainq.num_rows

    # Make sure they're even a captain
    if is_capt == 0
      return pm(channel, "0,1You must be a captain to use this command", 1, nil)
    else

      # See if we can pick
      our_turn = $con.query("SELECT `team_id` FROM `teams` WHERE `channel` = '#{channel}' ORDER BY `pick_id` DESC LIMIT 1;")
      team_to_pick = 0
      while row = our_turn.fetch_row do
        team_to_pick = row[0].to_i
      end

      # Since we are picking 1 after the other, 
      # we will want our team id to be NOT the last one,
      # but the other one.
      if team_to_pick == 2
        team_to_pick = 1
      elsif team_to_pick == 1
        team_to_pick = 2
      else
        return pm(channel, "Unable to find who's picking!", 1, nil)
      end

      team_1_color = "4,1"
      team_2_color = "11,1"

      # Now get our own team
      our_team = 0
      while row = is_captainq.fetch_row do
        our_team = row[0].to_i
      end

      if our_team != team_to_pick
        return pm(channel, "0,1It's not your turn to pick.", 1, nil)
      else

        # Find the UID of our target
        pick = $con.escape_string(pick)
        find_pick_uid_query = $con.query("SELECT player_id FROM irc_players WHERE `nick` = '#{pick}'")
        if find_pick_uid_query.num_rows > 0
          pick_id = 0
          while row = find_pick_uid_query.fetch_row do
            pick_id = row[0].to_i
          end

          is_added = $con.query("SELECT `player_id`,`captain` FROM `teams` WHERE `player_id` = '#{pick_id}' AND `channel` = '#{channel}'")

          # Way too much effort for "Unavailable"
          if is_added.num_rows > 0
            is_cpt = is_self = 0
            while row = is_added.fetch_row do
              is_self = row[0].to_i
              is_cpt = row[1].to_i
            end
            if playerid == is_self
              pm(channel, "0,1You can't pick yourself!", 1, nil)
            elsif is_cpt == 1
                pm(channel, "0,1You can't pick the other captain!", 1, nil)
            else
              pm(channel, "0,1That player has already been picked.", 1, nil)
            end

          # This is where we figure out the nitty gritty.  
          else
            # Is this person added?
            is_added_to_pug = $con.query("SELECT `player_id` FROM `current_players` WHERE `player_id` = '#{pick_id}'")
            if is_added_to_pug.num_rows == 0
              pm(channel, "0,1#{pick} is not added to the pug.", 1, nil)
            else
              # OK, they are added to the pug. Take them.
              $con.query("INSERT INTO `teams` (`player_id`,`team_id`,`captain`,`channel`,`picked_when`) VALUES ('#{pick_id}', '#{our_team}', '0', '#{channel}', '#{Time.new.to_i}')")
              $con.query("DELETE FROM `current_players` WHERE `player_id` = '#{pick_id}' AND `channel` = '#{channel}'")
              # Figure out who the other captain is
              oth_cpt_q = $con.query("SELECT irc_players.nick FROM `irc_players` INNER JOIN `teams` ON irc_players.player_id = teams.player_id WHERE teams.player_id != '#{playerid}' AND teams.captain = '1' AND teams.channel = '#{channel}' LIMIT 1;")
              our_name_q = $con.query("SELECT irc_players.nick FROM `irc_players` INNER JOIN `teams` ON irc_players.player_id = teams.player_id WHERE teams.player_id = '#{playerid}' AND teams.captain = '1' AND teams.channel = '#{channel}' LIMIT 1;")
              other_captain = ""
              our_captain_name = ""
              while row = oth_cpt_q.fetch_row do
                other_captain = row[0].to_s
              end
              while row = our_name_q.fetch_row do
                our_captain_name = row[0].to_s
              end
              if our_team == 1
                pm(channel, "0,1#{team_1_color}#{our_captain_name}0,1 has picked #{team_1_color}#{pick}0,1 for their team. #{team_2_color}#{other_captain}0,1 now picks.", 1, nil)
              else
                pm(channel, "0,1#{team_2_color}#{our_captain_name}0,1 has picked #{team_2_color}#{pick}0,1 for their team. #{team_1_color}#{other_captain}0,1 now picks.", 1, nil)
              end
              if pick_count(channel) == 10
                puts "START HERE YES?? #{pick_count(channel)}"
                pm(channel, "0,1Configuring server...", 1, nil)
                start_game channel
              else
                puts "Its not time yet: #{pick_count(channel)}"
                pm(other_captain, "It's your turn to pick! Added players to choose from: #{fetch_players channel}", nil, nil)
              end
            end
          end
        else
          pm(channel, "0,1Sorry, I cannot find a player with that nick. Please use tabcomplete to search for nicks.", 1, nil)
        end
      end
    end
  end

  def start_game channel
    puts "starting game!!!"
    server = find_not_full_server channel, nil, nil, nil
    puts "server is #{server}"
    game_info = configure_server channel, server
    password = game_info[0]
    map_info = game_info[1]
    team_a_array = []
    team_b_array = []
    team_a_id = []
    team_b_id = []
    # This could be condensed with some ordering and shifting
    team_query = $con.query("SELECT irc_players.nick, teams.captain, teams.player_id 
      FROM irc_players 
      INNER JOIN teams ON teams.player_id = irc_players.player_id 
      ORDER BY teams.team_id ASC, teams.pick_id ASC")
    int = 1
    while row = team_query.fetch_row do
      if int < 6
        if row[1].to_i == 1
          team_a_array.unshift(row[0])
          team_a_id.unshift(row[2])
        else
          team_a_array.push(row[0])
          team_a_id.push(row[2])
        end
      else
        if row[1].to_i == 1
          team_b_array.unshift(row[0])
          team_b_id.unshift(row[2])
        else
          team_b_array.push(row[0])
          team_b_id.push(row[2])
        end
      end
      int += 1
    end
    # This is awkward. I don't like it at all.
    full_teams = team_a_id + team_b_id
    team_string = ""
    full_teams.each { |x|
      if team_string.empty?
        team_string = "'" + x + "', "
      else
        team_string = team_string + " '" + x + "', "
      end
    }
    $con.query("INSERT INTO `history` (`leader_1`,`player_2`,`player_3`,`player_4`,`player_5`,`leader_6`,`player_7`,`player_8`,`player_9`,`player_10`,`map`,`server`,`duration`,`who_won`,`date_started`) VALUES (#{team_string} '#{map_info}', '#{$con.escape_string(server['name'])}', NULL, NULL, '#{Time.new.to_i}')")
    c_players = $con.query("SELECT teams.player_id, teams.team_id, teams.captain, irc_players.nick 
      FROM `teams` 
      INNER JOIN irc_players ON teams.player_id = irc_players.player_id 
      WHERE `channel` = '#{channel}' ORDER BY teams.pick_id ASC")
    while row = c_players.fetch_row do
      has_stats = $con.query("SELECT `player_id` FROM `player_stats` WHERE `player_id` = '#{row[0]}'")
      if has_stats.num_rows > 0
        $con.query("UPDATE `player_stats` SET `times_captained` = `times_captained` + '#{row[2].to_i}', `times_played` = `times_played` + '1' WHERE `player_id` = '#{row[0].to_i}'")
      else
        $con.query("INSERT INTO `player_stats` (`player_id`,`times_captained`,`times_played`,`wins`,`loses`) VALUES ('#{row[0].to_i}', '#{row[2].to_i}', '1', '0', '0')")
      end
      team_leader = $con.query("SELECT irc_players.nick FROM irc_players INNER JOIN teams ON irc_players.player_id = teams.player_id WHERE teams.captain = '1' AND teams.team_id = '#{row[1]}'")
      leader_name = ""
      while ldr = team_leader.fetch_row do
        leader_name = ldr[0]
      end
      unless row[3].to_s.include? "playerbotdebug"
        team_type = ""
        if team_a_array.include? row[3]
          team_type = "terrorists"
        else
          team_type = "counter-terrorists"
        end
        if server.nil?
          pm(row[3], "You have been picked on #{leader_name}'s team. You will be starting off as #{team_type} on map #{map_info}. I could not find an available server, so you will need to figure it out in mumble. :(", nil, nil)
        else
          pm(row[3], "You have been picked on #{leader_name}'s team. You will be starting off as #{team_type} on map #{map_info}. Server information: connect #{server['ip']}:#{server['port']}; password #{password}", nil, nil)
        end
      end
    end
    $con.query("TRUNCATE TABLE `teams`")
    $con.query("TRUNCATE TABLE `pug_status`")
    pm(channel, "0,1Final teams for this PUG:", 1, nil)
    pm(channel, "4,1Terrorists: #{team_a_array.join(", ")}", 1, nil)
    pm(channel, "11,1Counter-Terrorists: #{team_b_array.join(", ")}", 1, nil)
    pm(channel, "0,1The pug will take place on #{server['name']} with map #{map_info.capitalize}", 1, nil)
    if Constants.const['sponsor']['name']
      pm(channel, "9,1Servers are provided by 9,1#{Constants.const['sponsor']['name']}0,1. 7,1Visit their website at #{Constants.const['sponsor']['url']}", 1, nil)
    end
    gen_new_map
    puts "It should start here!"
  end

  def need_logic channel, locked
    if locked == 0
      players = Constants.const['pug']['players_required'].to_i
      captains = Constants.const['pug']['captains_required'].to_i

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
      pm(channel, "0,1[Need]: #{players} players and #{captains} captains.", 1, nil)
    else
      pm(channel, "0,1Drafts are currently going on.", 1, nil)
    end
  end

  def last_logic channel
    data = $con.query("SELECT `date_started` FROM `history` ORDER BY `match_id` DESC LIMIT 1")
    if data.num_rows == 0
      pm(channel, "0,1A match has yet to be started.", 1, nil)
    else
      dt = 0
      while row = data.fetch_row do
        dt = row[0].to_i
      end
      formated = DateTime.strptime(dt.to_s, '%s')
      pm(channel, "0,1The last match was started at #{formated}", 1, nil)
    end
  end

  def fetch_players channel
    data = $con.query("SELECT irc_players.nick 
      FROM irc_players 
      INNER JOIN current_players 
      ON irc_players.player_id = current_players.player_id 
      WHERE current_players.channel = '#{channel}'")
    string = ""
    while row = data.fetch_row do
      if string.empty?
        string = row[0] + ", "
      else
        string = string + row[0] + ", "
      end
    end
    string = string[0...-2] + "."
    return string
  end

  def pick_count channel
    data = $con.query("SELECT COUNT(*) 
      FROM `teams` 
      WHERE `channel` = '#{channel}'")
    int = 0
    while row = data.fetch_row do
      int = row[0].to_i
    end
    return int
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