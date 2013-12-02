require 'base64'

class Shipment
  include Mongoid::Document
  include Mongoid::Timestamps

  paginates_per 25

  NON_STANDARD_ZONES = [25, 22, 23, 17, 96]

  STATUS_FILTERS = {
      :new_shipment => 1,
      :bag_pickup => 2,
      :expected_delivery => 3
  }

  field :state, :default => :created.to_s

  field :tracking_id, :type => String, :default => lambda { UniqueIdGeneratorHelper.generate();}

  embeds_one :destination_ship_point, :class_name => 'ShipPoint'
  embeds_one :origination_ship_point, :class_name => 'ShipPoint'
  has_one    :stored_destination_ship_point, :class_name => 'StoredShipPoint'
  has_one    :stored_origination_ship_point, :class_name => 'StoredShipPoint'
  has_one    :insurance_log, :dependent => :destroy

  embeds_many :packages
  embeds_many :luggage
  embeds_many :overage_comments

  embeds_one :tracking_result
  belongs_to :user
  belongs_to :micro_site
  belongs_to :grouped_pickup_request

  field :golfer_name, :type => String
  field :golfer_email, :type => String
  field :golfer_phone, :type => String

  field :carrier, :type => String
  field :carrier_tracking_id, :type => String
  field :carrier_label_image_base64, :type => String
  field :carrier_label_format, :type => String
  field :carrier_label_html_base64, :type => String
  # Used as part of the two-phase shipment scheduling
  field :carrier_digest, :type => String
  # ID tied the the request for transit time estimates
  field :carrier_transit_estimate_id, :type =>String
  # The price we are charging our customers
  field :price_cents, :type =>Integer
  field :discount_cents, :type => Integer, :default => 0
  # The cost we get back from the carrier
  field :verified_cost_cents, :type => Integer, :default => 0  # Actual cost cents obtained from UPS
  field :cost_cents, :type =>Integer            # Cost cents computed using emperical data - from transactions already made.
  field :insurance_cents, :type=>Integer
  field :paid_insurance_cents, :type => Integer, :default => 0
  field :service_type, :type =>String
  field :bag_count, :type => Integer

  field :pro_id, :type => String
  field :pickup_date, :type=>Date
  index({pickup_date: 1})
  index({created_at: 1})
  index({tracking_id:1}, {:unique => true})
  index({pickup_date:1})
  index({state:1})
  index({origination_club_id:1})
  index({carrier_tracking_id:1})
  index({destination_club_id:1})
  index({golfer_name:1})
  index({desired_arrival_date:1})
  index({created_at:1})
  index({pickup_date:1})
  field :delivered_date, :type=>Date
  field :source,:type=>String
  field :desired_arrival_date, :type=>Date
  field :pickup_ready_time, :type=>String
  field :pickup_close_time, :type=>String
  field :origination_club_id, :type=>String
  field :destination_club_id, :type=>String
  field :salesman_id, :type=>String
  field :zone, :type=>Integer
  field :return_pickup_date, :type => Date
  field :return_arrival_date, :type => Date
  field :roundtrip_shipment, :type => String
  field :coupled_tracking_id, :type => String
  field :void_comment
  field :void_user
  field :void_date,:type=>Date
  field :misc_info, :type => String
  field :payment_mode,:type=>String
  field :carrier, :type => String
  field :drop_off_at_ups, :type => Boolean, :default => false #used for both UPS and FEDEX (drop_off_at_carrier)
  field :form_id, :type => String
  field :luggage_count, :type => Integer, :default => 0
  field :affiliate_id
  field :enqueued, :type => Boolean, :default => false
  field :luggage_insurance_cents, :type => Integer, :default => 0  # The amount of coverage requested for.
  field :paid_luggage_insurance_cents, :type => Integer, :default => 0 # Amount paid for that coverage.
  field :weight_oz, :type => Integer
  field :length_inches, :type => Integer
  field :width_inches, :type => Integer
  field :height_inches, :type => Integer
  field :carrier_code, :type => String
  field :golfer_id, :type => String       # enables to uniquely identify each shipment to a golfer.

  has_many :notes,:dependent=>:destroy
  has_many :undeliver_notes,:dependent=>:destroy
  has_many :shipment_notes,:dependent=>:destroy
  has_one :upgrade

  embeds_one :authorize_net_profile, :as => :authorize_netable

  has_many :pickup_requests
  belongs_to :coupon, :inverse_of => :shipment

  validates_uniqueness_of :tracking_id
  after_create :store_ship_unique_points_in_user_address_book

  attr_accessor :void_shipment_response, :order_id

  attr_accessible :roundtrip_shipment, :coupled_tracking_id, :golfer_name, :golfer_email, :golfer_phone,
                  :carrier_label_format, :carrier_label_html_base64, :carrier_label_image_base64, :status,
                  :misc_info, :drop_off_at_ups, :enqueued, :weight_oz, :height_inches, :width_inches, :length_inches


  scope :for_pickups, where(:state => "accepted")
  scope :confirmed_shipments, where(:state => "confirmed", :created_at.lt => Date.today - 1.day).desc(:created_at).limit(10)

  # TODO make 3 small scope
  scope :undelivered_shipments, Proc.new{ |start_date, end_date|
    start_date = (Date.today - 7.days).to_time if start_date.blank?
    end_date = Date.today.to_time if end_date.blank?
    any_of({:pickup_date.gte => start_date, :pickup_date.lte => end_date},
           {:desired_arrival_date.gte => start_date, :desired_arrival_date.lte => end_date}).
        where(:state.in => ["accepted"], :state.nin => ["delivered"]).without(:carrier_digest, :carrier_label_image_base64, :carrier_label_html_base64)
  }
  scope :undelivered_shipments_for_pickup, Proc.new{ |start_date, end_date|
    start_date = (Date.today - 7.days).to_time if start_date.blank?
    end_date = Date.today.to_time if end_date.blank?
    where({:pickup_date.gte => start_date, :pickup_date.lte => end_date}).
        where(:state.in => ["accepted"], :state.nin => ["delivered"]).without(:carrier_digest, :carrier_label_image_base64, :carrier_label_html_base64)
  }
  scope :undelivered_shipments_for_delivery, Proc.new{ |start_date, end_date|
    start_date = (Date.today - 7.days).to_time if start_date.blank?
    end_date = Date.today.to_time if end_date.blank?
    where({:desired_arrival_date.gte => start_date, :desired_arrival_date.lte => end_date}).
        where(:state.in => ["accepted"], :state.nin => ["delivered"]).without(:carrier_digest, :carrier_label_image_base64, :carrier_label_html_base64)
  }

  scope :search, Proc.new{|search_params|
    if search_params.present?
      regexp = Regexp.new(/.*#{search_params.strip}.*/i, true)
      where(:golfer_name => regexp)
    else
      where(:state.in => ["accepted"], :state.nin => ["delivered"])
    end
  }

  scope :v2_search, Proc.new{|search_params|
    if search_params.present?
      regexp = Regexp.new(/.*#{search_params.strip}.*/i, true)
      where(:golfer_name => regexp, :_type.in=>["GolfBag","LuggageBag"])
    else
      where(:_type.in=>["GolfBag","LuggageBag"],:state.in => ["accepted"], :state.nin => ["delivered"])
    end
  }

  alias :drop_off_at_carrier? :drop_off_at_ups?

  def shipment_order_id
    self.order.order_id rescue nil
  end

  def coupled_shipment
    return Shipment.where(:tracking_id => self.coupled_tracking_id).first
  end

  def voidable?
    self.current_state.name == :accepted || self.current_state.name == :completed
  end

  def email
    return self.golfer_email
  end

  def insurance_dollars
    return self.insurance_cents/100.00
  end

  def unit_insurance_cost
    self.insurance_dollars >1000 ? ((self.insurance_dollars - 1000)/100.0)*0.75 : 0
  end

  # first $1000 is free then every $100 is $0.65
  def insurance_cost
    if self.insurance_dollars >1000
      cost = ((self.insurance_dollars - 1000)/100.0)*0.75
      if self.packages.length > 1 && self.luggage.present?
        cost*(self.packages.length+self.luggage.length)
      elsif self.packages.length > 1
        cost*self.packages.length
      else
        cost
      end
    else
      0
    end
  end

  def price_dollars
    if self.price_cents.nil?
      return 0.00
    else
      return self.price_cents/100.00
    end
  end

  def payment_amount_dollars
    if self.payment_amount_cents.nil?
      return 0.00
    else
      return self.payment_amount_cents/100.00
    end
  end
  def roundtrip_cost
    @rountrip_human_price = self.price_cents + self.coupled_shipment.price_cents
    return "#{(@rountrip_human_price.to_f / 100.0)}"
  end

  def cost_dollars
    if self.cost_cents.nil?
      return 0.00
    else
      return self.cost_cents.to_f/100.00
    end
  end

  def label_image_binary
    Base64.decode64(carrier_label_image_base64)
  end

  def label_html_binary
    Base64.decode64(carrier_label_html_base64)
  end

  #used in conjunction with Shipsticks::AuthorizeNet::Chargeable
  def billing_id
    "shipsticks_tracking_id:#{tracking_id}"
  end

  def ledger_account
    return billing_id
  end

  def roundtrip_shipment?
    return !self.coupled_tracking_id.blank?
  end

  # identifies if this is the return leg
  def return_shipment?
    self.roundtrip_shipment.to_s.strip == "true" ? true : false
  end

  def queued_shipment?
    (self.pickup_date - 2.weeks) > Date.today
  end

  def shipped_within_state?
    self.origination_ship_point.state == self.destination_ship_point.state
  end



  def complete_shipment_voided?(response_hash)
    response_hash["VoidShipmentResponse"].present? && response_hash["VoidShipmentResponse"]["Status"].present? && response_hash["VoidShipmentResponse"]["Status"]["StatusType"].present? && response_hash["VoidShipmentResponse"]["Status"]["StatusType"]["Code"] == "1"
  end

  def update_package_status_on_complete_void(response_hash)
    self.packages.where(:status => Package::ACCEPTED).each do |package|
      if package.status != Package::CANCELLED
        package.update_attributes({:status => Package::CANCELLED,:void_date=>self.void_date,:void_comment=>self.void_comment,:void_user=>self.void_user})
      end

    end
  end
  def update_luggage_status_on_complete_void(response_hash)
    self.luggage.where(:state => "accepted").each do |luggage|
      luggage.cancel_luggage!
    end
  end




  def origination_club
    Rails.logger.error self.id
    if !self.origination_club_id.nil? && !self.origination_club_id.empty?
      return Club.find(self.origination_club_id)
    end
    return nil
  end

  def origination_club_name
    club = self.origination_club
    if club.blank?
      return "other"
    else
      return club.name || club.id
    end
  end

  def destination_club
    if !self.destination_club_id.nil? && !self.destination_club_id.empty?
      return Club.find(self.destination_club_id)
    end
    return nil
  rescue => e
    Rails.logger.error("[DESTINATION CLUB NOT FOUND] #{e.message} \n #{e.backtrace}")
    nil
  end

  def destination_club_name
    club = self.destination_club
    if club.nil?
      return "other"
    else
      return club.name
    end
  end

  def pro
    if !self.pro_id.nil?
      return User.find(self.pro_id)
    end
    return nil
  end

  def pro_name
    pro = self.pro
    if pro.nil?
      return "No Pro"
    else
      return pro.name
    end
  end
  def pro_name_for_report
    if pro.nil?
      return "No Pro"
    else
      return pro.name.split(",").join(" ")
    end
  end

  #################################################################################
  # update_package_status
  # Description: Verifies if a shipment is paid for by checking through
  #              Journaltransactions
  #
  ##################################################################################
  def paid?
    regexp = Regexp.new(/.*#{self.tracking_id}.*/i, true)
    records_count = JournalTransaction.any_of([{"journal_entries.description" => regexp}, {"journal_entries.shipment_tracking_id" => self.tracking_id}]).count.to_i
    (records_count > 0)
  end

  def payment_transaction_id
    regexp = Regexp.new(/.*#{self.tracking_id}.*/i, true)
    journal_transaction = JournalTransaction.any_of([{"journal_entries.description" => regexp}, {"journal_entries.shipment_tracking_id" => self.tracking_id}]).last
    journal_transaction.id.to_s
  end

  def authnet_transaction_id
    tid = ""

    if (self.instance_of?(GolfBag) || self.instance_of?(SkiBag) || self.instance_of?(LuggageBag))
      order = self.order
      tid = order.transaction_id if order && (order.payment_method != "club_billing")
    else
      if payment_mode !="club_billing"
        payment_tracking = PaymentTracking.where(:shipment_tracking_id=>self.tracking_id).first
        payment_tracking = PaymentTracking.where(:shipment_tracking_id => self.coupled_shipment.tracking_id).first if payment_tracking.nil? && self.coupled_shipment.present?
        tid = payment_tracking.present? ? JSON.parse(payment_tracking.sim_response)["x_trans_id"] : ""
      end
    end

    tid
  end

  def has_recent_tracking_result?
    !self.tracking_result.blank? && !self.tracking_result.tracking_result_expired?
  end

  def tracked_status
    return self.tracking_result.blank? ? self.state : self.tracking_result.status
  end

  def payment_amount_cents
    result = 0
    if( !self.authorize_net_profile.blank? )
      # Payed by guest credit card
      journal_transactions = JournalTransaction.where("journal_entries.credit_account"=>"shipsticks_tracking_id:#{self.tracking_id}").to_a
    end
    # If we didn't find anything the first way, let's try another way.  This is to take into account if
    # for some reason there is an authorize_net_profile but there are not journal_entries.  Not sure why
    # this happens.
    if( journal_transactions.blank? || journal_transactions.size == 0 || self.authorize_net_profile.blank? )
      # Payed by on file credit card
      journal_transactions = JournalTransaction.where("journal_entries.description"=>"ShipSticks Tracking ID: #{self.tracking_id}").to_a
    end
    Rails.logger.debug journal_transactions.size
    if(journal_transactions.size == 1)
      result = journal_transactions.first.journal_entries.first.amount_cents
    elsif (journal_transactions.size > 1)
      journal_transactions.each do |tx|
        result = result + tx.journal_entries.first.amount_cents
      end
    end
    return result
  end

  def get_club_billed_by_sales
    shipment=  (self.coupled_shipment.present? && self.roundtrip_shipment) ? self.coupled_shipment : self

    regexp = Regexp.new(/.*#{shipment.tracking_id}.*/i, true)
    journal_transactions = JournalTransaction.any_of([{"journal_entries.description" => regexp}, {"journal_entries.shipment_tracking_id" => shipment.tracking_id}])
    debit_accounts = journal_transactions.collect{|x| x.journal_entries.collect{|y| y.debit_account}}.flatten
    clubs = debit_accounts.select{|da| da.split(":").first == "club"}
    clubs[0].split(":").last if clubs.present?
  end

  def club_billing_process(options = {:misc_options => "", :golfer_details => []})
    shipment = Shipsticks::Ship::Pricing.confirm_shipment(self, options)
    coupled_shipment = shipment.coupled_shipment
    Shipsticks::Ship::Pricing.confirm_shipment(coupled_shipment, options) if coupled_shipment.present?
    if shipment && shipment.confirmed?
      schedule_pickup_requests
      coupled_shipment.schedule_pickup_requests if coupled_shipment && coupled_shipment.confirmed?
    else
      raise "ShipmentHasNotBeenConfirmed"
    end
  end

  def enqueue_package_cost
    Resque.enqueue(UpsPackageCost, self.tracking_id) if self.carrier == "UPS"
  end

  def email_salutation
    self.micro_site.present? ? self.micro_site.email_salutation : ""
  end

  def get_carrier_tracking_ids
    self.packages.length > 1 ? self.packages.collect(&:tracking_id).flatten : Array(self.carrier_tracking_id)
  end

  def get_carrier_tracking_ids_for_csv
    self.packages.length > 1 ? self.packages.collect{|p| p.status =='cancelled' ? p.tracking_id+"(void)" : p.tracking_id} : Array(self.carrier_tracking_id)
  end

  def allowed_carrier
    global_carrier = Setting.config.carrier
    return global_carrier if Sett ing.override_club_settings?
    club_carrier = self.micro_site.club.carrier_selection if self.micro_site.present? && self.micro_site.club && self.micro_site.club.has_carrier_selection
    club_carrier ||= self.origination_club.carrier_selection if self.origination_club.present? && self.origination_club.has_carrier_selection

    # when the roundtrip shipment needs to use the same carrier as the outbound because
    # the outbound shipment has a carrier selection
    club_carrier = self.destination_club.carrier_selection if self.return_shipment? && self.destination_club.present? && self.destination_club.has_carrier_selection?
    if club_carrier.present? && club_carrier.upcase != "BOTH"
      authorized_carrier = club_carrier
    else
      authorized_carrier = global_carrier
    end

    authorized_carrier
  end

  def populate_luggage(luggage, golfer_names, luggage_insurance = 20000)
    ups_insurance_feature_enabled = FeatureFlag.enabled?(:ups_insurance)

    if luggage.present?
      if ups_insurance_feature_enabled
        insurance_per_luggage = (luggage_insurance.to_i/luggage.size)
      end

      luggage.each do |key, size|
        luggage_type = (size.to_s + "_luggage").to_sym
        new_luggage_item = Factory.build(luggage_type)
        new_luggage_item.insurance_cents = insurance_per_luggage if ups_insurance_feature_enabled
        new_luggage_item.golfer_name = (golfer_names.present?) ? golfer_names[key] : self.golfer_name
        self.luggage << new_luggage_item
      end

      self.luggage_count = self.luggage.size.to_i
    end
  end

  def insurance_per_luggage_item
    (self.luggage_insurance_cents/self.luggage.size).to_i
  end

  def close_date_time
    DateTime.strptime(self.pickup_close_time, "%H%M")
  end

  def close_time_passed?
    DateTime.now > close_date_time
  end

  def luggage_bag?
    self.instance_of?(LuggageBag)
  end

  def golf_bag?
    self.instance_of?(GolfBag)
  end

  def ski_bag?
    self.instance_of?(SkiBag)
  end

  #============================================================================
  # Pricing
  # ========
  #
  # Interface
  # ----------
  # shipment.pricing
  #
  # Returns
  # --------
  # Returns the entire hash that needs to be rendered.
  # {:price_cents => shipment.price_cents,
  #  :total_price_cents => shipment.price_cents,
  #  :tracking_id => shipment.tracking_id,
  #  :service_type => shipment.service_type,
  #  :bag_count => shipment.bag_count,
  #  :package_cost => package_cost, :insurance_cost => shipment.insurance_cost,
  #  :package_insurance_cost => shipment.insurance_cost/shipment.bag_count, :package_ship_cost => package_ship_cost}
  #============================================================================
  def pricing
    package_cost = round_to(((self.price_cents - (self.insurance_cost*100))/self.bag_count)/100.0,2)
    package_ship_cost = round_to((self.price_cents/self.bag_count)/100.0,2)
    result = {:price_cents => self.price_cents, :total_price_cents => self.price_cents,
              :tracking_id => self.tracking_id, :service_type => self.service_type,
              :bag_count => self.bag_count, :package_cost => package_cost, :insurance_cost => self.insurance_cost,
              :package_insurance_cost => self.insurance_cost/self.bag_count, :package_ship_cost => package_ship_cost,
              :total_discount => self.discount_cents
    }
    result
  end
  # ===========================================================================
  # Post Payment processing
  # Creates a CIM profile if it doesn't exists
  # Identifies a payment profile and creates a payment transaction
  # ===========================================================================
  def post_payment_process(transaction_id, options = {:misc_info => "", :golfer_details => []})
    #self.charge_for_shipment
    #shipment = Shipsticks::Ship::Pricing.confirm_shipment(self, options)
    if self && self.confirmed?
      coupled_shipment = self.coupled_shipment
      payment_description = "Payment ID: #{transaction_id}"
      Ledger.new(self,payment_description,self,self.price_cents).add_shipping_transaction
      Ledger.new(coupled_shipment,payment_description,coupled_shipment,coupled_shipment.price_cents).add_shipping_transaction if coupled_shipment.present?
      schedule_pickup_requests
      coupled_shipment.schedule_pickup_requests if coupled_shipment && coupled_shipment.confirmed?
    else
      raise "ShipmentHasNotBeenConfirmed"
    end
  end


  # ===========================================================================
  # Process Payment
  # Called for payments made for logged in users with stored card information
  # ===========================================================================
  def process_payment(paying_user, amount, options = {:misc_options => "", :golfer_details => []}, overage = false)
    return charge_cim_overage(paying_user, amount) if overage == true
    coupled_shipment = self.coupled_shipment
    customer_profile_id = paying_user.authorize_net_profile.customer_profile_id
    payment_profile_id = paying_user.find_payment_profile_id_for_customer_profile_id(customer_profile_id)
    shipping_description = "ShipSticks Tracking ID: #{self.tracking_id}"
    shipment = Shipsticks::Ship::Pricing.confirm_shipment(self, options)
    coupled_shipment = Shipsticks::Ship::Pricing.confirm_shipment(coupled_shipment, options) if coupled_shipment.present?

    if shipment && shipment.confirmed?
      transaction_id = Shipsticks::AuthorizeNet::CIM.create_transaction(customer_profile_id, payment_profile_id, amount, shipping_description)
      payment_description = "Payment ID: #{transaction_id}"
      Ledger.new(self,payment_description,self,self.price_cents).add_shipping_transaction
      Ledger.new(coupled_shipment,payment_description,coupled_shipment,coupled_shipment.price_cents).add_shipping_transaction if coupled_shipment.present?
      schedule_pickup_requests
      coupled_shipment.schedule_pickup_requests if coupled_shipment && coupled_shipment.confirmed?
      PaymentTracking.create(:sim_response=>{"x_trans_id"=>transaction_id}.to_json,:shipment_tracking_id=>shipment.tracking_id)
      transaction_id
    else
      raise "ShipmentHasNotBeenConfirmed"
    end
  end

  def charge_cim_overage(paying_user, amount)
    customer_profile_id = paying_user.authorize_net_profile.customer_profile_id
    payment_profile_id = paying_user.find_payment_profile_id_for_customer_profile_id(customer_profile_id)
    shipping_description = "ShipSticks Tracking ID: #{self.tracking_id}"
    if self.accepted?
      transaction_id = Shipsticks::AuthorizeNet::CIM.create_transaction(customer_profile_id, payment_profile_id, amount, shipping_description)
      payment_description = "Payment ID: #{transaction_id}"
      Ledger.new(self,payment_description,self,self.price_cents).add_shipping_transaction
      transaction_id
    end
  end

  # compares if the time between pickup date and delivery date is greater than 5 days
  def transit_greater_than?(transit_days = 7)
    close_time = DateTime.strptime(self.pickup_close_time, '%H%M')
    pickup_datetime = self.pickup_date.to_time + close_time.hour.hours + close_time.min.minutes
    (self.desired_arrival_date.to_time.end_of_day - pickup_datetime).round >= (transit_days * 1.second)
  end

  # Checks for the number of business days available for tansit
  def available_days_for_transit
    # close_time = DateTime.strptime(self.pickup_close_time, '%H%M')
    # pickup_datetime = self.pickup_date.to_time + close_time.hour.hours + close_time.min.minutes
    # transit_days = ((self.desired_arrival_date.to_time - pickup_datetime)/(60 * 60 * 24)).to_i
    transit_days = (self.pickup_date...self.desired_arrival_date).select{|date| (1..5).include?(date.wday)}.size
    if transit_days > 4
      return [transit_days,">5"]
    else
      return [transit_days, transit_days.to_s]
    end
  end

  def set_payment_mode(billing_mode)
    self.payment_mode = billing_mode if self.payment_mode.blank?
    self.save

    if return_shipment = self.coupled_shipment
      return_shipment.payment_mode = self.payment_mode
      return_shipment.save
    end
  end

  def display_payment_mode
    payment_mode.humanize if payment_mode.present?
  end

  def display_payment_mode_for_report
    payment_mode == "club_billing" ? "Club billing" : "Authorize.net" if payment_mode.present?
  end

  def get_total_cost_for_pricing(golfer_name)
    package_costs = self.packages.group_by(&:golfer_name)[golfer_name].collect(&:total_price_cost_cents)
    luggage_costs = Array(self.luggage.group_by(&:golfer_name)[golfer_name]).collect(&:total_price_cost_cents) if self.luggage.present?
    Array(package_costs).sum.to_f+Array(luggage_costs).sum.to_f
  end

  def ups_service_code
    UPS_SERVICE_CODES[SHIPSTICKS_PRODUCT_TO_UPS_SERVICE[self.service_type.to_sym]]
  end

  # NOTE
  # Determines if the shipment needs a pickup. Certain clubs have daily pickups enabled
  # In such cases pickup need not be scheduled.
  def pickup_required?
    status = true
    return status unless self.origination_club.present?

    if self.carrier == CARRIER_UPS
      status = !self.origination_club.has_daily_pickup?
    elsif self.carrier == CARRIER_FEDEX && self.service_type == 'FEDEX_GROUND'
      status = !self.origination_club.has_fedex_ground_pickup?
    elsif self.carrier == CARRIER_FEDEX && self.service_type != 'FEDEX_GROUND'
      status = !self.origination_club.has_fedex_express_pickup?
    end

    status
  end

  def paid_luggage_insurance
    return 0 if !FeatureFlag.enabled?(:ups_insurance)
    free_insurance_cents = ::MINIMUM_FREE_LUGGAGE_INSURANCE

    if self.luggage.present?
      payable_amount_cents = ::LUGGAGE_INSURANCE_RATES[self.luggage_insurance_cents.to_s]
    end

    payable_amount_cents.to_i
  end

# IF all the packages are in complete
  def complete_full_shipment
    if self.state != "completed"
      if self.packages.where(:status => Package::COMPLETE).size == self.packages.size && self.luggage.where(:state=>"completed").size == self.luggage.size
        self.complete_shipment!
        Reports::ShipmentReport.new.add_to_snapshot(self) if FeatureFlag.enabled?(:redis_reports)
      end
    end
  end

  def mark_delivered
    if self.tracking_result.present?
      tracking_result = self.tracking_result
    else
      tracking_result = self.build_tracking_result(:tracking_id => self.tracking_id)
      self.save
    end

    if self.accepted?
      if tracking_result.status != "DELIVERED"
        self.deliver_shipment! if tracking_result.update_attributes(:status => "DELIVERED")
      elsif tracking_result.status == "DELIVERED" && self.accepted?
        self.deliver_shipment!
      end
    end
  end

  # determines if the all tracking results for each package and luggage are in the delivered state
  def all_packages_delivered?
    delivered = false
    undelivered_packages = self.packages.select {|p| !p.tracking_result.present? || p.tracking_result.status.to_s.upcase != "DELIVERED"}
    undelivered_luggage = self.luggage.select{|l| !l.tracking_result.present? || l.tracking_result.status.to_s.upcase != "DELIVERED"}
    delivered = true if undelivered_luggage.empty? && undelivered_packages.empty?

    delivered
  end

  def discounts?
    self.discount_cents > 0
  end

  def price_before_discount
    self.price_cents + self.discount_cents
  end


  def order
    Order.where("line_items.shipsticks_tracking_id" => self.tracking_id).last
  end

  def line_item
    order     = Order.where("line_items.shipsticks_tracking_id" => self.tracking_id).last
    line_item = order.line_items.where(:shipsticks_tracking_id => self.tracking_id).last if order.present?
  end

  def void
    return false unless self.accepted?
    if self.carrier == CARRIER_UPS
      options = {
          :shipsticks_tracking_id         => self.tracking_id,
          :shipment_identification_number => self.carrier_tracking_id
      }


      void_shipment_response = V2::Ups::ShipmentCancelRequest.new(options).void_shipment
    elsif self.carrier == CARRIER_FEDEX
      options = {
          :tracking_id => self.carrier_tracking_id,
          :form_id     => self.form_id
      }
      void_shipment_response = V2::Fedex::FedexDeleteShipmentRequest.new(options).delete_shipment
    end
    if void_shipment_response.success?
      insurance_log = self.insurance_log
      insurance_log.destroy if insurance_log.present?
      Notifier.cancel_shipment_for_sales(self).deliver
    else
      Notifier.cancel_shipment_exception(self).deliver
    end


    void_shipment_response.success?
  end

  def coupon_code
    self.coupon.code if self.coupon
  end

  def unit_coupon_discounts
    return 0 if self.discount_cents <= 0
    (self.packages.size + self.luggage.size) > 0 ? (self.discount_cents/(self.packages.size + self.luggage.size))/100.0 : 0
  end





end
Shipment.create_indexes
