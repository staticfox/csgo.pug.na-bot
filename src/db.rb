require 'mysql'

$con = Mysql.new "#{Constants.const['database']['mysql']['host']}", "#{Constants.const['database']['mysql']['user']}", "#{Constants.const['database']['mysql']['pass']}", "#{Constants.const['database']['mysql']['db']}"