#!/usr/bin/ruby1.8 -wKU

def get_pids
  `ps -eo pid,command | grep "merb : ifloat" | grep -v grep | cut -f 1 -d m`.split
end

def report(message)
  File.open("/tmp/ifloat_restarter.log", "a") { |f| f.puts "#{Time.now} - #{message}" }
  true
end

uptime = `uptime`
raise "unable to parse #{uptime.inspect}" unless uptime =~ / ([.\d]+)$/
load = $1.to_f

if load > 5
  pids = get_pids
  report "15 minute load > 5 but no ifloat merb PIDs detected!" and exit if pids.empty?
  report "15 minute load > 5 => sending kill to ifloat merb PIDs #{pids.inspect}"
  system "kill", *pids
  sleep 10
end

if get_pids.empty?
  report "no ifloat merb PIDs detected => starting service"
  system "bundle exec merb -a thin -c 10 --name ifloat"
end
