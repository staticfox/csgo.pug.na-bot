module DB

  def escape str
    return $con.escape_string(str)
  end

  def ping_mysql
    $con.ping
  end

end