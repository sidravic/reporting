class Order
  include Mongoid::Document
  include Mongoid::Timestamps

  field :total_price_cents, :type => Integer, :default => 0
  field :payment_method, :type => String
  field :paid, :type => Boolean, :default => false  #determines of the order is paid or unpaid {:true => :paid, :false => :unpaid}
  field :item_count, :type => Integer, :default => 0
  field :payer_email, :type => String
  field :payer_phone, :type => String
  field :payer_name, :type => String
  field :order_id, :type => String
  field :state, :type => String, :default => :created.to_s
  field :invoice_number, :type => String
  field :transaction_id, :type => String
  field :attempt_token, :type => String
  field :affiliate_id
  field :created_from, :type => String
  field :card_type, :type => String

  index({order_id: 1})
  index({invoice_number:1})
  index({payment_method:1})
  index({payer_email:1})
  index({state:1})

  paginates_per 10

  validates_uniqueness_of :order_id
  validates_inclusion_of :payment_method, :in => ["club_billing", "authorize.net", "preferred_card"], :unless => Proc.new {|o| o.payment_method.blank? }

  validate :validates_presence_of_items
  validate :validates_no_zero_total_price_cents

  belongs_to :user
  embeds_many :line_items
  has_many :notes, :dependent=> :destroy
  has_one :coupon

  attr_accessible :total_price_cents, :payment_method, :status, :item_count, :payer_email, :payer_phone,
                  :payer_name, :invoice_number, :transaction_id, :created_from

  before_validation :price

  def initialize
    super
    self.order_id = Order.generate_token
  end

  #returns items by golfer name in order
  def items_by_traveler(golfer_id)
    self.line_items.map{|li| li.item if li.item.golfer_id == golfer_id}
  end

  def self.items (orders)
    items = []
    orders.each do |order|
      order.line_items.each do |li|
        items << li.item
      end
    end
    return items
  end

  #returns all travelers name in order
  def travelers
    travelers_names = []
    items = []
    golfer_ids = self.line_items.map{|li| li.item.golfer_id}.uniq
    golfer_ids.each do |g|
      items = self.line_items.map{|li| li.item.golfer_name if li.item.golfer_id == g}.compact
      travelers_names << items.last if items.any?
    end
    travelers_names
  end


  ########## need to modify this start ###########

  #returns traveler's outbound items
  def traveler_outbound_items(golfer_id)
    self.items_by_traveler(golfer_id).compact.select{|i| !i.return_shipment?}
  end

  #returns traveler's roundtrip items
  def traveler_return_items(golfer_name)
    self.items_by_traveler(golfer_id).compact.select{|i| i.return_shipment?}
  end

  ########## need to modify this end ###########

  #returns traveler's luggage items
  def traveler_luggage(golfer_id)
    self.luggage.map{|l| l.item if l.item.golfer_id == golfer_id}.compact
  end

  def traveler_ski(golfer_id)
    self.ski_bags.map{|l| l.item if l.item.golfer_id == golfer_id}.compact
  end

  #returns traveler's golfbag items
  def traveler_golfbag(golfer_id)
    self.golf_bags.map{|l| l.item if l.item.golfer_id == golfer_id}.compact
  end

  #returns all luggage items in order
  def luggage
    self.line_items.where(:item_type => "LuggageBag")
  end

  #returns all golfbags in order
  def golf_bags
    self.line_items.where(:item_type => "GolfBag")
  end

  def ski_bags
    self.line_items.where(:item_type => "SkiBag")
  end

  def display_payment_mode
    self.payment_method == "club_billing" ? "Club billing" : "Authorize.net" if self.payment_method.present?
  end

  def validates_presence_of_items
    self.errors.add(:item_count, "Item count must be atleast one item on the orders") if self.item_count == 0
  end

  def validates_no_zero_total_price_cents
    self.errors.add(:total_price_cents, "Order cannot be billed at $0.00") if self.total_price_cents == 0
  end

  def price
    self.total_price_cents = self.line_items.inject(0){|sum, i| sum + i.item.price_cents}
    self.item_count = self.line_items.size.to_i
  end

  def total_price_dollars
    (self.total_price_cents.to_f/100)
  end

  def reprice!
    self.line_items.map{|i| i.price_cents = i.item.price_cents; i.save! }
    price
    save!
  end


  def add(line_item)
    identical_items = self.line_items.select{|li| li.shipsticks_tracking_id == line_item.shipsticks_tracking_id}
    if identical_items.empty?
      self.line_items << line_item
      self.price
    end
  end

  # Cannot use remove because remove is used by Mongoid and is triggered when destroy or destroy_all is fired.
  def remove!(line_item)
    line_item = self.line_items.find(line_item.id)
    if line_item.delete
      self.price
      self.save
    end
  end

  def update!
    return unless self.accepted?
    return self.cancel! if all_shipments_cancelled?

    if all_shipments_completed?
      self.complete!
    end
  end

  # Uses a method name called oprocess because `process` is a mongoid method used in
  # lib/mongoid/attributes.rb
  #
  # Till we think of a better name we use oprocess.
  def oprocess
    self.line_items.each do |line_item|
      begin
        shipment = line_item.item
        ShippingProcessor.create_shipment(shipment)
          #Reports::ShipmentReport.new.add_to_snapshot(shipment) if FeatureFlag.enabled?(:redis_reports)
      rescue => e
        Rails.logger.error("[ORDER PROCESS EXCEPTION] #{e.message} \n #{e.backtrace}")
        Notifier.shipment_creation_failure(shipment.tracking_id, ShippingProcessor::SHIPMENT_CREATION_ERROR, "#{e.message} \n #{e.backtrace}")
        next
      end
    end

    if self.line_items.collect(&:item).collect(&:carrier).include?(::CARRIER_UPS)
      ShippingProcessor.create_ups_grouped_pickup_request(self)
      return_shipments = self.line_items.collect(&:item).select{|s| s.return_shipment?}

      if !return_shipments.empty?
        ShippingProcessor.create_ups_grouped_pickup_request(self, true)
      end
    end
  end

  def self.generate_token
    semaphore = Mutex.new

    semaphore.synchronize do
      begin
        unique_token = SecureRandom.uuid
      end while Order.where(order_id: unique_token).exists?
      unique_token
    end
  end

  def generate_reattempt_token!
    self.attempt_token = Digest::MD5.hexdigest(SecureRandom.hex(10) + Time.now.to_i.to_s)
    self.save!
    self.attempt_token
  end

  def clear_attempt_token!
    attempt_token = self.attempt_token
    self.attempt_token = ""
    self.save!
  end

  def shipper_name
    if self.user.present?
      shipper_name = self.user.name
    else
      shipper_name = self.payer_name
    end
  end

  def ledger_account
    "order_tracking_id:#{self.order_id}"
  end

  def total_discount
    self.line_items.inject(0){|sum, li| sum += li.item.discount_cents }
  end

  def journal_transaction_id
    journal_transaction = JournalTransaction.where("journal_entries.order_tracking_id" => self.id.to_s).last
    return "" if journal_transaction.nil?

    journal_transaction.id.to_s
  end

  def get_club_billed_by_sales
    # The begin rescue blocks are to ensure fuck ups caused by deleted clubs.
    begin
      journal_transaction = JournalTransaction.where("journal_entries.order_tracking_id" => self.id.to_s).last
      return nil if journal_transaction.nil?

      entry   = journal_transaction.journal_entries.last
      club_id = entry.credit_account.split(":")[1]
      return nil if club_id.nil?

      Club.find(club_id)
    rescue => e
      Rails.logger.error("[ERROR][Club NOT FOUND] #{e.message} #{e.backtrace}")
      nil
    end
  end

  private

  def update_discounts
    shipment = self.line_items.first.item
    if shipment.coupon.present? && shipment.coupon.dollar_discount?
      shipment.discount_cents = shipment.coupon.dollar_discount_cents
      shipment.price_cents   -= shipment.discount_cents
      shipment.save
    end
  end

  def all_shipments_cancelled?
    cancelled_shipments = self.line_items.select{|li| li.item if li.item.cancelled? }
    self.line_items.size == cancelled_shipments.size
  end

  def all_shipments_completed?
    completed_shipments = self.line_items.select{|li| li.item if li.item.completed? }
    cancelled_shipments = self.line_items.select{|li| li.item if li.item.cancelled? }
    self.line_items.size == completed_shipments.size + cancelled_shipments.size
  end
end
