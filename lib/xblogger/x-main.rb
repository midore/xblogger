module Bblogger

  class Xblog
    def initialize(h)
      @req = h.keys[0].to_s
      @req == 'get' ? @year_month = h.values[0] : @path = h.values[0]
    end

    def base
      setup unless @req =~ /get|del/
      #begin
        case @req
        when 'get' then g_get
        when 'doc' then g_doc
        when /^post/
          return err_msg(1) unless @t_id.nil?
          g_post
        when 'update'
          return err_msg(2) unless @t_id
          g_up
        when /^del/
          if @req == "del" then @t_id = @path; @path = nil
          else; setup; end
          return err_msg(3) unless @t_id
          g_del
        end
      #rescue# => err
      #end
    end

    private

    def setup
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

    def g_doc
      print @t_xdoc, "\n"
    end

    def g_get
      Start.new().xget(@year_month)
    end

    def g_save(rh)
      h = @t_head.merge(rh)
      h[:content] = @t_body
      SaveText.new(h).base
    end

    def g_post
      return nil unless @t_xdoc
      return nil unless gets_msg("Post Entry")
      rh = Start.new().xpost(@t_xdoc)
      return nil unless rh
      g_save(rh)
    end

    def g_up
      return nil unless @t_xdoc
      return nil unless gets_msg("Update Entry")
      Start.new(@t_id).xup(@t_xdoc)
    end

    def g_del
      # get entry before delete.
      b = Start.new(@t_id).xdel_before
      return nil unless b
      print "\n", "-"*5, "\n"
      return nil unless gets_msg("Delete Entry.")
      # delete request
      Start.new(@t_id).xdel
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

  class Start
    include $BBLOGGER
    def initialize(eid=nil)
      @eid = eid
      # See
      # Blogger Developers Network: Clarifying recent changes to Blogger’s feed access
      # http://code.blogger.com/2011/06/clarifying-recent-changes-to-bloggers.html
      # @xurl: http => https
      @xurl = "https://www.blogger.com/feeds/#{xid}/posts/default"
      @entryurl = @xurl + "/" + @eid if @eid
    end

    def xget(x)
      return nil unless u = range_t(x)
      # u = u + "?category=Blogger"
      r = clbase.get(u)
      view_res_list(r)
      status_code_200(r.status_code, "Get")
    end

    def xpost(data)
      str = "Error: path to data directory. LOOK! /path/to/xblogger-config\n"
      return print str unless d = dir_check
      p r = clbase.post(@xurl, data)
      status_code_201(r.status_code, "Post")
      return nil unless r.status_code == 201
      # save data as hash
      rh = res_to_h(r)
      rh[:dir] = d
      return rh
    end

    def xup(data)
      return nil unless @entryurl
      r = clbase.put(@entryurl, data.to_s)
      status_code_200(r.status_code, "Update")
    end

    def xdel_before
      return nil unless @entryurl
      print_entryurl
      request_get_entry
    end

    def xdel
      return nil unless @entryurl
      print_entryurl
      r = clbase.delete(@entryurl)
      status_code_200(r.status_code, "Delete")
    end

    def print_entryurl
      print "Entry URL: ", @entryurl, "\n"
    end

    private

    def res_to_h(res)
      # result xml of Post request to Hash
      return nil unless res.to_xml.root.name == "entry"
      print "# -- Response --\n"
      h = Hash.new
      @xr = res.to_xml.root
      h[:edit_id] = get_editid
      [:published, :updated].each{|s| h[s] = get_xstr(s.to_s)}
      h[:url] = get_link if get_link
      ## When post the public entry, :control of response is nil.
      ## don't use h[:control]
      print_hash(h)
      return h unless h.empty?
    end

    def dir_check
      d = data_dir
      return false unless File.exist?(d)
      return false unless File.directory?(d)
      return d
    end

    def request_get_entry
      begin
        res = clbase.get(@entryurl)
      rescue GData::Client::UnknownError
        print "Entry not found\n"
        return nil
      end
      status_code_200(res.status_code, "Get Entry")
      return nil unless res.status_code == 200
      view_get_entry(res)
    end

    def view_get_entry(res)
      print "# This Entry.\n"
      h, @xr = Hash.new, res.to_xml.root
      h[:contentSummary] = get_xstr("content").to_s[0..150]
      view_res_entry(h)
    end

    def status_code_201(n, str)
      # Post
      print "StatusCode: #{n}\n"
      return success_msg(str) if n == 201
      print "Error: Request #{str}"
    end

    def status_code_200(n, str)
      # Get, Delete, Update
      print "StatusCode: #{n}\n"
      return success_msg(str) if n == 200
      print "Error: Request #{str}"
    end

    def success_msg(str)
      print "Success: Request #{str}.\n\n"
    end

    def clbase
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

    def view_res_list(r)
      print "# Response Get Request\n"
      r.to_xml.elements.each('entry'){|x|
        h, @xr = {}, x
        view_res_entry(h)
      }
      print "--\n"
    end

    def view_res_entry(h)
      h[:edit_id] = get_editid
      h[:url] = get_link
      [:published, :updated, :title].each{|s| h[s] = get_xstr(s.to_s)}
      h[:control] = get_xstr('app:control/app:draft')
      h[:category] = get_category
      h[:contentSummary] = get_xstr("content").to_s[0..200]
      print "# ", "-"*5, "\n"
      print_hash(h)
    end

    def print_hash(h)
      return nil unless h
      h.each{|k,v|
        next if v.nil?
        print k.to_s.upcase, ": ", v, "\n"
      }
    end

    def get_editid
      edit = @xr.elements["link[@rel='edit']"].attributes['href']
      edit.to_s.gsub(/.*?default\//,'')
    end

    def get_xstr(str)
      return nil unless @xr.elements[str]
      @xr.elements[str].text
    end

    def get_link
      link = ""
      @xr.get_elements('link').select{|y|
        link = y.attributes['href'] if y.attributes['rel'] == 'alternate'
       }
      return nil if link.empty?
      return link
    end

    def get_category
      ## <category term='Blogger' scheme='http://www.blogger.com/atom/ns#'/>
      cate = []
      @xr.get_elements('category').select{|y| cate.push(y.attributes['term'])}
      return nil if cate.empty?
      return cate.join(',').to_s
    end

    def range_t(t)
      return nil unless t = set_time(t)
      min = (Time.local(t.year, t.month) - 1).strftime("%Y-%m-%dT%H:%M:%S")
      t.month == 12 ? x = [t.year+1, 1] : x = [t.year, t.month+1]
      max = Time.local(x[0], x[1], 1).strftime("%Y-%m-%dT%H:%M:%S")
      print "\nRange: #{min} ~ #{max}\n"
      return @xurl + "?published-min=#{min}" + "&published-max=#{max}"
    end

    def set_time(t)
      tt = Time.now.strftime("%Y/%m") unless t
      unless tt
        m = /^(\d{4})\-(\d{2})$/.match(t)
        tt = m[1] + "/" + m[2] if m
      end
      begin
        tt = Time.parse(tt)
      rescue #ArgumentError
      return print "Error: Time parse error. example: 2010-01.\n"
      end
    end
  end

  class Xdoc
    def initialize(path)
      return nil unless File.exist?(path)
      ary = IO.readlines(path)
      @mark = ary.find_index("--content\n")
      return check(nil) unless @mark

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

