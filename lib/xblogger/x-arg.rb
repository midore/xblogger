module Bblogger

  class CheckStart
    def initialize(arg)
      begin
        @err = false
        m, @h = '', Hash.new
        arg.each{|x|
          m = /^--(.*)/.match(x) if /^--/.match(x)
          @h[m[1].to_sym] = x if m
        }
      rescue
        print "Error: see --h\n"; exit
      end
    end

    def base
      return help if (@h.has_key?(:h) or @h.has_key?(:help))
      return check_arg
    end

    private

    def help
      arg_keys.values.sort_by{|v| v}.each{|x| print x, "\n"}
      return 'help'
    end

    def arg_keys
      {
        'getinfo'=>'0, Get information. Example: --getinfo',
        'get'=>'1, Get Feeds. Example: --get 2010-01 | Blogger,Google',
        'getentry'=>'1, Get entry. Example: --getentry 123456789 # edit-id',
        'doc'=>'2, XML data. Example: --doc draft.txt',
        'post'=>'3, Post entry. Example: --post draft.txt',
        'update'=>'4, Update entry. Example: --update 2010-01-01-xxx.txt',
        'del'=>'5, Delete entry. Example: --del 123456789 # edit id',
        'delete'=>'6, Delete entry file. Example: --delete /path/to/file',
        'h'=>'Help: --h'
      }
    end

    def check_arg
      err_no_str, err_no_file = "No option", "Not found"
      @h.keys.each{|k| return @err = err_no_str unless arg_keys["#{k}"]}
      k = @h.keys[0]
      if k == :get
      elsif k == :del
        (@h[:del] == "--del") ? @err = "Error: edit id" : nil
        @err = "Error: edit id" if /\D/.match(@h[:del])
      elsif k == :getinfo
      elsif k == :getentry
      else
        return err_no_file unless File.exist?(@h[k]) and File.file?(@h[k])
      end
      return [@err, @h]
    end
  end

end

