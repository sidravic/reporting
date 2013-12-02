class Luggage
  include Mongoid::Document
  include Mongoid::Timestamps
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
  LUGGAGE_TYPE={:carry_on=>"Carry on",:checked=>"Checked",:oversized=>"Oversized"}
  embedded_in :shipment
  embeds_one :tracking_result

  field :size, :type => String
  field :weight_lbs, :type => Integer
  field :length, :type => Integer       #in inches
  field :width, :type => Integer      #in inches
  field :height, :type => Integer     #in inches
  field :state, :type => String, :default => :confirmed
  field :carrier_label_image_base64, :type => String
  field :carrier_label_format, :type => String
  field :carrier_label_html_base64, :type => String
  field :golfer_email, :type => String
  field :golfer_name, :type => String
  field :tracking_id, :type => String
  field :status, :type => String
  field :form_id, :type => String
  field :verified_cost_cents, :type => Integer, :default => 0
  field :price_cents, :type => Integer, :default => 0
  field :insurance_cents, :type => Integer, :default => 0
  has_many :undeliver_notes,:dependent=>:destroy


  field :void_comment
  field :void_user
  field :void_date,:type=>Date
  field :luggage_name, :type => String

  attr_accessible :carrier_label_image_base64, :carrier_label_format, :carrier_label_html_base64,
                  :size, :weight_lbs, :length, :width, :height, :golfer_email, :golfer_name,
                  :tracking_id, :status,:zone_cost_price,:insurance_price_cents

  # attr_accessor :zone_cost_price_cents,:insurance_price_cents

  LUGGAGE_VOID = lambda{|luggages, status|
    begin
      if status
        message = "Your luggages #{luggages.collect(&:tracking_id)} has been successfully voided"
      else
        message = "Your packages could not be voided. It may have to be done manually"
      end

      message
    rescue => e
      if status
        message = "Your luggages have been successfully voided"
      else
        message = "Your luggage could not be successfully voided. It may have to be done manually"
      end
      message
    end
  }

  def self.cancelled?(luggages)
    !(luggages.collect(&:state).include?("accepted"))
  end

  def status
    state
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
    notes << shipment.notes.desc(:created_at)
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
    self.complete_luggage!
    self.shipment.complete_full_shipment
    self.completed?
  end

  def self.total_weight(luggages)
    luggages.inject(0){|sum, luggage| sum += luggage.weight_lbs}
  end
end