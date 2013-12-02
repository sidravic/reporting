class LineItem
  include Mongoid::Document
  include Mongoid::Timestamps

  field :shipsticks_tracking_id, :type => String
  field :price_cents, :type => Integer, :default => 0
  field :item_type, :type => String

  index({shipsticks_tracking_id:1})
  index({item_type:1})

  embedded_in :order

  validates_presence_of :shipsticks_tracking_id
  validates_presence_of :price_cents
  validates_presence_of :item_type
  validates_inclusion_of :item_type, :in => ['Shipment', 'GolfBag', 'LuggageBag', 'SkiBag']
  validates_uniqueness_of :shipsticks_tracking_id
  validate :non_zero_price_cents

  def item
    self.item_type.constantize.where(:tracking_id => self.shipsticks_tracking_id).last
  end

  def non_zero_price_cents
    self.errors.add(:price_cents, "Item cannot have price $0.00") if self.price_cents == 0
  end

  def self.build_with(shipment)
    LineItem.new(:shipsticks_tracking_id => shipment.tracking_id, :price_cents => shipment.price_cents, :item_type => shipment.class.to_s)
  end
end
