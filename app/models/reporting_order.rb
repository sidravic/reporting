class ReportingOrder
  include Mongoid::Document
  include Mongoid::Timestamps

  embeds_many :shipments, class_name: 'ReportingShipment'
  embeds_one :paying_user, class_name: 'ReportingPayingUser'
  embeds_one :origination_ship_point, class_name: 'ShipPoint'
  embeds_one :destination_ship_point, class_name: 'ShipPoint'

  field :total_price_cents, :type => Integer, :default => 0
  field :payment_method, :type => String
  field :item_count, :type => Integer, :default => 0
  field :order_id, :type => String
  field :transaction_id, :type => String
  field :invoice_number, :type => String
  field :record_created_at, :type => Time
  field :record_updated_at, :type => Time
  field :coupon_code, :type => String


  index({order_id:1}, {unique: true})
  index({payment_method:1})
  index({record_created_at:1})
  index({coupon_code:1})
  index({origination_ship_point: 1})
  index({destination_ship_point: 1})
  attr_accessible :total_price_cents, :payment_method, :item_count, :order_id, :transaction_id,
                  :invoice_number, :record_created_at, :record_updated_at, :coupon_code
end
ReportingOrder.create_indexes