class Package
  include Mongoid::Document

  LARGE_PACKAGE_WEIGHT_OZ = 992
  LARGE_PACKAGE_LENGTH_INCHES = 50
  LARGE_PACKAGE_WIDTH_INCHES = 16
  LARGE_PACKAGE_HEIGHT_INCHES = 13

  SMALL_PACKAGE_WEIGHT_OZ = 672
  SMALL_PACKAGE_LENGTH_INCHES = 48
  SMALL_PACKAGE_WIDTH_INCHES = 12
  SMALL_PACKAGE_HEIGHT_INCHES = 12

  SMALL = "SMALL"
  LARGE = "LARGE"

  CANCELLED = "cancelled"
  ACCEPTED = "accepted"
  CONFIRMED = "confirmed"
  COMPLETE = "complete"

  SHIPMENT_VOID = lambda{|tracking_id, status|
    if status
      message = "Your shipment with tracking id #{tracking_id} has been successfully voided"
    else
      message = "Your shipment with tracking id #{tracking_id} could not successfully voided. You may have to manually void the shipment."
    end

    message
  }

  PACKAGE_VOID = lambda{|packages, status|
    begin
      if status
        message = "Your packages #{packages.collect(&:tracking_id)} has been successfully voided"
      else
        message = "Your packages could not be voided. It may have to be done manually"
      end

      message
    rescue => e
      if status
        message = "Your packages have been successfully voided"
      else
        message = "Your package could not be successfully voided. It may have to be done manually"
      end

      message
    end
  }
  embedded_in :shipment
  embeds_one :tracking_result

  field :person_id, :type => String
  field :weight_oz, :type => Integer
  field :length_inches, :type =>Integer
  field :width_inches, :type =>Integer
  field :height_inches, :type =>Integer
  field :carrier_label_image_base64, :type => String
  field :carrier_label_format, :type => String
  field :carrier_label_html_base64, :type => String
  field :golfer_email, :type => String
  field :golfer_name, :type => String
  field :golfer_phone, :type => String
  field :tracking_id, :type => String
  field :status, :type => String, :default => "confirmed"
  field :verified_cost_cents, :type => Integer, :default => 0
  field :form_id, :type => String
  field :void_comment
  field :void_user
  field :void_date,:type=>Date
  field :price_cents, :type => Integer, :default => 0
  field :insurance_cents, :type => Integer, :default => 0
  has_many :undeliver_notes,:dependent=>:destroy

  attr_accessible :carrier_label_image_base64, :carrier_label_format, :carrier_label_html_base64, :golfer_name, :golfer_email, :tracking_id, :status,:golfer_phone
  validates :weight_oz, :inclusion => { :in => [SMALL_PACKAGE_WEIGHT_OZ, LARGE_PACKAGE_WEIGHT_OZ ] }

  # attr_accessor :zone_cost_price_cents,:insurance_price_cents



  ########################################################################################################
  # Package.cancelled?
  # Parameters:
  # packages <Array:Package>
  # Description: Checks if each of the packages in the array is cancelled? or in a non accepted state
  #########################################################################################################
  def self.cancelled?(packages)
    packages = packages.first.shipment.reload.packages.find(packages.collect(&:_id))
    (!packages.collect(&:status).include?("accepted")) ? true : false
  end

  def weight_lbs
    return (weight_oz.to_f / 16.0).to_f
  end

  # Cancels an individual package in a multibag shipment
  def cancel
    self.update_attributes(:status => CANCELLED)
  end

  def accept
    self.update_attributes(:status => ACCEPTED)
  end

  def complete
    self.update_attributes(:status => COMPLETE)
    self.shipment.complete_full_shipment
    self.status == COMPLETE
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
    return result
  end

  def package_insurance_cost
    shipment.unit_insurance_cost
  end

  def show_package_and_shipment_notes
    notes = []
    notes << shipment.notes.desc(:created_at)
    notes << undeliver_notes.desc(:created_at)
    notes.flatten.sort! { |a,b| b.created_at <=> a.created_at }
  end

  def insurance_cost
    shipment.unit_insurance_cost
  end

  def has_recent_tracking_result?
    !self.tracking_result.blank? && !self.tracking_result.tracking_result_expired?
  end

  def tracked_status
    return self.tracking_result.blank? ? self.state : self.tracking_result.status
  end

  # Used mainly UI in shipping page
  def total_price_cost_cents
    price_cents.to_f+insurance_cents.to_f
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
end

Package.create_indexes