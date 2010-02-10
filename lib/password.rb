module Password
  FORMAT = /^\{SSHA\}(.+?)$/
  
  def self.gen_string(length)
    alphanum = ('0'..'9').to_a + ('a'..'z').to_a + ('A'..'Z').to_a
    alphanum_size = alphanum.size
    (1..length).inject("") { |s, n| s << alphanum[rand(alphanum_size)] }
  end
  
  def self.hash(pass, salt = gen_string(16))
    bytes = []
    pass.each_byte { |b| bytes << b }
    pass_utf8 = bytes.pack("U*")
    hash = Digest::SHA1.digest(pass_utf8 + salt)
    "{SSHA}" + [hash + salt].pack("m").chomp
  end
  
  def self.hashed?(pass)
    pass =~ FORMAT
  end
  
  def self.match?(hashed_pass, pass)
    return false unless hashed_pass =~ /^\{SSHA\}(.+?)$/
    salt = $1.unpack("m")[0][20,16]
    hash(pass, salt) == hashed_pass
  end
end