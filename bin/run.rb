#!/usr/bin/ruby
# coding: utf-8

# run.rb
# Mac OS X 10.6.6
# ruby 1.8.7

#------------------------------------------
# gdata
# http://code.google.com/p/gdata-ruby-util/downloads/list
#------------------------------------------

module Bblogger

  class Start
    def own_dir
      $LOAD_PATH.delete(".")
      bin = File.dirname(File.expand_path($PROGRAM_NAME))
      lib = File.join(File.dirname(bin), 'lib')
      $LOAD_PATH.push(lib)
    end

    def run
      own_dir
      ARGV.empty? ? exit : ARGV.delete("")
      require 'xblogger/x-arg'
      err, arg_h = CheckStart.new(ARGV).base
      if err
        err == 'help' ? exit : (print "#{err}\n"; exit)
      end

      begin
        # your xblogger-confing
        conf = '/path/to/your/xblogger-config'
        load conf, wrap=true
        # your gdata
        require '/path/to/your/gdata-1.1.1/lib/gdata.rb'
        require 'xblogger'
      rescue LoadError
        print "Error: path to \"xblogger-config\" or \"gdata library\"\n"
        exit
      end
      Xblog.new(arg_h).base
    end

    private :own_dir

  end

end

Bblogger::Start.new.run

