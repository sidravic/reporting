class GroupedPickupRequest
  include Mongoid::Document
  include Mongoid::Timestamps

  field :service_code, :type => String
  field :weight_lbs, :type => String
  field :address_line, :type => String
  field :address_line_1, :type => String
  field :city, :type => String
  field :state, :type => String
  field :zip, :type => String
  field :company_name, :type => String
  field :contact_name, :type => String
  field :phone_number, :type => String
  field :extension, :type => String
  field :pickup_date, :type => Date
  field :ready_time, :type => String
  field :close_time, :type => String
  field :status, :type => String
  field :pickup_status,:type => String
  field :exception, :type => Boolean, :default => false
  field :exception_status, :type => String
  field :carrier, :type => String
  field :prn
  field :fedex_location,:type => String
  field :request_state, :type => String, :default => "INITIALIZED"
  field :delayed_schedule_date, :type => Date
  field :confirmation_email_address, :type => String

  has_many :shipments

  # Using oprocess because mongoid uses an method `process` internally which is
  # triggered on initialize.
  # Till we find a better name use `oprocess` which stands for `order process`

  def oprocess
    process_ups if self.carrier == ::CARRIER_UPS
  end

  def process_ups
    if !self.shipments.first.drop_off_at_ups?
      if self.pickup_date < 2.weeks.from_now.to_date
        Resque.enqueue(UpsGroupedPickupRequest, self.id.to_s)
      else
        schedule_two_weeks_before_pickup_date
      end
    end
  end

  def schedule_two_weeks_before_pickup_date
    if self.carrier == ::CARRIER_UPS
      schedule_date = (self.pickup_date - 2.weeks).to_datetime.in_time_zone('Eastern Time (US & Canada)')
      Resque.enqueue_at(schedule_date, UpsGroupedPickupRequest, self.id.to_s)
      Resque.enqueue(DelayedNotifier, self.shipments.first.id, :confirm_queued_shipment)
    end
  end

end