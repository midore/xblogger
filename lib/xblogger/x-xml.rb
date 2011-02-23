module Bblogger

  class Mbxml

    def to_xml(h, content)
      #begin
        @content, @h = content, h
        set_doc
        return nil unless @xentry
        set_basic
        set_div
        #cleanup
        return @xentry
      #rescue NoMethodError
      #  print "Error: XML Parse\n"
      #rescue RuntimeError
      #  print "Error: Tag Issue\n"
      #end
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
      return nil if d > Time.now
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
      a = ["pre", "blockquote"]
      @on, @off  = Hash.new, Hash.new
      a.each{|x| @on["<#{x}>"] = "#{x}"; @off["</#{x}>"] = true}
      @line_p, @line_x, @tag = [], "", nil
      @n = 0
    end

    def cleanup
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

    def tag_x
      case @tag
      when "pre" then tag_pre
      when "blockquote" then tag_block
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
      @ep.add_element("a",{'href'=>all[1]}).add_text(all[2])
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

    # end of module
  end
  # end of moudle
end

