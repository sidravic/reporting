# encoding: utf-8
#require 'aws/s3'

class MicroSite
  include Mongoid::Document
  field :name
  field :domain
  field :sub_domain
  field :custom_message
  field :site_header
  field :site_faq

  field :meta_title
  field :meta_description
  field :description
  field :email_salutation
  field :css_url
  field :css_text
  field :v2_css_text
  field :v2_css_url
  field :tracking_code
  field :v2_enabled, :type => Boolean, :default => false
  field :ski_micro_site, :type => Boolean, :default => false


  #mount_uploader :logo, LogoUploader

  belongs_to :club
  has_many :shipments
  has_many :coupons

  before_create :create_static_header, :create_static_faq
  after_create :create_files
  before_destroy :delete_files

  validates_presence_of :name
  validates_format_of :sub_domain, :with => /^[\S]*$/

  def files_name
    name.gsub(/[^0-9A-Za-z]/, '_')
  end

  def display_meta_title
    self.meta_title.blank? ? "Ship Sticks - #{self.name}" : self.meta_title
  end

  def compile_less
    return v2_compile_less if FeatureFlag.enabled?(:micro_site_migration)
    system("rm -rf #{RAILS_ROOT}/public/partners/#{self.id}/css/bootstrap.css") if File.exist?("#{RAILS_ROOT}/public/partners/#{self.id}/css/bootstrap.css")
    system("lessc #{RAILS_ROOT}/public/partners/#{self.id}/css/bootstrap.less > #{RAILS_ROOT}/public/partners/#{self.id}/css/bootstrap.css")
  end

  def v2_compile_less
    system("rm -rf #{Rails.root}/public/partners/#{self.id}/css/v2_bootstrap.css") if File.exist?("#{Rails.root}/public/partners/#{self.id}/css/bootstrap.css")
    system("lessc #{Rails.root}/public/partners/#{self.id}/css/v2_#{self.files_name}.less > #{Rails.root}/public/partners/#{self.id}/css/v2_#{self.files_name}.css")
  end

  def save_css_text
    return v2_save_css_text if FeatureFlag.enabled?(:micro_site_migration)

    file_name = "#{Rails.root}/public/partners/#{self.id}/css/#{self.files_name}.less"
    s3_to_public unless File.exist?(file_name)
    self.update_attribute(:css_text,File.read(file_name))
  end

  def v2_save_css_text
    file_name = "#{Rails.root}/public/partners/#{self.id}/css/v2_#{self.files_name}.css"
    s3_to_public unless File.exist?(file_name)
    self.update_attribute(:v2_css_text, File.read(file_name))
  end

  def upload_css_to_s3
    return v2_upload_css_to_s3 if FeatureFlag.enabled?(:micro_site_migration)
    files = ["partners/#{self.id}/css/#{self.files_name}.less", "partners/#{self.id}/css/bootstrap.less","partners/#{self.id}/css/bootstrap.css"]
    files.each do |f|
      f_ = "#{RAILS_ROOT}/public/#{f}"
      begin
        AWS::S3::S3Object.delete f, S3_CREDENTIALS['bucket']+"_#{Rails.env}"
      rescue
      end
      content_type = File.extname(f_) == ".css" ? "text/css" : "text/plain"
      AWS::S3::S3Object.store(
          f, File.open(f_), S3_CREDENTIALS['bucket']+"_#{Rails.env}",
          :access => :public_read, 'Cache-Control' => 'max-age=315360000', :authenticated => false, 'Content-Type' => content_type, 'Access-Control-Allow-Origin' => '*'
      )
    end
    css_url = AWS::S3::S3Object.url_for("partners/#{self.id}/css/bootstrap.css",S3_CREDENTIALS['bucket']+"_#{Rails.env}",:authenticated => false)
    self.update_attribute(:css_url,css_url)
    save_css_text
  end

  def v2_upload_css_to_s3
    files = ["partners/#{self.id}/css/v2_#{self.files_name}.css", "partners/#{self.id}/css/v2_bootstrap.less" ]
    #css_text = File.read("#{Rails.root}/public/partners/#{self.id}/css/#{self.files_name}.css")

    files.each do |f|
      _file = "#{Rails.root}/public/#{f}"
      begin
        AWS::S3::S3Object.delete f, S3_CREDENTIALS['bucket'] + "_#{Rails.env}"
      rescue
      end

      content_type = (File.extname(".css") == ".css") ? "text/css" : "text/plain"
      AWS::S3::S3Object.store(f, File.open(_file), S3_CREDENTIALS['bucket'] + "_#{Rails.env}",
                              :access => :public_read, 'Cache-Control' => 'max-age=315360000',
                              :authenticated => false, 'Content-Type' => content_type,
                              'Access-Control-Allow-Origin' => '*')
    end

    css_url = AWS::S3::S3Object.url_for("partners/#{self.id}/css/v2_#{self.files_name}.css",
                                        S3_CREDENTIALS['bucket']+"_#{Rails.env}",
                                        :authenticated => false)
    self.v2_css_url = css_url
    self.save
    v2_save_css_text
  end



  def s3_to_public
    return v2_s3_to_public if FeatureFlag.enabled?(:micro_site_migration) || self.v2_enabled
    custom_name = files_name
    system("mkdir -p public/partners/#{id}") unless File.exist?("#{Rails.root}/public/partners/#{id}")
    system("mkdir -p public/partners/#{id}/css") unless File.exist?("#{Rails.root}/public/partners/#{id}/css")
    system("mkdir -p public/partners/#{id}/javascripts") unless File.exist?("#{Rails.root}/public/partners/#{id}/javascripts")
    system("mkdir -p public/partners/#{id}/images") unless File.exist?("#{Rails.root}/public/partners/#{id}/images")
    system("touch public/partners/#{id}/javascripts/#{custom_name}.js") unless File.exist?("#{Rails.root}/public/partners/#{id}/javascripts/#{custom_name}.js")
    files = ["partners/#{self.id}/css/#{self.files_name}.less", "partners/#{self.id}/css/bootstrap.less","partners/#{self.id}/css/bootstrap.css"]
    files.each do |f|
      f_ = "#{RAILS_ROOT}/public/#{f}"
      File.open(f_, "w") do |file|
        AWS::S3::S3Object.stream(f, S3_CREDENTIALS['bucket']+"_#{Rails.env}") do |s|
          file.write s
        end
      end
    end
  end

  def v2_s3_to_public
    custom_name = files_name

    system("mkdir -p public/partners/#{id}") unless File.exist?("#{Rails.root}/public/partners/#{id}")
    system("mkdir -p public/partners/#{id}/css") unless File.exist?("#{Rails.root}/public/partners/#{id}/css")
    system("mkdir -p public/partners/#{id}/javascripts") unless File.exist?("#{Rails.root}/public/partners/#{id}/javascripts")
    system("mkdir -p public/partners/#{id}/images") unless File.exist?("#{Rails.root}/public/partners/#{id}/images")
    system("touch public/partners/#{id}/javascripts/#{custom_name}.js") unless File.exist?("#{Rails.root}/public/partners/#{id}/javascripts/#{custom_name}.js")

    files = ["partners/#{self.id}/css/v2_#{self.files_name}.css", "partners/#{self.id}/css/v2_bootstrap.less"]
    files.each do |f|
      f_ = "#{Rails.root}/public/#{f}"
      File.open(f_, "w") do |file|
        AWS::S3::S3Object.stream(f, S3_CREDENTIALS['bucket'] + "_#{Rails.env}") do |s|
          file.write(s)
        end
      end
    end
  end

  private

  def create_static_header
    self.site_header = static_header
  end

  def create_static_faq
    self.site_faq = static_faq
  end

  #create files and folder for micro sites styling
  def create_files
    if FeatureFlag.enabled?(:micro_site_migration)
      create_v2_files
      return
    end

    custom_name = files_name
    system("mkdir -p public/partners/#{id}")
    system("mkdir -p public/partners/#{id}/css")
    system("mkdir -p public/partners/#{id}/javascripts")
    system("mkdir -p public/partners/#{id}/images")
    system("rails g site_stylesheets #{id} #{id} #{custom_name}")
    system("touch public/partners/#{id}/javascripts/#{custom_name}.js")
    prefix = ''
    compile_less
    upload_css_to_s3
  end

  def create_v2_files
    custom_name = files_name
    system("mkdir -p public/partners/#{id}")
    system("mkdir -p public/partners/#{id}/css")
    system("mkdir -p public/partners/#{id}/javascripts")
    system("mkdir -p public/partners/#{id}/images")
    system("rails g v2_microsite_files_creator #{id} #{id} #{custom_name}")
    system("touch public/partners/#{id}/javascripts/#{custom_name}.js")
    prefix = ""
    compile_less
    upload_css_to_s3
  end


  def delete_files
    #TODO remove from s3
    custom_name = files_name
    files = [
        "partners/#{id}/javascripts/#{custom_name}.js",
        "partners/#{id}/css/#{custom_name}.less",
        "partners/#{id}/css/bootstrap.less",
        "partners/#{id}/css/bootstrap.css"
    ]
    files.each do |f|
      AWS::S3::S3Object.delete f, S3_CREDENTIALS['bucket']+"_#{Rails.env}"
    end
    system("rm -rf public/partners/#{id.to_s}")
  end

  def static_header
    <<-eos
      <div class="right" style="height: 28px;">
        <div id="number">
          <h3 style="font-size: 20px; font-weight: normal; color: #333;"><font style="color: #73B435;">Call Now:</font> (855) 867-9915</h3>
        </div>
      </div>
      <div class="left" id="main-nav">
        <div style="margin-top: 7px;">
          <ul class="nav">
            <li class="arrow-right"></li>
            <li><a href="/ship">SHIP NOW</a></li>
            <li><a href="/track?tracking_id=">TRACK SHIPMENT</a></li>
          </ul>
          <div class="right">
            <span style="vertical-align: top; line-height: 3; color: #fff;">powered by</span>
            <img src="https://s3.amazonaws.com/shipsticks_partner_assets/universal/powered-by-shipsticks-logo.png" style="margin: 5px 15px 0 5px"/>
          </div>
          <div class="clearfix">&nbsp;</div>
        </div>
      </div>
    eos
  end

  def static_faq
    <<-eos
      <dl>
        <dt>Q: How do I register?</dt>
        <dd>A: If you are a PGA golf professional and work at a golf facility, simply go to <a href="http://www.shipsticks.com">www.shipsticks.com</a>.</dd>
        <dd>B. If you are a golfer and would like to ship your clubs using Ship Sticks, you don’t have to register—just go to <a href="http://www.shipsticks.com">www.shipsticks.com</a>.</dd>
        <dt>Q: Is there a fee to sign up with Ship Sticks?</dt>
        <dd>A: No, signing up is absolutely free.</dd>
        <dt>Q: Do I have to be a golf professional to use your service?</dt>
        <dd>A: No.</dd>
        <dt>Q: What if I’m not a member of a golf club?</dt>
        <dd>A: That’s not a problem. If you are going on a golf trip, you can schedule a pickup by going to www.shipsticks.com and filling out the required information to process your shipment. Or, put your clubs in a club glove, take them to your nearest golf facility, and ask them to use Ship Sticks.</dd>
        <dt>Q: Where do my sticks go when I ship them to a certain location?</dt>
        <dd>A: The pro shop of record and or the bag room will have your clubs. You will receive an e-mail with the contact information for the club where you sent your sticks.</dd>
        <dt>Q: What happens if my clubs don’t arrive before my tee time?</dt>
        <dd>A: Please contact Ship Sticks toll-free at 1-855-867-9915 and a customer service representative will be happy to help locate your clubs, as well as take care of your immediate golf needs.</dd>
        <dt>Q: How much insurance do I need?</dt>
        <dd>A: We understand the value of your clubs and automatically build in a baseline of $1000 of insurance. You are able to add up to $3500 to insure any single golf bag.</dd>
        <dt>Q: Is there a weight limit for my golf bag?</dt>
        <dd>A: Yes. Standard golf bags must be 48 pounds or less to receive the stated discounts. If over 48 pounds you must select the option for Staff/XL bag (up to 72 pounds).</dd>
        <dt>Q: How do I contact Ship Sticks?</dt>
        <dd>A: E-mail: <a href="mailto:info@shipsticks.com">info@shipsticks.com</a> <a href="mailto:sales@shipsticks.com">sales@shipsticks.com</a> Phone: Toll free 1-855-867-9915</dd>
        <dt>Q: What if my pro doesn’t use Ship Sticks?</dt>
        <dd>A: Well, tell him to get his act together! We suggest that you ask your pro to go to www.shipsticks.com and sign up. Then you can start enjoying the convenience and savings of Ship Sticks service.</dd>
      </dl>
    eos
  end
end
