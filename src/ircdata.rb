class HandleIRCData

  def self.update_on_join(nick, user, host, realname, authname)
    # Maybe an argument iteration would be nice
    nick = $con.escape_string(nick)
    user = $con.escape_string(user)
    host = $con.escape_string(host)
    realname = $con.escape_string(realname)
    authname = $con.escape_string(authname)

    find_account = $con.query("SELECT COUNT(`player_id`) FROM `irc_players` WHERE `authname` = '#{authname}'")

    value = 0
    while row = find_account.fetch_row do
      value = row[0].to_i
    end

    if value.to_i == 0
      # They arent authed, lets look for a relevent host mask
      find_host = $con.query("SELECT COUNT(`player_id`) FROM `irc_players` WHERE `host` = '#{host}'")
      nval = 0

      while row = find_host.fetch_row do
        nval = row[0].to_i
      end

      if nval.to_i == 0
        # Still nothing? Oh well, create them a new DB entry. We can merge later.
        if authname == "0"
          $con.query("INSERT INTO `irc_players` (`nick`,`ident`,`host`,`gecos`,`last_appearance`) VALUES ('#{nick}', '#{user}', '#{host}', '#{realname}', '#{Time.new.to_i}')")
        else
          $con.query("INSERT INTO `irc_players` (`authname`,`nick`,`ident`,`host`,`gecos`,`last_appearance`) VALUES ('#{authname}', '#{nick}', '#{user}', '#{host}', '#{realname}', '#{Time.new.to_i}')")
        end
      else
        # Oh, we found SOMETHING. Let's update it now.
        $con.query("UPDATE `irc_players` SET `nick` = '#{nick}', `ident` = '#{user}', `gecos` = '#{realname}', `last_appearance` = '#{Time.new.to_i}' WHERE `host` = '#{host}'")
      end
    else
      # A familiar face! Let's update their info.
      $con.query("UPDATE `irc_players` SET `nick` = '#{nick}', `ident` = '#{user}', `gecos` = '#{realname}', `last_appearance` = '#{Time.new.to_i}' WHERE `host` = '#{host}'")
    end
    #end of func
  end

end