require 'role_model'

class User
  include Mongoid::Document
  include Mongoid::Timestamps
  include RoleModel

  has_many :clubs, :dependent => :nullify
  has_many :shipments
  has_many :notes,:dependent=>:destroy
  has_one :address_book, :as => :address_book_owner
  has_many :upgrades
  has_many :accounts, :dependent=>:destroy

  #has_many :authentications, :dependent => :delete_all
  #has_many :access_grants, :dependent => :delete_all

  attr_accessible :email, :password, :password_confirmation, :remember_me, :first_name, :last_name

  # optionally set the integer attribute to store the roles in,
  # :roles_mask is the default
  roles_attribute :roles_mask

  # declare the valid roles -- do not change the order if you add more
  # roles later, always append them at the end!
  roles :admin, :sales_manager, :agent, :pro, :super_admin
  # Include default devise modules. Others available are:
  # :token_authenticatable, :encryptable, :confirmable, :lockable, :timeoutable and :omniauthable
  #devise :database_authenticatable, :registerable, :recoverable, :rememberable, :trackable, :validatable,  :lockable, :token_authenticatable

  field :first_name
  field :last_name
  field :pga_number
  field :salutation
  field :roles_mask
  field :email
  field :password
  field :phone_number
  field :requested_club
  field :is_active, :type => Boolean, :default => true
  field :terms_and_conditions_accepted, :type => Boolean, :default => false
  field :token_authentication_key #sso provider stuff
  #field :disabled, :default => false
  field :affiliate_id
  field :golf_tec_id
  field :is_golftec, :type => Boolean
  field :registration_type
  field :registration_location
  field :registered_on_micro_site
  field :has_connected_facebook, :type => Boolean
  field :gender
  field :birth_date, :type=>Date
  field :image


  embeds_one :authorize_net_profile, :as => :authorize_netable

  validates_presence_of :first_name, :last_name
  #validates_uniqueness_of :email, :case_sensitive => false
  attr_accessible :is_golftec,:golf_tec_id,:terms_and_conditions_accepted, :first_name, :last_name, :phone_number,
                  :requested_club, :email, :password, :password_confirmation, :remember_me, :roles_mask, :pga_number,
                  :_id, :is_active,:affiliate_id, :image, :birth_date, :gender,
                   :registration_type, :registration_location, :registered_on_micro_site, :has_connected_facebook


  has_and_belongs_to_many :coupons

  after_create :send_notification_for_pro
end
User.create_indexes