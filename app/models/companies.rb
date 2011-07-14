IMG_DIR = "public/images"

class Companies < ActiveRecord::Base
  attr_accessible :name, :postal_code, :serial_num, :address, :telephone
  validates_presence_of :name, :postal_code, :serial_num, :address, :telephone

  def image_dir_path
    tmp_path = [IMG_DIR,
                "/",
                @name.downcase.gsub(/\W/, "_") + "_" + @serial_num,
              ].join("/")
  end

  def images_url img="adresse"
    "/img_install.php?id=#{@serial_num}&part=#{img}"
  end
  #install.php?id=40958&part=adresse


end
