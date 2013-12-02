class ShipZone
  include Mongoid::Document
  include Mongoid::Timestamps

  ZONE_BY_DISTANCE = [
      {"2"=> 150},
      {"3"=> 300},
      {"4"=> 600},
      {"5"=> 1000},
      {"6"=> 1400},
      {"7"=> 1800},
      {"8"=> 2518}
  ]
  HAWAII_ALASKA_ZONE_BY_DISTANCE = {"22"=> 2000,
                                    "92"=> 2519,
                                    "23"=> 2848,
                                    "17"=> 3300,
                                    "25"=> 3759,
                                    "9" => 4048,
                                    "96"=> 4974 }


  HAWAII_ZONES = {:intra_hawaii => 14, :to_hawaii => 9, :from_hawaii => [92, 96]}
  ALASKA_ZONES = {:intra_alaska => 22, :to_alaska => 17, :from_alaska => [22, 25]}


  embeds_one :origin, :class_name => "ShipPoint"
  embeds_one :destination, :class_name => "ShipPoint"
  field :zone, :type => Integer
  field :verified_zone, :type => Integer
  field :origin_location, :type => Array
  field :destination_location, :type => Array

  index({origin: 1})
  index({destination: 1})

  validates_presence_of :zone
  validates_presence_of :origin
  validates_presence_of :destination

  attr_accessible :origin, :destination

  def self.initialize_ship_zone_lookup
    ShipZone.delete_all
    Shipment.where(:state => 'accepted').order('descending').limit(500).each do |shipment|
      unless (ship_zone = ShipZone.where("origin.zip5" => shipment.origination_ship_point.zip5, "destination.zip5" => shipment.destination_ship_point.zip5).first)
        ship_zone = ShipZone.new(:origin => shipment.origination_ship_point,
                                 :destination => shipment.destination_ship_point)
      end

      zone = Fedex::Rate.get_zone(ship_zone.origin, ship_zone.destination)
      if zone
        ship_zone.zone = zone
        ship_zone.verified_zone = zone
        ship_zone.save
      end
    end
  end

  def self.add_origin_destination_pair(shipment)
    ship_zone = ShipZone.new(:origin => shipment.origination_ship_point,
                             :destination => shipment.destination_ship_point)
    ship_zone.zone = Fedex::Rate.get_zone(ship_zone.origin, ship_zone.destination)
    ship_zone.origin = shipment.origination_ship_point
    ship_zone.destination = shipment.destination_ship_point
    ship_zone.verified_zone = ship_zone.zone
    ship_zone.save
    ship_zone
  end

  def self.lookup_zone(shipment)
    begin
      ship_zone = ShipZone.where("origin.zip5" => shipment.origination_ship_point.zip5, "destination.zip5" => shipment.destination_ship_point.zip5).last
      return ship_zone.zone if ship_zone.present?
      ship_zone = add_origin_destination_pair(shipment)
      ship_zone.zone
    rescue Timeout::Error => e
      Rails.logger.error("[ERROR] [FEDEX RATE TIMEOUT ERROR] #{e.message} \n #{e.backtrace}")
      ship_zone = ShipZone.new(:origin => shipment.origination_ship_point, :destination => shipment.destination_ship_point)
      ship_zone.distance_to_zone
    rescue => e
      Rails.logger.error("[ERROR] [FEDEX RATE API Temporarily down] #{e.message} \n #{e.backtrace}")
      ship_zone = ShipZone.new(:origin => shipment.origination_ship_point, :destination => shipment.destination_ship_point)
      ship_zone.distance_to_zone
    end
  end

  def self.lookup_zone_by_ship_points(origin_ship_point, destination_ship_point)
    ship_zone = ShipZone.where("origin.zip5" => origin_ship_point.zip5, "destination.zip5" => destination_ship_point.zip5).last
    return ship_zone.zone if ship_zone.present?
    ship_zone = add_origin_destination_pair_by_ship_points(origin_ship_point, destination_ship_point)
    ship_zone.zone
  end

  def self.add_origin_destination_pair_by_ship_points(origin_ship_point, destination_ship_point)
    ship_zone = ShipZone.new(:origin => origin_ship_point, :destination => destination_ship_point)
    ship_zone.zone = Fedex::Rate.get_zone(ship_zone.origin, ship_zone.destination)
    ship_zone.verified_zone = ship_zone.zone
    ship_zone.save
    ship_zone
  end
  # Pass zip codeorigination,destination
  # Find out ship zone if not present then fire olocation,dlocation and get zone
  # if olocation dlocation is blank then fire geozip and
  def self.lookup_zone_by_zip(origin_zip,destination_zip,origination=nil,destination=nil)
    ship_zone = ShipZone.where("origin.zip5" => origin_zip, "destination.zip5" =>destination_zip).last

    if ship_zone.present?
      ship_zone.zone
    else
      o_zip = GeoZip.get_zip_info(origin_zip)
      d_zip = GeoZip.get_zip_info(destination_zip)
      olocation = {:attention_name => '', :city => o_zip.city, :state => o_zip.state, :country => o_zip.country, :company_name => '', :phone_number => nil, :zip4 => nil, :zip5 => origin_zip, :zip => o_zip.zip,:_type=>"ShipPoint"}
      dlocation = {:attention_name => '', :city => d_zip.city, :state => d_zip.state, :country => d_zip.country, :company_name => '', :phone_number => nil, :zip4 => nil, :zip5 => destination_zip, :zip => d_zip.zip,:_type=>"ShipPoint"}
      origination = OpenStruct.new olocation
      destination = OpenStruct.new dlocation
      zone = Fedex::Rate.get_zone(origination, destination)

      # This code ensures that a numerical zone is always returned when FEDEX returns an alphabetized zone.
      # Alphabetized zones are actually FEDEX international zones and should not be returned and FEDEX acknowledges
      # that.
      # In such case use haversine distance to calculate the distance between to locations and generate a zone based
      # the distance metric
      if (zone.present? && zone.to_i == 0) || (zone.nil? && zone.to_i == 0)
        origination_ship_point = ShipPoint.new(:zip4 => nil, :zip5 => origin_zip, :zip => o_zip.zip, :state => o_zip.state, :city => o_zip.city, :country => o_zip.country)
        destination_ship_point = ShipPoint.new(:zip4 => nil, :zip5 => destination_zip, :zip => d_zip.zip, :state => d_zip.state, :city => d_zip.state, :country => d_zip.country)
        ship_zone = ShipZone.new(:origin => origination_ship_point, :destination => destination_ship_point)
        zone = ship_zone.distance_to_zone
      end

      zone
    end
  end

  def geocode
    geocoder_response = `geocode --json "#{self.origin.company_name}, #{self.origin.delivery_address_line}, #{self.origin.city}, #{self.origin.state}, #{self.origin.zip5}"`
    geocoder = JSON.parse(geocoder_response)
    loc1 = geocoder["results"].first["geometry"]["location"]
    lat = loc1["lat"]
    lng = loc1["lng"]

    geocoder_response = `geocode --json "#{self.destination.company_name}, #{self.destination.delivery_address_line}, #{self.destination.city}, #{self.destination.state}, #{self.destination.zip5}"`
    geocoder = JSON.parse(geocoder_response)
    loc2 = geocoder["results"].first["geometry"]["location"]
    lat2 = loc2["lat"]
    lng2 = loc2["lng"]
    [lat, lng, lat2, lng2]
  end

  def distance_to_zone
    latlngs = self.geocode
    distance = ShipZone.haversine_distance(*latlngs)
    Rails.logger.info "[DISTANCE TO ZONE] is #{distance}"
    zone = nil

    if (self.origin.state == "HI" || self.origin.state == "AK" || self.destination.state == "HI" || self.destination.state == "AK" )
      zone = hawaii_alaska_zones(distance)
    else
      zone = ZONE_BY_DISTANCE.first.keys.first
      ZONE_BY_DISTANCE.each_with_index do |zone_distance, index|
        zone = zone_distance.keys.first
        dist = zone_distance.values.first
        return zone.to_i if distance < dist
      end
      zone
    end
    zone
  end

  def hawaii_alaska_zones(distance)
    if self.origin.state == "HI" && self.destination.state == "HI"
      Rails.logger.info("[INTRA HAWAII] Shipping Zones")
      HAWAII_ZONES[:intra_hawaii]
    elsif self.origin.state == "AK" && self.destination.state == "AK"
      Rails.logger.info("[INTRA ALASKA] Shipping Zones")
      ALASKA_ZONES[:intra_alaska]
    elsif self.origin.state == "HI" && self.destination.state != "HI"
      Rails.logger.info("[FROM HAWAII] shipping zones")
      available_zones = HAWAII_ZONES[:from_hawaii]
      (distance > HAWAII_ALASKA_ZONE_BY_DISTANCE["92"] ? 96 : 92)
    elsif self.origin.state != "HI" && self.destination.state == "HI"
      Rails.logger.info("[TO HAWAII] shipping zones")
      HAWAII_ZONES[:to_hawaii]
    elsif self.origin.state == "AK" && self.destination != "AK"
      Rails.logger.info("[TO ALASKA] shipping zones")
      ALASKA_ZONES[:to_alaska]
    else
      Rails.logger.info("[FROM ALASKA] shipping zones")
      available_zones = ALASKA_ZONES[:from_alaska]
      (distance > HAWAII_ALASKA_ZONE_BY_DISTANCE["22"]) ? 23 : 22
    end
  end


  def self.haversine_distance(origin_lat, origin_lng, destination_lat, destination_lng)
    distance = ::Haversine.distance(origin_lat, origin_lng, destination_lat, destination_lng)
    distance.to_miles
  end

  def self.from_distance(shipment)
    ship_zone = ShipZone.new(:origin => shipment.origination_ship_point, :destination => shipment.destination_ship_point)
    ship_zone.distance_to_zone
  end
end

ShipZone.create_indexes