class Companies < ActiveRecord::Base
  attr_accessible :name, :postal_code, :serial_num, :address, :telephone
  validates_presence_of :name, :postal_code, :serial_num, :address


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
