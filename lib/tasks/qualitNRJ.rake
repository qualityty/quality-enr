# coding: utf-8

# TODO: Ajouter un bouton pour valider la ligne une fois l'adresse validée
# TODO: Ajouter un bouton pour Afficher/cacher les lignes validées

task :update_database => :environment do
  require "selenium/client"
  require 'open-uri'
  require 'nokogiri'

  url = "http://www.qualit-enr.org"
  annuaire = "/annuaire/index.html" 
  IMG_DIR = "app/assets/images"
  GOCR_DIR = Dir.pwd + "/db/gocr"

  codes_postaux = (97000..100000).step(1000).map{|x| x.to_s.rjust(5, "0")}
  #codes_postaux = ["83110"] 

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

  def correct_address addr
    group_replace = {
      /.(ruedela)\w/i => " rue de la ",
      /.(avenuedela)\w/i => " avenue de la ",
      /\w(Rue)\w/i => " rue ",
      / (Rue)[a-z]/i => "rue ",
      /\w(Rue) /i => " rue",
      /\w(avenue)\w/i => " avenue ",
      / (avenue)\w/i => "avenue ",
      /\w(avenue) /i => " avenue",
      /\w(chemin)\w/i => " chemin ",
      / (chemin)\w/i => "chemin ",
      /\w(chemin) /i => " chemin",
      /(jean)\w/i => "jean ",
      /(henri)\w/i => "henri ",
      /(marechal)\w/i => "marechal ",
      /(jules)\w/i => "jules ",
      /[a-z](i5) /i => "is",
      /(Ioi) / => "101",
      /(Io) / => "10",
      /(Ii) / => "11",
      /(I I) / => "11",
      /(I)\d+ /i => "1",
      /(I )\d+ /i => "1",
      /\d*( I) /i => "1",
      /\A(I) /i => "1",
      /\d+( I) /i => "1",
      /\d+( O) /i => "0",
      /[a-z](05)[a-z]/i => "os",
      /[a-z](50)[a-z]/i => "so",
      /[a-z](55)[a-z]/i => "ss",
      /[a-z](55)[ |\n]/i => "ss",
      /[a-z](55)\z/i => "ss",
      /[a-z](5)[a-z]/i => "s",
      /[a-z](5)[ |\n]/i => "s",
      /[a-z](5)\z/i => "s",
      / (5)[a-z]/i => "s",
      / (I)'/i => "l",
    }
    group_replace.each do |k,v|
      addr[k,1] = v while addr.match(k)
    end

    substitution = {
      /Ru\|E/i => "rue",
      /Rue/ => "rue",
      /u|/i => "u",
      / E/i => "e",
      /Ii/i => "11"
    }
    substitution.each do |k,v|
      addr.gsub(k,v)
    end
    addr
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

  selenium = Selenium::Client::Driver.new("localhost", 4444, "*chrome", "#{url}#{annuaire}", 20)
  selenium.start

  codes_postaux.each do |code_postal|
    begin
      selenium.open annuaire
      # Fill in the form
      selenium.click "rec4"
      puts "* " + code_postal
      selenium.set_speed 500
      selenium.click "rec9_tb"
      selenium.type_keys 'rec9_tb', code_postal
      selenium.set_speed 1300
      begin
        selenium.click "autocomplete_li_rec9_tb_0"
      rescue Exception => ex
        puts ex
      end

      selenium.fire_event "css=div.bouton_lancer", "click"
      selenium.wait_for_page_to_load
    rescue Exception => ex
      puts ex
      code_postal = "#{code_postal.to_i + 100}"
      unless code_postal[-3..-1].to_i > 100
        puts "\n- wrong postal code, retrying...\n"
        selenium.stop
        selenium.start
        retry
      else
        selenium.stop
      end
    end
    selenium.fire_event "//div[@id='list']/table/tbody/tr[2]", "click"
    selenium.wait_for_page_to_load
    selenium.set_speed 150

    keep_crawling, last_one = true, false

    while keep_crawling do

      @company = parse_company_page selenium.get_html_source, url
      if Companies.find_by_serial_num(@company.serial_num)
        puts "Company #{@company.name} is already Registered\n"
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
            @company[value.to_sym] = `gocr #{args}`.gsub("I","1").gsub("O", "0")[4..-1].strip
          else
            @company[value.to_sym] = `gocr #{args}`.titleize.strip
          end
        end
        @company.address = correct_address(@company.address)
        x = @company.telephone.dup.gsub(" ", "")
        @company.telephone = (0..x.size-2).step(2).map{|i| x[i..i+1]}.join(" ")

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
  images_telephone = Dir.glob("app/assets/images/*/*").select{|x| x =~ /tel/ } 
  pattern = /(\d+.*).png/
  images_telephone.each do |tel_img|
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


task :strip_n => :environment do
  Companies.all.each do |company|
    puts company.telephone
    company.telephone = company.telephone.strip
    company.address = company.address.strip
    company.save!
    puts company.telephone
  end
end

task :clean_up_addresses => :environment do

  def correct_address addr
    group_replace = {
      /.(ruedela)\w/i => " rue de la ",
      /.(avenuedela)\w/i => " avenue de la ",
      /\w(Rue)\w/i => " rue ",
      / (Rue)[a-z]/i => "rue ",
      /\w(Rue) /i => " rue",
      /\w(avenue)\w/i => " avenue ",
      / (avenue)\w/i => "avenue ",
      /\w(avenue) /i => " avenue",
      /\w(chemin)\w/i => " chemin ",
      / (chemin)\w/i => "chemin ",
      /\w(chemin) /i => " chemin",
      /(jean)\w/i => "jean ",
      /(henri)\w/i => "henri ",
      /(marechal)\w/i => "marechal ",
      /(jules)\w/i => "jules ",
      /[a-z](i5) /i => "is",
      /(Ioi) / => "101",
      /(Io) / => "10",
      /(Ii) / => "11",
      /(I I) / => "11",
      /(I)\d+ /i => "1",
      /(I )\d+ /i => "1",
      /\d*( I) /i => "1",
      /\A(I) /i => "1",
      /\d+( I) /i => "1",
      /\d+( O) /i => "0",
      /[a-z](05)[a-z]/i => "os",
      /[a-z](50)[a-z]/i => "so",
      /[a-z](55)[a-z]/i => "ss",
      /[a-z](55)[ |\n]/i => "ss",
      /[a-z](55)\z/i => "ss",
      /[a-z](5)[a-z]/i => "s",
      /[a-z](5)[ |\n]/i => "s",
      /[a-z](5)\z/i => "s",
      / (5)[a-z]/i => "s",
      / (I)'/i => "l",
      /(u\|)[A-Z]/ => "u",
      /(0550)/ => "osso",
    }
    group_replace.each do |k,v|
      addr[k,1] = v while addr.match(k)
    end

    substitution = {
      /Ru\|E/i => "rue",
      /Rue/ => "rue",
      / E/i => "e",
      /Ii/i => "11"
    }
    substitution.each do |k,v|
      addr.gsub(k,v)
    end
    addr
  end

  count = 0
  Companies.all.each do |company|
    tmp = correct_address company.address.dup
    unless company.address == tmp
      puts "#{count}::Old: " + company.address
      puts "#{count}::New: " + tmp
      puts
      count += 1
    end
    #company.address = correct_address company.address.dup
    #company.address.capitalize!
    #company.save!
  end
end

task :normalise_tel => :environment do
  Companies.all.each do |company|
    x = company.telephone.dup.gsub(" ", "")
    company.telephone = (0..x.size-2).step(2).map{|i| x[i..i+1]}.join(" ")
    company.save!
  end
end
