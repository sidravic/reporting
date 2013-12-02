class PaymentTracking
  include Mongoid::Document
  include Mongoid::Timestamps

  field :shipment_tracking_id
  field :sim_response
  field :card_type, :type => String
  field :created_at, :type => DateTime
  field :order_id, :type => String
  index({order_id:1})
  index({shipment_tracking_id:1})
  belongs_to :order



  paginates_per 25
end