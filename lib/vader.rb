#!/usr/bin/env ruby

dir = File.expand_path(ARGV[0] || Dir.pwd)

puts "Load path:"
puts $:.join("\n")

puts "\nargv:"
puts ARGV.inspect

puts "Watching #{dir}"

require 'rb-fsevent'
fsevent = FSEvent.new
fsevent.watch dir do |directories|
  puts "Detected change inside: #{directories.inspect}"
end
fsevent.run
