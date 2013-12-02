class MonthlyAggregate
  include Mongoid::Document
  include Mongoid::Timestamps

  field :value, type: Hash
end