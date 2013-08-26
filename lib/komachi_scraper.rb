require "open-uri"
require "nokogiri"
require 'ir_b'

# スクレイピングするURL
url = "http://komachi.yomiuri.co.jp/t/2013/0820/612572.htm?o=0&p=0"

html = open(url) {|f| f.read }
doc = Nokogiri::HTML.parse(html, nil, nil)

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

# keywords
KEYWORDS = {
  sori: %w[反町 そりまち こんな世の中じゃ],
  hote: %w[布袋],
  ega: %w[江頭],
  bret: %w[Bret.Michaels ブレット.?マイケルズ] +
    %w[ヘヴィメタのバンド ポイズン[^ガ]*バンド ビッグ・ヘア・バンド] +
    %w[ピンクマンさんに同意],
  rebekka: %w[レベッカ],
  pgirl: %w[ポイズンガ[ー-]ルバンド],
  yazawa: %w[矢沢],
  alize: %w[Alice.Cooper アリス.?クーパー],
  bell: %w[Bell.Biv.Devoe ベル.?ビヴ.?デヴォー],
  jorge: %w[ボーイ.?ジョージ],
  ayabe: %w[ピースの綾部],
  gohayato: %w[郷隼人],
  snow: %w[白雪姫に出てくるおばあさん],
  jiro: %w[赤川.?次郎],
  chasale: %w[チェーザレ・ボルジア],
  kageinari: %w[カゲ稲荷 カゲ稲荷.*この方],
}

def extract_name(text)
  extracted = KEYWORDS.map {|key, val|
    /#{val.join('|')}/ =~ text ? key : nil
  }.compact

  if extracted && extracted.size == 1
    extracted.first
  else
    nil
  end
end

DECISION_WORDS = %w[です[^が] しか でした よね でしょ かな] +
  %w[で即答 を思い浮か のほうです のポイズンで(した|す)]
DECISION_PREFIXES = [
  'ポイズン(の人」?)?(と|って)[い言](えば|ったら)',
  '(ポイズン)?(の人)?.?と[い言]われれば',
  'ポイズン(の人)?.*＝',
]

def extract_first(text)
  extracted = KEYWORDS.map {|key, val|
    regex = [
      /(#{val.join('|')}).{0,6}[一1１]票/,
      /(#{val.join('|')}).{0,5}(#{DECISION_WORDS.join('|')})/,
      /(#{DECISION_PREFIXES.join('|')})(#{val.join('|')})/,
    ]
    if regex.map{|r| r =~ text }.compact.first
      key
    end
  }.compact

  if extracted.size == 1
    extracted.first
  else
    nil
  end
end

def both?(res)
  res[:subject] + res[:body] =~ /#{[
    '両方',
    '二人',
    '混ざって出てきた',
    'ど(ちら|っち)でもな(い|かった)',
  ].join('|')}/
end
def nocount?(res)
  if res[:poster] == 'べこ妻(トピ主)'
    true
  elsif [res[:subject], res[:poster]] == %w[集計って！ 二度目です。]
    true
  else
    false
  end
end

invalid = 0
sum = reses.values.inject({}) do |h, res|
  # 片方の名前しか含まれてい無い場合の取得
  who = extract_name(res[:subject]) || extract_name(res[:body])

  # 複数検出されたときは、パターンマッチで優先度
  who ||= extract_first(res[:body])
#    .tap {|v| puts "#{res[:body]} is #{v}" if v == :poison}

  # どちらでもない？ or 両方
  who = :both if who.nil? && both?(res)

  if nocount? res
    # 集計しない
    invalid += 1
#    puts "invalid ... #{res}"
  elsif who
    h[who] = (h[who] || 0) + 1
  else
    h[nil] ||= []
    h[nil].push res
  end
  h
end

# output results
names = KEYWORDS.merge(
  both: ['両方/どちらでもない'],
  poison: ['POISON(バンド)'],
  pgirl: ['ポイズンガールバンド'],
).inject({}) {|h, kv| k, v = kv; h[k] = v.first.gsub(/\.\??/, ' '); h }
sum.select{|k,v| !k.nil? }.sort_by{|k,v| -v }.each do |k, v|
  puts "#{names[k]} = #{v}" if k
end
puts "other = #{sum[nil].size}"

puts "total = #{reses.size} , valid = #{reses.size - invalid}"

puts "\n--- other answers ---"
sum[nil].each {|e| p e }

