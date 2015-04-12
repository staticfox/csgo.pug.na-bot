require 'cinch'

require_relative 'constants'
require_relative 'db'
require_relative 'debug'
require_relative 'handlepug'
require_relative 'ircdata'

class BotManager < Cinch::Bot

  def self.cmsg target, message
    @bot.Channel(target).send message, false
    puts @bot # Don't ask. It works. Just. I dont event. Don't touch it.
  end

  def self.cnot target, message
    @bot.Channel(target).send message, true
    puts @bot
  end

  def self.umsg target, message
    @bot.User(target).send message, false
    puts @bot
  end

  def self.unot target, message
    @bot.User(target).send message, true
    puts @bot
  end

  def self.voiceuser channel, target
    @bot.Channel(channel).voice target
  end

  def self.quit
    @bot.quit
    sleep(2)
    exit
  end

  def self.initalize
    @bot = Cinch::Bot.new do
      configure do |c|
        c.server = Constants.const['irc']['server']
        c.channels = ['#csgo.pug.na']
        c.nick = Constants.const['irc']['bot_nick']
        c.user = Constants.const['irc']['ident']
        c.realname = Constants.const['irc']['real_name']
        c.local_host = Constants.const['irc']['bind_ip']
        c.plugins.plugins = [ Pug ]
        #c.verbose = false
      end

      unless Constants.const['irc']['ns_pass'].nil?
        on :connect do
          User(Constants.const['irc']['auth_server']).send "AUTH #{Constants.const['irc']['nickserv_acc']} #{Constants.const['irc']['ns_pass']}"
        end
      end

      # Not sure If this is even necessary
      on 354 do |message|
        s_array = message.raw.split(" ")
        gecos = ""
        i = 9
        while i < s_array.count
          if gecos.empty?
            gecos = s_array[i]
          else
            gecos = gecos + " " + s_array[i]
          end
          i += 1
        end
        HandleIRCData.update_on_join(s_array[6], s_array[4], s_array[5], gecos.slice(1..-1), s_array[8])
      end

      # Catch when we ctrl + c
      trap "INT" do
        @bot.quit "Caught interrupt from console"
        sleep(2)
        exit
      end
    end
  end

end