require 'nokogiri'
require 'faraday'
require 'faraday-cookie_jar'
require 'fileutils'
require 'uri'
require 'optparse'

BASE_URL = "http://hamatra.net".freeze
LOGIN_PATH = "/?m=pc&a=page_o_login".freeze
OUTPUT_DIR = "./output"

opts = OptionParser.new
opts.on("-u VALUE", "--user=VALUE") { |user| USERNAME = user }
opts.on("-p VALUE ", "--password=VALUE") { |password| PASSWORD = password }
opts.parse!

conn = Faraday.new(BASE_URL) do |builder|
  builder.request :url_encoded
  builder.use :cookie_jar
  builder.options.params_encoder = Faraday::FlatParamsEncoder
  builder.adapter Faraday.default_adapter
end

# login
login_res = conn.post("/") do |req|
  req.headers['Referer'] = LOGIN_PATH
  req.body = {
    m: 'pc',
    a: 'do_o_login',
    username: USERNAME,
    password: PASSWORD
  }
end

if login_res.headers["location"].match(/login_failed/)
  puts "hamatra SNSへのログインに失敗しました。ユーザー名とパスワードを確認してください"
  return
end


diary_path = "/?m=pc&a=page_fh_diary_list"
loop do
  res = conn.get(diary_path)
  html = res.body.force_encoding('UTF-8')
  doc = Nokogiri.HTML(html)

  doc.search("//div[@class='parts']/dl").each do |dl|
    link = dl.search("dd/div[@class='footer']/p/a")[1].get_attribute("href")

    diary_res = conn.get(link)
    diary_html = diary_res.body.force_encoding('UTF-8').gsub(/(\r\n|\r|\n|\f|\t)/, "")
    diary_doc = Nokogiri.HTML(diary_html)

    diary = diary_doc.search("//div[@class='dparts diaryDetailBox']/div[@class='parts']/dl")[0]
    date = diary.search("dt")[0].text
    title = diary.search("dd/div[@class='title']/p[@class='heading']")[0].text
    contents = diary.search("dd/div[@class='body']")
    photos = contents.search("ul[@class='photo']")
    contents.search("ul[@class='photo']").each(&:remove)
    contents.search('br').each { |br| br.replace "\n" }
    contents.search('a').each { |a| a.replace a.get_attribute("href") }

    dir = "#{OUTPUT_DIR}/#{date.gsub(/[年月日:]/, '')}"
    FileUtils.mkdir_p(dir)
    file = File.open("#{dir}/#{title}.txt", 'w+:UTF-8')
    file.puts contents.text
    file.close
    if photos.size > 0
      photos.search("li/a").each do |a|
        image_url = a.get_attribute("href")
        uri = URI::parse(image_url)
        query = Hash[URI::decode_www_form(uri.query)]
        image_res = conn.get(image_url)
        image_file = File.open("#{dir}/#{query["filename"]}", 'wb+')
        image_file.puts image_res.body
      end
    end
    puts "#{date} #{title}"
    sleep 1
  end

  # next link
  break unless doc.search("//div[@class='pagerRelative']/p[@class='next']/a").size.positive?
  diary_path = doc.search("//div[@class='pagerRelative']/p[@class='next']/a")[0].get_attribute("href")
end