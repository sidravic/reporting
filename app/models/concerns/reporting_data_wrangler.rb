require 'thread_safe'


class ReportingDataWrangler
  attr_reader :orders
  attr_reader :shipments

  def initialize(options)
    @orders = options[:orders] if options[:orders].present?
    @shipments = options[:shipments] if options[:shipments].present?
  end

  def self.prepare_order_data
    prepare_v2_data
    prepare_v1_data
  end

  def self.prepare_v2_data
    _orders = Order.where(:state.in => ["accepted", "delivered", "completed", "cancelled"],
                          :_type.in => ["GolfBag", "LuggageBag", "SkiBag"])

    data_wrangler = ReportingDataWrangler.new({orders: _orders})
    data_wrangler.prepare_v2_data
  end

  def self.prepare_v1_data
    _shipments = Shipment.where(:state.in => ["accepted", "delivered", "completed", "cancelled"],
                                :_type.in => ["Shipment", nil])
    data_wrangler = ReportingDataWrangler.new({shipments: _shipments})
    data_wrangler.prepare_v1_data
  end

  def prepare_v2_data
    self.orders.each do |o|
      order = self.prepare_order(o)
      shipments = self.prepare_shipments(o)
      shipments.each do |s|
        order.shipments << s
      end

      order.paying_user = self.prepare_paying_user(o)
      origination_ship_point, destination_ship_point = self.prepare_ship_points(o)
      order.origination_ship_point = origination_ship_point
      order.destination_ship_point = destination_ship_point
      order.save
    end
  end

  def prepare_v1_data
    self.shipments.each do |s|
      order = self.prepare_order(s)
      reporting_shipments = self.prepare_shipments(s)
      reporting_shipments.each do |rs|
        order.shipments << rs
      end

      order.save
    end
  end

  def prepare_order(obj)
    if obj.instance_of?(Order)
      order = obj
      coupon_code = prepare_coupon(order)
      ReportingOrder.new(:order_id => order.order_id,
                         :total_price_cents => order.total_price_cents,
                         :item_count => order.item_count,
                         :payment_method => order.payment_method,
                         :invoice_number => order.invoice_number,
                         :record_created_at => order.created_at,
                         :record_updated_at => order.updated_at,
                         :transaction_id => order.transaction_id.to_s,
                         :coupon_code =>  coupon_code)
    else
      shipment = obj
      order = ReportingOrder.new
      order.order_id = Order.generate_token
      order.total_price_cents = shipment.price_cents
      order.item_count = shipment.bag_count.to_i + shipment.luggage_count.to_i
      order.invoice_number = nil
      order.transaction_id = shipment.authnet_transaction_id.to_s
      order.record_created_at = shipment.created_at
      order.record_updated_at = shipment.updated_at
      order.coupon_code = shipment.coupon.code.to_s if shipment.coupon.present?
      order.origination_ship_point = shipment.origination_ship_point
      order.destination_ship_point = shipment.destination_ship_point
      order
    end
  end

  def prepare_shipments(obj)
    shipments_array = ThreadSafe::Array.new

    if obj.instance_of?(Order)
      order = obj
      order.line_items.each do |li|
        shipment = li.item
        reporting_shipment = ReportingShipment.new(:golfer_name => shipment.golfer_name,
                                                   :golfer_email => shipment.golfer_email,
                                                   :golfer_phone => shipment.golfer_phone,
                                                   :carrier => shipment.carrier,
                                                   :tracking_id => shipment.tracking_id,
                                                   :carrier_tracking_id => shipment.carrier_tracking_id,
                                                   :price_cents => shipment.price_cents,
                                                   :discount_cents => shipment.discount_cents,
                                                   :verified_cost_cents => shipment.verified_cost_cents,
                                                   :cost_cents => shipment.cost_cents,
                                                   :paid_insurance_cents => shipment.paid_insurance_cents,
                                                   :serivce_type => shipment.service_type,
                                                   :pickup_date => shipment.pickup_date,
                                                   :desired_arrival_date => shipment.desired_arrival_date,
                                                   :delivered_date => shipment.delivered_date,
                                                   :pickup_ready_time => shipment.pickup_ready_time,
                                                   :pickup_close_time => shipment.pickup_close_time,
                                                   :state => shipment.state,
                                                   :zone => shipment.zone,
                                                   :return_pickup_date => shipment.return_pickup_date,
                                                   :return_arrival_date => shipment.return_arrival_date,
                                                   :coupled_tracking_id => shipment.coupled_tracking_id,
                                                   :void_date => shipment.void_date,
                                                   :drop_off_at_ups => shipment.drop_off_at_ups,
                                                   :luggage_insurance_cents => shipment.luggage_insurance_cents,
                                                   :paid_insurance_cents => shipment.paid_insurance_cents,
                                                   :record_created_at => shipment.created_at,
                                                   :record_updated_at => shipment.updated_at)


        shipments_array << reporting_shipment
      end
    else
      shipment = obj
      if shipment.packages.empty? && shipment.luggage.empty?
        reporting_shipment = prepare_package_as_shipment(shipment, shipment)
        shipments_array << reporting_shipment
      end

      shipment.packages.each do |p|
        reporting_shipment = prepare_package_as_shipment(p, shipment)
        shipments_array << reporting_shipment
      end

      shipment.luggage.each do |l|
        reporting_shipment = prepare_package_as_shipment(l, shipment)
        shipments_array << reporting_shipment
      end
    end

    shipments_array
  end

  def prepare_package_as_shipment(package, shipment)
    ReportingShipment.new(:golfer_name => package.golfer_name,
                          :golfer_email => package.golfer_email,
                          :golfer_phone => package.golfer_phone,
                          :carrier => shipment.carrier,
                          :tracking_id => shipment.tracking_id,
                          :carrier_tracking_id => package.tracking_id,
                          :price_cents => package.price_cents,
                          :discount_cents => shipment.discount_cents,
                          :verified_cost_cents => package.verified_cost_cents,
                          :cost_cents => 0,
                          :paid_insurance_cents => 0,
                          :service_type => shipment.service_type,
                          :desired_arrival_date => shipment.desired_arrival_date,
                          :pickup_date => shipment.pickup_date,
                          :delivered_date => shipment.delivered_date,
                          :pickup_ready_time => shipment.pickup_ready_time,
                          :pickup_close_time => shipment.pickup_close_time,
                          :state => (package.respond_to?(:status) ? package.status : package.state),
                          :zone => shipment.zone,
                          :return_pickup_date => shipment.return_pickup_date,
                          :return_arrival_date => shipment.return_arrival_date,
                          :coupled_tracking_id => shipment.coupled_tracking_id,
                          :void_date => shipment.void_date,
                          :drop_off_at_ups => shipment.drop_off_at_ups,
                          :luggage_insurance_cents => shipment.luggage_insurance_cents,
                          :paid_insurance_cents => shipment.paid_insurance_cents,
                          :record_created_at => shipment.created_at,
                          :record_updated_at => shipment.updated_at)
  end


  def prepare_paying_user(order)
    _user = order.user
    if _user.present?
      ReportingPayingUser.new(:name => "#{_user.first_name} #{_user.last_name}",
                                     :email => _user.email,
                                     :phone => _user.phone_number,
                                     :roles => _user.roles.entries,
                                     :is_golftec_user => _user.is_golftec,
                                     :golf_tec_id => _user.golf_tec_id,
                                     :registration_location => _user.registration_location,
                                     :record_created_at => _user.created_at,
                                     :record_updated_at => _user.updated_at

      )
    else
      ReportingPayingUser.new(:name => order.payer_name,
                              :email => order.payer_email,
                              :phone => order.payer_phone,
                              :roles => [],
                              :is_golftec_user => false,
                              :golf_tec_id => nil,
                              :registration_location => nil,
                              :record_created_at => order.created_at,
                              :record_updated_at => order.updated_at
      )

    end
  end

  def prepare_ship_points(o)
    shipment = o.line_items.first.item
    [shipment.origination_ship_point, shipment.destination_ship_point]
  end

  def prepare_coupon(_order)
    return _order.coupon.code.to_s if _order.coupon.present?
    shipment = _order.line_items.first.item
    shipment.coupon_code
  end
end