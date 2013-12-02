class PickupRequest
  include Mongoid::Document
  include Mongoid::Timestamps

  belongs_to :shipment

  field :pickup_id, :type => String
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

  index({pickup_date: 1})
  index({pickup_status:1})
  index({request_state:1})


  #pickup status
  SCHEDULED      = "SCHEDULED"
  SCHEDULE_ERROR = "SCHEDULE_ERROR"

  #status
  REQUEST_SUCCESS = "REQUEST_SUCCESS"
  REQUEST_FAILED  = "REQUEST_FAILED"

  attr_accessible :pickup_id, :service_code, :weight_lbs, :address_line, :address_line_1, :city, :state,
                  :zip, :company_name, :contact_name, :phone_number, :extension, :pickup_date, :ready_time,
                  :close_time, :status, :pickup_status, :exception, :exception_status, :carrier, :prn, :fedex_location,
                  :request_state, :delayed_schedule_date



  def cancel_pickup_request
    Shipsticks::Ship::Cancel.cancel_pickup(self)
  end

  def close_date_time
    DateTime.strptime(self.close_time, "%H%M")
  end

  def close_time_passed?
    DateTime.now > close_date_time
  end



  # Using oprocess because mongoid uses an method `process` internally which is
  # triggered on initialize.
  # Till we find a better name use `oprocess` which stands for `order process`
  def oprocess
    if self.shipment.carrier == ::CARRIER_FEDEX
      process_fedex
    elsif self.shipment.carrier == ::CARRIER_UPS
      process_ups
    end
  end

  def process_fedex
    if self.pickup_date > Date.today + 14.days && service_type == "FEDEX_GROUND"
      schedule_two_weeks_before_pickup_date
    elsif self.pickup_date > (Date.today + 1.day) && service_type != "FEDEX_GROUND"
      if pickup_date_monday? && (today_is_sunday? || today_is_saturday?)
        schedule_date = self.pickup_date.to_datetime
      elsif pickup_date_monday?
        schedule_date = (self.pickup_date - 3.days).to_datetime
      else
        schedule_date = (self.pickup_date - 1.day).to_datetime
      end
      Resque.enqueue_at(schedule_date, ::FedexPickupRequest, self.id.to_s)
    else
      Resque.enqueue(::FedexPickupRequest, self.id.to_s)
    end
  end

  def process_ups
    if !self.shipment.drop_off_at_ups?
      if self.pickup_date < 2.weeks.from_now.to_date
        Resque.enqueue(UpsPickupRequest, self.id.to_s)
      else
        schedule_two_weeks_before_pickup_date
      end
    end
  end

  def schedule_two_weeks_before_pickup_date
    if self.carrier == ::CARRIER_FEDEX
      two_week_window = (self.pickup_date - 14.days).to_datetime
      Resque.enqueue_at(two_week_window, ::FedexPickupRequest, self.id.to_s)
    elsif self.carrier == ::CARRIER_UPS
      schedule_date = (self.pickup_date - 2.weeks).to_datetime.in_time_zone('Eastern Time (US & Canada)')
      Resque.enqueue_at(schedule_date, UpsPickupRequest, self.id.to_s)
      Resque.enqueue(DelayedNotifier, self.shipment.id, :confirm_queued_shipment)
    end
  end

  private

  def service_type
    self.shipment.service_type
  end

  def pickup_date_monday?
    self.pickup_date.wday == 1
  end

  def today_is_saturday?
    Date.today.wday == 6
  end

  def today_is_sunday?
    Date.today.wday == 0
  end



end
PickupRequest.create_indexes