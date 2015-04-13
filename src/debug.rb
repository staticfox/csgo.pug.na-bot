require_relative 'bot'
require_relative 'logic/database'

module Debug

  include DB

  def debug_start(channel, players)
    begin
      players = players.to_i
    rescue
      BotManager.cmsg(channel, "Players must be an integer!")
    end
    channel = escape channel.to_s
    fv = $con.query("SELECT COUNT(*) FROM `irc_players` WHERE `nick` LIKE '%playerbotdebug%'")
    vc = 0
    if fv.num_rows > 0
      while row = fv.fetch_row do
        vc = row[0].to_i
      end
    end
    i = 0
    while i < players do
      $con.query("INSERT INTO `irc_players` (`authname`,`nick`,`ident`,`host`,`gecos`,`last_appearance`) VALUES ('playerbotdebug#{vc}#{i}', 'playerbotdebug#{vc}#{i}', 'playerbotdebug#{vc}#{i}', '127.0.0.1', 'playerbotdebug#{vc}#{i}', '#{Time.new.to_i}')")
      pidq = $con.query("SELECT `player_id` FROM `irc_players` WHERE `nick` = 'playerbotdebug#{vc}#{i}'")
      pid = 0
      while row = pidq.fetch_row do
        pid = row[0].to_i
      end
      $con.query("INSERT INTO `current_players` (`player_id`,`channel`,`captain`,`idle_time`) VALUES ('#{pid}', '#{channel}', '0', '#{Time.new.to_i}')")
      i += 1
    end
    BotManager.cmsg(channel, "Added #{players} pseudo players.")
  end

end