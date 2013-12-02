class ReportingShipment
  include Mongoid::Document
  include Mongoid::Timestamps

  field :golfer_name, :type => String
  field :golfer_email, :type => String
  field :golfer_phone, :type => String

  field :carrier, :type => String
  field :state, :type => String
  field :tracking_id, :type => String
  field :carrier_tracking_id, :type => String
  field :price_cents, :type => String
  field :discount_cents, :type => String
  field :verified_cost_cents, :type => String
  field :cost_cents, :type => String
  field :paid_insurance_cents, :type => String
  field :service_type, :type => String
  field :pickup_date, :type => Date
  field :desired_arrival_date, :type => Date
  field :delivered_date, :type => Date
  field :pickup_ready_time, :type=>String
  field :pickup_close_time, :type=>String
  field :zone, :type => Integer
  field :return_pickup_date, :type => Integer
  field :return_arrival_date, :type => Date
  field :coupled_tracking_id, :type => String
  field :void_date,:type => Date
  field :drop_off_at_ups, :type => Boolean, :default => false
  field :luggage_insurance_cents, :type => Integer, :default => 0
  field :paid_luggage_insurance_cents, :type => Integer, :default => 0
  field :record_created_at, :type => Time
  field :record_updated_at, :type => Time

  embeds_one :origination_ship_point, class_name:'ShipPoint'
  embeds_one :destination_ship_point, class_name:'ShipPoint'

  index({tracking_id:1})
  index({carrier_tracking_id:1})
  #index({tracking_id:1, carrier_tracking_id:1}, {unique:true})
  index({carrier:1})
  index({service_type:1})
  index({zone:1})
  index({pickup_date:1})
  index({desired_arrival_date:1})
  index({return_pickup_date:1})
  index({return_arrival_date:1})
  index({record_created_at:1})

  attr_accessible :golfer_name, :golfer_email, :golfer_phone, :carrier, :carrier_tracking_id, :price_cents,
                  :discount_cents, :verified_cost_cents, :cost_cents, :paid_insurance_cents, :service_type,
                  :pickup_date, :desired_arrival_date, :delivered_date, :pickup_ready_time, :pickup_close_time,
                  :zone, :return_pickup_date, :return_arrival_date, :coupled_tracking_id, :void_date,
                  :drop_off_at_ups, :luggage_insurance_cents, :paid_luggage_insurance_cents, :record_created_at,
                  :record_updated_at, :state, :tracking_id



end

ReportingShipment.create_indexes