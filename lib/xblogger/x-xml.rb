module Bblogger

  class Mbxml
    def to_xml(h, content)
      @content, @h = content, h
      set_doc
      return nil unless @xentry
      set_basic
      set_div
      return @xentry
    end

    private

    def get_ele(s)
      @doc.root.elements[s]
    end

    def set_doc
      # return nil unless xmldoc.valid_encoding?
      @doc = REXML::Document.new(xmldoc)
      @xentry = @doc.root if @doc
    end

    def set_basic
      ['title', 'content/div', 'app:control'].each{|s|
        v = get_ele(s)
        i = "@" + s.gsub(/(.*?)[\/,:]/, '')
        self.instance_variable_set(i, v)
      }
      set_title; set_control; set_category
      set_published
    end

    def set_published
      return nil unless @h[:date]
      begin
        d = Time.parse(@h[:date])
      rescue
        return nil
      end
      @xentry.add_element("published").add_text(d.iso8601.to_s)
    end

    def set_title
      @title.add_text(@h[:title].strip.gsub("/","-"))
    end

    def set_category
      c = @h[:category]
      c.split(",").to_a.each{|x|
        @xentry.add_element("category", {'scheme'=>'http://www.blogger.com/atom/ns#','term'=>"#{x}"})
      }
    end

    def set_control
      @xentry.delete_element(@control) unless @h[:control] == 'yes'
    end

    def set_key
      a = ["more", "pre", "blockquote"]
      @on, @off  = Hash.new, Hash.new
      a.each{|x| @on["<#{x}>"] = "#{x}"; @off["</#{x}>"] = true}
      @line_p, @line_x, @tag = [], "", nil
      @n = 0
    end

    def set_div
      @content = @content.join().strip.lines.to_a
      set_key
      set_body
      @line_p = @content[@n..@content.size]
      tag_p unless @line_p.empty?
      return @div
    end

    def set_body
      @content.each_with_index{|x,no|
        line = x.strip
        if @on[line]
          @line_p = @content[@n..no-1]
          tag_p unless @line_p.empty? || no < 1
          @tag, @n = @on[line], no
        elsif @off[line]
          @line_x = @content[@n+1..no-1].join("")
          tag_x
          @n = no + 1
        end
      }
    end

    #2011-11-23
    def tag_more
      REXML::Comment.new("more", @div)
    end

    def tag_x
      case @tag
      when "pre" then tag_pre
      when "blockquote" then tag_block
      when "more" then tag_more
      end
    end

    def tag_pre
      e = @div.add_element(@tag).add_element("code")
      e.add_text(@line_x)
    end

    def tag_block
      e = @div.add_element(@tag).add_element("p")
      @line_x.strip.each_line{|x|
        e.add_text(x.chomp)
        tag_br(e) if x.include?("\n")
      }
    end

    def tag_p
      @ep = @div.add_element("p")
      @line_p.map{|x| x.chomp}.each_with_index{|w,x|
        @m = /<(a)|<(img)|<(del)/.match(w)
        @m ? sub_tag_p(w) : @ep.add_text(w)
        tag_br(@ep) if @line_p.size > x + 1
      }
    end

    def sub_tag_p(line)
      pre_str unless @m.pre_match.empty?
      tag_a(line) if @m[1]
      tag_img(line)if @m[2]
      tag_del(line) if @m[3]
      w = /<\/.*?>|<.*?\/>/.match(line)
      post_str(w) if w
    end

    def pre_str
      @ep.add_text(@m.pre_match)
    end

    def post_str(w)
      @ep.add_text(w.post_match)
    end

    def tag_br(ele)
       ele.add_element("br")
    end

    def tag_a(line)
      return nil if line =~ /<[a|\/a]>/
      all = /<a\shref=["'](.*?)["']>(.*?)<\/a>/.match(line)
      http = /http.?:\/\//.match(all[1]) if all
      (print "MISSED LINK TAG...#{line}\n"; raise) if (all[2].nil? or http.nil?)
      # 2001-11-29
      # u = URI.escape(all[1])
      # u = ERB::Util.url_encode(all[1])
      # pending
      u = all[1]
      a = @ep.add_element("a")
      a.add_attribute("href", u)
      a.add_text(all[2])
    end

    def tag_del(line)
      del = /<del>(.*?)<\/del>/.match(line)
      (print "MISSED DEL TAG...#{line}\n"; raise) if del.nil?
      @ep.add_element("del").add_text(del[1])
    end

    def tag_img(line)
      src = /<img\ssrc=["'](.*?)["']/.match(line)
      alt = /alt=["'](.*?)["']/.match(line)
      (print "MISSED IMG TAG...#{line}\n"; raise) unless src
      img = @ep.add_element("img")
      img.add_attributes('src'=>src[1]) if src
      img.add_attributes('alt'=>alt[1]) if alt
    end

    def xmldoc
        "<?xml version='1.0' encoding='UTF-8'?><entry xmlns='http://www.w3.org/2005/Atom'><title type='text'/><content type='xhtml'><div xmlns='http://www.w3.org/1999/xhtml'></div></content><app:control xmlns:app='http://www.w3.org/2007/app'><app:draft>yes</app:draft></app:control></entry>"
    end
  end

  class ResultView
    def initialize
      @res, @str, @xr = nil, nil, nil
    end

    def base(res, str)
      #p res.to_xml.root
      puts "# \n-------------------------------------- \n\n"
      @res, @str = res, str
      @xr = @res.to_xml.root
      result_view
    end

    private
    def result_view
      # @xr.elements.each{|x| p x}
      case @str
      when 'GetEntry'
        if @xr.name == "entry"
          print "# -- Get Entry --\n"
          view_getentry(Hash.new)
        end
      when 'GetFeed'
        return print "Not found entry.\n" unless @xr.elements['entry']
        print "# -- Get Feed --\n"
        view_getfeeds
      when 'GetInfo'
        print "# -- Get Information --\n"
        view_getinfo
      when /PostEntry/
        print "# -- Post Entry --\n"
        return view_postentry
      end
    end

    def view_getfeeds
      @xr.get_elements('entry').each{|x|
        h, @xr = {}, x
        view_getentry(h)
      }
    end

    def view_getentry(h)
      h[:control] = get_xstr('app:control/app:draft')
      h[:edit_id] = get_editid
      h[:url] = get_link
      [:published, :updated, :title].each{|s| h[s] = get_xstr(s.to_s)}
      h[:category] = get_category
      h[:summary] = get_xstr("summary")
      #### 2011-10-02
      h[:content] = get_xstr("content")
      print_hash(h)
    end

    def view_postentry
      return nil unless @xr.name == "entry"
      h = Hash.new
      h[:edit_id] = get_editid
      [:published, :updated].each{|s| h[s] = get_xstr(s.to_s)}
      h[:url] = get_link if get_link
      print_hash(h)
      return h unless h.empty?
    end

    def print_hash(h)
      return nil unless h
      h.each{|k,v|
        next if v.nil?
        print k.to_s.upcase, ": ", v, "\n"
      }
      print "\n"
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
      # <category term='Blogger' scheme='http://www.blogger.com/atom/ns#'/>
      cate = []
      @xr.get_elements('category').select{|y| cate.push(y.attributes['term'])}
      return nil if cate.empty?
      return cate.join(',').to_s
    end

    def get_editid
      edit = @xr.elements["link[@rel='edit']"].attributes['href']
      edit.to_s.gsub(/.*?default\//,'')
    end

    def xinfo_category
      @xr.get_elements('entry/category').each{|y| print "[", y.attributes['term'], "]\s"}
      print "\n"
    end

    def xinfo_link(str)
       @xr.get_elements("#{str}").each{|y|
        m = y.attributes['rel'].to_s.match(/\#(.*?)$/)
        m ? s = m[1] : s = y.attributes['rel']
        print "#{s} => ", y.attributes['href'], "\n"
      }
    end

    def xinfo_blogid
      blogid = nil
      @xr.get_elements('entry/link').select{|y|
        blogid = /(\d.*?)\//.match(y.attributes['href']) if y.attributes['rel'].to_s.match(/post/)
      }
      return blogid[1] if blogid
    end

    def xinfo_title
      return @xr.elements["title"].text
    end

    def view_getinfo
      print "# BlogTitle:\n #{xinfo_title}\n"
      print "# Blog ID:\n #{xinfo_blogid}\n"
      print "# Category:\n"
      xinfo_category
      print "# Link:\n"
      xinfo_link("link")
      print "# Entry Link:\n"
      xinfo_link("entry/link")
      print "-"*5 ,"\n"
    end
  end
  # end of moudle
end


