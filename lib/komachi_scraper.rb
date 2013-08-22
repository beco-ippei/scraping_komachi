require "open-uri"
require "nokogiri"
require 'ir_b'

# スクレイピングするURL
url = "http://komachi.yomiuri.co.jp/t/2013/0820/612572.htm?o=0&p=0"

charset = nil
html = open(url) do |f|
  charset = f.charset
  f.read
end

doc = Nokogiri::HTML.parse(html, nil, charset)

# scraping
reses = doc.xpath('id("reslist")/tr/td/..').inject({}) do |h, td|
  unless (hd = td.xpath('td[@class="hd"]/a')).empty?
    id = hd.attribute('id').value
    id_num = /[\d]+/ =~ id && Regexp::last_match[0].to_i

    h[id_num] ||= {}
    h[id_num].merge!({
      subject: hd.children.text,
      poster: td.xpath('td[@class="poster"]/div').children.text,
    })
  end

  unless (body = td.xpath('td[@class="resbody"]/div')).empty?
    id = body.attribute('id').value
    id_num = (/[\d]+/ =~ id && Regexp::last_match[0].to_i)

    h[id_num] ||= {}
    h[id_num][:body] = body.xpath('p').children.
      select{|e| e.is_a? Nokogiri::XML::Text }.
      map(&:text).join(' ').gsub(/\r|\n/, '')
  end
  h
end

def extract(text)
  sori = /反町/ =~ text
  hote = /布袋/ =~ text
  if (sori && hote) || (!sori && !hote)
    nil
  else
    sori ? :sori : :hote
  end
end

def extract_first(text)
  if idx= text.index(/反町|布袋/)
    text[idx..idx+1] == '反町' ? :sori : :hote
  end
end

sum = reses.values.inject({}) do |h, res|
  who = extract res[:subject]
  who ||= extract res[:body]
  who ||= extract_first res[:body]

  h[:who] ||= {sori: 0, hote: 0, nil => 0}
  h[:who][who] += 1
  h
end

p sum

