# coding: utf-8

require 'open-uri'
require 'rexml/document'

profileid = ARGV[0] # 'your ProfileID'
(print "Input the Number. The Number is a part of URL in your Blogger's ProfilePage \n"; exit) unless profileid

begin
  u = "http://www.blogger.com/feeds/#{profileid}/blogs"
  save_file = 'blogger-profile.xml'
  unless File.exist?(save_file)
    open(u){|x| File.open(save_file, 'w:utf-8'){|f| f.write x.read}}
    print "Saved: blogger-profile.xml\n"
    sleep 1
  end
  str = IO.read(save_file)
  doc = REXML::Document.new(str)
  blogtitle = doc.root.elements['title'].text
  blogid, blogurl = '', ''
  doc.root.get_elements('entry/link').each{|x|
    rel, hr  = x.attributes['rel'], x.attributes['href']
    if /post/.match(rel)
      (m = /feeds\/(.*?)\/posts/.match(hr)) ? blogid = m[1] : nil
    elsif /alternate/.match(rel)
      blogurl = hr
    end
  }
  print "BlogTitle=> #{blogtitle}\nBlogURL=> #{blogurl}\nBlogID => #{blogid}\n"
rescue SocketError
  print "SocketError\n"; exit
end

