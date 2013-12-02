class Coupon
  include Mongoid::Document
  include Mongoid::Timestamps

  PERCENTAGE_DISCOUNT = 0
  DOLLAR_DISCOUNT 	= 1

  DOMAIN_ALL_SITES 	= 0
  DOMAIN_MICRO_SITES  = 1
  DOMAIN_SHIPSTICKS 	= 2
  SHIPSTICKS          = "shipsticks.com"

  field :code, :type => String
  field :allowed_domain, :type => Integer, :default => DOMAIN_ALL_SITES
  field :description, :type => String
  field :discount_type, :type => Integer, :default => PERCENTAGE_DISCOUNT
  field :dollar_discount_cents, :type => Integer, :default => 0
  field :percentage_discount, :type => Integer, :default => 0
  field :max_usage_count, :type => Integer, :default => 1
  field :usage_count, :type => Integer, :default => 0
  field :expiry_date, :type => DateTime, :default => (DateTime.now + 1.week)
  field :completed_date, :type => DateTime

  index({code:1})
  index({expiry_date:1})
  index({allowed_domain:1})

  attr_accessor :domain

  attr_accessible :code, :allowed_domain, :description, :discount_type, :dollar_discount_cents, :percentage_discount,
                  :max_usage_count, :usage_count, :expiry_date, :completed_date, :micro_site_id

  validates_inclusion_of :discount_type, :in => [PERCENTAGE_DISCOUNT, DOLLAR_DISCOUNT]
  validates_uniqueness_of :code

  has_and_belongs_to_many :users
  belongs_to :micro_site # if Coupon is associated with DOMAIN_MICRO_SITE

  #scope :active, where(:completed_date => nil, :expiry_date.gt => Date.today.to_time.iso8601).and("this.usage_count <= this.max_usage_count")
  #scope :expired, any_of({:completed_date.ne => nil}, {:expiry_date.lte => Date.today.to_time}, {:usage_count => {"$gte" => "this.max_usage_count"}})
  has_many :shipments, :inverse_of => :coupon
  belongs_to :order

  def expired?
    return !(DateTime.now.to_date < self.completed_date) if self.completed_date.present?
    !(DateTime.now.to_date < self.expiry_date)
  end

  def max_usage_completed?
    !(self.usage_count < self.max_usage_count)
  end

  def valid_domain?
    return true if self.allowed_domain == DOMAIN_ALL_SITES
    return true if domain.instance_of?(MicroSite) && self.allowed_domain == DOMAIN_MICRO_SITES && self.micro_site.id == domain.id
    return true if domain.instance_of?(String) && self.allowed_domain == DOMAIN_SHIPSTICKS && domain.downcase == SHIPSTICKS

    false
  end

  def active?(domain = nil)
    self.domain = domain
    !expired? && !max_usage_completed? && valid_domain?
  end

  def discount_on(amount_cents)
    return (self.dollar_discount_cents.to_f) if self.discount_type == DOLLAR_DISCOUNT
    discounted_cents = (((amount_cents * self.percentage_discount).to_f)/100).to_i
    discounted_cents
  end

  def available_for?(user)
    !self.users.include?(user)
  end

  def percentage_discount?
    self.discount_type == ::Coupon::PERCENTAGE_DISCOUNT
  end

  def dollar_discount?
    self.discount_type == ::Coupon::DOLLAR_DISCOUNT
  end

  def accepted_shipments
    self.shipments.where(:state.in => ["accepted", "completed", "cancelled"])
  end
end
