require 'yaml'

module Const
  def const
    @const
  end

  def load_config
    begin
      @const = YAML.load_file(File.dirname(__FILE__) + '/../cfg/config.yaml')
    rescue Errno::ENOENT
      puts "You haven't configured your bot!"
      exit
    rescue => e
      puts "An error has occured reading the config file: #{e}"
      exit
    end
  end
end

class GlobalConstants
  include Const
end

Constants = GlobalConstants.new
Constants.load_config