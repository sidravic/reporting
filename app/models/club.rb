class Club
  include Mongoid::Document

  field :club_id, :type => String
  #key :club_id
  field :name, :type => String
  index({name: 1})
  field :attn, :type => String
  # field :address_id, :type => String
  field :phone, :type => String
  field :url, :type => String
  field :pro_name, :type => String
  field :no_pro, :type => Boolean, :default => false
  field :next_pickup_date, :type => Date
  field :club_billing_enabled, :type => Boolean, :default => false
  field :saturday_delivery, :type => Boolean
  field :saturday_pickup, :type => Boolean
  field :closed_monday, :type => Boolean,:default => false
  field :has_daily_pickup, :type => Boolean, :default => false
  field :has_fedex_ground_pickup, :type => Boolean, :default => false
  field :has_fedex_express_pickup, :type => Boolean, :default => false
  field :has_carrier_selection, :type => Boolean, :default => false
  field :carrier_selection, :type => String, :default => "both"
  field :allow_in_autocomplete, :type => Boolean, :default => false
  field :disabled, :type => Boolean, :default => false
  field :geo_zip_enabled, :type => Boolean, :default => true

  index({disabled: 1})

  validates_inclusion_of :carrier_selection, :in => ["FEDEX","UPS","both"], :message => "carrier %s is not included in the list"

  belongs_to :user, :class_name => 'User', :autosave => true
  belongs_to :salesman, :class_name => 'User', :autosave => true
  has_many :micro_sites
  has_one :address_book, :as => :address_book_owner

  embeds_one :original_address, :class_name => 'Address'
  embeds_one :ship_to_address, :class_name => 'Address'
  embeds_one :billing_contact, :class_name => 'Contact'
  embeds_one :club_billing_offer, :class_name => 'Offer'

  accepts_nested_attributes_for :user, :salesman, :ship_to_address, :billing_contact, :club_billing_offer, :original_address

  embeds_one :authorize_net_profile, :as => :authorize_netable

  scope :active, where(:disabled.ne => true)
  scope :inactive, where(:disabled => true)
  scope :has_pro, where(:user_id.ne => nil)
  scope :no_pro, where(:user_id => nil)
  scope :billable_clubs, where(:club_billing_enabled => true).order_by([[:name, :asc]])
  scope :allow_autocomplete, where(:allow_in_autocomplete.ne => true)
  # scope :no_micro_site, where(:micro_site_id => nil)
  #account id used when billing club

  # after_save :async_index
  # after_destroy :async_index_destroy


  paginates_per 30



  def billing_id
    "club:#{club_id}"
  end

  def ledger_account
    return billing_id
  end

  def club_email_address
    if( self.pro_of_record? )
      return self.user.email
    else
      return Shipsticks::Application.config.no_pro_email
    end
  end

  def get_address
    "#{ship_to_address.address_1.to_s} #{ship_to_address.address_2.to_s}"
  end
  def pro_of_record?
    return !self.user.nil?
  end

  def pro_name
    self.pro_of_record? ? self.pro_of_record.name : self[:pro_name]
  end

  def pro_of_record
    self.user
  end

  def pro_of_record=(pro)
    self.update_has_pro(pro)
    self.user = pro
  end

  def update_has_pro(val)
    self.no_pro = val.nil?
  end

  def self.name_collection
    names = Club.all.only(:name).collect(&:name)
    names = names.map {|name| name[0..0].upcase unless name.nil?}
    names.uniq
  end
  def set_carrier(carrier_name)
    if has_carrier_selection
      self.carrier_selection = carrier_name
      self.save
    else
      false
    end
  end

  def club_name_with_state_city
    "#{name} (#{self.ship_to_address.state}, #{self.ship_to_address.city})" rescue name
  end

  def activate!
    self.disabled = false
    self.save!
  end
end

Club.create_indexes
