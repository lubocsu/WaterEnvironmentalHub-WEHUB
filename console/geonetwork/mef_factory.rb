require 'net/http'
require 'zip/zip'
require 'active_support/core_ext'

class MefFactory
  attr_accessor :server_address, :temp_directory
  
  def initialize(temp_directory='tmp/mefs', server_address='localhost:3000')
    @server_address = server_address
    @temp_directory = temp_directory
  end
  
  def metadata(uuid)
    http_get("http://#{server_address}/geonetwork/metadata/#{uuid}.xml")
  end
  
  def info(uuid)
    http_get("http://#{server_address}/geonetwork/info/#{uuid}.xml")
  end
  
  def filepath(uuid)
    "#{Dir.getwd}/#{temp_directory}/#{filename(uuid)}"
  end
  
  def filename(uuid)
    "#{uuid}.mef"
  end
  
  def build(uuid)
    puts "\nBuilding Mef file for #{uuid}"
    
    files = {}
    files.store('metadata.xml', metadata(uuid))
    files.store('info.xml', info(uuid))
    
    directories = ['private', 'public']
    
    Zip::ZipFile.open(filepath(uuid), Zip::ZipFile::CREATE) do |zip|
      files.each do |key, value|
        zip.get_output_stream("#{key}") { |f| f.puts value }  
      end
      directories.each do |directory|
        if !zip.find_entry(directory)
          zip.mkdir(directory)
        end
      end
    end
    
    puts "Success! Mef #{filepath(uuid)} was built"    
  end
  
  def build_all
    uuid_list = Hash.from_xml(http_get("http://#{server_address}/geonetwork/mef-import-list.xml"))['strings']
    puts "#{uuid_list.count} Mef files will be created"
    
    uuid_list.each do |uuid|
      build(uuid)
    end
  end
  
  def http_get(uri)
    puts "Getting #{uri}"
    url = URI.parse(uri)
    request = Net::HTTP::Get.new(url.to_s)    
    response = Net::HTTP.start(url.host, url.port) {|http| http.request(request)}
    response.body
  end
end
