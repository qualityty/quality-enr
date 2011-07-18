class Companies < ActiveRecord::Base
  attr_accessible :name, :postal_code, :serial_num, :address, :telephone
  validates_presence_of :name, :postal_code, :serial_num, :address
  validates_uniqueness_of :name, :scope => [:serial_num, :telephone]
  
  scope :done, where("validated = ?", true)
  scope :todo, where("validated = ?", false)

  def self.filter_companies filter
    filter = (filter.nil? ? "all" : filter )
    Companies.send(filter)
  end

  def cycle_todo_button
    validated ? "X" : "O"
  end

  def web
    postal_code.match(/Web/) ? postal_code.scan(/(.*) Web : (.*)/).flatten.last.downcase! : "" 
  end
  def zip_code
    postal_code.scan(/\w+/).first
  end
  def city
    postal_code.scan(/\w+/)[1]
  end

  def images_url img="adresse"
    "/img_install.php?id=#{@serial_num}&part=#{img}"
  end

  def images_url item, serial_num
    "/img_install.php?id=#{serial_num}&part=#{item}"
  end

  def image_dir_path
    tmp_path = [ name.downcase.gsub(/\W/, "_"),
                 serial_num,
               ].join("_")
    tmp_path += "/"
  end
  def image_dir_path_absolute
    Dir.pwd + "/" + image_dir_path
  end

  def image_name item, ext="png"
    serial_num.to_s + "_#{item}." + ext
  end

  def image_absolute_path item, ext="png"
    image_dir_path_absolute + image_name(item)
  end

  def image_path item, ext="png"
    image_dir_path + image_name(item)
  end

  def image item
    "#{image_dir_path + image_name(item)}"
  end

end
