module Bblogger

  module  Blogs
    include $BBLOGGER

    def getinfo
      print "# GetInfo Request \n#{@baseurl}\n"
      res = @obj.get(@baseurl)
      print_status_code(res, 200)
      @view.base(res, "GetInfo")
    end

    def getfeed(option)
      # "https://www.blogger.com/feeds/#{xid}/posts/summary?category=google&amp;Blogger"
      # "?published-min=2011-06-25T23:59:59&published-max=2011-07-01T00:00:00"
      url = @feedurl + option
      print "# GetFeed Request\n#{url}\n"
      res = @obj.get(url)
      print_status_code(res, 200)
      @view.base(res, "GetFeed")
    end

    def getentry
      url = "#{@posturl}/" +  @t_id
      print "# GetEntry Request\n#{url}\n"
      res = @obj.get(url)
      print_status_code(res, 200)
      @view.base(res, "GetEntry")
    end

    def postentry
      print "# Post Request\n#{@posturl}\n"
      res = @obj.post(@posturl, @t_xdoc)
      print_status_code(res, 201)
      rh = @view.base(res, "PostEntry")
      return nil unless rh
      savetext(rh)
    end

    def savetext(rh)
      h = @t_head.merge(rh)
      h[:content] = @t_body
      h[:dir] = data_dir
      SaveText.new(h).base
    end

    def putentry
      url = "#{@posturl}/" +  @t_id
      print "# Put Request\n#{url}\n"
      res = @obj.put(url, @t_xdoc)
      print_status_code(res, 200)
    end

    def deleteentry
      url = "#{@posturl}/" +  @t_id
      print "# Delete Request\n#{url}\n"
      res = @obj.delete(url)
      print_status_code(res, 200)
    end

    def check
      str = "Error: Not Found data directory.\n"
      return print str unless dir_check
      return nil unless pw
      return nil unless ac
      return true
    end

    def dir_check
      d = data_dir
      return false unless File.exist?(d)
      return false unless File.directory?(d)
      return d
    end

    def loginauth
      exit if check.nil?
      begin
        a = GData::Client::Blogger.new
        a.source = xname
        token = a.clientlogin(ac, pw)
        a.headers = {
          "Authorization" => "GoogleLogin auth=#{token}",
          'Content-Type' => 'application/atom+xml'
        }
      return a
      rescue GData::Client::AuthorizationError
        print "ERROR: Blogger Login Error. LOOK! /path/to/xblogger-config\n"
        exit
      rescue => err
        print "ERROR: #{err.class}\n"
        exit
      end
    end

    def door
      @obj = loginauth
      exit unless @obj
      return @obj
    end

    def print_status_code(res, no)
      print "Status Code: ", res.status_code, "\n"
      exit unless res.status_code == no
    end
  end

  class Xblog
    include Blogs

    def initialize(h)
      @req, @opt = h.keys[0].to_s, h.values[0]
      @baseurl = "https://www.blogger.com/feeds/default/blogs"
      @posturl ="https://www.blogger.com/feeds/#{xid}/posts/default"
      @feedurl = "https://www.blogger.com/feeds/#{xid}/posts/summary"
      @view = ResultView.new
      @obj, @t_id, @path = nil, nil, nil
      @t_head, @t_xdoc, @t_body = nil, nil, nil
    end

    def base
      #begin
        setup if @req.match(/delete|post|update|doc/)
        return group_get if @req.match(/get/)
        return group_del if @req.match(/del/)
        return nil unless @t_xdoc
        return print @t_xdoc, "\n" if @req == 'doc'
        return group_post if @req.match(/post/)
        return group_update if @req.match(/update/)
      #rescue => err
      #  print "ERROR: #{err.class}\n"
      #  exit
      #end
    end

    private

    def group_get
      case @req
      when 'get'
        @opt = Time.now.strftime("%Y-%m") if @opt == "--get"
      when 'getentry'
        @t_id = @opt
        return nil unless @t_id
        return nil if @t_id.match(/\D/)
      end
      door
      return getinfo if @req == 'getinfo'
      return getfeed(set_option) if @req == 'get'
      return getentry if @req == 'getentry'
    end

    def group_update
      return err_msg(2) unless @t_id
      return nil unless gets_msg("Update Entry")
      door; putentry
    end

    def group_post
      return err_msg(1) unless @t_id.nil?
      return nil unless gets_msg("Post Entry")
      door; postentry
    end

    def group_del
      @t_id = @opt if @req == 'del'
      return err_msg(3) unless @t_id
      door; getentry
      return nil unless gets_msg("Delete Entry.")
      door; deleteentry
    end

    def set_option
      @opt.match(/^\d{4}.\d{2}$/) ? opt = set_time : opt = set_category
    end

    def set_time
      t = Time.parse(@opt.gsub("-","/"))
      min = t.strftime("%Y-%m-%dT%H:%M:%S")
      t.month == 12 ? x = [t.year+1, 1] : x = [t.year, t.month+1]
      max = Time.local(x[0], x[1], 1).strftime("%Y-%m-%dT%H:%M:%S")
      return "?published-min=#{min}&published-max=#{max}"
    end

    def set_category
      return "?category=#{@opt.gsub(",","&amp;")}"
    end

    def setup
      @path = @opt
      @t_head, @t_xdoc, @t_body = Xdoc.new(@path).base
      return err_msg(4) if @t_head.nil?
      @t_id = @t_head[:edit_id]
      print_t_head
    end

    def print_t_head
      @t_head.each{|k,v| print k.to_s.upcase, ": ", v, "\n" if v}
      print "# ", "="*5, "\n"
    end

    def err_msg(n)
      case n
      when 1 then print "Error1: posted, already.\n"
      when 2 then print "Error2: need to post, before update.\n"
      when 3 then print "Error3: edit_id is empty.\n"
      when 4 then print "Error4: text file format.\n"
      end
    end

    def gets_msg(str)
      print str, "\n"
      print "# Edit ID: #{@t_id}\n" if @t_id
      print "OK? [y/n]\n"
      ans = $stdin.gets.chomp
      exit if /^n$/.match(ans)
      exit if ans.empty?
      return true if ans == 'y'
    end
  end

  class Xdoc
    def initialize(path)
      return nil unless File.exist?(path)
      ary = IO.readlines(path)
      @mark = ary.find_index("--content\n")
      return check(nil) unless @mark
      # --
      con_h = ary[@mark+1..ary.size]
      con_s = con_h.join().strip
      return check(nil) if con_s.empty?
      @meta, @content = to_meta(ary), con_s
      @xdoc = to_xml(@meta, con_h) if @meta
    end

    def base
      return nil if (@meta.nil? or @xdoc.nil?)
      return [@meta, @xdoc, @content]
    end

    private

    def to_xml(h, arr)
      Mbxml.new().to_xml(h, arr)
    end

    def to_meta(ary)
      h, k = need_key, nil
      ary.each_with_index{|x,y|
        break if @mark == y
        next if x.strip.empty?
        m = /^--(.*?)\n$/.match(x)
        m ? k = m[1].to_sym : (h[k] = x.strip if h.key?(k))
      }
      return nil unless check(h)
      return h
    end

    def check(h)
      return print "Error: content.\n" unless h
      return print "Error: category\n" unless h[:category]
      return print "Error: title\n" unless h[:title]
      return print "Error: control\n" unless h[:control]
      return true
    end

    def need_key
      {:edit_id=>nil, :published=>nil, :updated=>nil, :date=>nil, :control=>nil, :category=>nil, :title=>nil}
    end
  end

  class SaveText
    def initialize(h)
      return nil unless h[:dir]
      @h = h
      @dir, @pubd = h[:dir], h[:published]
      @h.delete(:dir)
    end

    def base
      path, data = getpath, getdata
      if File.exist?(path)
        return print "\nError: Same file exist.\nFile: #{path}\n"
      end
      File.open(path, 'w:utf-8'){|f| f.print data}
      print "Saved: #{path}\n"
    end

    private

    def getdata
      str = String.new
      @h[:date] ||= Time.parse(@pubd).strftime("%Y/%m/%d %a %p %H:%M:%S")
      a = [:edit_id, :published, :updated, :date, :control, :category, :title, :url]
      a.each{|k|
        next if @h[k].nil?
        str << "--#{k}\n#{@h[k]}\n"
      }
      str << "--content\n#{@h[:content]}\n"
      return str
    end

    def getpath
      return nil unless @dir
      subd = File.join(@dir, Time.parse(@pubd).strftime("%Y-%m"))
      Dir.mkdir(subd) unless File.exist?(subd)
      f = Time.parse(@pubd).strftime("%Y-%m-%dT%H-%M-%S") + "-" + @h[:edit_id] + ".txt"
      File.join(subd, f)
    end
  end
  # end of module
end

