require 'geoserver_translator.rb'
require 'external_service_translator.rb'
require 'uuidtools'

class Dataset < ActiveRecord::Base
  
  has_and_belongs_to_many :dataset_groups
  belongs_to :feature_type
  belongs_to :feature_source
  belongs_to :owner
  has_one :author
  belongs_to :creative_commons_license

  accepts_nested_attributes_for :owner, :author
  
  validates_presence_of :name, :description, :feature_type, :feature_source
  
  before_create :generate_uuid
  
  attr_accessor :feature
  
  def generate_uuid
    if self.uuid.nil?
      self.uuid = UUIDTools::UUID.timestamp_create().to_s
    end
  end

  def feature
    if @feature.nil?
      @feature = Feature.new(uuid, feature_source, name, feature_period)
    end
    @feature
  end  
  
  def as_json(options={})    
    json = { 
      :dataset => { :uuid => self.uuid, :name => self.name, :description => self.description }, 
      :group => self.dataset_groups.first.as_json(:exclude => self.uuid)
    }
  end

  def to_xml(options = {})
    options[:indent] ||= 2
    xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
    xml.instruct! unless options[:skip_instruct]
    xml.dataset do 
      xml.tag!(:date, created_at)
      xml.tag!(:description, description)
      if !feature_period.nil?
        xml.tag!(:period, feature_period)
      end
      xml.tag!(:name, name)
      xml.tag!(:source, source) unless source.nil?
      xml.tag!(:uuid, uuid)
      xml.tag!(:id, uuid)
      xml.owner do
        if !owner.user_id.nil?
          xml.tag!(:user_id, owner.user_id)
        end
        if !owner.group_id.nil?
          xml.tag!(:group_id, owner.group_id)
        end
      end unless owner.nil?
      xml.author do        
        xml.tag!(:name, "#{author.first_name} #{author.last_name}")
        xml.tag!(:email, author.email)
      end unless author.nil?
      begin      
        if feature.keywords
          xml.tag!(:properties, feature.keywords.join(', ').chop!)
        end
      rescue
      end

      if feature.latitude_longitude
        xml.tag!(:coordinates, feature.latitude_longitude)
      end
      if feature.bounding_box
        xml.tag!(:bounding_box, feature.bounding_box)
      end
      xml.formats do
        feature.formats.each do |format|
          xml.format format
        end
      end
      xml.tag!(:wms, feature_source == FeatureSource.find_by_name('geoserver'))
      xml.tag!(:external, feature.is_data_source_external?) unless !feature.is_data_source_external?
      xml.tag!(:creative_commons_license, creative_commons_license.name) unless creative_commons_license.nil?
    end
  end

   
end
