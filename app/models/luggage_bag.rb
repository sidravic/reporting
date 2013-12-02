class LuggageBag < Shipment

  CARRY_ON_WEIGHT = 25
  CHECKED_BAG_WEIGHT = 50
  OVERSIZED_WEIGHT = 72

  CARRY_ON_MAX_DIMENSIONS = 45
  CARRY_ON_LENGTH = 25
  CARRY_ON_WIDTH = 15
  CARRY_ON_HEIGHT = 5

  CHECKED_BAG_MAX_DIMENSIONS = 62
  CHECKED_BAG_LENGTH = 26
  CHECKED_BAG_WIDTH = 16
  CHECKED_BAG_HEIGHT = 20

  OVERSIZED_MAX_DIMENSIONS = 74
  OVERSIZED_BAG_LENGTH = 41
  OVERSIZED_BAG_WIDTH = 11
  OVERSIZED_BAG_HEIGHT = 22

  LUGGAGE_TYPE = {:carry_on => "Carry on",
                  :checked => "Checked",
                  :oversized=>"Oversized"
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
  field :void_date,:type=>Date
  field :luggage_name, :type => String

  embeds_one :tracking_result
  has_many :undeliver_notes,:dependent=>:destroy

  attr_accessible :size, :weight_lbs, :height_inches, :height, :width_inches, :width, :length_inches, :length, :weight_oz

  def status
    state
  end

  def luggage_index(shipment, golfer_name)
    index = 1
    luggages = []
    return_shipment = shipment.return_shipment?
    luggages = self.order.traveler_luggage(shipment.golfer_id).select{|g| g.return_shipment? == return_shipment} if self.order.present?
    return "" if luggages.size == 1 || luggages.size == 0
    luggages.each_with_index do |luggage,i|
      index = i+1 if luggage.tracking_id == shipment.tracking_id
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

  def show_package_and_shipment_notes
    notes = []
    notes << self.shipment_notes.desc(:created_at)
    notes << undeliver_notes.desc(:created_at)
    notes.flatten.sort! { |a,b| b.created_at <=> a.created_at }
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
      when 'carry_on'
        'CO'
      when 'oversized'
        'OS'
      when 'checked'
        'CB'
    end
  end

  def price_before_discount_and_insurance
    price_before_discount - self.paid_luggage_insurance_cents
  end
end