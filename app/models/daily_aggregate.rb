class DailyAggregate
  include Mongoid::Document
  include Mongoid::Timestamps

  field :value, :type => Hash



  #DailyAggregate.where("_id.date" => {"$lte" => (Date.today - 5.days)}).all.size
end