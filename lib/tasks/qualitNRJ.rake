# coding: utf-8
task :update_database => :environment do
  require "selenium/client"
  require 'open-uri'
  require 'nokogiri'

  url = "http://www.qualit-enr.org"
  annuaire = "/annuaire/index.html" 
  IMG_DIR = "app/assets/images"
  GOCR_DIR = Dir.pwd + "/db/gocr"

  codes_postaux = (21000..97000).step(1000).map{|x| x.to_s.rjust(5, "0")}

  def download full_url, to_here
    writeOut = open(to_here, "wb")
    writeOut.write(open(full_url).read)
    writeOut.close
  end

  def images_url item, serial_num
    "/img_install.php?id=#{serial_num}&part=#{item}"
  end

  def image_dir_path name, serial_num
    tmp_path = [IMG_DIR,
                  [name.downcase.gsub(/\W/, "_"),
                   serial_num,
                  ].join("_"),
              ].join("/")
    tmp_path += "/"
  end
  def image_dir_path_absolute name, serial_num
    image_dir = Dir.pwd + "/" + image_dir_path(name, serial_num)
  end

  def image_name item, serial_num, ext="png"
    image_name = serial_num.to_s + "_#{item}." + ext
  end

  def image_absolute_path name, serial_num, item, ext="png"
    image_dir_path_absolute(name, serial_num) + image_name(item, serial_num)
  end

  def create_image_dir dir
    Dir.mkdir(dir) unless File.directory?(dir)
  end

  def parse_company_page page, url
    doc = Nokogiri::HTML(page)
    company = Companies.new
    #patern = /^(.*)(\d{5}.*)Web : (.*)$/
    patern = /^(.*)(\d{5}.*)$/

    company_images  = doc.css("#infos_installateur img").map{|x| x[:src]}
    company_text = doc.at_css("#infos_installateur").text
    company.serial_num = company_images.first.scan(/\d/).join.to_i
    company.name = company_text.scan(patern).flatten.first.titleize
    company.postal_code = company_text.scan(patern).flatten.last.titleize
    company.address, company.telephone = "", ""

    company
  end

  selenium = Selenium::Client::Driver.new("localhost", 4444, "*chrome", "#{url}#{annuaire}", 30)
  selenium.start

  codes_postaux.each do |code_postal|
puts code_postal
    selenium.open annuaire
    # Fill in the form
    selenium.click "rec4"
    selenium.set_speed 500
    selenium.click "rec9_tb"
    selenium.mouse_down "rec9_tb"
    selenium.type_keys 'rec9_tb', code_postal
    selenium.set_speed 1000
    selenium.click "autocomplete_li_rec9_tb_0"
    selenium.fire_event "css=div.bouton_lancer", "click"
    selenium.wait_for_page_to_load
    selenium.fire_event "//div[@id='list']/table/tbody/tr[2]", "click"
    selenium.wait_for_page_to_load
    selenium.set_speed 100

    keep_crawling, last_one = true, false

    while keep_crawling do

      @company = parse_company_page selenium.get_html_source, url
      if Companies.find_by_serial_num(@company.serial_num)
        puts "Company #{@company.name} is already Registered"
      else
        puts "Name:        " + @company.name
        {'adresse'=>'address', 'tel'=>'telephone'}.each do |key, value|
          image = image_absolute_path(@company.name, @company.serial_num, key)
          create_image_dir image_dir_path_absolute(@company.name, @company.serial_num)
          download( url + images_url(key, @company.serial_num),
                   image)

          gocr_opts = {
                        "p" => "#{GOCR_DIR}/",
                        "i" => "#{image_absolute_path(@company.name, @company.serial_num, key)}",
                        "m" => "130"
                      }
          args = gocr_opts.map{|k,v| "-#{k} #{v}" }.join(" ")
          if key == "tel"
            Devil.with_image(image) do |img|
              img.crop(0, 0, 130, 14)
              img.save(image)
            end
            @company[value.to_sym] = `gocr #{args}`.gsub("I","1").gsub("O", "0")[4..-1]
          else
            @company[value.to_sym] = `gocr #{args}`.titleize
          end
        end
        puts "Address:     " + @company.address
        puts "Telephone:   " + @company.telephone
        puts "Serial:      " + @company.serial_num.to_s
        puts "Postal_code: " + @company.postal_code.gsub("Web : ", "\n")
        puts "\n"

        @company.save!
      end

      if not selenium.is_text_present "Entreprise suivante" and selenium.is_text_present "Entreprise précédente" 
        keep_crawling = false
      else
        selenium.click "css=div.entreprise_suivante > a"
        selenium.wait_for_page_to_load
      end
    end

  end
  selenium.stop
end


task :dl_images do

  require 'open-uri'

  url = "http://www.qualit-enr.org"
  codes_images = [ 34765, 15761, 30004, 7039, 21439, 36393,
            23358, 40590, 39907, 27639, 36633, 35743, 35384,
            15757, 37803, 41540, 7073, 35664, 41717, 34557]
  IMG_DIR = Dir.pwd + "/public/images/db"

  def download full_url, to_here
    writeOut = open(to_here, "wb")
    writeOut.write(open(full_url).read)
    writeOut.close
  end

  def images_url serial_num
    "/img_install.php?id=#{serial_num}&part=adresse"
  end
  codes_images.each do |code|
    download(url + images_url(code), "#{IMG_DIR}/img_#{code}_adresse.png")
  end
end

task :process_images do
  codes_images = [ 34765, 15761, 7039, 21439, 36393,
            23358, 40590, 39907, 27639, 36633, 35743, 35384,
            15757, 37803, 41540, 7073, 35664, 41717, 34557]

  IMG_DIR = Dir.pwd + "/public/images/db"
  GOCR_DIR = Dir.pwd + "/db/gocr"

  def download full_url, to_here
    writeOut = open(to_here, "wb")
    writeOut.write(open(full_url).read)
    writeOut.close
  end

  def images_url serial_num
    "/img_install.php?id=#{serial_num}&part=adresse"
  end

  codes_images.each do |code|
    #puts "gocr -p #{GOCR_DIR}/ -i #{IMG_DIR}/img_#{code}_tel.png"
    tel = `gocr -p #{GOCR_DIR}/ -i #{IMG_DIR}/img_#{code}_tel.png -m 130`
    tel = tel.gsub("I","1")[4..-1]
    puts tel
  end
end

task :crop_images do
#  GOCR_DIR = Dir.pwd + "/db/gocr"
#  tel = `gocr -p #{GOCR_DIR}/ -i #{IMG_DIR}/img_#{code}_tel.png -m 130`
#  tel = tel.gsub("I","1")[4..-1]

  images_telephone = Dir.glob("app/assets/images/*/*").select{|x| x =~ /tel/ } 
  pattern = /(\d+.*).png/
  images_telephone.each do |tel_img|
#    img_out_name = tel_img.scan(pattern).flatten.first + "_cropped.png"
#    img_out = tel_img.sub(pattern,img_out_name)

    puts "Processing #{tel_img}"

    Devil.with_image(tel_img) do |img|
      img.crop(0, 0, 130, 14)
      img.save(tel_img)
    end
  end
end

task :delete_cropped_images do
#  GOCR_DIR = Dir.pwd + "/db/gocr"
#  tel = `gocr -p #{GOCR_DIR}/ -i #{IMG_DIR}/img_#{code}_tel.png -m 130`
#  tel = tel.gsub("I","1")[4..-1]

  images_cropped = Dir.glob("app/assets/images/*/*").select{|x| x =~ /crop/ } 
  pattern = /(\d+.*).png/
  images_cropped.each do |cropped_img|
    File.delete(cropped_img)
  end
end
desc 'Create YAML test fixtures from data in an existing database.
Defaults to development database. Set RAILS_ENV to override.'

task :extract_fixtures => :environment do
  sql = "SELECT * FROM %s"
  skip_tables = ["schema_info"]
  ActiveRecord::Base.establish_connection
  (ActiveRecord::Base.connection.tables - skip_tables).each do |table_name|
    i = "000"
    File.open("#{Dir.pwd}/test/fixtures/#{table_name}.yml", 'w') do |file|
      data = ActiveRecord::Base.connection.select_all(sql % table_name)
      file.write data.inject({}) { |hash, record|
      hash["#{table_name}_#{i.succ!}"] = record
      hash
      }.to_yaml
    end
  end
end

task :setup_ey do
  gemlock = Dir.pwd + "/Gemfile.lock"
  File.delete(gemlock)

  gemfile = Dir.pwd + "/Gemfile"
  new_gem = File.read(gemfile).gsub(/sqlite3/, "mysql2")
  File.open(gemfile, "w") {|file| file.puts new_gem}

  out_dir = Dir.pwd + "/public/assets/"
  img_dir = Dir.pwd + "/app/assets/images/*"
  Dir.mkdir(out_dir)
  `cp -rf #{img_dir} #{out_dir}`
  `cp #{Dir.pwd}/app/assets/stylesheets/styles.css #{Dir.pwd}/public/assets/application.css`
  `bundle install --no-deployment`
end

