class SkiBag < Shipment

  SKI_BAG_WEIGHT = 25
  SNOWBOARD_BAG_WEIGHT = 25
  DOUBLE_SKI_BAG_WEIGHT = 40
  DOUBLE_SNOWBOARD_BAG_WEIGHT = 40

  #CARRY_ON_MAX_DIMENSIONS = 45
  SKI_BAG_LENGTH = 72
  SKI_BAG_WIDTH  = 8
  SKI_BAG_HEIGHT = 8

  #CHECKED_BAG_MAX_DIMENSIONS = 62
  SNOWBOARD_BAG_LENGTH = 62
  SNOWBOARD_BAG_WIDTH  = 14
  SNOWBOARD_BAG_HEIGHT = 6

  #OVERSIZED_MAX_DIMENSIONS = 74
  DOUBLE_SKI_BAG_LENGTH = 80
  DOUBLE_SKI_BAG_WIDTH  = 10
  DOUBLE_SKI_BAG_HEIGHT = 10

  DOUBLE_SNOWBOARD_BAG_LENGTH = 70
  DOUBLE_SNOWBOARD_BAG_WIDTH  = 14
  DOUBLE_SNOWBOARD_BAG_HEIGHT = 10

  #SNOWBOOT DIMENSIONS
  SNOWBOOT_BAG_LENGTH = 25
  SNOWBOOT_BAG_WIDTH  = 15
  SNOWBOOT_BAG_HEIGHT = 5
  SNOWBOOT_BAG_WEIGHT = 25

  SKI_TYPE = {:ski              => "Ski",
              :snowboard        => "Snowboard",
              :double_ski       => "Double Ski",
              :double_snowboard => "Double Snowboard",
              :snowboot         => "Snow Boot"
  }

  field :size, :type => String
  field :weight_lbs, :type => Integer, :default => 0
  field :length, :type => Integer, :default => 0
  field :height, :type => Integer, :default => 0
  field :width, :type => Integer      #in inches
  # Uses parent state
  #field :state, :type => String, :default => :confirmed
  field :status, :type => String
  field :form_id, :type => String
  field :verified_cost_cents, :type => Integer, :default => 0
  field :void_comment
  field :void_user
  field :void_date,:type => Date
  field :ski_name, :type => String
  field :paid_ski_insurance_cents, :type => Integer

  embeds_one :tracking_result
  has_many :undeliver_notes, :dependent => :destroy

  attr_accessible :size, :weight_lbs, :height_inches, :height,
                  :width_inches, :width, :length_inches, :length, :weight_oz







  def status
    state
  end

  def ski_index(shipment, golfer_name)
    index = 1
    skis = []
    return_shipment = shipment.return_shipment?
    skis = self.order.traveler_ski(shipment.golfer_id).select{|g| g.return_shipment? == return_shipment} if self.order.present?
    return " " if skis.size == 1 || skis.size == 0
    skis.each_with_index do |ski,i|
      index = i+1 if ski.tracking_id == shipment.tracking_id
    end
    return index
  end

  def weight_oz
    (self.weight_lbs * 16).to_i
  end

  def insurance_cost
    0
  end

  def total_price_cost_cents
    price_cents.to_f+insurance_cents.to_f
  end

  def has_recent_tracking_result?
    !self.tracking_result.blank? && !self.tracking_result.tracking_result_expired?
  end

  def tracked_status
    return self.tracking_result.blank? ? self.state : self.tracking_result.status
  end

  def golfer_phone
    nil
  end

  def golfer_first_name
    if golfer_name.to_s.split(" ").size > 1
      golfer_name.to_s.split(" ")[0...-1].join(" ")
    else
      " "
    end
  end

  def golfer_last_name
    golfer_name.to_s if golfer_name.to_s.split(" ").size == 1
    golfer_name.to_s.split[-1]
  end

  def complete
    self.complete_shipment!
    #self.shipment.complete_full_shipment
    self.completed?
  end

  def printable_size
    self.size.humanize
  end

  def concise_printable_size
    case self.size
      when 'ski'
        'SK'
      when 'snowboard'
        'SB'
      when 'double_ski'
        'DSK'
      when 'double_snowboard'
        'DSB'
      when "snowboot"
        'SNB'
    end
  end

  def price_before_discount_and_insurance
    price_before_discount - self.paid_luggage_insurance_cents
  end
end