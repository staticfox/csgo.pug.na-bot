require_relative 'database'

module IRCHandler

  include DB

  def update_idle uid
    $con.query("UPDATE `current_players` SET `idle_time` = '#{Time.new.to_i}' WHERE `player_id` = '#{uid}'")
  end

  def user_left playerid
    # Now let's see if we are already added
    addcheckq = $con.query("SELECT COUNT(`id`) FROM `current_players` WHERE `player_id` = '#{playerid}'")
    count = 0
    while row = addcheckq.fetch_row do
      count = row[0].to_i
    end

    locked = 0
    is_locked = $con.query("SELECT `locked_out` FROM `pug_status`")
    if is_locked.num_rows > 0
      while row = is_locked.fetch_row do
        locked = row[0].to_i
      end
    end

    unless count == 0 && locked == 0
      $con.query("DELETE FROM `current_players` WHERE `player_id` = '#{playerid}'")
    end
  end

  def nick_change(oldnick, newnick)
    # Since we use player IDs, we only need to change 1 field :]
    $con.query("UPDATE `irc_players` SET `nick` = '#{newnick}' WHERE `nick` = '#{oldnick}'")
  end

  def has_uid nick
    nick = escape nick.to_s
    # Let's get their player ID first.
    pidq = $con.query("SELECT `player_id` FROM `irc_players` WHERE `nick` = '#{nick}' LIMIT 1")

    playerid = 0
    while row = pidq.fetch_row do
      playerid = row[0].to_i
    end
    return playerid
  end

  def get_uid m
    nick = escape m.user.nick.to_s
    pidq = $con.query("SELECT `player_id` FROM `irc_players` WHERE `nick` = '#{nick}' LIMIT 1")
    playerid = 0
    while row = pidq.fetch_row do
      playerid = row[0].to_i
    end

    if playerid == 0
      authname = escape m.user.authname.to_s
      ident = escape m.user.user.to_s
      host = escape m.user.host.to_s
      real = escape m.user.realname.to_s
      $con.query("INSERT INTO `irc_players` (`authname`,`nick`,`ident`,`host`,`gecos`,`last_appearance`) VALUES ('#{authname}', '#{nick}', '#{ident}', '#{host}', '#{real}', '#{Time.new.to_i}')")
      pidq = $con.query("SELECT `player_id` FROM `irc_players` WHERE `nick` = '#{nick}' LIMIT 1")
      playerid = 0
      while row = pidq.fetch_row do
        playerid = row[0].to_i
      end
      if playerid == 0
        self.generate_new_id user # Technically speaking, we shouldn't get caught in a loop.
      else
        return playerid
      end
    else
      return playerid
    end
  end

end