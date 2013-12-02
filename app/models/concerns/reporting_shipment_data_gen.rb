require 'thread_safe'

class ReportingShipmentDataGen
  attr_reader :shipments
  def initialize(options)
    @shipments = options[:shipments]
  end

  def self.prepare_shipment_data
    prepare_v2_data
    prepare_v1_data
  end

  def self.prepare_v1_data
    _shipments = Shipment.where(:state.in => ["accepted", "delivered", "completed", "cancelled"],
                                :_type.in => ["Shipment", nil])
    data_wrangler = ReportingShipmentDataGen.new({shipments: _shipments})
    data_wrangler.prepare_v1_data
  end

  def self.prepare_v2_data
    _shipments = Shipment.where(:state.in => ["accepted", "delivered", "completed", "cancelled"],
                          :_type.in => ["GolfBag", "LuggageBag", "SkiBag"])

    data_wrangler = ReportingShipmentDataGen.new({shipments: _shipments})
    data_wrangler.prepare_v2_data
  end


  def prepare_v2_data
    puts "Running v2 now..."
    self.shipments.each do |s|
      reporting_shipments = self.prepare_shipments(s)
      reporting_shipments.each do |_shipment|
        _shipment.with(safe:true).save
      end
    end
  end

  def prepare_v1_data
    puts "Running v1 now..."
    self.shipments.each do |s|
      reporting_shipments = self.prepare_shipments(s)
      reporting_shipments.each do |_shipment|
        _shipment.with(safe:true).save
      end
    end
  end


  def prepare_shipments(s)
    reporting_shipments = ThreadSafe::Array.new

    if (s.golf_bag? || s.ski_bag? || s.luggage_bag?)
        prepared_shipment = prepare_shipment(s)
        reporting_shipments.push(prepared_shipment)
    else
      if !s.packages.present? && !s.luggage.present?
        rs = prepare_package_as_shipment(s, s)
        reporting_shipments << rs unless rs.nil?
      end

      s.packages.each do |p|
         rs = prepare_package_as_shipment(s, p)
         reporting_shipments << rs unless rs.nil?
      end

      s.luggage.each do |l|
        rs = prepare_package_as_shipment(s, l)
        reporting_shipments << rs unless rs.nil?
      end
    end

    reporting_shipments
  end


  def prepare_shipment(shipment)
    rs = ReportingShipment.new(:golfer_name => shipment.golfer_name,
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
                          :service_type => shipment.service_type,
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
                          :record_updated_at => shipment.updated_at
      )

    rs.origination_ship_point = shipment.origination_ship_point
    rs.destination_ship_point = shipment.destination_ship_point
    rs
  end

  def prepare_package_as_shipment(shipment, package)
    return nil if package.tracking_id.blank?
    rs = ReportingShipment.new(:golfer_name => package.golfer_name,
                          :golfer_email => package.golfer_email,
                          :golfer_phone => package.golfer_phone,
                          :carrier => shipment.carrier,
                          :tracking_id => "#{shipment.tracking_id}_#{package.tracking_id}",
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

    rs.origination_ship_point = rs.origination_ship_point
    rs.destination_ship_point = rs.destination_ship_point
    rs
  end
end