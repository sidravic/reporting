class ReportingPayingUser
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name
  field :email
  field :phone
  field :roles, type: Array
  field :is_golftec_user, :type => Boolean
  field :golf_tec_id,:type => String
  field :registration_location
  field :registration_type
  field :record_created_at, :type => Time
  field :record_updated_at, :type => Time

  index({email:1}, {unique: true})
  index({role:1})
  index({record_created_at:1})
end
ReportingPayingUser.create_indexes