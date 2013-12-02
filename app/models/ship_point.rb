class ShipPoint
  include Mongoid::Document
  embedded_in :shipment, :inverse_of => :destination_ship_point
  embedded_in :shipment, :inverse_of => :origination_ship_point

  embedded_in :ship_zone, :inverse_of => :origin
  embedded_in :ship_zone, :inverse_of => :destination

  embedded_in :pickup_request_schedule, :inverse_of => :ship_point

  field :company_name, :type => String
  field :attention_name, :type => String
  field :phone_number, :type => String
  field :delivery_address_line, :type => String
  field :delivery_address_line_1, :type => String
  field :city, :type => String
  field :state, :type => String
  field :zip5, :type => String
  field :zip4, :type => String
  field :extension, :type => String
  field :address_type, :type => String, :default => 'standard'

  validates_presence_of :company_name, :delivery_address_line, :city, :state, :zip5
  validates_length_of :company_name, :maximum=>35
  validates_length_of :attention_name, :maximum=>35
  validates_length_of :delivery_address_line,:maximum=>35
  validates_length_of :delivery_address_line_1, :maximum=>35

  def zip=(ambiguous_zip)
    zip_array = ambiguous_zip.to_s.split("-")
    self.zip5=zip_array[0].slice(0,5) unless zip_array[0] == nil
    self.zip4=zip_array[1].slice(0,4) unless zip_array[1] == nil
  end

  def company_name
    return self[:company_name].to_s.slice(0,35)
  end

  def attention_name
    return self[:attention_name].to_s.slice(0,35)
  end
  def attention_name_for_report
    return self[:attention_name].to_s.slice(0,35).split(",").join(" ") if self[:attention_name]
  end
  def zip
    result = zip5
    if("#{zip4}" != "")
      result = "#{result}-#{zip4}"
    end
    return result
  end

  def one_line_address
    return "#{self.delivery_address_line} #{self.city} #{self.state} #{self.zip}"
  end

  def short_address
    [company_name, city, state].compact.join(', ')
  end

  def pro_name
    "#{self.attention_name} - #{self.phone_number}"
  end

end
ShipPoint.create_indexes