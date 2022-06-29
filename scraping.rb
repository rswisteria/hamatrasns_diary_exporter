require 'nokogiri'
require 'faraday'
require 'faraday-cookie_jar'
require 'fileutils'
require 'uri'
require 'optparse'

BASE_URL = "http://hamatra.net".freeze
LOGIN_PATH = "/?m=pc&a=page_o_login".freeze
OUTPUT_DIR = "./output"

is_my_diary = true
is_community = false
community_id = nil

opts = OptionParser.new
opts.on("-u VALUE", "--user=VALUE") { |user| USERNAME = user }
opts.on("-p VALUE ", "--password=VALUE") { |password| PASSWORD = password }
opts.on("-c COM_ID", "--com_id=COM_ID") { |com_id| is_my_diary = false; is_community = true; community_id = com_id }
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


# 自分の日記
if is_my_diary
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

      dir = "#{OUTPUT_DIR}/my_diary/#{date.gsub(/[年月日:]/, '')}"
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
end

if is_community
  community_path = "/?m=pc&a=page_c_topic_detail&target_c_commu_topic_id=#{community_id}&order=asc"
  dir = "#{OUTPUT_DIR}/communities/#{community_id}"
  FileUtils.mkdir_p(dir)
  file = File.open("#{dir}/messages.txt", 'w+:UTF-8')

  loop do
    res = conn.get(community_path)
    html = res.body.force_encoding('UTF-8').gsub(/(\r\n|\r|\n|\f|\t)/, "")
    doc = Nokogiri.HTML(html)
    topic_desc = nil

    doc.search("//div[@class='parts']/dl").each do |dl|
      date = dl.search("dt")[0].text
      order_node = dl.search("dd/div[@class='title']/p[@class='heading']/strong")
      order = order_node.text.to_i
      name_node = dl.search("dd/div[@class='title']/p[@class='heading']/a[2]")
      name = name_node.text
      contents = dl.search("dd/div[@class='body']/p[@class='text']")
      photos = dl.search("dd/div[@class='body']/ul[@class='photo']")
      contents.search("ul[@class='photo']").each(&:remove)
      contents.search('br').each { |br| br.replace "\n" }
      contents.search('a').each { |a| a.replace a.get_attribute("href") }
      contents_text = contents.text

      if order == 0 && !topic_desc.nil?
        next
      end
      topic_desc = contents_text

      puts "#{order} #{date} #{name}"
      if order == 0
        file.puts "■ #{date} #{name}"
      else
        file.puts "============================"
        file.puts
        file.puts "#{order} #{date} #{name}"
        file.puts "---"
      end
      file.puts contents_text
      file.puts

      if photos.size > 0
        image_dir = "#{OUTPUT_DIR}/#{community_id}/#{order}"
        FileUtils.mkdir_p(image_dir)
        photos.search("li/a").each do |a|
          image_url = a.get_attribute("href")
          uri = URI::parse(image_url)
          query = Hash[URI::decode_www_form(uri.query)]
          image_res = conn.get(image_url)
          image_file = File.open("#{image_dir}/#{query["filename"]}", 'wb+')
          image_file.puts image_res.body
        end
      end
    end
    sleep 1
    break unless doc.search("//div[@class='pagerRelative']/p[@class='next']/a").size.positive?
    community_path = doc.search("//div[@class='pagerRelative']/p[@class='next']/a")[0].get_attribute("href")
  end
end