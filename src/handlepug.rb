require 'cinch'

require_relative 'constants'
require_relative 'debug'
require_relative 'logic/database'
require_relative 'logic/internal'
require_relative 'logic/irc'
require_relative 'logic/pug'
require_relative 'logic/srcds'

class Pug

  include Cinch::Plugin

  include Const
  include DB
  include Debug
  include InteralCalc
  include IRCHandler
  include PugLogic
  include SRCDS

  # IRC Events
  listen_to :channel, method: :event_channel
  listen_to :join, method: :event_join
  listen_to :part, method: :event_leaving
  listen_to :quit, method: :event_leaving
  listen_to :kick, method: :event_leaving
  listen_to :nick, method: :event_nick

  timer 90, method: :mysql_keepalive

  # Player commands
  match /add(?: (.+))?/i, method: :command_add
  match /captain/i, method: :command_captain
  match /last/i, method: :command_last
  match /list/i, method: :command_list
  match /map/i, method: :command_map
  match /need/i, method: :command_need
  match /players/i, method: :command_list
  match /remove/i, method: :command_remove
  match /reward/i, method: :command_reward
  match /rotation/i, method: :command_maps
  match /server/i, method: :command_server
  match /stats(?: (.+))?/i, method: :command_stats
  match /status/i, method: :command_status

  # Captain commands
  match /pick ([\S]+)/i, method: :command_pick

  # Debug commands
  match /debug ([\S]+)/i, method: :command_debug
  match /wipetables/i, method: :command_wipe

  # Admin commands
  match /restrict ([\S]+) ([\S]+)(?: (.+))?/i, method: :command_restrict
  match /quit/i, method: :command_quit

  # Channel ticks
  def event_channel m
    uid = get_uid m
    channel = escape m.channel.to_s
    update_idle uid
    # Check to see if we can play video games yet
    afk_timeout = Constants.const['pug']['afk_timeout'].to_i
    pug_timeout = Constants.const['pug']['draft_timeout'].to_i
    players = Constants.const['pug']['players_required'].to_i
    captains = Constants.const['pug']['captains_required'].to_i
    idle_time = Constants.const['pug']['idle_time'].to_i
    ready_to_start channel, afk_timeout, pug_timeout, players, captains, idle_time
  end

  # Remove players
  def event_leaving m
    uid = get_uid m
    user_left uid #logic/irc
  end

  # /nick
  def event_nick m
    old = escape m.to_s[24..-1][/[^!]+/]
    newnick = escape m.user.nick.to_s
    nick_change old, newnick #logic/irc
  end

  # Add to pug
  def command_add m, cpt
    channel = escape m.channel.to_s
    nick = escape m.user.nick.to_s
    playerid = get_uid m
    locked = locked_logic channel
    add_logic channel, playerid, nick, cpt, locked #logic/pug
    # Recheck here for when we add
    afk_timeout = Constants.const['pug']['afk_timeout'].to_i
    pug_timeout = Constants.const['pug']['draft_timeout'].to_i
    players = Constants.const['pug']['players_required'].to_i
    captains = Constants.const['pug']['captains_required'].to_i
    idle_time = Constants.const['pug']['idle_time'].to_i
    ready_to_start channel, afk_timeout, pug_timeout, players, captains, idle_time #logic/internal
  end

  # Get captain information
  def command_captain m
    channel = escape m.channel.to_s
    locked = locked_logic channel
    return m.reply "0,1There are no team drafts in process." if locked == 0
    playerid = get_uid m
    get_captain channel, playerid, m.user.nick
  end

  # Remove from pug
  def command_remove m
    uid = get_uid m
    channel = escape m.channel.to_s
    locked = locked_logic channel
    remove_logic uid, channel, locked #logic/pug
  end

  # Print the last time a match was started
  def command_last m
    channel = escape m.channel.to_s
    last_logic channel
  end

  # Can they get +v?
  def event_join m
    uid = get_uid m
    reward_logic uid, m.channel, m.user.nick
  end

  def command_reward m
    uid = get_uid m
    reward_manual uid, m.channel, m.user.nick
  end

  def command_stats m, text
    uid = get_uid m
    get_stats uid, m.user.nick, text, m.channel
  end

  # Print out a list of all of our current players
  def command_list m
    get_list escape m.channel.to_s #logic/pug
  end

  # Show the current map
  def command_map m
    get_map m.channel #logic/srcds
  end

  # Show all maps
  def command_maps m
    get_map_list m.channel #logic/srcds
  end

  # Print out a a list of what we need
  def command_need m
    channel = escape m.channel.to_s
    locked = locked_logic channel
    need_logic channel, locked #logic/pug
  end

  # Pick players during drafts
  def command_pick m, pick
    channel = escape m.channel.to_s
    playerid = get_uid m
    locked = locked_logic channel
    pick_logic channel, playerid, pick, locked #logic/pug
  end

  # Get server info
  def command_server m
    channel = escape m.channel.to_s
    get_server channel, 0, nil #logic/srcds
  end

  # Get server's statuses
  def command_status m
    channel = escape m.channel.to_s
    get_status channel #logic/srcds
  end

  # Keep MySQL connection alive
  def mysql_keepalive
    ping_mysql
  end

  def command_restrict m, p_restricted, time, message
    restrictor = escape m.user.nick
    restrictor_id = get_uid m
    channel = escape m.user.nick
    return m.reply "0,1You must be a channel op to use this command." unless m.channel.opped? m.user
    restrict_player restrictor, restrictor_id, channel, p_restricted, time, message, 0
  end

  # Debugging purposes, this will screw up your DB
  def command_debug m, num
    return m.reply "0,1Debugging mode must be enabled." unless Constants.const['bot']['debug'].to_i == 1
    return m.reply "0,1You must be a channel op to use this command." unless m.channel.opped? m.user
    channel = escape m.channel.to_s
    debug_start channel, num #debug
  end

  # Kill the bot
  def command_quit m
    return m.reply "0,1You must be a channel op to use this command." unless m.channel.opped? m.user
    quit_bot #logic/pug
  end

end