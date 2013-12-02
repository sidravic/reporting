class GolfBag < Shipment

  LARGE_PACKAGE_WEIGHT_OZ = 992
  LARGE_PACKAGE_LENGTH_INCHES = 50
  LARGE_PACKAGE_WIDTH_INCHES = 16
  LARGE_PACKAGE_HEIGHT_INCHES = 13

  SMALL_PACKAGE_WEIGHT_OZ = 672
  SMALL_PACKAGE_LENGTH_INCHES = 50
  SMALL_PACKAGE_WIDTH_INCHES = 16
  SMALL_PACKAGE_HEIGHT_INCHES = 8

  scope :golf_bags, where(:_type => 'GolfBag')
  validates :weight_oz, :inclusion => { :in => [SMALL_PACKAGE_WEIGHT_OZ, LARGE_PACKAGE_WEIGHT_OZ ] }


  def golfbag_index(shipment, golfer_name)
    index = 1
    golf_bags = []
    return_shipment = shipment.return_shipment?
    golf_bags = self.order.traveler_golfbag(shipment.golfer_id).select{|g| g.return_shipment? == return_shipment} if self.order.present?
    return "" if golf_bags.size == 1 || golf_bags.size == 0
    golf_bags.each_with_index do |g,i|
      index = i+1 if g.tracking_id == shipment.tracking_id
    end
    return index
  end

  def weight_lbs
    return (weight_oz.to_f / 16.0).to_f
  end

  def size
    result = nil
    if(weight_oz == LARGE_PACKAGE_WEIGHT_OZ)
      result = "LARGE"
    elsif(weight_oz == SMALL_PACKAGE_WEIGHT_OZ)
      result = "SMALL"
    else
      raise "Illegal Package weight: #{self.weight_oz} in package: #{self.inspect}"
    end

    result
  end

  def printable_size
    case self.size
      when "SMALL"
        "Standard"
      when "LARGE"
        "XL"
    end
  end

  def concise_printable_size
    case self.size
      when "SMALL"
        "GS"
      when "LARGE"
        "GX"
    end
  end

  def price_before_discount_and_insurance
    price_before_discount - self.paid_insurance_cents
  end
end